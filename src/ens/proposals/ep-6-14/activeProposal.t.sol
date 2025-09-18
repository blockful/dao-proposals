// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

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

        // REVOKE FUNCTION
        {
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
            {
                _safeExecuteTransaction(
                    0xA434D495249abE33E031Fe71a969B81f3c07950D,
                    abi.encodeWithSelector(
                        bytes4(keccak256("withdrawETH(address,uint256,address)")),
                        0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2,
                        1 ether,
                        safe
                    )
                );
            }
            {
                _safeExecuteTransaction(
                    0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f,
                    abi.encodeWithSelector(
                        bytes4(keccak256("gaugeWithdraw(address,address,address,uint256)")),
                        0x5C0F23A5c1be65Fa710d385814a7Fd1Bda480b1C,
                        safe,
                        safe,
                        1 ether
                    )
                );
            }
            {
                address[] memory gauges = new address[](1);
                gauges[0] = 0x79eF6103A513951a3b25743DB509E267685726B7;
                _safeExecuteTransaction(
                    0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f,
                    abi.encodeWithSelector(bytes4(keccak256("gaugeClaimRewards(address[])")), gauges)
                );
            }
            {
                address[] memory gauges = new address[](1);
                gauges[0] = 0x79eF6103A513951a3b25743DB509E267685726B7;
                _safeExecuteTransaction(
                    0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f, abi.encodeWithSelector(0x3f85d390, gauges, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD, abi.encodeWithSelector(0x6e553f65, 1 ether, safe)
                );
            }
            {
                _safeExecuteTransaction(
                    0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C,
                    abi.encodeWithSelector(0x095ea7b3, 0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802)
                );
            }
            {
                _safeExecuteTransaction(
                    0x83F20F44975D03b1b09e64809B757c47f942BEeA,
                    abi.encodeWithSelector(0x095ea7b3, 0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802)
                );
            }
            {
                uint256[] memory amounts = new uint256[](1);
                amounts[0] = 1 ether;
                _safeExecuteTransaction(
                    0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802, abi.encodeWithSelector(0xb72df5de, amounts, 1 ether)
                );
            }
            {
                uint256[] memory amounts = new uint256[](1);
                amounts[0] = 1 ether;
                _safeExecuteTransaction(
                    0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802, abi.encodeWithSelector(0xd40ddb8c, 1 ether, amounts)
                );
            }
            {
                uint256[] memory amounts = new uint256[](1);
                amounts[0] = 1 ether;
                _safeExecuteTransaction(
                    0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802, abi.encodeWithSelector(0x7706db75, amounts, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802,
                    abi.encodeWithSelector(0x1a4d01d2, 1 ether, 1 ether, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802,
                    abi.encodeWithSelector(0x095ea7b3, 0xcF5136C67fA8A375BaBbDf13c0307EF994b5681D, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802,
                    abi.encodeWithSelector(0x3df02124, 1 ether, 1 ether, 1 ether, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0xcF5136C67fA8A375BaBbDf13c0307EF994b5681D, abi.encodeWithSelector(0xb6b55f25, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0xcF5136C67fA8A375BaBbDf13c0307EF994b5681D, abi.encodeWithSelector(0x2e1a7d4d, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(0xcF5136C67fA8A375BaBbDf13c0307EF994b5681D, abi.encodeWithSelector(0xe6f1daf2));
            }
            {
                _safeExecuteTransaction(
                    0xBA12222222228d8Ba445958a75a0704d566BF2C8,
                    abi.encodeWithSelector(0xfa6e671d, safe, 0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f, true)
                );
            }
            {
                _safeExecuteTransaction(
                    0x239e55F427D44C3cc793f49bFB507ebe76638a2b,
                    abi.encodeWithSelector(0x0de54ba0, 0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f, true)
                );
            }
            {
                _safeExecuteTransaction(
                    0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7,
                    abi.encodeWithSelector(
                        0x095ea7b3, 0x000000000000000000000000bfcf63294ad7105dea65aa58f8ae5be2d9d0952a, 1 ether
                    )
                );
            }
        }

        // ALLOW FUNCTION
        {
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.FunctionNotAllowed,
                        bytes32(bytes4(0xf51b0fd4))
                    )
                );
                _safeExecuteTransaction(0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3, abi.encodeWithSelector(0xf51b0fd4));
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                uint256[] memory amounts = new uint256[](2);
                amounts[0] = 1 ether;
                amounts[1] = 1 ether;
                _safeExecuteTransaction(
                    0x59Ab5a5b5d617E478a2479B0cAD80DA7e2831492, abi.encodeWithSelector(0x0b4c7e4d, amounts, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0x59Ab5a5b5d617E478a2479B0cAD80DA7e2831492,
                    abi.encodeWithSelector(0x5b36389c, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0x59Ab5a5b5d617E478a2479B0cAD80DA7e2831492,
                    abi.encodeWithSelector(0xe3103273, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0x59Ab5a5b5d617E478a2479B0cAD80DA7e2831492,
                    abi.encodeWithSelector(0x1a4d01d2, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0x399e111c7209a741B06F8F86Ef0Fdd88fC198D20, abi.encodeWithSelector(0xa694fc3a, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0x399e111c7209a741B06F8F86Ef0Fdd88fC198D20, abi.encodeWithSelector(0x38d07436, 1 ether, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0x399e111c7209a741B06F8F86Ef0Fdd88fC198D20,
                    abi.encodeWithSelector(0xc32e7202, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97, 1 ether, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0xe080027Bd47353b5D1639772b4a75E9Ed3658A0d,
                    abi.encodeWithSelector(0xb72df5de, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0xe080027Bd47353b5D1639772b4a75E9Ed3658A0d,
                    abi.encodeWithSelector(0xd40ddb8c, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0xe080027Bd47353b5D1639772b4a75E9Ed3658A0d,
                    abi.encodeWithSelector(0x1a4d01d2, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0xe080027Bd47353b5D1639772b4a75E9Ed3658A0d,
                    abi.encodeWithSelector(0x7706db75, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0xBA7eBDEF7723e55c909Ac44226FB87a93625c44e, abi.encodeWithSelector(0xa694fc3a, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0xBA7eBDEF7723e55c909Ac44226FB87a93625c44e, abi.encodeWithSelector(0x38d07436, 1 ether, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0xBA7eBDEF7723e55c909Ac44226FB87a93625c44e,
                    abi.encodeWithSelector(0xc32e7202, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97, 1 ether, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0xCF370C3279452143f68e350b824714B49593a334,
                    abi.encodeWithSelector(0xc32e7202, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97, 1 ether, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0xCF370C3279452143f68e350b824714B49593a334,
                    abi.encodeWithSelector(0x3d18b912, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0x994BE003de5FD6E41d37c6948f405EB0759149e6,
                    abi.encodeWithSelector(0xc32e7202, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97, 1 ether, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0x994BE003de5FD6E41d37c6948f405EB0759149e6,
                    abi.encodeWithSelector(0x3d18b912, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0x4B891340b51889f438a03DC0e8aAAFB0Bc89e7A6, abi.encodeWithSelector(0xb6b55f25, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0x4B891340b51889f438a03DC0e8aAAFB0Bc89e7A6, abi.encodeWithSelector(0x2e1a7d4d, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0x4B891340b51889f438a03DC0e8aAAFB0Bc89e7A6, abi.encodeWithSelector(0xe6f1daf2, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0x70A1c01902DAb7a45dcA1098Ca76A8314dd8aDbA, abi.encodeWithSelector(0xb6b55f25, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0x70A1c01902DAb7a45dcA1098Ca76A8314dd8aDbA, abi.encodeWithSelector(0x2e1a7d4d, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0x70A1c01902DAb7a45dcA1098Ca76A8314dd8aDbA, abi.encodeWithSelector(0xe6f1daf2, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0x1f3A4C8115629C33A28bF2F97F22D31d256317F6, abi.encodeWithSelector(0xb6b55f25, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0x1f3A4C8115629C33A28bF2F97F22D31d256317F6, abi.encodeWithSelector(0x2e1a7d4d, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0x1f3A4C8115629C33A28bF2F97F22D31d256317F6, abi.encodeWithSelector(0xe6f1daf2, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0x7671299eA7B4bbE4f3fD305A994e6443b4be680E, abi.encodeWithSelector(0xb6b55f25, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0x7671299eA7B4bbE4f3fD305A994e6443b4be680E, abi.encodeWithSelector(0x2e1a7d4d, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0x7671299eA7B4bbE4f3fD305A994e6443b4be680E, abi.encodeWithSelector(0xe6f1daf2, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0x63037a4e3305d25D48BAED2022b8462b2807351c, abi.encodeWithSelector(0xb6b55f25, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0x63037a4e3305d25D48BAED2022b8462b2807351c, abi.encodeWithSelector(0x2e1a7d4d, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0x63037a4e3305d25D48BAED2022b8462b2807351c, abi.encodeWithSelector(0x38d07436, 1 ether, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0x63037a4e3305d25D48BAED2022b8462b2807351c, abi.encodeWithSelector(0xe6f1daf2, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0xcc7d5785AD5755B6164e21495E07aDb0Ff11C2A8,
                    abi.encodeWithSelector(0xb72df5de, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0xcc7d5785AD5755B6164e21495E07aDb0Ff11C2A8,
                    abi.encodeWithSelector(0xd40ddb8c, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0xcc7d5785AD5755B6164e21495E07aDb0Ff11C2A8,
                    abi.encodeWithSelector(0x7706db75, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0xcc7d5785AD5755B6164e21495E07aDb0Ff11C2A8,
                    abi.encodeWithSelector(0x1a4d01d2, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0x36cC1d791704445A5b6b9c36a667e511d4702F3f, abi.encodeWithSelector(0xb6b55f25, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0x36cC1d791704445A5b6b9c36a667e511d4702F3f, abi.encodeWithSelector(0x2e1a7d4d, 1 ether)
                );
            }
        }

        // SCOPE FUNCTION
        {
            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0, // wstETH
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0x000000000022D473030F116dDEE9F6B43aC78BA3, // spender
                            1 ether // amount
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0, // wstETH
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0xC13e21B648A5Ee794902342038FF3aDAB66BE987, // spender
                            1 ether // amount
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, // wstETH
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0x000000000022D473030F116dDEE9F6B43aC78BA3, // spender
                            1 ether // amount
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, // wstETH
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0x56C526b0159a258887e0d79ec3a80dfb940d0cD7, // spender
                            1 ether // amount
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, // wstETH
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb, // spender
                            1 ether // amount
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, // wstETH
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0xcc7d5785AD5755B6164e21495E07aDb0Ff11C2A8, // spender
                            1 ether // amount
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xae78736Cd615f374D3085123A210448E74Fc6393, // rETH Token
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0x56C526b0159a258887e0d79ec3a80dfb940d0cD7, // spender
                            1 ether // amount
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xae78736Cd615f374D3085123A210448E74Fc6393, // rETH Token
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0xe080027Bd47353b5D1639772b4a75E9Ed3658A0d, // spender
                            1 ether // amount
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.ParameterNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987, // target contract
                        abi.encodeWithSelector(
                            0x5a3b74b9, // setUserUseReserveAsCollateral
                            0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0, // asset
                            true // useAsCollateral
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.ParameterNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987, // target contract
                        abi.encodeWithSelector(
                            0x5a3b74b9, // setUserUseReserveAsCollateral
                            0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // asset
                            true // useAsCollateral
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.ParameterNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987, // target contract
                        abi.encodeWithSelector(
                            0x5a3b74b9, // setUserUseReserveAsCollateral
                            0xdAC17F958D2ee523a2206206994597C13D831ec7, // asset
                            true // useAsCollateral
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.ParameterNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987, // target contract
                        abi.encodeWithSelector(
                            0x5a3b74b9, // setUserUseReserveAsCollateral
                            0xdC035D45d973E3EC169d2276DDab16f1e407384F, // asset
                            true // useAsCollateral
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.ParameterNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987, // target contract
                        abi.encodeWithSelector(
                            0x617ba037, // supply
                            0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0, // asset
                            1 ether, // amount
                            address(this), // onBehalfOf
                            0 // referralCode
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.ParameterNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987, // target contract
                        abi.encodeWithSelector(
                            0x617ba037, // supply
                            0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // asset
                            1 ether, // amount
                            address(this), // onBehalfOf
                            0 // referralCode
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.ParameterNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987, // target contract
                        abi.encodeWithSelector(
                            0x617ba037, // supply
                            0xdAC17F958D2ee523a2206206994597C13D831ec7, // asset
                            1 ether, // amount
                            address(this), // onBehalfOf
                            0 // referralCode
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.ParameterNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987, // target contract
                        abi.encodeWithSelector(
                            0x617ba037, // supply
                            0xdC035D45d973E3EC169d2276DDab16f1e407384F, // asset
                            1 ether, // amount
                            address(this), // onBehalfOf
                            0 // referralCode
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.ParameterNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987, // target contract
                        abi.encodeWithSelector(
                            0x69328dec, // withdraw
                            0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0, // asset
                            1 ether, // amount
                            address(this) // to
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.ParameterNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987, // target contract
                        abi.encodeWithSelector(
                            0x69328dec, // withdraw
                            0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // asset
                            1 ether, // amount
                            address(this) // to
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.ParameterNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987, // target contract
                        abi.encodeWithSelector(
                            0x69328dec, // withdraw
                            0xdAC17F958D2ee523a2206206994597C13D831ec7, // asset
                            1 ether, // amount
                            address(this) // to
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.ParameterNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987, // target contract
                        abi.encodeWithSelector(
                            0x69328dec, // withdraw
                            0xdC035D45d973E3EC169d2276DDab16f1e407384F, // asset
                            1 ether, // amount
                            address(this) // to
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xA35b1B31Ce002FBF2058D22F30f95D405200A15b, // ETHx Token
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0x22d473030f116ddee9f6b43ac78ba3, // spender
                            1 ether // amount
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xA35b1B31Ce002FBF2058D22F30f95D405200A15b, // ETHx Token
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0x56C526b0159a258887e0d79ec3a80dfb940d0cD7, // spender
                            1 ether // amount
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xA35b1B31Ce002FBF2058D22F30f95D405200A15b, // ETHx Token
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0x59Ab5a5b5d617E478a2479B0cAD80DA7e2831492, // spender
                            1 ether // amount
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xA35b1B31Ce002FBF2058D22F30f95D405200A15b, // ETHx Token
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2, // spender
                            1 ether // amount
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.ParameterNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0x1B0e765F6224C21223AeA2af16c1C46E38885a40, // Compound v3: CometRewards
                        abi.encodeWithSelector(
                            0xb7034f7e, // claim
                            0x3Afdc9BCA9213A35503b077a6072F3D0d5AB0840, // comet
                            address(this), // src
                            true // shouldAccrue
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.ParameterNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0x1B0e765F6224C21223AeA2af16c1C46E38885a40, // Compound v3: CometRewards
                        abi.encodeWithSelector(
                            0xb7034f7e, // claim
                            0x5D409e56D886231aDAf00c8775665AD0f9897b56, // comet
                            address(this), // src
                            true // shouldAccrue
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.ParameterNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0x1B0e765F6224C21223AeA2af16c1C46E38885a40, // Compound v3: CometRewards
                        abi.encodeWithSelector(
                            0xb7034f7e, // claim
                            0xc3d688B66703497DAA19211EEdff47f25384cdc3, // comet
                            address(this), // src
                            true // shouldAccrue
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xf1C9acDc66974dFB6dEcB12aA385b9cD01190E38, // osETH Token
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0x22d473030f116ddee9f6b43ac78ba3, // spender
                            1 ether // amount
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xf1C9acDc66974dFB6dEcB12aA385b9cD01190E38, // osETH Token
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0x56C526b0159a258887e0d79ec3a80dfb940d0cD7, // spender
                            1 ether // amount
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xf1C9acDc66974dFB6dEcB12aA385b9cD01190E38, // osETH Token
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0xe080027Bd47353b5D1639772b4a75E9Ed3658A0d, // spender
                            1 ether // amount
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xA57b8d98dAE62B26Ec3bcC4a365338157060B234, // Aura: Booster
                        abi.encodeWithSelector(
                            0x43a0d066, // deposit
                            240, // _pid
                            1 ether, // _amount
                            true // _stake
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xA57b8d98dAE62B26Ec3bcC4a365338157060B234, // Aura: Booster
                        abi.encodeWithSelector(
                            0x43a0d066, // deposit
                            260, // _pid
                            1 ether, // _amount
                            true // _stake
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xdC035D45d973E3EC169d2276DDab16f1e407384F, // Usds
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0x5D409e56D886231aDAf00c8775665AD0f9897b56, // spender
                            1 ether // amount
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xdC035D45d973E3EC169d2276DDab16f1e407384F, // Usds
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45, // spender
                            1 ether // amount
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xdC035D45d973E3EC169d2276DDab16f1e407384F, // Usds
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0xA188EEC8F81263234dA3622A406892F3D630f98c, // spender
                            1 ether // amount
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xdC035D45d973E3EC169d2276DDab16f1e407384F, // Usds
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0xC13e21B648A5Ee794902342038FF3aDAB66BE987, // spender
                            1 ether // amount
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3, // OETH
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45, // spender
                            1 ether // amount
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3, // OETH
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0xcc7d5785AD5755B6164e21495E07aDb0Ff11C2A8, // spender
                            1 ether // amount
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.ParameterNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD, // target contract
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45, // spender
                            1 ether // amount
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.FunctionNotAllowed,
                            bytes32(bytes4(0x9b8d6d38))
                        )
                    );
                    _safeExecuteTransaction(
                        0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD, // target contract
                        abi.encodeWithSelector(
                            0x9b8d6d38, // deposit
                            1 ether, // assets
                            address(this), // receiver
                            0 // referral
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2, // Aave v3: Pool
                        abi.encodeWithSelector(
                            0x5a3b74b9, // setUserUseReserveAsCollateral
                            0xA35b1B31Ce002FBF2058D22F30f95D405200A15b, // asset
                            true // useAsCollateral
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2, // Aave v3: Pool
                        abi.encodeWithSelector(
                            0x617ba037, // supply
                            0xA35b1B31Ce002FBF2058D22F30f95D405200A15b, // asset
                            1 ether, // amount
                            address(this), // onBehalfOf
                            0 // referralCode
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2, // Aave v3: Pool
                        abi.encodeWithSelector(
                            0x69328dec, // withdraw
                            0xA35b1B31Ce002FBF2058D22F30f95D405200A15b, // asset
                            1 ether, // amount
                            address(this) // to
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.ParameterNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8, // aWETH Token
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0xd01607c3C5eCABa394D8be377a08590149325722, // spender
                            1 ether // amount
                        )
                    );
                }
                {
                    {
                        _safeExecuteTransaction(
                            0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8, // aWETH Token
                            abi.encodeWithSelector(
                                0x095ea7b3, // approve
                                0xA434D495249abE33E031Fe71a969B81f3c07950D, // spender
                                1 ether // amount
                            )
                        );
                    }
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // USDC Token
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0xA188EEC8F81263234dA3622A406892F3D630f98c, // spender
                            1 ether // amount
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // USDC Token
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb, // spender
                            1 ether // amount
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // USDC Token
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0xC13e21B648A5Ee794902342038FF3aDAB66BE987, // spender
                            1 ether // amount
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // USDC Token
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0xd0A61F2963622e992e6534bde4D52fd0a89F39E0, // spender
                            1 ether // amount
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xdAC17F958D2ee523a2206206994597C13D831ec7, // USDT Token
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0xC13e21B648A5Ee794902342038FF3aDAB66BE987, // spender
                            1 ether // amount
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0x239e55F427D44C3cc793f49bFB507ebe76638a2b, // target contract
                        abi.encodeWithSelector(
                            0x6a627842, // mint
                            0x1f3A4C8115629C33A28bF2F97F22D31d256317F6 // gauge
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0x239e55F427D44C3cc793f49bFB507ebe76638a2b, // target contract
                        abi.encodeWithSelector(
                            0x6a627842, // mint
                            0x4B891340b51889f438a03DC0e8aAAFB0Bc89e7A6 // gauge
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0x239e55F427D44C3cc793f49bFB507ebe76638a2b, // target contract
                        abi.encodeWithSelector(
                            0x6a627842, // mint
                            0x70A1c01902DAb7a45dcA1098Ca76A8314dd8aDbA // gauge
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xF403C135812408BFbE8713b5A23a04b3D48AAE31, // Convex: Booster
                        abi.encodeWithSelector(
                            0x43a0d066, // deposit
                            232, // _pid
                            1 ether, // _amount
                            true // _stake
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xF403C135812408BFbE8713b5A23a04b3D48AAE31, // Convex: Booster
                        abi.encodeWithSelector(
                            0x43a0d066, // deposit
                            268, // _pid
                            1 ether, // _amount
                            true // _stake
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xF403C135812408BFbE8713b5A23a04b3D48AAE31, // Convex: Booster
                        abi.encodeWithSelector(
                            0x441a3e70, // withdraw
                            232, // _pid
                            1 ether // _amount
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xF403C135812408BFbE8713b5A23a04b3D48AAE31, // Convex: Booster
                        abi.encodeWithSelector(
                            0x441a3e70, // withdraw
                            268, // _pid
                            1 ether // _amount
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xF403C135812408BFbE8713b5A23a04b3D48AAE31, // Convex: Booster
                        abi.encodeWithSelector(
                            0x60759fce, // depositAll
                            232, // _pid
                            true // _stake
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xF403C135812408BFbE8713b5A23a04b3D48AAE31, // Convex: Booster
                        abi.encodeWithSelector(
                            0x60759fce, // depositAll
                            268, // _pid
                            true // _stake
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xd061D61a4d941c39E5453435B6345Dc261C2fcE0, // Curve: Token Minter
                        abi.encodeWithSelector(
                            0x6a627842, // mint
                            0x36cC1d791704445A5b6b9c36a667e511d4702F3f // gauge_addr
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xd061D61a4d941c39E5453435B6345Dc261C2fcE0, // Curve: Token Minter
                        abi.encodeWithSelector(
                            0x6a627842, // mint
                            0x63037a4e3305d25D48BAED2022b8462b2807351c // gauge_addr
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xd061D61a4d941c39E5453435B6345Dc261C2fcE0, // Curve: Token Minter
                        abi.encodeWithSelector(
                            0x6a627842, // mint
                            0x7671299eA7B4bbE4f3fD305A994e6443b4be680E // gauge_addr
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        0xd061D61a4d941c39E5453435B6345Dc261C2fcE0, // Curve: Token Minter
                        abi.encodeWithSelector(
                            0x6a627842, // mint
                            0xcF5136C67fA8A375BaBbDf13c0307EF994b5681D // gauge_addr
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xd01607c3C5eCABa394D8be377a08590149325722, // WrappedTokenGatewayV3
                        abi.encodeWithSelector(
                            0x474cf53d, // depositETH
                            0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2, // ()
                            0 // referralCode
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xd01607c3C5eCABa394D8be377a08590149325722, // WrappedTokenGatewayV3
                        abi.encodeWithSelector(
                            0x80500d20, // withdrawETH
                            0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2, // ()
                            1 ether, // amount
                            address(this) // to
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0x5D409e56D886231aDAf00c8775665AD0f9897b56, // CometWithExtendedAssetList
                        abi.encodeWithSelector(
                            0xf2b9fdb8, // supply
                            0xdC035D45d973E3EC169d2276DDab16f1e407384F, // asset
                            1 ether // amount
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0x5D409e56D886231aDAf00c8775665AD0f9897b56, // CometWithExtendedAssetList
                        abi.encodeWithSelector(
                            0xf3fef3a3, // withdraw
                            0xdC035D45d973E3EC169d2276DDab16f1e407384F, // asset
                            1 ether // amount
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0x59Ab5a5b5d617E478a2479B0cAD80DA7e2831492, // Vyper_contract
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0x7671299eA7B4bbE4f3fD305A994e6443b4be680E, // spender
                            1 ether // amount
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0x59Ab5a5b5d617E478a2479B0cAD80DA7e2831492, // Vyper_contract
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0xF403C135812408BFbE8713b5A23a04b3D48AAE31, // spender
                            1 ether // amount
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0x1dF858Ae1fE8F58d6157B8Eb9f7089e62e303982, // DepositToken
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0x399e111c7209a741B06F8F86Ef0Fdd88fC198D20, // spender
                            1 ether // amount
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0x399e111c7209a741B06F8F86Ef0Fdd88fC198D20, // BaseRewardPool
                        abi.encodeWithSelector(
                            0x7050ccd9, // getReward
                            address(this), // account (AVATAR)
                            true // claimExtras
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xe080027Bd47353b5D1639772b4a75E9Ed3658A0d, // CurveStableSwapNG
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0x63037a4e3305d25D48BAED2022b8462b2807351c, // spender
                            1 ether // amount
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xe080027Bd47353b5D1639772b4a75E9Ed3658A0d, // CurveStableSwapNG
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0xF403C135812408BFbE8713b5A23a04b3D48AAE31, // spender
                            1 ether // amount
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xE3eA98BD863bEF37D951973743aAC2e56edd99BC, // DepositToken
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0xBA7eBDEF7723e55c909Ac44226FB87a93625c44e, // spender
                            1 ether // amount
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xBA7eBDEF7723e55c909Ac44226FB87a93625c44e, // BaseRewardPool
                        abi.encodeWithSelector(
                            0x7050ccd9, // getReward
                            address(this), // account (AVATAR)
                            true // claimExtras
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0x58D97B57BB95320F9a05dC918Aef65434969c2B2, // MorphoTokenEthereum
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45, // spender
                            1 ether // amount
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0x58D97B57BB95320F9a05dC918Aef65434969c2B2, // MorphoTokenEthereum
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0xc92ebbdf79F0507f65A392B0Ab4667716bFE0110, // spender
                            1 ether // amount
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xc20059e0317DE91738d13af027DfC4a50781b066, // SDAO
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45, // spender
                            1 ether // amount
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xc20059e0317DE91738d13af027DfC4a50781b066, // SDAO
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0xc92ebbdf79F0507f65A392B0Ab4667716bFE0110, // spender
                            1 ether // amount
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0x4F2083f5fBede34C2714aFfb3105539775f7FE64, // GnosisSafe
                        abi.encodeWithSelector(
                            0x3365582c, //
                            0xc078f884a2676e1345748b1feace7b0abee5d00ecadb6e574dcdd109a63e8943,
                            //
                            0x000000000000000000000000fdafc9d1902f4e0b84f65f49f244b32b31013b74 //
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0x4F2083f5fBede34C2714aFfb3105539775f7FE64, // GnosisSafe
                        abi.encodeWithSelector(
                            0xf08a0323, // setFallbackHandler
                            0x2f55e8b20D0B9FEFA187AA7d00B6Cbe563605bF5 // handler
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xA188EEC8F81263234dA3622A406892F3D630f98c, // UsdsPsmWrapper
                        abi.encodeWithSelector(
                            0x95991276, // sellGem
                            safe, // usr
                            1 ether
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xA188EEC8F81263234dA3622A406892F3D630f98c, // UsdsPsmWrapper
                        abi.encodeWithSelector(
                            0x8d7ef9bb, // buyGem
                            safe, // usr
                            1 ether
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xd0A61F2963622e992e6534bde4D52fd0a89F39E0, // PSMVariant1Actions
                        abi.encodeWithSelector(
                            0x57de6782, // withdrawAndSwap
                            safe, // receiver
                            1 ether, // amountOut
                            1 ether // maxAmountIn
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xd0A61F2963622e992e6534bde4D52fd0a89F39E0, // PSMVariant1Actions
                        abi.encodeWithSelector(
                            0x850d6b31, // redeemAndSwap
                            safe, // receiver
                            1 ether, // shares
                            1 ether // minAmountOut
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xd0A61F2963622e992e6534bde4D52fd0a89F39E0, // PSMVariant1Actions
                        abi.encodeWithSelector(
                            0x8fba2cee, // swapAndDeposit
                            safe, // receiver
                            1 ether, // amountIn
                            1 ether // minAmountOut
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xBC65Ad17C500a2A4D159fA5a503f4992c7B545FE, // UsdcVault
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0xd0A61F2963622e992e6534bde4D52fd0a89F39E0, // spender
                                // condition)
                            1 ether // value
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xc4Ce391d82D164c166dF9c8336DDF84206b2F812, // StablePool
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0x4B891340b51889f438a03DC0e8aAAFB0Bc89e7A6, // spender
                            1 ether // amount
                        )
                    );
                }
                {
                    {
                        vm.expectRevert(
                            abi.encodeWithSelector(
                                IZodiacRoles.ConditionViolation.selector,
                                IZodiacRoles.Status.TargetAddressNotAllowed,
                                bytes32(0)
                            )
                        );
                        _safeExecuteTransaction(
                            0xc4Ce391d82D164c166dF9c8336DDF84206b2F812, // StablePool
                            abi.encodeWithSelector(
                                0x095ea7b3, // approve
                                0xA57b8d98DAe62b26EC3bCC4a365338157860b234, // spender
                                1 ether // amount
                            )
                        );
                    }
                }
                {
                    {
                        vm.expectRevert(
                            abi.encodeWithSelector(
                                IZodiacRoles.ConditionViolation.selector,
                                IZodiacRoles.Status.TargetAddressNotAllowed,
                                bytes32(0)
                            )
                        );
                        _safeExecuteTransaction(
                            0xc4Ce391d82D164c166dF9c8336DDF84206b2F812, // StablePool
                            abi.encodeWithSelector(
                                0x095ea7b3, // approve
                                0xb21A277466e7dB6934556a1Ce12eb3F032815c8A, // spender
                                1 ether // amount
                            )
                        );
                    }
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xCF370C3279452143f68e350b824714B49593a334, // BaseRewardPool4626
                        abi.encodeWithSelector(
                            0x3d18b912 // getReward  (no
                        )
                    );
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xCF370C3279452143f68e350b824714B49593a334, // BaseRewardPool4626
                        abi.encodeWithSelector(
                            0x7050ccd9, // getReward  (with
                            safe, // _account
                            true // _claimExtras
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0x57c23c58B1D8C3292c15BEcF07c62C5c52457A42, // StablePool
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            address(0x1), // spender
                            1 ether // amount
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0x994BE003de5FD6E41d37c6948f405EB0759149e6, // BaseRewardPool4626
                        abi.encodeWithSelector(
                            0x3d18b912 // getReward  (no
                        )
                    );
                }

                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0x994BE003de5FD6E41d37c6948f405EB0759149e6, // BaseRewardPool4626
                        abi.encodeWithSelector(
                            0x7050ccd9, // getReward  (with
                            safe, // _account
                            true // _claimExtras
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0x000000000022D473030F116dDEE9F6B43aC78BA3, // Permit2
                        abi.encodeWithSelector(
                            0x87517c45, // approve
                            address(0x1), // token
                            0xb21A277466e7dB6934556a1Ce12eb3F032815c8A, // spender
                            uint160(1 ether), // amount
                            uint48(block.timestamp + 3600) // expiration
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xb21A277466e7dB6934556a1Ce12eb3F032815c8A, // CompositeLiquidityRouter
                        abi.encodeWithSelector(
                            0xc1da024c, // addLiquidityUnbalancedToERC4626Pool
                            address(0x1), // pool
                            new bool[](2), // wrapUnderlying
                            new uint256[](2), // exactAmountIn
                            1 ether, // minBptAmountOut
                            false, // wethIsEth
                            "" // userData
                        )
                    );
                }

                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xb21A277466e7dB6934556a1Ce12eb3F032815c8A, // CompositeLiquidityRouter
                        abi.encodeWithSelector(
                            0xd8a7f9fe, // removeLiquidityProportionalFromERC4626Pool
                            address(0x1), // pool
                            new bool[](2), // unwrapWrapped
                            1 ether, // exactBptAmountIn
                            new uint256[](2), // minAmountOut
                            false, // wethIsEth
                            "" // userData
                        )
                    );
                }

                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xb21A277466e7dB6934556a1Ce12eb3F032815c8A, // CompositeLiquidityRouter
                        abi.encodeWithSelector(
                            0xe3c3e64f, // addLiquidityProportionalToERC4626Pool
                            address(0x1), // pool
                            new bool[](2), // wrapUnderlying
                            new uint256[](2), // maxAmountIn
                            1 ether, // exactBptAmountOut
                            false, // wethIsEth
                            "" // userData
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0x4AB7aB316D43345009B2140e0580B072eEc7DF16, // StablePool
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            address(0x1), // spender
                            1 ether // amount
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490, // Vyper_contract
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            address(0x1), // _spender
                            1 ether // _value
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xcc7d5785AD5755B6164e21495E07aDb0Ff11C2A8, // CurveStableSwapNG
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            address(0x1), // _spender
                            1 ether // _value
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb, // Morpho
                        abi.encodeWithSelector(
                            0x5c2bea49, // withdraw
                            abi.encode(
                                address(0x1), // loanToken (address not in allowed list)
                                address(0x1), // collateralToken (address not in allowed list)
                                address(0x1), // oracle (address not in allowed list)
                                address(0x1), // irm (address not in allowed list)
                                uint256(1) // lltv (value not in allowed list)
                            ), // marketParams tuple
                            1 ether, // assets
                            1 ether, // shares
                            safe, // onBehalf
                            safe // receiver
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0x330eefa8a787552DC5cAd3C3cA644844B1E61Ddb, // UniversalRewardsDistributor
                        abi.encodeWithSelector(
                            0xfabed412, // claim
                            safe, // account
                            address(0x1), // reward
                            1 ether, // claimable
                            new bytes32[](0) // proof
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae, // Angle: Distributor
                        abi.encodeWithSelector(
                            0x71ee95c0, // claim
                            new address[](1), // users
                            new address[](1), // tokens
                            new uint256[](1), // amounts
                            new bytes32[][](1) // proofs
                        )
                    );
                }
            }

            {
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector,
                            IZodiacRoles.Status.TargetAddressNotAllowed,
                            bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        0x7ac96180C4d6b2A328D3a19ac059D0E7Fc3C6d41, // SparkRewards
                        abi.encodeWithSelector(
                            0xef98231e, // claim
                            1 ether, // epoch
                            safe, // account
                            address(0x1), // token
                            1 ether, // cumulativeAmount
                            bytes32(0), // expectedMerkleRoot
                            new bytes32[](0) // merkleProof
                        )
                    );
                }
            }
        }

        vm.stopPrank();
    }

    function _afterExecution() public override {
        vm.startPrank(karpatkey);
        // vm.pauseGasMetering();

        // {
        //     vm.0x36cC1d791704445A5b6b9c36a667e511d4702F3f(
        //         abi.encodeWithSelector(
        //             IZodiacRoles.ConditionViolation.selector,
        // /"

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
