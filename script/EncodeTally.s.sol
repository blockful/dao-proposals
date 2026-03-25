// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Script, console2 } from "@forge-std/src/Script.sol";
import { ISafe } from "@ens/interfaces/ISafe.sol";
import { IRolesModifier, ConditionFlat } from "@ens/interfaces/IRolesModifier.sol";
import { IERC20 } from "@forge-std/src/interfaces/IERC20.sol";

contract EncodeTally is Script {
    address constant ROLES_MOD = 0x703806E61847984346d2D7DDd853049627e50A40;
    address constant SAFE = 0x4F2083f5fBede34C2714aFfb3105539775f7FE64;
    address constant TIMELOCK = 0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    bytes32 constant MANAGER_ROLE = 0x4d414e4147455200000000000000000000000000000000000000000000000000;

    function _sig() internal pure returns (bytes memory) {
        return abi.encodePacked(
            bytes32(uint256(uint160(TIMELOCK))),
            bytes32(0),
            uint8(1)
        );
    }

    function run() external view {
        // TX5: Safe.execTransaction(scopeTarget(MANAGER_ROLE, USDC))
        bytes memory inner5 = abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, USDC);
        bytes memory tx5 = abi.encodeWithSelector(ISafe.execTransaction.selector, ROLES_MOD, 0, inner5, uint8(0), 0, 0, 0, address(0), address(0), _sig());
        console2.log("TX5_DATA:");
        console2.logBytes(tx5);

        // TX6: Safe.execTransaction(scopeFunction(MANAGER_ROLE, USDC, transfer, conditions, 0))
        ConditionFlat[] memory conditions = new ConditionFlat[](3);
        conditions[0] = ConditionFlat({ parent: 0, paramType: 5, operator: 5, compValue: "" });
        conditions[1] = ConditionFlat({ parent: 0, paramType: 1, operator: 16, compValue: abi.encodePacked(bytes32(uint256(uint160(TIMELOCK)))) });
        conditions[2] = ConditionFlat({ parent: 0, paramType: 1, operator: 0, compValue: "" });
        bytes memory inner6 = abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, USDC, IERC20.transfer.selector, conditions, uint8(0));
        bytes memory tx6 = abi.encodeWithSelector(ISafe.execTransaction.selector, ROLES_MOD, 0, inner6, uint8(0), 0, 0, 0, address(0), address(0), _sig());
        console2.log("TX6_DATA:");
        console2.logBytes(tx6);

        // TX7: Safe.execTransaction(scopeTarget(MANAGER_ROLE, TIMELOCK))
        bytes memory inner7 = abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, TIMELOCK);
        bytes memory tx7 = abi.encodeWithSelector(ISafe.execTransaction.selector, ROLES_MOD, 0, inner7, uint8(0), 0, 0, 0, address(0), address(0), _sig());
        console2.log("TX7_DATA:");
        console2.logBytes(tx7);

        // TX8: Safe.execTransaction(allowFunction(MANAGER_ROLE, TIMELOCK, 0x00000000, EXEC_SEND=1))
        bytes memory inner8 = abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, TIMELOCK, bytes4(0), uint8(1));
        bytes memory tx8 = abi.encodeWithSelector(ISafe.execTransaction.selector, ROLES_MOD, 0, inner8, uint8(0), 0, 0, 0, address(0), address(0), _sig());
        console2.log("TX8_DATA:");
        console2.logBytes(tx8);
    }
}
