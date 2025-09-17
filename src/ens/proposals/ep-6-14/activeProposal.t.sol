// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Test } from "@forge-std/src/Test.sol";
import { console2 } from "@forge-std/src/console2.sol";

import { IToken } from "@ens/interfaces/IToken.sol";
import { IGovernor } from "@ens/interfaces/IGovernor.sol";
import { ITimelock } from "@ens/interfaces/ITimelock.sol";
import { ISafe } from "@ens/interfaces/ISafe.sol";
import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";

import { ENS_Governance } from "@ens/ens.t.sol";

struct PermitData {
    uint256 deadline;
    uint256 value;
    uint8 v;
    bytes32 r;
    bytes32 s;
}

interface IZodiacRoles {
    enum Status {
        Ok,
        /// Role not allowed to delegate call to target address
        DelegateCallNotAllowed,
        /// Role not allowed to call target address
        TargetAddressNotAllowed,
        /// Role not allowed to call this function on target address
        FunctionNotAllowed,
        /// Role not allowed to send to target address
        SendNotAllowed,
        /// Or conition not met
        OrViolation,
        /// Nor conition not met
        NorViolation,
        /// Parameter value is not equal to allowed
        ParameterNotAllowed,
        /// Parameter value less than allowed
        ParameterLessThanAllowed,
        /// Parameter value greater than maximum allowed by role
        ParameterGreaterThanAllowed,
        /// Parameter value does not match
        ParameterNotAMatch,
        /// Array elements do not meet allowed criteria for every element
        NotEveryArrayElementPasses,
        /// Array elements do not meet allowed criteria for at least one element
        NoArrayElementPasses,
        /// Parameter value not a subset of allowed
        ParameterNotSubsetOfAllowed,
        /// Bitmask exceeded value length
        BitmaskOverflow,
        /// Bitmask not an allowed value
        BitmaskNotAllowed,
        CustomConditionViolation,
        AllowanceExceeded,
        CallAllowanceExceeded,
        EtherAllowanceExceeded
    }

    error ConditionViolation(Status, bytes32);

    enum Operation {
        Call,
        DelegateCall
    }

    function execTransactionWithRole(
        address to,
        uint256 value,
        bytes calldata data,
        Operation operation,
        bytes32 roleKey,
        bool shouldRevert
    )
        external
        returns (bool success);
}

contract Proposal_ENS_EP_6_14_Test is ENS_Governance {
    address safe = 0x4F2083f5fBede34C2714aFfb3105539775f7FE64;
    address karpatkey = 0xb423e0f6E7430fa29500c5cC9bd83D28c8BD8978;

    // POSTER 0x000000000000cd17345801aa8147b8D3950260FF
    IZodiacRoles roles = IZodiacRoles(0x703806E61847984346d2D7DDd853049627e50A40);
    bytes32 constant MANAGER_ROLE = 0x4d414e4147455200000000000000000000000000000000000000000000000000;

    function _beforeProposal() public override {
        vm.startPrank(karpatkey);

        // 8
        {
            _safeExecuteTransaction(
                0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1,
                abi.encodeWithSelector(
                    bytes4(
                        keccak256(
                            "requestWithdrawalsWithPermit(uint256[],address,(uint256,uint256,uint8,bytes32,bytes32))"
                        )
                    ),
                    new uint256[](1),
                    safe,
                    PermitData({ deadline: block.timestamp + 1 days, value: 1 ether, v: 0, r: 0, s: 0 })
                )
            );
        }
        // 15
        {
            _safeExecuteTransaction(
                0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1,
                abi.encodeWithSelector(
                    bytes4(
                        keccak256(
                            "requestWithdrawalsWstETHWithPermit(uint256[],address,(uint256,uint256,uint8,bytes32,bytes32))"
                        )
                    ),
                    new uint256[](1),
                    safe,
                    PermitData({ deadline: block.timestamp + 1 days, value: 1 ether, v: 0, r: 0, s: 0 })
                )
            );
        }
        // 29
        {
            _safeExecuteTransaction(
                0xA434D495249abE33E031Fe71a969B81f3c07950D,
                abi.encodeWithSelector(
                    bytes4(keccak256("depositETH(address,address,uint16)")),
                    0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2,
                    safe,
                    1 ether
                )
            );
        }

        vm.stopPrank();
    }

    function _afterExecution() public override {
        vm.startPrank(karpatkey);
        // vm.pauseGasMetering();

        // {
        //     vm.expectRevert(
        //         abi.encodeWithSelector(
        //             IZodiacRoles.ConditionViolation.selector,
        //             3,
        //             0x474cf53d00000000000000000000000000000000000000000000000000000000
        //         )
        //     );
        //     _safeExecuteTransaction(
        //         0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1,
        //         abi.encodeWithSelector(
        //             Lido.requestWithdrawalsWithPermit.selector,
        //             new uint256[](1),
        //             safe,
        //             PermitData({ deadline: block.timestamp + 1 days, value: 1 ether, v: 0, r: 0, s: 0 })
        //         )
        //     );
        // }

        vm.stopPrank();
    }

    function _safeExecuteTransaction(address target, bytes memory data) internal {
        uint256 snapshot = vm.snapshot();
        roles.execTransactionWithRole(target, 0, data, IZodiacRoles.Operation.Call, MANAGER_ROLE, false);
        vm.revertTo(snapshot);
    }

    function _generateCallData()
        public
        override
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory, string memory)
    {
        //     (targets, values, calldatas, description) = abi.decode(_getCalldata(), (address[], uint256[], bytes[],
        // string));

        //     address[] memory targets = new address[](1);
        //     targets[0] = address(safe);

        //     bytes[] memory internalCalldatas = new bytes[](1);
        //     internalCalldatas[0] = abi.encodeWithSelector(
        //         ISafe.execTransaction.selector,
        //         0x9641d764fc13c8B624c04430C7356C1C7C8102e2,
        //         0,
        //         _getSafeCalldata(),
        //         1,
        //         0,
        //         0,
        //         0,
        //         0x0000000000000000000000000000000000000000,
        //         0x0000000000000000000000000000000000000000,
        //         hex"000000000000000000000000fe89cc7abb2c4183683ab71653c4cdc9b02d44b7000000000000000000000000000000000000000000000000000000000000000001"
        //     );

        //     assertEq(calldatas, internalCalldatas);

        //     return (targets, new uint256[](1), new string[](1), internalCalldatas, description);
        return (new address[](1), new uint256[](1), new string[](1), new bytes[](1), description);
    }

    function _isProposalSubmitted() public view override returns (bool) {
        return false;
    }
}
