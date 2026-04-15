// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";
import { IZodiacRoles } from "@ens/interfaces/IZodiacRoles.sol";

/**
 * @title ZodiacRolesHelper
 * @notice Shared helpers for testing Zodiac Roles permissions on the ENS Endowment Safe
 * @dev Karpatkey manages the ENS Endowment via the Zodiac Roles Modifier. These helpers
 *      support dry-run testing of role-based permissions (snapshot → execute → revert).
 */
abstract contract ZodiacRolesHelper is Test {
    IZodiacRoles public constant roles = IZodiacRoles(0x703806E61847984346d2D7DDd853049627e50A40);
    bytes32 internal constant MANAGER_ROLE = 0x4d414e4147455200000000000000000000000000000000000000000000000000;
    address internal constant karpatkey = 0xb423e0f6E7430fa29500c5cC9bd83D28c8BD8978;

    // ─── Zodiac Condition: Param Types
    // ─────────────────────────────────

    uint8 internal constant PARAM_TYPE_NONE = 0;
    uint8 internal constant PARAM_TYPE_STATIC = 1;
    uint8 internal constant PARAM_TYPE_TUPLE = 3;
    uint8 internal constant PARAM_TYPE_CALLDATA = 5;

    // ─── Zodiac Condition: Operators
    // ───────────────────────────────────

    uint8 internal constant OP_PASS = 0;
    uint8 internal constant OP_OR = 2;
    uint8 internal constant OP_MATCHES = 5;
    uint8 internal constant OP_EQUAL_TO_AVATAR = 15;
    uint8 internal constant OP_EQUAL_TO = 16;

    // ─── Zodiac Condition: Execution Options
    // ──────────────────────────

    uint8 internal constant EXEC_NONE = 0;
    uint8 internal constant EXEC_SEND = 1;
    uint8 internal constant EXEC_DELEGATE_CALL = 2;

    /**
     * @notice Dry-run a transaction through the Zodiac Roles module
     * @dev Takes a VM snapshot, executes via execTransactionWithRole, then reverts.
     *      Use to test whether a role-based call is allowed or blocked.
     * @param target The target contract for the call
     * @param data The calldata to execute
     */
    function _safeExecuteTransaction(address target, bytes memory data) internal {
        uint256 snapshot = vm.snapshot();
        roles.execTransactionWithRole(target, 0, data, IZodiacRoles.Operation.Call, MANAGER_ROLE, false);
        vm.revertTo(snapshot);
    }

    /**
     * @notice Expect a ConditionViolation revert with a specific status
     * @dev Call this before `_safeExecuteTransaction` to assert a role restriction
     * @param status The expected violation status (e.g., TargetAddressNotAllowed)
     */
    function _expectConditionViolation(IZodiacRoles.Status status) internal {
        vm.expectRevert(abi.encodeWithSelector(IZodiacRoles.ConditionViolation.selector, status, bytes32(0)));
    }

    /**
     * @notice Pack a transaction for MultiSend (operation=Call, value=0)
     * @param to Target address
     * @param data Calldata
     */
    function _packTx(address to, bytes memory data) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(0), to, uint256(0), uint256(data.length), data);
    }
}
