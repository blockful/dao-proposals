// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { ENS_Governance } from "@ens/ens.t.sol";
import { ENSConstants } from "@ens/Constants.sol";
import { SafeHelper } from "@ens/helpers/SafeHelper.sol";
import { ISafe } from "@ens/interfaces/ISafe.sol";
import { IENSToken } from "@ens/interfaces/IENSToken.sol";
import { ITimelock } from "@ens/interfaces/ITimelock.sol";
import { ISecurityCouncil } from "@ens/interfaces/ISecurityCouncil.sol";
import { IRolesModifier } from "@ens/interfaces/IRolesModifier.sol";

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

    /// @dev Endowment modules that must survive the owner swap untouched
    address internal constant ENDOWMENT_ZODIAC_ROLES = 0x703806E61847984346d2D7DDd853049627e50A40;
    address internal constant ENDOWMENT_ALLOWANCE_MODULE = 0xCFbFaC74C26F8647cBDb8c5caf80BB5b32E43134;

    /// @dev The two Foundation Safe owners without ENS reverse records (presumed
    ///      Brett Sun / Anthony Leutenegger — flagged for public confirmation)
    address internal constant FOUNDATION_OWNER_4 = 0x595703734b85452B467E82fFc794C3cb212C204a;
    address internal constant FOUNDATION_OWNER_5 = 0x81Ba03CaA16D7b29fA9e0b9FCE64cca7CC68CAcc;
    address internal constant ALEXURBELIS_ETH = 0x481d11fC39324FAA54B736e84bdD45998EEf1ea8;
    address internal constant KARTIK_ETH = 0x53C61cfb8128ad59244E8c1D26109252ACe23d14;

    /// @dev Runtime codehashes pinned at the reviewed fork block. The wrapper hash
    ///      was additionally diffed off-chain against the verified
    ///      blockful/security-council-ens deployment (0x2acBf518…) — identical except
    ///      the embedded timelock immutable. The timelock hash corresponds to the
    ///      Sourcify-verified EndowmentTimelock, whose bundled TimelockController is
    ///      byte-identical to canonical OZ v4.3.2.
    bytes32 internal constant SC_VETO_CODEHASH = 0xe589f30fb03183570c32359833596e0a555a9db1b34c383beccfd46808cb9ce3;
    bytes32 internal constant ENDOWMENT_TIMELOCK_CODEHASH =
        0x8cc4f7b6e858765b5e7a86de0ddd527f92338814901e37c7215e5acc5f48071b;

    uint256 internal constant FOUNDATION_ENS_GRANT = 1_000_000e18;
    uint256 internal constant ENDOWMENT_TIMELOCK_MIN_DELAY = 9 days;
    uint256 internal constant SC_VETO_EXPIRATION = 1_849_227_635; // 2028-08-07 UTC (deploy + 2y + 1wk)

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

        // Snapshot enabled modules — must be exactly the two known ones and untouched:
        //   1. Zodiac Roles v2 modifier (karpatkey manager pod, DeFi-scoped MANAGER role)
        //   2. Safe Allowance Module (30 ETH / 25-day ETH spending limit delegated to
        //      main.mg.wg.ens.eth — bypasses owner signatures and survives the swap)
        // The `next` pointer must be the sentinel, proving the list is complete.
        address next;
        (endowmentModulesBefore, next) = endowmentSafe.getModulesPaginated(SENTINEL_OWNERS, 10);
        assertEq(next, SENTINEL_OWNERS, "endowment: module list must be complete");
        assertEq(endowmentModulesBefore.length, 2, "endowment: expected 2 enabled modules");
        assertEq(endowmentModulesBefore[0], ENDOWMENT_ZODIAC_ROLES, "endowment: module 0 must be Zodiac Roles");
        assertEq(endowmentModulesBefore[1], ENDOWMENT_ALLOWANCE_MODULE, "endowment: module 1 must be Allowance Module");

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

        // AccessControl is not enumerable on-chain, so exact membership was proven
        // off-chain from the complete event history: the timelock emitted exactly 10
        // events between deployment (block 25_656_954) and the admin renounce
        // (block 25_657_026) — 3 RoleAdminChanged, 5 RoleGranted (admin: deployer +
        // self; proposer: Foundation Safe + SC veto wrapper; executor: address(0)),
        // 1 MinDelayChange, 1 RoleRevoked (deployer's admin) — and nothing since.
        // The negative checks below pin every other plausible privileged candidate.
        address[6] memory nonPrivileged = [
            address(timelock), // DAO timelock holds NO role on the new stack
            address(governor),
            SECURITY_COUNCIL_SAFE, // SC acts only through the veto wrapper
            ENSConstants.KARPATKEY,
            ENDOWMENT_TIMELOCK_DEPLOYER,
            SC_VETO_CONTRACT // wrapper is proposer only — never admin
        ];
        for (uint256 i = 0; i < nonPrivileged.length; i++) {
            assertFalse(endowmentTimelock.hasRole(TIMELOCK_ADMIN_ROLE, nonPrivileged[i]), "unexpected admin");
        }
        assertFalse(endowmentTimelock.hasRole(PROPOSER_ROLE, address(timelock)));
        assertFalse(endowmentTimelock.hasRole(PROPOSER_ROLE, address(governor)));
        assertFalse(endowmentTimelock.hasRole(PROPOSER_ROLE, SECURITY_COUNCIL_SAFE));
        assertFalse(endowmentTimelock.hasRole(PROPOSER_ROLE, ENSConstants.KARPATKEY));
        assertFalse(endowmentTimelock.hasRole(PROPOSER_ROLE, ENDOWMENT_TIMELOCK_DEPLOYER));

        // Pin the exact deployed code of both new privileged contracts so the
        // reviewed semantics (OZ v4.3.2 timelock; cancel-only veto wrapper) are
        // reproducible from this test alone.
        assertEq(ENDOWMENT_TIMELOCK.codehash, ENDOWMENT_TIMELOCK_CODEHASH, "timelock code drifted");
        assertEq(SC_VETO_CONTRACT.codehash, SC_VETO_CODEHASH, "veto wrapper code drifted");

        // Role administration is self-gated: every grant/revoke must be scheduled through
        // the timelock itself (9-day delay), which the Security Council can veto. This is
        // what prevents the Foundation from silently stripping the SC's cancel right.
        assertEq(endowmentTimelock.getRoleAdmin(PROPOSER_ROLE), TIMELOCK_ADMIN_ROLE);
        assertEq(endowmentTimelock.getRoleAdmin(EXECUTOR_ROLE), TIMELOCK_ADMIN_ROLE);
        assertEq(endowmentTimelock.getRoleAdmin(TIMELOCK_ADMIN_ROLE), TIMELOCK_ADMIN_ROLE);

        // ── Security Council veto wrapper: cancel authority wired to the SC Safe ──
        ISecurityCouncil scVeto = ISecurityCouncil(SC_VETO_CONTRACT);
        assertEq(scVeto.owner(), SECURITY_COUNCIL_SAFE);
        assertEq(scVeto.timelock(), ENDOWMENT_TIMELOCK);
        assertEq(scVeto.expiration(), SC_VETO_EXPIRATION, "veto expiration must be 2028-08-07");
        assertGt(scVeto.expiration(), block.timestamp, "veto power must not be expired");

        // ── Foundation Safe: exactly the five approved board signers, 3-of-5 ──
        ISafe foundationSafe = ISafe(ENS_FOUNDATION_SAFE);
        address[] memory foundationOwners = foundationSafe.getOwners();
        assertEq(foundationOwners.length, 5);
        assertEq(foundationSafe.getThreshold(), 3);
        assertEq(foundationOwners[0], _proposer(), "owner 0 must be nick.eth");
        assertEq(foundationOwners[1], ALEXURBELIS_ETH, "owner 1 must be alexurbelis.eth");
        assertEq(foundationOwners[2], FOUNDATION_OWNER_4, "owner 2 changed");
        assertEq(foundationOwners[3], FOUNDATION_OWNER_5, "owner 3 changed");
        assertEq(foundationOwners[4], KARTIK_ETH, "owner 4 must be kartik.eth");

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

        // ── Adversarial: the Foundation cannot strip the Security Council's veto
        //    right directly — revokeRole is gated by TIMELOCK_ADMIN_ROLE, held only
        //    by the timelock itself, so any role change must be scheduled (9 days)
        //    and is itself vetoable ──
        vm.prank(ENS_FOUNDATION_SAFE);
        vm.expectRevert();
        endowmentTimelock.revokeRole(PROPOSER_ROLE, SC_VETO_CONTRACT);
        assertTrue(endowmentTimelock.hasRole(PROPOSER_ROLE, SC_VETO_CONTRACT), "SC veto right must survive");

        // ── Adversarial: nobody can shorten the delay directly either ──
        vm.prank(ENS_FOUNDATION_SAFE);
        vm.expectRevert(bytes("TimelockController: caller must be timelock"));
        endowmentTimelock.updateDelay(0);

        // ── Adversarial: the SC wrapper holds PROPOSER_ROLE but exposes no schedule
        //    forwarding — the Security Council can cancel, never initiate ──
        vm.prank(SECURITY_COUNCIL_SAFE);
        (bool scheduledViaWrapper,) = SC_VETO_CONTRACT.call(
            abi.encodeWithSelector(
                ITimelock.schedule.selector,
                address(endowmentSafe),
                0,
                innerExec,
                bytes32(0),
                keccak256("sc-cannot-schedule"),
                ENDOWMENT_TIMELOCK_MIN_DELAY
            )
        );
        assertFalse(scheduledViaWrapper, "SC wrapper must not forward schedule calls");

        // ── Adversarial: neither module path can touch the Safe's owner set.
        //    This closes the last on-chain recovery/takeover vector outside the
        //    Foundation timelock path: karpatkey's MANAGER role is DeFi-scoped and
        //    holds no Safe owner-management permissions (the Allowance Module is
        //    structurally transfer-only — its entrypoint takes no calldata at all) ──
        bytes memory evictData =
            abi.encodeWithSelector(ISafe.swapOwner.selector, SENTINEL_OWNERS, ENDOWMENT_TIMELOCK, address(0xBEEF));
        vm.prank(ENSConstants.KARPATKEY); // ens-endowment.pod.xyz — sole MANAGER member
        vm.expectRevert();
        IRolesModifier(ENDOWMENT_ZODIAC_ROLES)
            .execTransactionWithRole(address(endowmentSafe), 0, evictData, 0, "MANAGER", true);
        assertTrue(endowmentSafe.isOwner(ENDOWMENT_TIMELOCK), "owner set must be unchanged");
        assertFalse(endowmentSafe.isOwner(address(0xBEEF)));

        // A non-module cannot reach execTransactionFromModule at all (Safe GS104)
        vm.prank(address(0xBEEF));
        vm.expectRevert(bytes("GS104"));
        endowmentSafe.execTransactionFromModule(address(endowmentSafe), 0, evictData, 0);
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return false; // Draft — not yet on-chain
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-empowering-ens-foundation";
    }
}
