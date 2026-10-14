// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";

import { ENSConstants } from "@ens/Constants.sol";
import { MultiSendHelper } from "@ens/helpers/MultiSendHelper.sol";
import { IMultiSend } from "@ens/interfaces/IMultiSend.sol";
import { ISafe } from "@ens/interfaces/ISafe.sol";
import { ISecurityCouncil } from "@ens/interfaces/ISecurityCouncil.sol";
import { ITimelock } from "@ens/interfaces/ITimelock.sol";

interface IAllowanceModule {
    function addDelegate(address delegate) external;
    function removeDelegate(address delegate, bool removeAllowances) external;
    function setAllowance(
        address delegate,
        address token,
        uint96 allowanceAmount,
        uint16 resetTimeMin,
        uint32 resetBaseMin
    )
        external;
    function executeAllowanceTransfer(
        address safe,
        address token,
        address payable to,
        uint96 amount,
        address paymentToken,
        uint96 payment,
        address delegate,
        bytes memory signature
    )
        external;
    function getDelegates(
        address safe,
        uint48 start,
        uint8 pageSize
    )
        external
        view
        returns (address[] memory results, uint48 next);
    function getTokens(address safe, address delegate) external view returns (address[] memory);
    function getTokenAllowance(address safe, address delegate, address token) external view returns (uint256[5] memory);
}

interface ISafeNonce {
    function nonce() external view returns (uint256);
}

/**
 * @title ENS Foundation takes over the kpk management fee
 * @notice https://discuss.ens.domains/t/draft-executable-next-era-of-ens-dao-empowering-the-ens-foundation/22329
 *
 * The kpk fee is paid with the Safe Allowance Module on the Endowment Safe. The Meta-Gov Safe is
 * the only delegate today (EP 5.6: 30 ETH; EP 6.2: 25-day reset). This change moves the delegate
 * to the Foundation Safe with the same parameters. The Foundation schedules it on the Endowment
 * timelock (not a DAO vote), so the test runs it through the timelock.
 *
 * schedule.json / execute.json are the Safe Transaction Builder batches for the Foundation Safe.
 */
contract Proposal_ENS_Foundation_KPK_Fee_Delegate_Test is Test, MultiSendHelper {
    string private constant SCHEDULE_JSON = "src/ens/proposals/ep-foundation-kpk-fee-delegate/schedule.json";
    string private constant EXECUTE_JSON = "src/ens/proposals/ep-foundation-kpk-fee-delegate/execute.json";

    // ─── Endowment
    address private constant SAFE = ENSConstants.ENDOWMENT_SAFE;
    address private constant FOUNDATION = ENSConstants.FOUNDATION_SAFE;
    address private constant META_GOV = ENSConstants.META_GOV_MULTISIG;
    address private constant NEW_MAIN = 0xa23BEBFD3628D6Dd7B0638c147db11d9B6FaBD59;
    address payable private constant KPK_FEE_SAFE = payable(0x58e6c7ab55Aa9012eAccA16d1ED4c15795669E1C);
    address private constant SENTINEL = address(0x1);
    address private constant ETH = address(0);

    // ─── Allowance (same values as EP 6.2, Endowment Safe nonce 20)
    uint96 private constant ALLOWANCE = 30 ether;
    uint16 private constant RESET_TIME_MIN = 36_000; // 25 days
    uint32 private constant RESET_BASE_MIN = 28_825_613;

    // ─── Timelock op
    bytes32 private constant SALT = "ENS-KPK-FEE-DELEGATE";
    address private constant MULTI_SEND_CALL_ONLY_V141 = 0x9641d764fc13c8B624c04430C7356C1C7C8102e2;

    IAllowanceModule private constant allowanceModule = IAllowanceModule(ENSConstants.ALLOWANCE_MODULE);
    ITimelock private constant endowmentTimelock = ITimelock(payable(ENSConstants.ENDOWMENT_TIMELOCK));

    uint256 private safeNonceBefore;
    uint256 private metaGovNonceBefore;

    function setUp() public {
        // After the Update #10 Modifier switch (block 26,177,043) and the Oct 2026 fee (15.71 ETH)
        vm.createSelectFork({ blockNumber: 26_192_000, urlOrAlias: "mainnet" });
    }

    function test_proposal() public {
        _beforeProposal();
        bytes memory execData = _generateCallData();
        _callDataComparison(execData);
        _executeViaEndowmentTimelock(execData);
        _afterExecution();
        _feePulls();
    }

    /// @notice Control: with ETH in the Safe, the Meta-Gov Safe can pull the fee today.
    function test_metaGovPullsBeforeSwitch() public {
        vm.deal(SAFE, 30 ether);
        uint256 kpkBefore = KPK_FEE_SAFE.balance;
        _pull(META_GOV, 1 ether);
        assertEq(KPK_FEE_SAFE.balance - kpkBefore, 1 ether, "kpk received");
    }

    /// @notice The Security Council can cancel the op during the 9 days.
    function test_securityCouncilCanVeto() public {
        bytes memory execData = _generateCallData();
        vm.prank(FOUNDATION);
        endowmentTimelock.schedule(SAFE, 0, execData, bytes32(0), SALT, 9 days);
        bytes32 id = endowmentTimelock.hashOperation(SAFE, 0, execData, bytes32(0), SALT);
        assertTrue(endowmentTimelock.isOperationPending(id), "scheduled");

        vm.prank(ENSConstants.SECURITY_COUNCIL_SAFE);
        ISecurityCouncil(ENSConstants.SECURITY_COUNCIL_VETO).veto(id);
        assertFalse(endowmentTimelock.isOperation(id), "cancelled");

        vm.warp(block.timestamp + 9 days);
        vm.expectRevert(bytes("TimelockController: operation is not ready"));
        endowmentTimelock.execute(SAFE, 0, execData, bytes32(0), SALT);
    }

    /// @notice Trust assumption, unchanged from today: the module caps the amount per period but
    ///         lets the delegate choose any recipient. Paying kpk only is a process rule.
    function test_delegateChoosesRecipient() public {
        _executeViaEndowmentTimelock(_generateCallData());
        vm.deal(SAFE, 30 ether);
        address payable other = payable(makeAddr("not-kpk"));
        vm.prank(FOUNDATION);
        allowanceModule.executeAllowanceTransfer(SAFE, ETH, other, 1 ether, ETH, 0, FOUNDATION, "");
        assertEq(other.balance, 1 ether, "any recipient");
    }

    // ─── Before
    // ───────────────────────────────────────────────────

    function _beforeProposal() internal {
        // The timelock owns the Safe; the Foundation Safe can schedule on it
        address[] memory owners = ISafe(SAFE).getOwners();
        assertEq(owners.length, 1, "Safe owner count");
        assertEq(owners[0], ENSConstants.ENDOWMENT_TIMELOCK, "Safe owner");
        assertEq(ISafe(SAFE).getThreshold(), 1, "Safe threshold");
        assertEq(endowmentTimelock.getMinDelay(), 9 days, "timelock delay");
        assertTrue(endowmentTimelock.hasRole(endowmentTimelock.PROPOSER_ROLE(), FOUNDATION), "Foundation proposes");
        assertFalse(endowmentTimelock.hasRole(endowmentTimelock.PROPOSER_ROLE(), META_GOV), "Meta-Gov does not");
        assertTrue(endowmentTimelock.hasRole(endowmentTimelock.EXECUTOR_ROLE(), address(0)), "anyone executes");
        _assertModules();
        safeNonceBefore = ISafeNonce(SAFE).nonce();

        // Meta-Gov is the only delegate, with the EP 6.2 allowance
        _assertDelegates(META_GOV);
        uint256[5] memory mg = allowanceModule.getTokenAllowance(SAFE, META_GOV, ETH);
        assertEq(mg[0], ALLOWANCE, "Meta-Gov amount");
        assertEq(mg[2], RESET_TIME_MIN, "Meta-Gov reset");
        assertEq((mg[3] - RESET_BASE_MIN) % RESET_TIME_MIN, 0, "Meta-Gov period is on the EP 6.2 cycle");
        metaGovNonceBefore = mg[4];

        uint256[5] memory f = allowanceModule.getTokenAllowance(SAFE, FOUNDATION, ETH);
        assertEq(f[0] + f[1] + f[2] + f[3] + f[4], 0, "Foundation has no allowance");
    }

    // ─── Calldata
    // ─────────────────────────────────────────────────

    function _generateCallData() internal pure returns (bytes memory execData) {
        bytes memory batch = bytes.concat(
            _packCall(address(allowanceModule), abi.encodeCall(IAllowanceModule.addDelegate, (FOUNDATION))),
            _packCall(
                address(allowanceModule),
                abi.encodeCall(
                    IAllowanceModule.setAllowance, (FOUNDATION, ETH, ALLOWANCE, RESET_TIME_MIN, RESET_BASE_MIN)
                )
            ),
            _packCall(address(allowanceModule), abi.encodeCall(IAllowanceModule.removeDelegate, (META_GOV, true)))
        );

        // Endowment Safe tx signed by the timelock, batched with MultiSendCallOnly 1.4.1 (as in Update #10)
        (, execData) = _buildSafeExecDelegateCalldata(
            SAFE,
            MULTI_SEND_CALL_ONLY_V141,
            abi.encodeCall(IMultiSend.multiSend, (batch)),
            ENSConstants.ENDOWMENT_TIMELOCK
        );
    }

    /// @dev Both Safe Transaction Builder files must match the derived op exactly.
    function _callDataComparison(bytes memory execData) internal view {
        string memory json = vm.readFile(SCHEDULE_JSON);
        _assertBatch(json, "schedule");
        assertEq(_signature(json), "schedule(address,uint256,bytes,bytes32,bytes32,uint256)", "schedule method");
        assertEq(vm.parseJsonAddress(json, ".transactions[0].contractInputsValues.target"), SAFE, "schedule target");
        assertEq(vm.parseJsonUint(json, ".transactions[0].contractInputsValues.value"), 0, "schedule value");
        assertEq(vm.parseJsonBytes(json, ".transactions[0].contractInputsValues.data"), execData, "schedule data");
        assertEq(
            vm.parseJsonBytes32(json, ".transactions[0].contractInputsValues.predecessor"),
            bytes32(0),
            "schedule predecessor"
        );
        assertEq(vm.parseJsonBytes32(json, ".transactions[0].contractInputsValues.salt"), SALT, "schedule salt");
        assertEq(vm.parseJsonUint(json, ".transactions[0].contractInputsValues.delay"), 9 days, "schedule delay");

        json = vm.readFile(EXECUTE_JSON);
        _assertBatch(json, "execute");
        assertEq(_signature(json), "execute(address,uint256,bytes,bytes32,bytes32)", "execute method");
        assertEq(vm.parseJsonAddress(json, ".transactions[0].contractInputsValues.target"), SAFE, "execute target");
        assertEq(vm.parseJsonUint(json, ".transactions[0].contractInputsValues.value"), 0, "execute value");
        assertEq(vm.parseJsonBytes(json, ".transactions[0].contractInputsValues.payload"), execData, "execute data");
        assertEq(
            vm.parseJsonBytes32(json, ".transactions[0].contractInputsValues.predecessor"),
            bytes32(0),
            "execute predecessor"
        );
        assertEq(vm.parseJsonBytes32(json, ".transactions[0].contractInputsValues.salt"), SALT, "execute salt");
    }

    function _executeViaEndowmentTimelock(bytes memory execData) internal {
        vm.prank(META_GOV);
        vm.expectRevert();
        endowmentTimelock.schedule(SAFE, 0, execData, bytes32(0), SALT, 9 days);

        vm.prank(FOUNDATION);
        endowmentTimelock.schedule(SAFE, 0, execData, bytes32(0), SALT, 9 days);

        vm.expectRevert(bytes("TimelockController: operation is not ready"));
        endowmentTimelock.execute(SAFE, 0, execData, bytes32(0), SALT);

        vm.warp(block.timestamp + 9 days);
        vm.prank(address(0xA11CE)); // anyone can execute
        endowmentTimelock.execute(SAFE, 0, execData, bytes32(0), SALT);
    }

    // ─── After
    // ────────────────────────────────────────────────────

    function _afterExecution() internal view {
        // Only the delegate changed
        address[] memory owners = ISafe(SAFE).getOwners();
        assertEq(owners.length, 1, "Safe owner count");
        assertEq(owners[0], ENSConstants.ENDOWMENT_TIMELOCK, "Safe owner");
        _assertModules();
        assertEq(ISafeNonce(SAFE).nonce(), safeNonceBefore + 1, "one Safe tx");

        // Foundation: same allowance, same 25-day cycle, nothing spent
        _assertDelegates(FOUNDATION);
        address[] memory tokens = allowanceModule.getTokens(SAFE, FOUNDATION);
        assertEq(tokens.length, 1, "one token");
        assertEq(tokens[0], ETH, "ETH");
        uint256 nowMin = block.timestamp / 60;
        uint256[5] memory f = allowanceModule.getTokenAllowance(SAFE, FOUNDATION, ETH);
        assertEq(f[0], ALLOWANCE, "Foundation amount");
        assertEq(f[1], 0, "Foundation spent");
        assertEq(f[2], RESET_TIME_MIN, "Foundation reset");
        assertEq(f[3], nowMin - ((nowMin - RESET_BASE_MIN) % RESET_TIME_MIN), "Foundation period start");
        assertEq(f[4], 1, "Foundation nonce");

        // Meta-Gov: allowance deleted, nonce kept so old signatures cannot replay
        uint256[5] memory mg = allowanceModule.getTokenAllowance(SAFE, META_GOV, ETH);
        assertEq(mg[0] + mg[1] + mg[2] + mg[3], 0, "Meta-Gov allowance deleted");
        assertEq(mg[4], metaGovNonceBefore, "Meta-Gov nonce kept");
    }

    function _feePulls() internal {
        // The Safe keeps no idle ETH (kpk frees it before each fee), so fund it for the test
        vm.deal(SAFE, 60 ether);

        vm.prank(META_GOV);
        vm.expectRevert(bytes("newSpent > allowance.spent && newSpent <= allowance.amount"));
        allowanceModule.executeAllowanceTransfer(SAFE, ETH, KPK_FEE_SAFE, 1 ether, ETH, 0, META_GOV, "");

        // Only the delegate itself can pull its allowance
        vm.prank(META_GOV);
        vm.expectRevert(
            bytes("expectedDelegate == signer && delegates[address(safe)][uint48(signer)].delegate == signer")
        );
        allowanceModule.executeAllowanceTransfer(SAFE, ETH, KPK_FEE_SAFE, 1 ether, ETH, 0, FOUNDATION, "");

        uint256 kpkBefore = KPK_FEE_SAFE.balance;
        _pull(FOUNDATION, 15.71 ether);
        assertEq(KPK_FEE_SAFE.balance - kpkBefore, 15.71 ether, "kpk received the fee");

        vm.prank(FOUNDATION);
        vm.expectRevert(bytes("newSpent > allowance.spent && newSpent <= allowance.amount"));
        allowanceModule.executeAllowanceTransfer(SAFE, ETH, KPK_FEE_SAFE, 14.3 ether, ETH, 0, FOUNDATION, "");

        // Next period: the full 30 ETH is available again
        vm.warp(block.timestamp + 25 days);
        _pull(FOUNDATION, 30 ether);
        assertEq(KPK_FEE_SAFE.balance - kpkBefore, 45.71 ether, "kpk received both fees");
    }

    // ─── Helpers
    // ──────────────────────────────────────────────────

    function _pull(address delegate, uint96 amount) internal {
        vm.prank(delegate);
        allowanceModule.executeAllowanceTransfer(SAFE, ETH, KPK_FEE_SAFE, amount, ETH, 0, delegate, "");
    }

    function _assertModules() internal view {
        (address[] memory modules,) = ISafe(SAFE).getModulesPaginated(SENTINEL, 10);
        assertEq(modules.length, 2, "Safe module count");
        assertEq(modules[0], NEW_MAIN, "Roles Modifier");
        assertEq(modules[1], address(allowanceModule), "Allowance Module");
    }

    function _assertDelegates(address expected) internal view {
        (address[] memory delegates,) = allowanceModule.getDelegates(SAFE, 0, 50);
        assertEq(delegates.length, 1, "one delegate");
        assertEq(delegates[0], expected, "delegate");
    }

    function _assertBatch(string memory json, string memory label) internal view {
        assertEq(vm.parseJsonUint(json, ".chainId"), 1, string.concat(label, " chain"));
        assertEq(vm.parseJsonAddress(json, ".meta.createdFromSafeAddress"), FOUNDATION, string.concat(label, " Safe"));
        assertFalse(vm.keyExistsJson(json, ".transactions[1]"), string.concat(label, " has one call"));
        assertEq(
            vm.parseJsonAddress(json, ".transactions[0].to"),
            ENSConstants.ENDOWMENT_TIMELOCK,
            string.concat(label, " target is the timelock")
        );
        assertEq(vm.parseJsonUint(json, ".transactions[0].value"), 0, string.concat(label, " value"));
    }

    function _signature(string memory json) internal view returns (string memory sig) {
        sig = string.concat(vm.parseJsonString(json, ".transactions[0].contractMethod.name"), "(");
        for (uint256 i;; i++) {
            string memory input = string.concat(".transactions[0].contractMethod.inputs[", vm.toString(i), "]");
            if (!vm.keyExistsJson(json, input)) break;
            sig = string.concat(sig, i == 0 ? "" : ",", vm.parseJsonString(json, string.concat(input, ".type")));
        }
        sig = string.concat(sig, ")");
    }
}
