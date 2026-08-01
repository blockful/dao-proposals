// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { ENS_Governance } from "@ens/ens.t.sol";
import { ENSConstants } from "@ens/Constants.sol";
import { SafeHelper } from "@ens/helpers/SafeHelper.sol";
import { ISafe } from "@ens/interfaces/ISafe.sol";
import { IENSToken } from "@ens/interfaces/IENSToken.sol";
import { ITimelock } from "@ens/interfaces/ITimelock.sol";
import { ISecurityCouncil } from "@ens/interfaces/ISecurityCouncil.sol";

/// @notice Draft review of "[Executable] Next Era of ENS DAO: Empowering the ENS Foundation"
///         (Tally draft 2913928210729141431, proposed by nick.eth).
///
///         The proposal executes two calls from the DAO timelock (wallet.ensdao.eth):
///           1. ENS.transfer(ENS_FOUNDATION_SAFE, 1_000_000e18) — one-time grant restricted
///              to Foundation employee compensation.
///           2. endowmentSafe.execTransaction(swapOwner(SENTINEL, timelock, ENDOWMENT_TIMELOCK))
///              — replaces the DAO timelock as sole owner (threshold 1) of the Endowment Safe
///              (endowment.ensdao.eth) with a dedicated EndowmentTimelock.
///
///         On-chain configuration of the new control stack (verified in _beforeProposal):
///           - ENDOWMENT_TIMELOCK is OZ TimelockController v4.3.2 (Sourcify exact match,
///             OZ source byte-identical to the canonical v4.3.2 release), minDelay = 9 days.
///           - PROPOSER_ROLE: the Foundation Safe (3-of-5) and the Security Council veto
///             contract (cancel-only wrapper, owner = the 5-of-8 Security Council Safe;
///             runtime bytecode identical to the verified blockful/security-council-ens
///             deployment except for the embedded timelock immutable).
///           - EXECUTOR_ROLE: open (address(0)).
///           - TIMELOCK_ADMIN_ROLE: only the timelock itself (deployer renounced).
contract Proposal_ENS_EP_Empowering_ENS_Foundation_Draft_Test is ENS_Governance, SafeHelper {
    // ─── Proposal actors (verified on-chain, see PR description) ───────────
    /// @dev 3-of-5 Safe (v1.4.1); owners include nick.eth, alexurbelis.eth, kartik.eth
    address internal constant ENS_FOUNDATION_SAFE = 0x9C7dB6B1085ec4D07f75c0BD91AD3FcD368fA19E;
    /// @dev EndowmentTimelock — OZ TimelockController v4.3.2, deployed by ens.gregskril.eth
    address internal constant ENDOWMENT_TIMELOCK = 0x0bcC3dA6aD796F59288C0961602675E88A2B406C;
    /// @dev Security Council veto wrapper (cancel-only) pointed at ENDOWMENT_TIMELOCK
    address internal constant SC_VETO_CONTRACT = 0x0A9387643ce6291f8C545286675D76bCd0Ba3EdD;
    /// @dev 5-of-8 Security Council Safe (owner of SC_VETO_CONTRACT)
    address internal constant SECURITY_COUNCIL_SAFE = 0x7101B78638e34444F0a5AdE9e1149fbEeC029931;
    /// @dev Deployer of ENDOWMENT_TIMELOCK — must NOT retain admin
    address internal constant ENDOWMENT_TIMELOCK_DEPLOYER = 0x8764f2939aE6ed4EcB5baD2cdB7e2B81aA153bd1;
    /// @dev Safe OwnerManager linked-list sentinel
    address internal constant SENTINEL_OWNERS = address(0x1);

    uint256 internal constant FOUNDATION_ENS_GRANT = 1_000_000e18;
    uint256 internal constant ENDOWMENT_TIMELOCK_MIN_DELAY = 9 days;

    ITimelock internal endowmentTimelock = ITimelock(payable(ENDOWMENT_TIMELOCK));

    // ─── State snapshots
    // ───────────────────────────────────────────────────
    uint256 internal timelockEnsBalanceBefore;
    uint256 internal foundationEnsBalanceBefore;
    address[] internal endowmentModulesBefore;

    function _selectFork() public override {
        // After block 25_657_026, where the EndowmentTimelock deployer renounced
        // TIMELOCK_ADMIN_ROLE — the final role configuration this review depends on.
        vm.createSelectFork({ blockNumber: 25_659_000, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0xb8c2C29ee19D8307cb7255e1Cd9CbDE883A267d5; // nick.eth (draft author)
    }

    function _beforeProposal() public override {
        // ── Endowment Safe: DAO timelock is the sole owner, threshold 1 ──
        address[] memory owners = endowmentSafe.getOwners();
        assertEq(owners.length, 1, "endowment: expected single owner");
        assertEq(owners[0], address(timelock), "endowment: owner must be DAO timelock");
        assertEq(endowmentSafe.getThreshold(), 1, "endowment: threshold must be 1");
        assertTrue(endowmentSafe.isOwner(address(timelock)));
        assertFalse(endowmentSafe.isOwner(ENDOWMENT_TIMELOCK));

        // Snapshot enabled modules (karpatkey Endowment Manager) — must be untouched.
        (endowmentModulesBefore,) = endowmentSafe.getModulesPaginated(SENTINEL_OWNERS, 10);
        assertEq(endowmentModulesBefore.length, 2, "endowment: expected 2 enabled modules");

        // ── EndowmentTimelock: role configuration matches the proposal's claims ──
        assertEq(endowmentTimelock.getMinDelay(), ENDOWMENT_TIMELOCK_MIN_DELAY);
        assertTrue(endowmentTimelock.hasRole(PROPOSER_ROLE, ENS_FOUNDATION_SAFE));
        assertTrue(endowmentTimelock.hasRole(PROPOSER_ROLE, SC_VETO_CONTRACT));
        assertTrue(endowmentTimelock.hasRole(EXECUTOR_ROLE, address(0)), "executor role must be open");
        assertTrue(endowmentTimelock.hasRole(TIMELOCK_ADMIN_ROLE, ENDOWMENT_TIMELOCK), "self-administered");
        assertFalse(
            endowmentTimelock.hasRole(TIMELOCK_ADMIN_ROLE, ENDOWMENT_TIMELOCK_DEPLOYER),
            "deployer must have renounced admin"
        );
        assertFalse(endowmentTimelock.hasRole(TIMELOCK_ADMIN_ROLE, ENS_FOUNDATION_SAFE));

        // ── Security Council veto wrapper: cancel authority wired to the SC Safe ──
        ISecurityCouncil scVeto = ISecurityCouncil(SC_VETO_CONTRACT);
        assertEq(scVeto.owner(), SECURITY_COUNCIL_SAFE);
        assertEq(scVeto.timelock(), ENDOWMENT_TIMELOCK);
        assertGt(scVeto.expiration(), block.timestamp, "veto power must not be expired");

        // ── Foundation Safe: 3-of-5 with the draft author as an owner ──
        ISafe foundationSafe = ISafe(ENS_FOUNDATION_SAFE);
        assertEq(foundationSafe.getOwners().length, 5);
        assertEq(foundationSafe.getThreshold(), 3);
        assertTrue(foundationSafe.isOwner(_proposer()), "nick.eth must be a Foundation Safe owner");

        // ── Balances ──
        timelockEnsBalanceBefore = ensToken.balanceOf(address(timelock));
        foundationEnsBalanceBefore = ensToken.balanceOf(ENS_FOUNDATION_SAFE);
        assertGe(timelockEnsBalanceBefore, FOUNDATION_ENS_GRANT, "timelock must hold >= 1M ENS");
    }

    function _generateCallData()
        public
        override
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory, string memory)
    {
        uint256 numTransactions = 2;

        targets = new address[](numTransactions);
        values = new uint256[](numTransactions);
        calldatas = new bytes[](numTransactions);
        signatures = new string[](numTransactions);

        // 1. One-time transfer of 1,000,000 ENS to the Foundation Safe.
        targets[0] = ENSConstants.ENS_TOKEN;
        calldatas[0] = abi.encodeWithSelector(IENSToken.transfer.selector, ENS_FOUNDATION_SAFE, FOUNDATION_ENS_GRANT);
        values[0] = 0;
        signatures[0] = "";

        // 2. Swap the Endowment Safe's sole owner: DAO timelock -> EndowmentTimelock.
        //    prevOwner is the sentinel because the timelock is the head (and only entry)
        //    of the Safe owner linked list. Executed via execTransaction with the DAO
        //    timelock's pre-approved signature (msg.sender == owner, threshold 1).
        bytes memory swapOwnerData =
            abi.encodeWithSelector(ISafe.swapOwner.selector, SENTINEL_OWNERS, address(timelock), ENDOWMENT_TIMELOCK);
        (targets[1], calldatas[1]) =
            _buildSafeExecCalldata(address(endowmentSafe), address(endowmentSafe), swapOwnerData, address(timelock));
        values[1] = 0;
        signatures[1] = "";

        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        // ── 1M ENS moved, exactly ──
        assertEq(
            ensToken.balanceOf(ENS_FOUNDATION_SAFE),
            foundationEnsBalanceBefore + FOUNDATION_ENS_GRANT,
            "foundation must receive exactly 1M ENS"
        );
        assertEq(
            ensToken.balanceOf(address(timelock)),
            timelockEnsBalanceBefore - FOUNDATION_ENS_GRANT,
            "timelock must send exactly 1M ENS"
        );

        // ── Endowment Safe ownership swapped, nothing else changed ──
        address[] memory owners = endowmentSafe.getOwners();
        assertEq(owners.length, 1, "endowment: still a single owner");
        assertEq(owners[0], ENDOWMENT_TIMELOCK, "endowment: owner must be the EndowmentTimelock");
        assertEq(endowmentSafe.getThreshold(), 1, "endowment: threshold unchanged");
        assertTrue(endowmentSafe.isOwner(ENDOWMENT_TIMELOCK));
        assertFalse(endowmentSafe.isOwner(address(timelock)), "DAO timelock must no longer be an owner");

        (address[] memory modulesAfter,) = endowmentSafe.getModulesPaginated(SENTINEL_OWNERS, 10);
        assertEq(modulesAfter.length, endowmentModulesBefore.length, "modules must be untouched");
        for (uint256 i = 0; i < modulesAfter.length; i++) {
            assertEq(modulesAfter[i], endowmentModulesBefore[i], "module entry changed");
        }

        // ── Negative: the DAO timelock lost direct owner control of the Endowment ──
        bytes memory oneWeiToFoundation = "";
        vm.prank(address(timelock));
        vm.expectRevert(bytes("GS026")); // signer is not an owner
        endowmentSafe.execTransaction(
            ENS_FOUNDATION_SAFE,
            1,
            oneWeiToFoundation,
            0,
            0,
            0,
            0,
            address(0),
            address(0),
            _buildPreApprovedSignature(address(timelock))
        );

        // ── Negative: the Foundation Safe has no direct owner control either ──
        vm.prank(ENS_FOUNDATION_SAFE);
        vm.expectRevert(bytes("GS026"));
        endowmentSafe.execTransaction(
            ENS_FOUNDATION_SAFE,
            1,
            oneWeiToFoundation,
            0,
            0,
            0,
            0,
            address(0),
            address(0),
            _buildPreApprovedSignature(ENS_FOUNDATION_SAFE)
        );

        // ── Functional: owner-path Endowment transactions now flow through the
        //    9-day EndowmentTimelock, the Security Council can cancel while queued,
        //    and execution works after the delay ──
        bytes memory innerExec = abi.encodeWithSelector(
            ISafe.execTransaction.selector,
            ENS_FOUNDATION_SAFE, // to: send 1 wei of Endowment ETH to the Foundation Safe
            uint256(1),
            oneWeiToFoundation,
            uint8(0),
            uint256(0),
            uint256(0),
            uint256(0),
            address(0),
            address(0),
            _buildPreApprovedSignature(ENDOWMENT_TIMELOCK)
        );

        // A random address cannot schedule (no PROPOSER_ROLE)
        assertFalse(endowmentTimelock.hasRole(PROPOSER_ROLE, address(this)));
        vm.expectRevert();
        endowmentTimelock.schedule(
            address(endowmentSafe), 0, innerExec, bytes32(0), keccak256("unauthorized"), ENDOWMENT_TIMELOCK_MIN_DELAY
        );

        // (a) Foundation schedules, Security Council cancels
        bytes32 saltVetoed = keccak256("ep-foundation-review-vetoed");
        vm.prank(ENS_FOUNDATION_SAFE);
        endowmentTimelock.schedule(
            address(endowmentSafe), 0, innerExec, bytes32(0), saltVetoed, ENDOWMENT_TIMELOCK_MIN_DELAY
        );
        bytes32 vetoedId = endowmentTimelock.hashOperation(address(endowmentSafe), 0, innerExec, bytes32(0), saltVetoed);
        assertTrue(endowmentTimelock.isOperationPending(vetoedId));

        vm.prank(SECURITY_COUNCIL_SAFE);
        ISecurityCouncil(SC_VETO_CONTRACT).veto(vetoedId);
        assertFalse(endowmentTimelock.isOperation(vetoedId), "vetoed operation must be cancelled");

        // (b) Foundation schedules again; execution blocked before the delay,
        //     succeeds after 9 days with the expected 1 wei effect
        bytes32 saltExecuted = keccak256("ep-foundation-review-executed");
        vm.prank(ENS_FOUNDATION_SAFE);
        endowmentTimelock.schedule(
            address(endowmentSafe), 0, innerExec, bytes32(0), saltExecuted, ENDOWMENT_TIMELOCK_MIN_DELAY
        );
        bytes32 executedId =
            endowmentTimelock.hashOperation(address(endowmentSafe), 0, innerExec, bytes32(0), saltExecuted);

        vm.expectRevert(bytes("TimelockController: operation is not ready"));
        endowmentTimelock.execute(address(endowmentSafe), 0, innerExec, bytes32(0), saltExecuted);

        uint256 endowmentEthBefore = address(endowmentSafe).balance;
        uint256 foundationEthBefore = ENS_FOUNDATION_SAFE.balance;

        vm.warp(block.timestamp + ENDOWMENT_TIMELOCK_MIN_DELAY + 1);
        // EXECUTOR_ROLE is open — any caller may execute once ready
        endowmentTimelock.execute(address(endowmentSafe), 0, innerExec, bytes32(0), saltExecuted);

        assertTrue(endowmentTimelock.isOperationDone(executedId));
        assertEq(address(endowmentSafe).balance, endowmentEthBefore - 1, "endowment must send 1 wei");
        assertEq(ENS_FOUNDATION_SAFE.balance, foundationEthBefore + 1, "foundation must receive 1 wei");
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return false; // Draft — not yet on-chain
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-empowering-ens-foundation";
    }
}
