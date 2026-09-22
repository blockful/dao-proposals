// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";
import { ENSConstants } from "@ens/Constants.sol";
import { MultiSendHelper } from "@ens/helpers/MultiSendHelper.sol";
import { IMultiSend } from "@ens/interfaces/IMultiSend.sol";
import { ISafe } from "@ens/interfaces/ISafe.sol";
import { IOZTimelock, ISafeModules } from "./calldataCheck.t.sol";

contract Proposal_ENS_KPK_Update_10_Execution_Boundary_Test is Test, MultiSendHelper {
    address private constant NEW_MAIN = 0xa23BEBFD3628D6Dd7B0638c147db11d9B6FaBD59;
    bytes32 private constant SALT = keccak256("ENS_Switch_ZRM");
    IOZTimelock private constant endowmentTimelock = IOZTimelock(ENSConstants.ENDOWMENT_TIMELOCK);
    string private referenceJson;

    function setUp() public {
        vm.createSelectFork("mainnet", vm.envOr("REVIEW_BLOCK", uint256(25_984_900)));
        referenceJson = vm.readFile("src/ens/proposals/ep-kpk-update-10/referenceExecution.json");
    }

    function test_referenceWrapperAndOperationAreDerivedFromInterfaces() public view {
        bytes memory batch = bytes.concat(
            _packCall(
                ENSConstants.ENDOWMENT_SAFE,
                abi.encodeCall(ISafeModules.disableModule, (address(1), ENSConstants.ZODIAC_ROLES))
            ),
            _packCall(ENSConstants.ENDOWMENT_SAFE, abi.encodeCall(ISafeModules.enableModule, (NEW_MAIN)))
        );
        (, bytes memory data) =
            _buildSafeMultiSendCalldata(batch, ENSConstants.ENDOWMENT_SAFE, ENSConstants.ENDOWMENT_TIMELOCK);
        assertEq(data, vm.parseJsonBytes(referenceJson, ".data"), "Safe wrapper bytes");
        assertEq(vm.parseJsonUint(referenceJson, ".chainId"), block.chainid, "chain");
        assertEq(vm.parseJsonAddress(referenceJson, ".timelock"), ENSConstants.ENDOWMENT_TIMELOCK, "timelock");
        assertEq(vm.parseJsonAddress(referenceJson, ".target"), ENSConstants.ENDOWMENT_SAFE, "target");
        assertEq(vm.parseJsonUint(referenceJson, ".value"), 0, "value");
        assertEq(vm.parseJsonBytes32(referenceJson, ".predecessor"), bytes32(0), "predecessor");
        assertEq(vm.parseJsonBytes32(referenceJson, ".salt"), SALT, "salt");
        assertEq(vm.parseJsonUint(referenceJson, ".delay"), endowmentTimelock.getMinDelay(), "delay");
        assertEq(
            endowmentTimelock.hashOperation(ENSConstants.ENDOWMENT_SAFE, 0, data, bytes32(0), SALT),
            vm.parseJsonBytes32(referenceJson, ".operationId"),
            "reference operation id"
        );
        assertEq(
            abi.encodeCall(IOZTimelock.schedule, (ENSConstants.ENDOWMENT_SAFE, 0, data, bytes32(0), SALT, 9 days)),
            vm.parseJsonBytes(referenceJson, ".scheduleData"),
            "schedule bytes"
        );
        assertEq(
            abi.encodeCall(IOZTimelock.execute, (ENSConstants.ENDOWMENT_SAFE, 0, data, bytes32(0), SALT)),
            vm.parseJsonBytes(referenceJson, ".executeData"),
            "execute bytes"
        );
    }

    function test_exactDelayAndReplayProtection() public {
        bytes memory data = vm.parseJsonBytes(referenceJson, ".data");
        uint256 nonceBefore = ISafeModules(ENSConstants.ENDOWMENT_SAFE).nonce();
        bytes32 id = _schedule(data, bytes32(0));
        vm.warp(block.timestamp + 9 days - 1);
        vm.expectRevert(bytes("TimelockController: operation is not ready"));
        endowmentTimelock.execute(ENSConstants.ENDOWMENT_SAFE, 0, data, bytes32(0), SALT);
        vm.warp(block.timestamp + 1);
        endowmentTimelock.execute(ENSConstants.ENDOWMENT_SAFE, 0, data, bytes32(0), SALT);
        assertTrue(endowmentTimelock.isOperationDone(id), "completed");
        assertFalse(
            ISafeModules(ENSConstants.ENDOWMENT_SAFE).isModuleEnabled(ENSConstants.ZODIAC_ROLES), "old disabled"
        );
        assertTrue(ISafeModules(ENSConstants.ENDOWMENT_SAFE).isModuleEnabled(NEW_MAIN), "new enabled");
        assertTrue(
            ISafeModules(ENSConstants.ENDOWMENT_SAFE).isModuleEnabled(ENSConstants.ALLOWANCE_MODULE),
            "allowance retained"
        );
        assertEq(ISafeModules(ENSConstants.ENDOWMENT_SAFE).nonce(), nonceBefore + 1, "one Safe transaction");
        vm.expectRevert(bytes("TimelockController: operation is not ready"));
        endowmentTimelock.execute(ENSConstants.ENDOWMENT_SAFE, 0, data, bytes32(0), SALT);
        assertEq(ISafeModules(ENSConstants.ENDOWMENT_SAFE).nonce(), nonceBefore + 1, "replay consumes no nonce");
    }

    function test_unexecutedPredecessorBlocksSwitch() public {
        bytes memory data = vm.parseJsonBytes(referenceJson, ".data");
        bytes32 predecessor = keccak256("unexecuted ownership operation");
        bytes32 id = _schedule(data, predecessor);
        vm.warp(block.timestamp + 9 days);
        vm.expectRevert(bytes("TimelockController: missing dependency"));
        endowmentTimelock.execute(ENSConstants.ENDOWMENT_SAFE, 0, data, predecessor, SALT);
        assertFalse(endowmentTimelock.isOperationDone(id), "dependent operation must not finish");
        _assertUnswitched();
    }

    function test_zeroGasWrapperRevertsFailedSwitchAtomically() public {
        bytes memory data = _reversedBatchWrapper(0);
        uint256 nonceBefore = ISafeModules(ENSConstants.ENDOWMENT_SAFE).nonce();
        bytes32 id = _schedule(data, bytes32(0));
        vm.warp(block.timestamp + 9 days);
        vm.expectRevert(bytes("TimelockController: underlying transaction reverted"));
        endowmentTimelock.execute(ENSConstants.ENDOWMENT_SAFE, 0, data, bytes32(0), SALT);
        assertTrue(endowmentTimelock.isOperationPending(id), "failed operation remains pending");
        assertEq(ISafeModules(ENSConstants.ENDOWMENT_SAFE).nonce(), nonceBefore, "failed wrapper preserves nonce");
        _assertUnswitched();
    }

    /// @dev A different scheduled wrapper can report completion without switching modules.
    function test_nonzeroSafeTxGasCanMarkFailedSwitchDone() public {
        bytes memory data = _reversedBatchWrapper(500_000);
        uint256 nonceBefore = ISafeModules(ENSConstants.ENDOWMENT_SAFE).nonce();
        bytes32 id = _schedule(data, bytes32(0));
        vm.warp(block.timestamp + 9 days);
        endowmentTimelock.execute(ENSConstants.ENDOWMENT_SAFE, 0, data, bytes32(0), SALT);
        assertTrue(endowmentTimelock.isOperationDone(id), "timelock did not inspect Safe false return");
        assertEq(
            ISafeModules(ENSConstants.ENDOWMENT_SAFE).nonce(), nonceBefore + 1, "failed Safe action consumes nonce"
        );
        _assertUnswitched();
    }

    function _schedule(bytes memory data, bytes32 predecessor) internal returns (bytes32 id) {
        id = endowmentTimelock.hashOperation(ENSConstants.ENDOWMENT_SAFE, 0, data, predecessor, SALT);
        vm.prank(ENSConstants.FOUNDATION_SAFE);
        endowmentTimelock.schedule(ENSConstants.ENDOWMENT_SAFE, 0, data, predecessor, SALT, 9 days);
    }

    function _reversedBatchWrapper(uint256 safeTxGas) internal pure returns (bytes memory) {
        bytes memory batch = bytes.concat(
            _packCall(ENSConstants.ENDOWMENT_SAFE, abi.encodeCall(ISafeModules.enableModule, (NEW_MAIN))),
            _packCall(
                ENSConstants.ENDOWMENT_SAFE,
                abi.encodeCall(ISafeModules.disableModule, (address(1), ENSConstants.ZODIAC_ROLES))
            )
        );
        return abi.encodeCall(
            ISafe.execTransaction,
            (
                address(multiSend),
                0,
                abi.encodeCall(IMultiSend.multiSend, (batch)),
                1,
                safeTxGas,
                0,
                0,
                address(0),
                address(0),
                _buildPreApprovedSignature(ENSConstants.ENDOWMENT_TIMELOCK)
            )
        );
    }

    function _assertUnswitched() internal view {
        assertTrue(
            ISafeModules(ENSConstants.ENDOWMENT_SAFE).isModuleEnabled(ENSConstants.ZODIAC_ROLES), "old still enabled"
        );
        assertFalse(ISafeModules(ENSConstants.ENDOWMENT_SAFE).isModuleEnabled(NEW_MAIN), "new still disabled");
        assertTrue(
            ISafeModules(ENSConstants.ENDOWMENT_SAFE).isModuleEnabled(ENSConstants.ALLOWANCE_MODULE),
            "allowance retained"
        );
    }
}
