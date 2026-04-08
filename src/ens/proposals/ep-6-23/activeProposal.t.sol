// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { ISafe } from "@ens/interfaces/ISafe.sol";
import { IZodiacRoles } from "@ens/interfaces/IZodiacRoles.sol";
import { IRolesModifier, ConditionFlat } from "@ens/interfaces/IRolesModifier.sol";
import { IMultiSend } from "@ens/interfaces/IMultiSend.sol";
import { IAnnotationRegistry } from "@ens/interfaces/IAnnotationRegistry.sol";
import { ENS_Governance } from "@ens/ens.t.sol";
import { SafeHelper } from "@ens/helpers/SafeHelper.sol";
import { ZodiacRolesHelper } from "@ens/helpers/ZodiacRolesHelper.sol";
import { console2 } from "@forge-std/src/console2.sol";
import { IERC20 } from "@forge-std/src/interfaces/IERC20.sol";

struct PermitData {
    uint256 deadline;
    uint256 value;
    uint8 v;
    bytes32 r;
    bytes32 s;
}

struct MarketParams {
    address loanToken;
    address collateralToken;
    address oracle;
    address irm;
    uint256 lltv;
}

contract Proposal_ENS_EP_6_23_Test is ENS_Governance, SafeHelper, ZodiacRolesHelper {
    address private safe = address(endowmentSafe);

    // Core Contracts
    IRolesModifier private constant ROLES_MOD = IRolesModifier(0x703806E61847984346d2D7DDd853049627e50A40);
    IMultiSend private constant PROPOSAL_MULTI_SEND = IMultiSend(0xA83c336B20401Af773B6219BA5027174338D1836);
    IAnnotationRegistry private constant ANNOTATION_REGISTRY =
        IAnnotationRegistry(0x000000000000cd17345801aa8147b8D3950260FF);

    // Additional Param Types
    uint8 private constant PARAM_TYPE_DYNAMIC = 2;
    uint8 private constant PARAM_TYPE_ARRAY = 4;
    uint8 private constant PARAM_TYPE_ABI_ENCODED = 6;

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 23_627_766, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0x1D5460F896521aD685Ea4c3F2c679Ec0b6806359;
    }

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
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                uint256[] memory amounts = new uint256[](2);
                amounts[0] = 1 ether;
                amounts[1] = 1 ether;
                _safeExecuteTransaction(
                    0x59Ab5a5b5d617E478a2479B0cAD80DA7e2831492, abi.encodeWithSelector(0x0b4c7e4d, amounts, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x59Ab5a5b5d617E478a2479B0cAD80DA7e2831492,
                    abi.encodeWithSelector(0x5b36389c, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x59Ab5a5b5d617E478a2479B0cAD80DA7e2831492,
                    abi.encodeWithSelector(0xe3103273, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x59Ab5a5b5d617E478a2479B0cAD80DA7e2831492,
                    abi.encodeWithSelector(0x1a4d01d2, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x399e111c7209a741B06F8F86Ef0Fdd88fC198D20, abi.encodeWithSelector(0xa694fc3a, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x399e111c7209a741B06F8F86Ef0Fdd88fC198D20, abi.encodeWithSelector(0x38d07436, 1 ether, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x399e111c7209a741B06F8F86Ef0Fdd88fC198D20,
                    abi.encodeWithSelector(0xc32e7202, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97, 1 ether, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0xe080027Bd47353b5D1639772b4a75E9Ed3658A0d,
                    abi.encodeWithSelector(0xb72df5de, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0xe080027Bd47353b5D1639772b4a75E9Ed3658A0d,
                    abi.encodeWithSelector(0xd40ddb8c, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0xe080027Bd47353b5D1639772b4a75E9Ed3658A0d,
                    abi.encodeWithSelector(0x1a4d01d2, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0xe080027Bd47353b5D1639772b4a75E9Ed3658A0d,
                    abi.encodeWithSelector(0x7706db75, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0xBA7eBDEF7723e55c909Ac44226FB87a93625c44e, abi.encodeWithSelector(0xa694fc3a, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0xBA7eBDEF7723e55c909Ac44226FB87a93625c44e, abi.encodeWithSelector(0x38d07436, 1 ether, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0xBA7eBDEF7723e55c909Ac44226FB87a93625c44e,
                    abi.encodeWithSelector(0xc32e7202, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97, 1 ether, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0xCF370C3279452143f68e350b824714B49593a334,
                    abi.encodeWithSelector(0xc32e7202, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97, 1 ether, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0xCF370C3279452143f68e350b824714B49593a334,
                    abi.encodeWithSelector(0x3d18b912, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x994BE003de5FD6E41d37c6948f405EB0759149e6,
                    abi.encodeWithSelector(0xc32e7202, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97, 1 ether, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x994BE003de5FD6E41d37c6948f405EB0759149e6,
                    abi.encodeWithSelector(0x3d18b912, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x4B891340b51889f438a03DC0e8aAAFB0Bc89e7A6, abi.encodeWithSelector(0xb6b55f25, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x4B891340b51889f438a03DC0e8aAAFB0Bc89e7A6, abi.encodeWithSelector(0x2e1a7d4d, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x4B891340b51889f438a03DC0e8aAAFB0Bc89e7A6, abi.encodeWithSelector(0xe6f1daf2, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x70A1c01902DAb7a45dcA1098Ca76A8314dd8aDbA, abi.encodeWithSelector(0xb6b55f25, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x70A1c01902DAb7a45dcA1098Ca76A8314dd8aDbA, abi.encodeWithSelector(0x2e1a7d4d, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x70A1c01902DAb7a45dcA1098Ca76A8314dd8aDbA, abi.encodeWithSelector(0xe6f1daf2, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x1f3A4C8115629C33A28bF2F97F22D31d256317F6, abi.encodeWithSelector(0xb6b55f25, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x1f3A4C8115629C33A28bF2F97F22D31d256317F6, abi.encodeWithSelector(0x2e1a7d4d, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x1f3A4C8115629C33A28bF2F97F22D31d256317F6, abi.encodeWithSelector(0xe6f1daf2, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x7671299eA7B4bbE4f3fD305A994e6443b4be680E, abi.encodeWithSelector(0xb6b55f25, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x7671299eA7B4bbE4f3fD305A994e6443b4be680E, abi.encodeWithSelector(0x2e1a7d4d, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x7671299eA7B4bbE4f3fD305A994e6443b4be680E, abi.encodeWithSelector(0xe6f1daf2, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x63037a4e3305d25D48BAED2022b8462b2807351c, abi.encodeWithSelector(0xb6b55f25, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x63037a4e3305d25D48BAED2022b8462b2807351c, abi.encodeWithSelector(0x2e1a7d4d, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x63037a4e3305d25D48BAED2022b8462b2807351c, abi.encodeWithSelector(0x38d07436, 1 ether, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x63037a4e3305d25D48BAED2022b8462b2807351c, abi.encodeWithSelector(0xe6f1daf2, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0xcc7d5785AD5755B6164e21495E07aDb0Ff11C2A8,
                    abi.encodeWithSelector(0xb72df5de, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0xcc7d5785AD5755B6164e21495E07aDb0Ff11C2A8,
                    abi.encodeWithSelector(0xd40ddb8c, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0xcc7d5785AD5755B6164e21495E07aDb0Ff11C2A8,
                    abi.encodeWithSelector(0x7706db75, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0xcc7d5785AD5755B6164e21495E07aDb0Ff11C2A8,
                    abi.encodeWithSelector(0x1a4d01d2, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x36cC1d791704445A5b6b9c36a667e511d4702F3f, abi.encodeWithSelector(0xb6b55f25, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
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
                    _expectConditionViolation(IZodiacRoles.Status.ParameterNotAllowed);
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987,
                        abi.encodeWithSelector(
                            0x5a3b74b9, // setUserUseReserveAsCollateral
                            0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0, // asset
                            true // useAsCollateral
                        )
                    );
                }
                {
                    _expectConditionViolation(IZodiacRoles.Status.ParameterNotAllowed);
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987,
                        abi.encodeWithSelector(
                            0x5a3b74b9, // setUserUseReserveAsCollateral
                            0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // asset
                            true // useAsCollateral
                        )
                    );
                }
                {
                    _expectConditionViolation(IZodiacRoles.Status.ParameterNotAllowed);
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987,
                        abi.encodeWithSelector(
                            0x5a3b74b9, // setUserUseReserveAsCollateral
                            0xdAC17F958D2ee523a2206206994597C13D831ec7, // asset
                            true // useAsCollateral
                        )
                    );
                }
                {
                    _expectConditionViolation(IZodiacRoles.Status.ParameterNotAllowed);
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987,
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
                    _expectConditionViolation(IZodiacRoles.Status.ParameterNotAllowed);
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987,
                        abi.encodeWithSelector(
                            0x617ba037, // supply
                            0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0, // asset
                            1 ether, // amount
                            safe, // onBehalfOf
                            0 // referralCode
                        )
                    );
                }
                {
                    _expectConditionViolation(IZodiacRoles.Status.ParameterNotAllowed);
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987,
                        abi.encodeWithSelector(
                            0x617ba037, // supply
                            0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // asset
                            1 ether, // amount
                            safe, // onBehalfOf
                            0 // referralCode
                        )
                    );
                }
                {
                    _expectConditionViolation(IZodiacRoles.Status.ParameterNotAllowed);
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987,
                        abi.encodeWithSelector(
                            0x617ba037, // supply
                            0xdAC17F958D2ee523a2206206994597C13D831ec7, // asset
                            1 ether, // amount
                            safe, // onBehalfOf
                            0 // referralCode
                        )
                    );
                }
                {
                    _expectConditionViolation(IZodiacRoles.Status.ParameterNotAllowed);
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987,
                        abi.encodeWithSelector(
                            0x617ba037, // supply
                            0xdC035D45d973E3EC169d2276DDab16f1e407384F, // asset
                            1 ether, // amount
                            safe, // onBehalfOf
                            0 // referralCode
                        )
                    );
                }
            }

            {
                {
                    _expectConditionViolation(IZodiacRoles.Status.ParameterNotAllowed);
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987,
                        abi.encodeWithSelector(
                            0x69328dec, // withdraw
                            0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0, // asset
                            1 ether, // amount
                            safe // to
                        )
                    );
                }
                {
                    _expectConditionViolation(IZodiacRoles.Status.ParameterNotAllowed);
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987,
                        abi.encodeWithSelector(
                            0x69328dec, // withdraw
                            0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // asset
                            1 ether, // amount
                            safe // to
                        )
                    );
                }
                {
                    _expectConditionViolation(IZodiacRoles.Status.ParameterNotAllowed);
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987,
                        abi.encodeWithSelector(
                            0x69328dec, // withdraw
                            0xdAC17F958D2ee523a2206206994597C13D831ec7, // asset
                            1 ether, // amount
                            safe // to
                        )
                    );
                }
                {
                    _expectConditionViolation(IZodiacRoles.Status.ParameterNotAllowed);
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987,
                        abi.encodeWithSelector(
                            0x69328dec, // withdraw
                            0xdC035D45d973E3EC169d2276DDab16f1e407384F, // asset
                            1 ether, // amount
                            safe // to
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
                    _safeExecuteTransaction(
                        0x1B0e765F6224C21223AeA2af16c1C46E38885a40, // Compound v3: CometRewards
                        abi.encodeWithSelector(
                            0xb7034f7e, // claim
                            0x3Afdc9BCA9213A35503b077a6072F3D0d5AB0840, // comet
                            safe, // src
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
                    _expectConditionViolation(IZodiacRoles.Status.ParameterNotAllowed);
                    _safeExecuteTransaction(
                        0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD,
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
                        0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD,
                        abi.encodeWithSelector(
                            0x9b8d6d38, // deposit
                            1 ether, // assets
                            safe, // receiver
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
                            safe, // onBehalfOf
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
                            safe // to
                        )
                    );
                }
            }

            {
                {
                    _expectConditionViolation(IZodiacRoles.Status.ParameterNotAllowed);
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
                        0x239e55F427D44C3cc793f49bFB507ebe76638a2b,
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
                        0x239e55F427D44C3cc793f49bFB507ebe76638a2b,
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
                        0x239e55F427D44C3cc793f49bFB507ebe76638a2b,
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                    _safeExecuteTransaction(
                        0xd01607c3C5eCABa394D8be377a08590149325722, // WrappedTokenGatewayV3
                        abi.encodeWithSelector(
                            0x80500d20, // withdrawETH
                            0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2, // ()
                            1 ether, // amount
                            safe // to
                        )
                    );
                }
            }

            {
                {
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                    _safeExecuteTransaction(
                        0x399e111c7209a741B06F8F86Ef0Fdd88fC198D20, // BaseRewardPool
                        abi.encodeWithSelector(
                            0x7050ccd9, // getReward
                            safe, // account (AVATAR)
                            true // claimExtras
                        )
                    );
                }
            }

            {
                {
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                    _safeExecuteTransaction(
                        0xBA7eBDEF7723e55c909Ac44226FB87a93625c44e, // BaseRewardPool
                        abi.encodeWithSelector(
                            0x7050ccd9, // getReward
                            safe, // account (AVATAR)
                            true // claimExtras
                        )
                    );
                }
            }

            {
                {
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                    _safeExecuteTransaction(
                        0x58D97B57BB95320F9a05dC918Aef65434969c2B2, // MorphoTokenEthereum
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0xC92E8bdf79f0507f65a392b0ab4667716BFE0110, // spender
                            1 ether // amount
                        )
                    );
                }
            }

            {
                {
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                    _safeExecuteTransaction(
                        0xc20059e0317DE91738d13af027DfC4a50781b066, // SDAO
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0xC92E8bdf79f0507f65a392b0ab4667716BFE0110, // spender
                            1 ether // amount
                        )
                    );
                }
            }

            {
                {
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                    _safeExecuteTransaction(
                        0x4F2083f5fBede34C2714aFfb3105539775f7FE64, // GnosisSafe
                        abi.encodeWithSelector(
                            0x3365582c, //
                            0xc078f884a2676e1345748b1feace7b0abee5d00ecadb6e574dcdd109a63e8943,
                            0x000000000000000000000000fdafc9d1902f4e0b84f65f49f244b32b31013b74
                        )
                    );
                }
            }

            {
                {
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                    _safeExecuteTransaction(
                        0xBc65ad17c5C0a2A4D159fa5a503f4992c7B545FE, // UsdcVault
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
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
                        _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                        _safeExecuteTransaction(
                            0xc4Ce391d82D164c166dF9c8336DDF84206b2F812, // StablePool
                            abi.encodeWithSelector(
                                0x095ea7b3, // approve
                                0xA57b8d98dAE62B26Ec3bcC4a365338157060B234, // spender
                                1 ether // amount
                            )
                        );
                    }
                }
                {
                    {
                        _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                    _safeExecuteTransaction(
                        0xCF370C3279452143f68e350b824714B49593a334, // BaseRewardPool4626
                        abi.encodeWithSelector(
                            0x3d18b912 // getReward  (no
                        )
                    );
                }
                {
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                    _safeExecuteTransaction(
                        0x994BE003de5FD6E41d37c6948f405EB0759149e6, // BaseRewardPool4626
                        abi.encodeWithSelector(
                            0x3d18b912 // getReward  (no
                        )
                    );
                }

                {
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                    _safeExecuteTransaction(
                        0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb, // Morpho
                        abi.encodeWithSelector(
                            0x5c2bea49, // withdraw
                            abi.encode(
                                address(0x1), // loanToken
                                address(0x1), // collateralToken
                                address(0x1), // oracle
                                address(0x1), // irm
                                uint256(1) // lltv
                            ),
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
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
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.TargetAddressNotAllowed, bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    0xc20059e0317DE91738d13af027DfC4a50781b066, // SPK Token
                    abi.encodeWithSelector(
                        0xa9059cbb, // transfer
                        address(timelock), // to
                        1 ether // amount
                    )
                );
            }
        }

        vm.stopPrank();
    }


    function _afterExecution() public override {
        vm.startPrank(karpatkey);
        vm.pauseGasMetering();

        // REVOKE FUNCTION
        {
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.FunctionNotAllowed,
                        bytes32(bytes4(0xacf41e4d))
                    )
                );
                _safeExecuteTransaction(
                    0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1,
                    abi.encodeWithSelector(
                        0xacf41e4d,
                        new uint256[](1),
                        safe,
                        PermitData({ deadline: block.timestamp + 1 days, value: 1 ether, v: 0, r: 0, s: 0 })
                    )
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.FunctionNotAllowed,
                        bytes32(bytes4(0x7951b76f))
                    )
                );
                _safeExecuteTransaction(
                    0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1,
                    abi.encodeWithSelector(
                        0x7951b76f,
                        new uint256[](1),
                        safe,
                        PermitData({ deadline: block.timestamp + 1 days, value: 1 ether, v: 0, r: 0, s: 0 })
                    )
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.TargetAddressNotAllowed,
                        bytes32(bytes4(0))
                    )
                );
                _safeExecuteTransaction(
                    0xA434D495249abE33E031Fe71a969B81f3c07950D,
                    abi.encodeWithSelector(0x474cf53d, 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2, safe, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0xA434D495249abE33E031Fe71a969B81f3c07950D,
                    abi.encodeWithSelector(0x80500d20, 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2, 1 ether, safe)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f,
                    abi.encodeWithSelector(0x65ca4804, 0x5C0F23A5c1be65Fa710d385814a7Fd1Bda480b1C, safe, safe, 1 ether)
                );
            }
            {
                address[] memory gauges = new address[](1);
                gauges[0] = 0x79eF6103A513951a3b25743DB509E267685726B7;
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f, abi.encodeWithSelector(0x0e248fea, gauges)
                );
            }
            {
                address[] memory gauges = new address[](1);
                gauges[0] = 0x79eF6103A513951a3b25743DB509E267685726B7;
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f, abi.encodeWithSelector(0x3f85d390, gauges, 1 ether)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.FunctionNotAllowed,
                        bytes32(bytes4(0x6e553f65))
                    )
                );
                _safeExecuteTransaction(
                    0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD, abi.encodeWithSelector(0x6e553f65, 1 ether, safe)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C,
                    abi.encodeWithSelector(0x095ea7b3, 0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x83F20F44975D03b1b09e64809B757c47f942BEeA,
                    abi.encodeWithSelector(0x095ea7b3, 0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802)
                );
            }
            {
                uint256[] memory amounts = new uint256[](1);
                amounts[0] = 1 ether;
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802, abi.encodeWithSelector(0xb72df5de, amounts, 1 ether)
                );
            }
            {
                uint256[] memory amounts = new uint256[](1);
                amounts[0] = 1 ether;
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802, abi.encodeWithSelector(0xd40ddb8c, 1 ether, amounts)
                );
            }
            {
                uint256[] memory amounts = new uint256[](1);
                amounts[0] = 1 ether;
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802, abi.encodeWithSelector(0x7706db75, amounts, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802,
                    abi.encodeWithSelector(0x1a4d01d2, 1 ether, 1 ether, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802,
                    abi.encodeWithSelector(0x095ea7b3, 0xcF5136C67fA8A375BaBbDf13c0307EF994b5681D, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802,
                    abi.encodeWithSelector(0x3df02124, 1 ether, 1 ether, 1 ether, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0xcF5136C67fA8A375BaBbDf13c0307EF994b5681D, abi.encodeWithSelector(0xb6b55f25, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    0xcF5136C67fA8A375BaBbDf13c0307EF994b5681D, abi.encodeWithSelector(0x2e1a7d4d, 1 ether)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(0xcF5136C67fA8A375BaBbDf13c0307EF994b5681D, abi.encodeWithSelector(0xe6f1daf2));
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.FunctionNotAllowed,
                        bytes32(bytes4(0xfa6e671d))
                    )
                );
                _safeExecuteTransaction(
                    0xBA12222222228d8Ba445958a75a0704d566BF2C8,
                    abi.encodeWithSelector(0xfa6e671d, safe, 0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f, true)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.FunctionNotAllowed,
                        bytes32(bytes4(0x0de54ba0))
                    )
                );
                _safeExecuteTransaction(
                    0x239e55F427D44C3cc793f49bFB507ebe76638a2b,
                    abi.encodeWithSelector(0x0de54ba0, 0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f, true)
                );
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector,
                        IZodiacRoles.Status.FunctionNotAllowed,
                        bytes32(bytes4(0x095ea7b3))
                    )
                );
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
                _safeExecuteTransaction(0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3, abi.encodeWithSelector(0xf51b0fd4));
            }
            {
                uint256[] memory amounts = new uint256[](2);
                amounts[0] = 1 ether;
                amounts[1] = 1 ether;
                _safeExecuteTransaction(
                    0x59Ab5a5b5d617E478a2479B0cAD80DA7e2831492, abi.encodeWithSelector(0x0b4c7e4d, amounts, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0x59Ab5a5b5d617E478a2479B0cAD80DA7e2831492,
                    abi.encodeWithSelector(0x5b36389c, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0x59Ab5a5b5d617E478a2479B0cAD80DA7e2831492,
                    abi.encodeWithSelector(0xe3103273, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0x59Ab5a5b5d617E478a2479B0cAD80DA7e2831492,
                    abi.encodeWithSelector(0x1a4d01d2, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0x399e111c7209a741B06F8F86Ef0Fdd88fC198D20, abi.encodeWithSelector(0xa694fc3a, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0x399e111c7209a741B06F8F86Ef0Fdd88fC198D20, abi.encodeWithSelector(0x38d07436, 1 ether, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0x399e111c7209a741B06F8F86Ef0Fdd88fC198D20,
                    abi.encodeWithSelector(0xc32e7202, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97, 1 ether, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0xe080027Bd47353b5D1639772b4a75E9Ed3658A0d,
                    abi.encodeWithSelector(0xb72df5de, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0xe080027Bd47353b5D1639772b4a75E9Ed3658A0d,
                    abi.encodeWithSelector(0xd40ddb8c, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97)
                );
            }
            {
                _safeExecuteTransaction(
                    0xe080027Bd47353b5D1639772b4a75E9Ed3658A0d,
                    abi.encodeWithSelector(0x1a4d01d2, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0xe080027Bd47353b5D1639772b4a75E9Ed3658A0d,
                    abi.encodeWithSelector(0x7706db75, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97)
                );
            }
            {
                _safeExecuteTransaction(
                    0xBA7eBDEF7723e55c909Ac44226FB87a93625c44e, abi.encodeWithSelector(0xa694fc3a, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0xBA7eBDEF7723e55c909Ac44226FB87a93625c44e, abi.encodeWithSelector(0x38d07436, 1 ether, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0xBA7eBDEF7723e55c909Ac44226FB87a93625c44e,
                    abi.encodeWithSelector(0xc32e7202, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97, 1 ether, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0xCF370C3279452143f68e350b824714B49593a334,
                    abi.encodeWithSelector(0xc32e7202, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97, 1 ether, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0xCF370C3279452143f68e350b824714B49593a334,
                    abi.encodeWithSelector(0x3d18b912, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97)
                );
            }
            {
                _safeExecuteTransaction(
                    0x994BE003de5FD6E41d37c6948f405EB0759149e6,
                    abi.encodeWithSelector(0xc32e7202, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97, 1 ether, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0x994BE003de5FD6E41d37c6948f405EB0759149e6,
                    abi.encodeWithSelector(0x3d18b912, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97)
                );
            }
            {
                _safeExecuteTransaction(
                    0x4B891340b51889f438a03DC0e8aAAFB0Bc89e7A6, abi.encodeWithSelector(0xb6b55f25, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0x4B891340b51889f438a03DC0e8aAAFB0Bc89e7A6, abi.encodeWithSelector(0x2e1a7d4d, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0x4B891340b51889f438a03DC0e8aAAFB0Bc89e7A6, abi.encodeWithSelector(0xe6f1daf2, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0x70A1c01902DAb7a45dcA1098Ca76A8314dd8aDbA, abi.encodeWithSelector(0xb6b55f25, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0x70A1c01902DAb7a45dcA1098Ca76A8314dd8aDbA, abi.encodeWithSelector(0x2e1a7d4d, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0x70A1c01902DAb7a45dcA1098Ca76A8314dd8aDbA, abi.encodeWithSelector(0xe6f1daf2, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0x1f3A4C8115629C33A28bF2F97F22D31d256317F6, abi.encodeWithSelector(0xb6b55f25, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0x1f3A4C8115629C33A28bF2F97F22D31d256317F6, abi.encodeWithSelector(0x2e1a7d4d, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0x1f3A4C8115629C33A28bF2F97F22D31d256317F6, abi.encodeWithSelector(0xe6f1daf2, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0x7671299eA7B4bbE4f3fD305A994e6443b4be680E, abi.encodeWithSelector(0xb6b55f25, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0x7671299eA7B4bbE4f3fD305A994e6443b4be680E, abi.encodeWithSelector(0x2e1a7d4d, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0x7671299eA7B4bbE4f3fD305A994e6443b4be680E, abi.encodeWithSelector(0xe6f1daf2, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0x63037a4e3305d25D48BAED2022b8462b2807351c, abi.encodeWithSelector(0xb6b55f25, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0x63037a4e3305d25D48BAED2022b8462b2807351c, abi.encodeWithSelector(0x2e1a7d4d, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0x63037a4e3305d25D48BAED2022b8462b2807351c, abi.encodeWithSelector(0x38d07436, 1 ether, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0x63037a4e3305d25D48BAED2022b8462b2807351c, abi.encodeWithSelector(0xe6f1daf2, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0xcc7d5785AD5755B6164e21495E07aDb0Ff11C2A8,
                    abi.encodeWithSelector(0xb72df5de, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0xcc7d5785AD5755B6164e21495E07aDb0Ff11C2A8,
                    abi.encodeWithSelector(0xd40ddb8c, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97)
                );
            }
            {
                _safeExecuteTransaction(
                    0xcc7d5785AD5755B6164e21495E07aDb0Ff11C2A8,
                    abi.encodeWithSelector(0x7706db75, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97)
                );
            }
            {
                _safeExecuteTransaction(
                    0xcc7d5785AD5755B6164e21495E07aDb0Ff11C2A8,
                    abi.encodeWithSelector(0x1a4d01d2, 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0x36cC1d791704445A5b6b9c36a667e511d4702F3f, abi.encodeWithSelector(0xb6b55f25, 1 ether)
                );
            }
            {
                _safeExecuteTransaction(
                    0x36cC1d791704445A5b6b9c36a667e511d4702F3f, abi.encodeWithSelector(0x2e1a7d4d, 1 ether)
                );
            }
        }

        // SCOPE FUNCTION
        {
            {
                {
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
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987,
                        abi.encodeWithSelector(
                            0x5a3b74b9, // setUserUseReserveAsCollateral
                            0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0, // asset
                            true // useAsCollateral
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987,
                        abi.encodeWithSelector(
                            0x5a3b74b9, // setUserUseReserveAsCollateral
                            0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // asset
                            true // useAsCollateral
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987,
                        abi.encodeWithSelector(
                            0x5a3b74b9, // setUserUseReserveAsCollateral
                            0xdAC17F958D2ee523a2206206994597C13D831ec7, // asset
                            true // useAsCollateral
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987,
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
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987,
                        abi.encodeWithSelector(
                            0x617ba037, // supply
                            0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0, // asset
                            1 ether, // amount
                            safe, // onBehalfOf
                            0 // referralCode
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987,
                        abi.encodeWithSelector(
                            0x617ba037, // supply
                            0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // asset
                            1 ether, // amount
                            safe, // onBehalfOf
                            0 // referralCode
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987,
                        abi.encodeWithSelector(
                            0x617ba037, // supply
                            0xdAC17F958D2ee523a2206206994597C13D831ec7, // asset
                            1 ether, // amount
                            safe, // onBehalfOf
                            0 // referralCode
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987,
                        abi.encodeWithSelector(
                            0x617ba037, // supply
                            0xdC035D45d973E3EC169d2276DDab16f1e407384F, // asset
                            1 ether, // amount
                            safe, // onBehalfOf
                            0 // referralCode
                        )
                    );
                }
            }

            {
                {
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987,
                        abi.encodeWithSelector(
                            0x69328dec, // withdraw
                            0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0, // asset
                            1 ether, // amount
                            safe // to
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987,
                        abi.encodeWithSelector(
                            0x69328dec, // withdraw
                            0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // asset
                            1 ether, // amount
                            safe // to
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987,
                        abi.encodeWithSelector(
                            0x69328dec, // withdraw
                            0xdAC17F958D2ee523a2206206994597C13D831ec7, // asset
                            1 ether, // amount
                            safe // to
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        0xC13e21B648A5Ee794902342038FF3aDAB66BE987,
                        abi.encodeWithSelector(
                            0x69328dec, // withdraw
                            0xdC035D45d973E3EC169d2276DDab16f1e407384F, // asset
                            1 ether, // amount
                            safe // to
                        )
                    );
                }
            }

            {
                {
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
                    _safeExecuteTransaction(
                        0x1B0e765F6224C21223AeA2af16c1C46E38885a40, // Compound v3: CometRewards
                        abi.encodeWithSelector(
                            0xb7034f7e, // claim
                            0x3Afdc9BCA9213A35503b077a6072F3D0d5AB0840, // comet
                            safe, // src
                            true // shouldAccrue
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        0x1B0e765F6224C21223AeA2af16c1C46E38885a40, // Compound v3: CometRewards
                        abi.encodeWithSelector(
                            0xb7034f7e, // claim
                            0x5D409e56D886231aDAf00c8775665AD0f9897b56, // comet
                            safe, // src
                            true // shouldAccrue
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        0x1B0e765F6224C21223AeA2af16c1C46E38885a40, // Compound v3: CometRewards
                        abi.encodeWithSelector(
                            0xb7034f7e, // claim
                            0xc3d688B66703497DAA19211EEdff47f25384cdc3, // comet
                            safe, // src
                            true // shouldAccrue
                        )
                    );
                }
            }

            {
                {
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
                    _safeExecuteTransaction(
                        0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD,
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
                    _safeExecuteTransaction(
                        0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD,
                        abi.encodeWithSelector(
                            0x9b8d6d38, // deposit
                            1 ether, // assets
                            safe, // receiver
                            0 // referral
                        )
                    );
                }
            }

            {
                {
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
                    _safeExecuteTransaction(
                        0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2, // Aave v3: Pool
                        abi.encodeWithSelector(
                            0x617ba037, // supply
                            0xA35b1B31Ce002FBF2058D22F30f95D405200A15b, // asset
                            1 ether, // amount
                            safe, // onBehalfOf
                            0 // referralCode
                        )
                    );
                }
            }

            {
                {
                    _safeExecuteTransaction(
                        0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2, // Aave v3: Pool
                        abi.encodeWithSelector(
                            0x69328dec, // withdraw
                            0xA35b1B31Ce002FBF2058D22F30f95D405200A15b, // asset
                            1 ether, // amount
                            safe // to
                        )
                    );
                }
            }

            {
                {
                    _safeExecuteTransaction(
                        0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8, // aWETH Token
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0xd01607c3C5eCABa394D8be377a08590149325722, // spender
                            1 ether // amount
                        )
                    );
                }
            }

            {
                {
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
                    _safeExecuteTransaction(
                        0x239e55F427D44C3cc793f49bFB507ebe76638a2b,
                        abi.encodeWithSelector(
                            0x6a627842, // mint
                            0x1f3A4C8115629C33A28bF2F97F22D31d256317F6 // gauge
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        0x239e55F427D44C3cc793f49bFB507ebe76638a2b,
                        abi.encodeWithSelector(
                            0x6a627842, // mint
                            0x4B891340b51889f438a03DC0e8aAAFB0Bc89e7A6 // gauge
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        0x239e55F427D44C3cc793f49bFB507ebe76638a2b,
                        abi.encodeWithSelector(
                            0x6a627842, // mint
                            0x70A1c01902DAb7a45dcA1098Ca76A8314dd8aDbA // gauge
                        )
                    );
                }
            }

            {
                {
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
                    _safeExecuteTransaction(
                        0xd061D61a4d941c39E5453435B6345Dc261C2fcE0, // Curve: Token Minter
                        abi.encodeWithSelector(
                            0x6a627842, // mint
                            0x36cC1d791704445A5b6b9c36a667e511d4702F3f // gauge_addr
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        0xd061D61a4d941c39E5453435B6345Dc261C2fcE0, // Curve: Token Minter
                        abi.encodeWithSelector(
                            0x6a627842, // mint
                            0x63037a4e3305d25D48BAED2022b8462b2807351c // gauge_addr
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        0xd061D61a4d941c39E5453435B6345Dc261C2fcE0, // Curve: Token Minter
                        abi.encodeWithSelector(
                            0x6a627842, // mint
                            0x7671299eA7B4bbE4f3fD305A994e6443b4be680E // gauge_addr
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
                            0xcF5136C67fA8A375BaBbDf13c0307EF994b5681D // gauge_addr
                        )
                    );
                }
            }

            {
                {
                    _safeExecuteTransaction(
                        0xd01607c3C5eCABa394D8be377a08590149325722, // WrappedTokenGatewayV3
                        abi.encodeWithSelector(
                            0x474cf53d, // depositETH
                            0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2, // ()
                            safe
                        )
                    );
                }
            }

            {
                {
                    _safeExecuteTransaction(
                        0xd01607c3C5eCABa394D8be377a08590149325722, // WrappedTokenGatewayV3
                        abi.encodeWithSelector(
                            0x80500d20, // withdrawETH
                            0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2, // ()
                            1 ether, // amount
                            safe // to
                        )
                    );
                }
            }

            {
                {
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
                    _safeExecuteTransaction(
                        0x399e111c7209a741B06F8F86Ef0Fdd88fC198D20, // BaseRewardPool
                        abi.encodeWithSelector(
                            0x7050ccd9, // getReward
                            safe, // account (AVATAR)
                            true // claimExtras
                        )
                    );
                }
            }

            {
                {
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
                    _safeExecuteTransaction(
                        0xBA7eBDEF7723e55c909Ac44226FB87a93625c44e, // BaseRewardPool
                        abi.encodeWithSelector(
                            0x7050ccd9, // getReward
                            safe, // account (AVATAR)
                            true // claimExtras
                        )
                    );
                }
            }

            {
                {
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
                    _safeExecuteTransaction(
                        0x58D97B57BB95320F9a05dC918Aef65434969c2B2, // MorphoTokenEthereum
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0xC92E8bdf79f0507f65a392b0ab4667716BFE0110, // spender
                            1 ether // amount
                        )
                    );
                }
            }

            {
                {
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
                    _safeExecuteTransaction(
                        0xc20059e0317DE91738d13af027DfC4a50781b066, // SDAO
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0xC92E8bdf79f0507f65a392b0ab4667716BFE0110, // spender
                            1 ether // amount
                        )
                    );
                }
            }

            {
                {
                    _safeExecuteTransaction(
                        0x4F2083f5fBede34C2714aFfb3105539775f7FE64, // GnosisSafe
                        abi.encodeWithSelector(
                            0x3365582c, // setDomainVerifier(bytes32,address)
                            0xc078f884a2676e1345748b1feace7b0abee5d00ecadb6e574dcdd109a63e8943,
                            0xfdaFc9d1902f4e0b84f65F49f244b32b31013b74
                        )
                    );
                }
            }

            {
                {
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
                    _safeExecuteTransaction(
                        0xBc65ad17c5C0a2A4D159fa5a503f4992c7B545FE, // UsdcVault
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0xd0A61F2963622e992e6534bde4D52fd0a89F39E0, // spender
                            1 ether // value
                        )
                    );
                }
            }

            {
                {
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
                        _safeExecuteTransaction(
                            0xc4Ce391d82D164c166dF9c8336DDF84206b2F812, // StablePool
                            abi.encodeWithSelector(
                                0x095ea7b3, // approve
                                0xA57b8d98dAE62B26Ec3bcC4a365338157060B234, // spender
                                1 ether // amount
                            )
                        );
                    }
                }
                {
                    {
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
                    _safeExecuteTransaction(
                        0xCF370C3279452143f68e350b824714B49593a334, // BaseRewardPool4626
                        abi.encodeWithSelector(
                            0x3d18b912 // getReward  (no
                        )
                    );
                }
                {
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
                    _safeExecuteTransaction(
                        0x57c23c58B1D8C3292c15BEcF07c62C5c52457A42, // StablePool
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0x70A1c01902DAb7a45dcA1098Ca76A8314dd8aDbA,
                            1 ether // amount
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        0x57c23c58B1D8C3292c15BEcF07c62C5c52457A42, // StablePool
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0xA57b8d98dAE62B26Ec3bcC4a365338157060B234,
                            1 ether // amount
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        0x57c23c58B1D8C3292c15BEcF07c62C5c52457A42, // StablePool
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0xb21A277466e7dB6934556a1Ce12eb3F032815c8A,
                            1 ether // amount
                        )
                    );
                }
            }

            {
                {
                    _safeExecuteTransaction(
                        0x994BE003de5FD6E41d37c6948f405EB0759149e6, // BaseRewardPool4626
                        abi.encodeWithSelector(
                            0x3d18b912 // getReward  (no
                        )
                    );
                }

                {
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
                    _safeExecuteTransaction(
                        0x000000000022D473030F116dDEE9F6B43aC78BA3, // Permit2
                        abi.encodeWithSelector(
                            0x87517c45, // approve
                            0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0, // token
                            0xb21A277466e7dB6934556a1Ce12eb3F032815c8A, // spender
                            uint160(1 ether), // amount
                            uint48(block.timestamp + 3600) // expiration
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        0x000000000022D473030F116dDEE9F6B43aC78BA3, // Permit2
                        abi.encodeWithSelector(
                            0x87517c45, // approve
                            0xA35b1B31Ce002FBF2058D22F30f95D405200A15b, // token
                            0xb21A277466e7dB6934556a1Ce12eb3F032815c8A, // spender
                            uint160(1 ether), // amount
                            uint48(block.timestamp + 3600) // expiration
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        0x000000000022D473030F116dDEE9F6B43aC78BA3, // Permit2
                        abi.encodeWithSelector(
                            0x87517c45, // approve
                            0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, // token
                            0xb21A277466e7dB6934556a1Ce12eb3F032815c8A, // spender
                            uint160(1 ether), // amount
                            uint48(block.timestamp + 3600) // expiration
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        0x000000000022D473030F116dDEE9F6B43aC78BA3, // Permit2
                        abi.encodeWithSelector(
                            0x87517c45, // approve
                            0xf1C9acDc66974dFB6dEcB12aA385b9cD01190E38, // token
                            0xb21A277466e7dB6934556a1Ce12eb3F032815c8A, // spender
                            uint160(1 ether), // amount
                            uint48(block.timestamp + 3600) // expiration
                        )
                    );
                }
            }

            {
                {
                    _safeExecuteTransaction(
                        0xb21A277466e7dB6934556a1Ce12eb3F032815c8A, // CompositeLiquidityRouter
                        abi.encodeWithSelector(
                            0xc1da024c, // addLiquidityUnbalancedToERC4626Pool
                            0x4AB7aB316D43345009B2140e0580B072eEc7DF16, // pool
                            new bool[](2), // wrapUnderlying
                            new uint256[](2), // exactAmountIn
                            1 ether, // minBptAmountOut
                            false, // wethIsEth
                            "" // userData
                        )
                    );
                }

                {
                    _safeExecuteTransaction(
                        0xb21A277466e7dB6934556a1Ce12eb3F032815c8A, // CompositeLiquidityRouter
                        abi.encodeWithSelector(
                            0xd8a7f9fe, // removeLiquidityProportionalFromERC4626Pool
                            0x57c23c58B1D8C3292c15BEcF07c62C5c52457A42, // pool
                            new bool[](2), // unwrapWrapped
                            1 ether, // exactBptAmountIn
                            new uint256[](2), // minAmountOut
                            false, // wethIsEth
                            "" // userData
                        )
                    );
                }

                {
                    _safeExecuteTransaction(
                        0xb21A277466e7dB6934556a1Ce12eb3F032815c8A, // CompositeLiquidityRouter
                        abi.encodeWithSelector(
                            0xe3c3e64f, // addLiquidityProportionalToERC4626Pool
                            0xc4Ce391d82D164c166dF9c8336DDF84206b2F812, // pool
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
                    _safeExecuteTransaction(
                        0x4AB7aB316D43345009B2140e0580B072eEc7DF16, // StablePool
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0x1f3A4C8115629C33A28bF2F97F22D31d256317F6, // spender
                            1 ether // amount
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        0x4AB7aB316D43345009B2140e0580B072eEc7DF16, // StablePool
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0xb21A277466e7dB6934556a1Ce12eb3F032815c8A, // spender
                            1 ether // amount
                        )
                    );
                }
            }

            {
                {
                    _safeExecuteTransaction(
                        0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490, // Vyper_contract
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A, // _spender
                            1 ether // _value
                        )
                    );
                }
            }

            {
                {
                    _safeExecuteTransaction(
                        0xcc7d5785AD5755B6164e21495E07aDb0Ff11C2A8, // CurveStableSwapNG
                        abi.encodeWithSelector(
                            0x095ea7b3, // approve
                            0x36cC1d791704445A5b6b9c36a667e511d4702F3f, // _spender
                            1 ether // _value
                        )
                    );
                }
            }

            {
                {
                    _safeExecuteTransaction(
                        0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb, // Morpho
                        abi.encodeWithSelector(
                            0x5c2bea49, // withdraw
                            MarketParams(
                                0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // loanToken
                                0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599, // collateralToken
                                0xDddd770BADd886dF3864029e4B377B5F6a2B6b83, // oracle
                                0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC, // irm
                                860_000_000_000_000_000 // lltv
                            ),
                            1 ether, // assets
                            1 ether, // shares
                            safe, // onBehalf
                            safe // receiver
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb, // Morpho
                        abi.encodeWithSelector(
                            0x5c2bea49, // withdraw
                            MarketParams(
                                0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // loanToken
                                0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0, // collateralToken
                                0x48F7E36EB6B826B2dF4B2E630B62Cd25e89E40e2, // oracle
                                0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC, // irm
                                860_000_000_000_000_000 // lltv
                            ),
                            1 ether, // assets
                            1 ether, // shares
                            safe, // onBehalf
                            safe // receiver
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb, // Morpho
                        abi.encodeWithSelector(
                            0x5c2bea49, // withdraw
                            MarketParams(
                                0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // loanToken
                                0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf, // collateralToken
                                0xA6D6950c9F177F1De7f7757FB33539e3Ec60182a, // oracle
                                0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC, // irm
                                860_000_000_000_000_000 // lltv
                            ),
                            1 ether, // assets
                            1 ether, // shares
                            safe, // onBehalf
                            safe // receiver
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb, // Morpho
                        abi.encodeWithSelector(
                            0x5c2bea49, // withdraw
                            MarketParams(
                                0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, // loanToken
                                0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0, // collateralToken
                                0xbD60A6770b27E084E8617335ddE769241B0e71D8, // oracle
                                0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC, // irm
                                945_000_000_000_000_000 // lltv
                            ),
                            1 ether, // assets
                            1 ether, // shares
                            safe, // onBehalf
                            safe // receiver
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb, // Morpho
                        abi.encodeWithSelector(
                            0x5c2bea49, // withdraw
                            MarketParams(
                                0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, // loanToken
                                0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0, // collateralToken
                                0xbD60A6770b27E084E8617335ddE769241B0e71D8, // oracle
                                0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC, // irm
                                965_000_000_000_000_000 // lltv
                            ),
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
                    address[] memory users = new address[](1);
                    users[0] = 0x4F2083f5fBede34C2714aFfb3105539775f7FE64;
                    _safeExecuteTransaction(
                        0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae, // Angle: Distributor
                        abi.encodeWithSelector(
                            0x71ee95c0, // claim
                            users, // users
                            new address[](1), // tokens
                            new uint256[](1), // amounts
                            new bytes32[][](1) // proofs
                        )
                    );
                }
            }

            {
                {
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
            {
                {
                    _safeExecuteTransaction(
                        0xc20059e0317DE91738d13af027DfC4a50781b066, // SPK Token
                        abi.encodeWithSelector(
                            0xa9059cbb, // transfer
                            address(timelock), // to
                            1 ether // amount
                        )
                    );
                }
            }
        }
        
        address SPK = 0xc20059e0317DE91738d13af027DfC4a50781b066;
        console2.log("SPK Token balance of timelock: ", IERC20(SPK).balanceOf(address(timelock)));
        console2.log("SPK Token balance of safe: ", IERC20(SPK).balanceOf(address(safe)));
        vm.stopPrank();
    }



    // ====================================================================
    // Calldata Generation
    // ====================================================================

    function _generateCallData()
        public
        override
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory, string memory)
    {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        signatures = new string[](1);

        targets[0] = safe;
        calldatas[0] = _buildFullSafeCalldata();
        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    function _buildFullSafeCalldata() internal view returns (bytes memory) {
        (, bytes memory cd) = _buildSafeExecDelegateCalldata(
            address(endowmentSafe),
            address(PROPOSAL_MULTI_SEND),
            _buildMultiSendCalldata(),
            address(timelock)
        );
        return cd;
    }

    function _buildMultiSendCalldata() internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            IMultiSend.multiSend.selector,
            _buildPackedTransactions()
        );
    }

    function _buildPackedTransactions() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packRevokes(),
            _packAnnotation1(),
            _packScopes1(),
            _packScopes2(),
            _packScopes3(),
            _packScopes4(),
            _packScopes5(),
            _packScopes6(),
            _packScopes7(),
            _packScopes8(),
            _packAnnotation2()
        );
    }

    // --- Revoke Block (TX 1-29) ---
    function _packRevokes() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packRevokes_A(),
            _packRevokes_B(),
            _packRevokes_C(),
            _packRevokes_D()
        );
    }

    function _packRevokes_A() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.revokeTarget.selector, MANAGER_ROLE, 0x893411580e590D62dDBca8a703d61Cc4A8c7b2b9)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.revokeFunction.selector, MANAGER_ROLE, 0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1, bytes4(0xacf41e4d))),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.revokeFunction.selector, MANAGER_ROLE, 0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1, bytes4(0x7951b76f))),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.revokeTarget.selector, MANAGER_ROLE, 0xA434D495249abE33E031Fe71a969B81f3c07950D)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.revokeFunction.selector, MANAGER_ROLE, 0xA434D495249abE33E031Fe71a969B81f3c07950D, bytes4(0x474cf53d))),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.revokeFunction.selector, MANAGER_ROLE, 0xA434D495249abE33E031Fe71a969B81f3c07950D, bytes4(0x80500d20))),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.revokeTarget.selector, MANAGER_ROLE, 0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.revokeFunction.selector, MANAGER_ROLE, 0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f, bytes4(0x65ca4804)))
        );
    }

    function _packRevokes_B() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.revokeFunction.selector, MANAGER_ROLE, 0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f, bytes4(0x0e248fea))),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.revokeFunction.selector, MANAGER_ROLE, 0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f, bytes4(0x3f85d390))),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.revokeFunction.selector, MANAGER_ROLE, 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD, bytes4(0x6e553f65))),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.revokeTarget.selector, MANAGER_ROLE, 0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.revokeFunction.selector, MANAGER_ROLE, 0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C, bytes4(0x095ea7b3))),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.revokeTarget.selector, MANAGER_ROLE, 0x83F20F44975D03b1b09e64809B757c47f942BEeA)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.revokeFunction.selector, MANAGER_ROLE, 0x83F20F44975D03b1b09e64809B757c47f942BEeA, bytes4(0x095ea7b3))),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.revokeTarget.selector, MANAGER_ROLE, 0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802))
        );
    }

    function _packRevokes_C() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.revokeFunction.selector, MANAGER_ROLE, 0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802, bytes4(0xb72df5de))),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.revokeFunction.selector, MANAGER_ROLE, 0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802, bytes4(0xd40ddb8c))),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.revokeFunction.selector, MANAGER_ROLE, 0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802, bytes4(0x7706db75))),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.revokeFunction.selector, MANAGER_ROLE, 0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802, bytes4(0x1a4d01d2))),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.revokeFunction.selector, MANAGER_ROLE, 0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802, bytes4(0x095ea7b3))),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.revokeFunction.selector, MANAGER_ROLE, 0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802, bytes4(0x3df02124))),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.revokeTarget.selector, MANAGER_ROLE, 0xcF5136C67fA8A375BaBbDf13c0307EF994b5681D)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.revokeFunction.selector, MANAGER_ROLE, 0xcF5136C67fA8A375BaBbDf13c0307EF994b5681D, bytes4(0xb6b55f25)))
        );
    }

    function _packRevokes_D() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.revokeFunction.selector, MANAGER_ROLE, 0xcF5136C67fA8A375BaBbDf13c0307EF994b5681D, bytes4(0x2e1a7d4d))),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.revokeFunction.selector, MANAGER_ROLE, 0xcF5136C67fA8A375BaBbDf13c0307EF994b5681D, bytes4(0xe6f1daf2))),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.revokeFunction.selector, MANAGER_ROLE, 0xBA12222222228d8Ba445958a75a0704d566BF2C8, bytes4(0xfa6e671d))),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.revokeFunction.selector, MANAGER_ROLE, 0x239e55F427D44C3cc793f49bFB507ebe76638a2b, bytes4(0x0de54ba0))),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.revokeFunction.selector, MANAGER_ROLE, 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7, bytes4(0x095ea7b3)))
        );
    }


    // --- Annotation 1 (TX 30) ---
    function _packAnnotation1() internal pure returns (bytes memory) {
        string memory annotationJson =
            "{\"rolesMod\":\"0x703806e61847984346d2d7ddd853049627e50a40\",\"roleKey\":\"0x4d414e414745520000000000000000"
            "0000000000000000000000000000000000\",\"removeAnnotations\":[\"https://kit.karpatkey.com/api/v1/permissio"
            "ns/eth/balancer/deposit?targets=wstETH-WETH-BPT\",\"https://kit.karpatkey.com/api/v1/permissions/eth/b"
            "alancer/stake?targets=wstETH-WETH-BPT\",\"https://kit.karpatkey.com/api/v1/permissions/eth/balancer/de"
            "posit?targets=B-rETH-STABLE\",\"https://kit.karpatkey.com/api/v1/permissions/eth/balancer/stake?target"
            "s=B-rETH-STABLE\",\"https://kit.karpatkey.com/api/v1/permissions/eth/balancer/deposit?targets=osETH%2F"
            "wETH-BPT\",\"https://kit.karpatkey.com/api/v1/permissions/eth/balancer/stake?targets=osETH%2FwETH-BPT\""
            ",\"https://kit.karpatkey.com/api/v1/permissions/eth/cowswap/swap?sell=0xE95A203B1a91a908F9B9CE46459d1"
            "01078c2c3cb%2C0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF%2C0xba100000625a3754423978a60c9317c58a424e3"
            "D%2C0xc00e94Cb662C3520282E6f5717214004A7f26888%2C0xD533a949740bb3306d119CC777fa900bA034cd52%2C0x4e3F"
            "BD56CD56c3e72c1403e103b45Db9da5B9D2B%2C0x6B175474E89094C44Da98b954EedeAC495271d0F%2C0xA35b1B31Ce002F"
            "BF2058D22F30f95D405200A15b%2C0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32%2C0xf1C9acDc66974dFB6dEcB12a"
            "A385b9cD01190E38%2C0xae78736Cd615f374D3085123A210448E74Fc6393%2C0xD33526068D116cE69F19A9ee46F0bd304F"
            "21A51f%2C0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84%2C0x48C3399719B582dD63eB5AADf12A40B4C3f52FA2%2C0"
            "xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48%2C0xdAC17F958D2ee523a2206206994597C13D831ec7%2C0xC02aaA39b"
            "223FE8D0A0e5C4F27eAD9083C756Cc2%2C0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0&buy=0x6B175474E89094C44"
            "Da98b954EedeAC495271d0F%2C0xae78736Cd615f374D3085123A210448E74Fc6393%2C0xA0b86991c6218b36c1d19D4a2e9"
            "Eb0cE3606eB48%2C0xdAC17F958D2ee523a2206206994597C13D831ec7%2C0xae7ab96520DE3A18E5e111B5EaAb095312D7f"
            "E84%2C0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2%2C0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0\",\"http"
            "s://kit.karpatkey.com/api/v1/permissions/eth/cowswap/swap?sell=0xE95A203B1a91a908F9B9CE46459d101078c"
            "2c3cb%2C0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF%2C0xba100000625a3754423978a60c9317c58a424e3D%2C0x"
            "c00e94Cb662C3520282E6f5717214004A7f26888%2C0xD533a949740bb3306d119CC777fa900bA034cd52%2C0x4e3FBD56CD"
            "56c3e72c1403e103b45Db9da5B9D2B%2C0x6B175474E89094C44Da98b954EedeAC495271d0F%2C0xA35b1B31Ce002FBF2058"
            "D22F30f95D405200A15b%2C0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32%2C0xf1C9acDc66974dFB6dEcB12aA385b9"
            "cD01190E38%2C0xae78736Cd615f374D3085123A210448E74Fc6393%2C0xD33526068D116cE69F19A9ee46F0bd304F21A51f"
            "%2C0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84%2C0x48C3399719B582dD63eB5AADf12A40B4C3f52FA2%2C0xA0b86"
            "991c6218b36c1d19D4a2e9Eb0cE3606eB48%2C0xdAC17F958D2ee523a2206206994597C13D831ec7%2C0xC02aaA39b223FE8"
            "D0A0e5C4F27eAD9083C756Cc2%2C0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0&buy=0x856c4Efb76C1D1AE02e20CE"
            "B03A2A6a08b0b8dC3%2C0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD%2C0x59d9356e565ab3a36dd77763fc0d87fea"
            "f85508c%2C0xdC035D45d973E3EC169d2276DDab16f1e407384F%2C0xdAC17F958D2ee523a2206206994597C13D831ec7\",\""
            "https://kit.karpatkey.com/api/v1/permissions/eth/cowswap/swap?sell=0x856c4Efb76C1D1AE02e20CEB03A2A6a"
            "08b0b8dC3%2C0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD%2C0x59d9356e565ab3a36dd77763fc0d87feaf85508c%"
            "2C0xdC035D45d973E3EC169d2276DDab16f1e407384F%2C0xdAC17F958D2ee523a2206206994597C13D831ec7&buy=0xE95A"
            "203B1a91a908F9B9CE46459d101078c2c3cb%2C0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF%2C0xba100000625a37"
            "54423978a60c9317c58a424e3D%2C0xc00e94Cb662C3520282E6f5717214004A7f26888%2C0xD533a949740bb3306d119CC7"
            "77fa900bA034cd52%2C0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B%2C0x6B175474E89094C44Da98b954EedeAC495"
            "271d0F%2C0xA35b1B31Ce002FBF2058D22F30f95D405200A15b%2C0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32%2C0"
            "xf1C9acDc66974dFB6dEcB12aA385b9cD01190E38%2C0xae78736Cd615f374D3085123A210448E74Fc6393%2C0xD33526068"
            "D116cE69F19A9ee46F0bd304F21A51f%2C0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84%2C0x48C3399719B582dD63e"
            "B5AADf12A40B4C3f52FA2%2C0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48%2C0xdAC17F958D2ee523a220620699459"
            "7C13D831ec7%2C0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2%2C0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca"
            "0\"]}";
        return _packTx(
            address(ANNOTATION_REGISTRY),
            abi.encodeWithSelector(IAnnotationRegistry.post.selector, annotationJson, "ROLES_PERMISSION_ANNOTATION")
        );
    }

    // --- Scope Block 1: Token Approvals + Euler (TX 31-43) ---
    function _packScopes1() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packScopes1_A(),
            _packScopes1_B()
        );
    }

    function _packScopes1_A() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0, bytes4(0x095ea7b3), _cond_31(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, bytes4(0x095ea7b3), _cond_32(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xae78736Cd615f374D3085123A210448E74Fc6393, bytes4(0x095ea7b3), _cond_33(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xC13e21B648A5Ee794902342038FF3aDAB66BE987, bytes4(0x5a3b74b9), _cond_34(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xC13e21B648A5Ee794902342038FF3aDAB66BE987, bytes4(0x617ba037), _cond_35(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xC13e21B648A5Ee794902342038FF3aDAB66BE987, bytes4(0x69328dec), _cond_36(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xA35b1B31Ce002FBF2058D22F30f95D405200A15b, bytes4(0x095ea7b3), _cond_37(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0x1B0e765F6224C21223AeA2af16c1C46E38885a40, bytes4(0xb7034f7e), _cond_38(), EXEC_NONE))
        );
    }

    function _packScopes1_B() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xf1C9acDc66974dFB6dEcB12aA385b9cD01190E38, bytes4(0x095ea7b3), _cond_39(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xA57b8d98dAE62B26Ec3bcC4a365338157060B234, bytes4(0x43a0d066), _cond_40(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xdC035D45d973E3EC169d2276DDab16f1e407384F, bytes4(0x095ea7b3), _cond_41(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3, bytes4(0x095ea7b3), _cond_42(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3, bytes4(0xf51b0fd4), EXEC_NONE))
        );
    }


    // --- Scope Block 2: Aave, Convex, 1inch, Uniswap (TX 44-59) ---
    function _packScopes2() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packScopes2_A(),
            _packScopes2_B(),
            _packScopes2_C()
        );
    }

    function _packScopes2_A() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD, bytes4(0x095ea7b3), _cond_44(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD, bytes4(0x9b8d6d38), _cond_45(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2, bytes4(0x617ba037), _cond_46(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2, bytes4(0x69328dec), _cond_47(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2, bytes4(0x5a3b74b9), _cond_48(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8, bytes4(0x095ea7b3), _cond_49(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, bytes4(0x095ea7b3), _cond_50(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xdAC17F958D2ee523a2206206994597C13D831ec7, bytes4(0x095ea7b3), _cond_51(), EXEC_NONE))
        );
    }

    function _packScopes2_B() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0x239e55F427D44C3cc793f49bFB507ebe76638a2b, bytes4(0x6a627842), _cond_52(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xF403C135812408BFbE8713b5A23a04b3D48AAE31, bytes4(0x43a0d066), _cond_53(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xF403C135812408BFbE8713b5A23a04b3D48AAE31, bytes4(0x60759fce), _cond_54(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xF403C135812408BFbE8713b5A23a04b3D48AAE31, bytes4(0x441a3e70), _cond_55(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0x23dA9AdE38E4477b23770DeD512fD37b12381FAB, bytes4(0x569d3489), _cond_56(), EXEC_DELEGATE_CALL)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xd061D61a4d941c39E5453435B6345Dc261C2fcE0, bytes4(0x6a627842), _cond_57(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0x56C526b0159a258887e0d79ec3a80dfb940d0cD7, bytes4(0x26a38e64), _cond_58(), EXEC_SEND)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45, bytes4(0x04e45aaf), _cond_59(), EXEC_NONE))
        );
    }

    function _packScopes2_C() internal pure returns (bytes memory) {
        return abi.encodePacked(

        );
    }


    // --- Scope Block 3: Lido, Spark, Curve (TX 60-71) ---
    function _packScopes3() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packScopes3_A(),
            _packScopes3_B()
        );
    }

    function _packScopes3_A() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0xd01607c3C5eCABa394D8be377a08590149325722)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xd01607c3C5eCABa394D8be377a08590149325722, bytes4(0x474cf53d), _cond_61(), EXEC_SEND)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xd01607c3C5eCABa394D8be377a08590149325722, bytes4(0x80500d20), _cond_62(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0x5D409e56D886231aDAf00c8775665AD0f9897b56)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0x5D409e56D886231aDAf00c8775665AD0f9897b56, bytes4(0xf2b9fdb8), _cond_64(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0x5D409e56D886231aDAf00c8775665AD0f9897b56, bytes4(0xf3fef3a3), _cond_65(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0x59Ab5a5b5d617E478a2479B0cAD80DA7e2831492)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0x59Ab5a5b5d617E478a2479B0cAD80DA7e2831492, bytes4(0x095ea7b3), _cond_67(), EXEC_NONE))
        );
    }

    function _packScopes3_B() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0x59Ab5a5b5d617E478a2479B0cAD80DA7e2831492, bytes4(0x0b4c7e4d), EXEC_SEND)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0x59Ab5a5b5d617E478a2479B0cAD80DA7e2831492, bytes4(0x5b36389c), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0x59Ab5a5b5d617E478a2479B0cAD80DA7e2831492, bytes4(0xe3103273), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0x59Ab5a5b5d617E478a2479B0cAD80DA7e2831492, bytes4(0x1a4d01d2), EXEC_NONE))
        );
    }


    // --- Scope Block 4: Convex Rewards (TX 72-91) ---
    function _packScopes4() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packScopes4_A(),
            _packScopes4_B(),
            _packScopes4_C()
        );
    }

    function _packScopes4_A() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0x1dF858Ae1fE8F58d6157B8Eb9f7089e62e303982)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0x1dF858Ae1fE8F58d6157B8Eb9f7089e62e303982, bytes4(0x095ea7b3), _cond_73(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0x399e111c7209a741B06F8F86Ef0Fdd88fC198D20)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0x399e111c7209a741B06F8F86Ef0Fdd88fC198D20, bytes4(0xa694fc3a), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0x399e111c7209a741B06F8F86Ef0Fdd88fC198D20, bytes4(0x38d07436), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0x399e111c7209a741B06F8F86Ef0Fdd88fC198D20, bytes4(0xc32e7202), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0x399e111c7209a741B06F8F86Ef0Fdd88fC198D20, bytes4(0x7050ccd9), _cond_78(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0xe080027Bd47353b5D1639772b4a75E9Ed3658A0d))
        );
    }

    function _packScopes4_B() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xe080027Bd47353b5D1639772b4a75E9Ed3658A0d, bytes4(0x095ea7b3), _cond_80(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0xe080027Bd47353b5D1639772b4a75E9Ed3658A0d, bytes4(0xb72df5de), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0xe080027Bd47353b5D1639772b4a75E9Ed3658A0d, bytes4(0xd40ddb8c), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0xe080027Bd47353b5D1639772b4a75E9Ed3658A0d, bytes4(0x1a4d01d2), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0xe080027Bd47353b5D1639772b4a75E9Ed3658A0d, bytes4(0x7706db75), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0xE3eA98BD863bEF37D951973743aAC2e56edd99BC)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xE3eA98BD863bEF37D951973743aAC2e56edd99BC, bytes4(0x095ea7b3), _cond_86(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0xBA7eBDEF7723e55c909Ac44226FB87a93625c44e))
        );
    }

    function _packScopes4_C() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0xBA7eBDEF7723e55c909Ac44226FB87a93625c44e, bytes4(0xa694fc3a), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0xBA7eBDEF7723e55c909Ac44226FB87a93625c44e, bytes4(0x38d07436), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0xBA7eBDEF7723e55c909Ac44226FB87a93625c44e, bytes4(0xc32e7202), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xBA7eBDEF7723e55c909Ac44226FB87a93625c44e, bytes4(0x7050ccd9), _cond_91(), EXEC_NONE))
        );
    }


    // --- Scope Block 5: CowSwap, TWAP, SPK (TX 92-112) ---
    function _packScopes5() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packScopes5_A(),
            _packScopes5_B(),
            _packScopes5_C()
        );
    }

    function _packScopes5_A() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0x58D97B57BB95320F9a05dC918Aef65434969c2B2)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0x58D97B57BB95320F9a05dC918Aef65434969c2B2, bytes4(0x095ea7b3), _cond_93(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0xc20059e0317DE91738d13af027DfC4a50781b066)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xc20059e0317DE91738d13af027DfC4a50781b066, bytes4(0x095ea7b3), _cond_95(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xc20059e0317DE91738d13af027DfC4a50781b066, bytes4(0xa9059cbb), _cond_96(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0x4F2083f5fBede34C2714aFfb3105539775f7FE64)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0x4F2083f5fBede34C2714aFfb3105539775f7FE64, bytes4(0xf08a0323), _cond_98(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0x4F2083f5fBede34C2714aFfb3105539775f7FE64, bytes4(0x3365582c), _cond_99(), EXEC_NONE))
        );
    }

    function _packScopes5_B() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0xfdaFc9d1902f4e0b84f65F49f244b32b31013b74)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xfdaFc9d1902f4e0b84f65F49f244b32b31013b74, bytes4(0x0d0d9800), _cond_101(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0xA188EEC8F81263234dA3622A406892F3D630f98c)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xA188EEC8F81263234dA3622A406892F3D630f98c, bytes4(0x95991276), _cond_103(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xA188EEC8F81263234dA3622A406892F3D630f98c, bytes4(0x8d7ef9bb), _cond_104(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0xd0A61F2963622e992e6534bde4D52fd0a89F39E0)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xd0A61F2963622e992e6534bde4D52fd0a89F39E0, bytes4(0x8fba2cee), _cond_106(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xd0A61F2963622e992e6534bde4D52fd0a89F39E0, bytes4(0x57de6782), _cond_107(), EXEC_NONE))
        );
    }

    function _packScopes5_C() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xd0A61F2963622e992e6534bde4D52fd0a89F39E0, bytes4(0x850d6b31), _cond_108(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0xBc65ad17c5C0a2A4D159fa5a503f4992c7B545FE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xBc65ad17c5C0a2A4D159fa5a503f4992c7B545FE, bytes4(0x095ea7b3), _cond_110(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0xc4Ce391d82D164c166dF9c8336DDF84206b2F812)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xc4Ce391d82D164c166dF9c8336DDF84206b2F812, bytes4(0x095ea7b3), _cond_112(), EXEC_NONE))
        );
    }


    // --- Scope Block 6: Permit2, CowSwap TWAP (TX 113-128) ---
    function _packScopes6() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packScopes6_A(),
            _packScopes6_B(),
            _packScopes6_C()
        );
    }

    function _packScopes6_A() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0xCF370C3279452143f68e350b824714B49593a334)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0xCF370C3279452143f68e350b824714B49593a334, bytes4(0xc32e7202), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0xCF370C3279452143f68e350b824714B49593a334, bytes4(0x3d18b912), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xCF370C3279452143f68e350b824714B49593a334, bytes4(0x7050ccd9), _cond_116(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0x57c23c58B1D8C3292c15BEcF07c62C5c52457A42)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0x57c23c58B1D8C3292c15BEcF07c62C5c52457A42, bytes4(0x095ea7b3), _cond_118(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0x994BE003de5FD6E41d37c6948f405EB0759149e6)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0x994BE003de5FD6E41d37c6948f405EB0759149e6, bytes4(0xc32e7202), EXEC_NONE))
        );
    }

    function _packScopes6_B() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0x994BE003de5FD6E41d37c6948f405EB0759149e6, bytes4(0x3d18b912), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0x994BE003de5FD6E41d37c6948f405EB0759149e6, bytes4(0x7050ccd9), _cond_122(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0x000000000022D473030F116dDEE9F6B43aC78BA3)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0x000000000022D473030F116dDEE9F6B43aC78BA3, bytes4(0x87517c45), _cond_124(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0xb21A277466e7dB6934556a1Ce12eb3F032815c8A)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xb21A277466e7dB6934556a1Ce12eb3F032815c8A, bytes4(0xe3c3e64f), _cond_126(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xb21A277466e7dB6934556a1Ce12eb3F032815c8A, bytes4(0xc1da024c), _cond_127(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xb21A277466e7dB6934556a1Ce12eb3F032815c8A, bytes4(0xd8a7f9fe), _cond_128(), EXEC_NONE))
        );
    }

    function _packScopes6_C() internal pure returns (bytes memory) {
        return abi.encodePacked(

        );
    }


    // --- Scope Block 7: Convex/Curve Vaults (TX 129-163) ---
    function _packScopes7() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packScopes7_A(),
            _packScopes7_B(),
            _packScopes7_C(),
            _packScopes7_D(),
            _packScopes7_E()
        );
    }

    function _packScopes7_A() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0x4B891340b51889f438a03DC0e8aAAFB0Bc89e7A6)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0x4B891340b51889f438a03DC0e8aAAFB0Bc89e7A6, bytes4(0xb6b55f25), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0x4B891340b51889f438a03DC0e8aAAFB0Bc89e7A6, bytes4(0x2e1a7d4d), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0x4B891340b51889f438a03DC0e8aAAFB0Bc89e7A6, bytes4(0xe6f1daf2), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0x70A1c01902DAb7a45dcA1098Ca76A8314dd8aDbA)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0x70A1c01902DAb7a45dcA1098Ca76A8314dd8aDbA, bytes4(0xb6b55f25), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0x70A1c01902DAb7a45dcA1098Ca76A8314dd8aDbA, bytes4(0x2e1a7d4d), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0x70A1c01902DAb7a45dcA1098Ca76A8314dd8aDbA, bytes4(0xe6f1daf2), EXEC_NONE))
        );
    }

    function _packScopes7_B() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0x4AB7aB316D43345009B2140e0580B072eEc7DF16)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0x4AB7aB316D43345009B2140e0580B072eEc7DF16, bytes4(0x095ea7b3), _cond_138(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0x1f3A4C8115629C33A28bF2F97F22D31d256317F6)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0x1f3A4C8115629C33A28bF2F97F22D31d256317F6, bytes4(0xb6b55f25), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0x1f3A4C8115629C33A28bF2F97F22D31d256317F6, bytes4(0x2e1a7d4d), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0x1f3A4C8115629C33A28bF2F97F22D31d256317F6, bytes4(0xe6f1daf2), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490, bytes4(0x095ea7b3), _cond_144(), EXEC_NONE))
        );
    }

    function _packScopes7_C() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0x7671299eA7B4bbE4f3fD305A994e6443b4be680E)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0x7671299eA7B4bbE4f3fD305A994e6443b4be680E, bytes4(0xb6b55f25), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0x7671299eA7B4bbE4f3fD305A994e6443b4be680E, bytes4(0x2e1a7d4d), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0x7671299eA7B4bbE4f3fD305A994e6443b4be680E, bytes4(0xe6f1daf2), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0x63037a4e3305d25D48BAED2022b8462b2807351c)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0x63037a4e3305d25D48BAED2022b8462b2807351c, bytes4(0xb6b55f25), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0x63037a4e3305d25D48BAED2022b8462b2807351c, bytes4(0x2e1a7d4d), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0x63037a4e3305d25D48BAED2022b8462b2807351c, bytes4(0x38d07436), EXEC_NONE))
        );
    }

    function _packScopes7_D() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0x63037a4e3305d25D48BAED2022b8462b2807351c, bytes4(0xe6f1daf2), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0xcc7d5785AD5755B6164e21495E07aDb0Ff11C2A8)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0xcc7d5785AD5755B6164e21495E07aDb0Ff11C2A8, bytes4(0xb72df5de), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0xcc7d5785AD5755B6164e21495E07aDb0Ff11C2A8, bytes4(0xd40ddb8c), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0xcc7d5785AD5755B6164e21495E07aDb0Ff11C2A8, bytes4(0x7706db75), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0xcc7d5785AD5755B6164e21495E07aDb0Ff11C2A8, bytes4(0x1a4d01d2), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xcc7d5785AD5755B6164e21495E07aDb0Ff11C2A8, bytes4(0x095ea7b3), _cond_159(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0x36cC1d791704445A5b6b9c36a667e511d4702F3f))
        );
    }

    function _packScopes7_E() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0x36cC1d791704445A5b6b9c36a667e511d4702F3f, bytes4(0xb6b55f25), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0x36cC1d791704445A5b6b9c36a667e511d4702F3f, bytes4(0x2e1a7d4d), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.allowFunction.selector, MANAGER_ROLE, 0x36cC1d791704445A5b6b9c36a667e511d4702F3f, bytes4(0xe6f1daf2), EXEC_NONE))
        );
    }


    // --- Scope Block 8: Morpho Blue (TX 164-172) ---
    function _packScopes8() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packScopes8_A(),
            _packScopes8_B()
        );
    }

    function _packScopes8_A() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb, bytes4(0xa99aad89), _cond_165(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb, bytes4(0x5c2bea49), _cond_166(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0x330eefa8a787552DC5cAd3C3cA644844B1E61Ddb)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0x330eefa8a787552DC5cAd3C3cA644844B1E61Ddb, bytes4(0xfabed412), _cond_168(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae, bytes4(0x71ee95c0), _cond_170(), EXEC_NONE)),
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, 0x7ac96180C4d6b2A328D3a19ac059D0E7Fc3C6d41))
        );
    }

    function _packScopes8_B() internal pure returns (bytes memory) {
        return abi.encodePacked(
            _packTx(address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeFunction.selector, MANAGER_ROLE, 0x7ac96180C4d6b2A328D3a19ac059D0E7Fc3C6d41, bytes4(0xef98231e), _cond_172(), EXEC_NONE))
        );
    }


    // --- Annotation 2 (TX 173) ---
    function _packAnnotation2() internal pure returns (bytes memory) {
        string memory annotationJson =
            "{\"rolesMod\":\"0x703806e61847984346d2d7ddd853049627e50a40\",\"roleKey\":\"0x4d414e414745520000000000000000"
            "0000000000000000000000000000000000\",\"addAnnotations\":[{\"schema\":\"https://kit.karpatkey.com/api/v1/op"
            "enapi.json\",\"uris\":[\"https://kit.karpatkey.com/api/v1/permissions/eth/aave_v3/deposit?market=Core&ta"
            "rgets=ETHx\",\"https://kit.karpatkey.com/api/v1/permissions/eth/balancer_v2/deposit?targets=wstETH-WET"
            "H-BPT\",\"https://kit.karpatkey.com/api/v1/permissions/eth/balancer_v2/stake?targets=wstETH-WETH-BPT\","
            "\"https://kit.karpatkey.com/api/v1/permissions/eth/balancer_v2/deposit?targets=B-rETH-STABLE\",\"https:"
            "//kit.karpatkey.com/api/v1/permissions/eth/balancer_v2/stake?targets=B-rETH-STABLE\",\"https://kit.kar"
            "patkey.com/api/v1/permissions/eth/balancer_v2/deposit?targets=osETH%2FwETH-BPT\",\"https://kit.karpatk"
            "ey.com/api/v1/permissions/eth/balancer_v2/stake?targets=osETH%2FwETH-BPT\",\"https://kit.karpatkey.com"
            "/api/v1/permissions/eth/compound_v3/deposit?targets=cUSDCv3&tokens=USDC\",\"https://kit.karpatkey.com/"
            "api/v1/permissions/eth/compound_v3/deposit?targets=cUSDSv3&tokens=USDS\",\"https://kit.karpatkey.com/a"
            "pi/v1/permissions/eth/compound_v3/deposit?targets=cUSDTv3&tokens=USDT\",\"https://kit.karpatkey.com/ap"
            "i/v1/permissions/eth/convex/deposit?targets=232\",\"https://kit.karpatkey.com/api/v1/permissions/eth/c"
            "onvex/deposit?targets=268\",\"https://kit.karpatkey.com/api/v1/permissions/eth/cowswap/swap?sell=ETH%2"
            "C0xE95A203B1a91a908F9B9CE46459d101078c2c3cb%2C0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF%2C0xba10000"
            "0625a3754423978a60c9317c58a424e3D%2C0xc00e94Cb662C3520282E6f5717214004A7f26888%2C0xD533a949740bb3306"
            "d119CC777fa900bA034cd52%2C0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B%2C0x6B175474E89094C44Da98b954Ee"
            "deAC495271d0F%2C0xA35b1B31Ce002FBF2058D22F30f95D405200A15b%2C0x5A98FcBEA516Cf06857215779Fd812CA3beF1"
            "B32%2C0x58D97B57BB95320F9a05dC918Aef65434969c2B2%2C0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3%2C0xf1"
            "C9acDc66974dFB6dEcB12aA385b9cD01190E38%2C0xae78736Cd615f374D3085123A210448E74Fc6393%2C0xD33526068D11"
            "6cE69F19A9ee46F0bd304F21A51f%2C0xc20059e0317DE91738d13af027DfC4a50781b066%2C0xae7ab96520DE3A18E5e111"
            "B5EaAb095312D7fE84%2C0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD%2C0x48C3399719B582dD63eB5AADf12A40B4"
            "C3f52FA2%2C0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48%2C0xdC035D45d973E3EC169d2276DDab16f1e407384F%2"
            "C0xdAC17F958D2ee523a2206206994597C13D831ec7%2C0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2%2C0x7f39C58"
            "1F595B53c5cb19bD0b3f8dA6c935E2Ca0&buy=ETH%2C0xE95A203B1a91a908F9B9CE46459d101078c2c3cb%2C0x6B175474E"
            "89094C44Da98b954EedeAC495271d0F%2C0xA35b1B31Ce002FBF2058D22F30f95D405200A15b%2C0x856c4Efb76C1D1AE02e"
            "20CEB03A2A6a08b0b8dC3%2C0xf1C9acDc66974dFB6dEcB12aA385b9cD01190E38%2C0xae78736Cd615f374D3085123A2104"
            "48E74Fc6393%2C0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84%2C0xa3931d71877C0E7a3148CB7Eb4463524FEc27fb"
            "D%2C0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48%2C0xdC035D45d973E3EC169d2276DDab16f1e407384F%2C0xdAC1"
            "7F958D2ee523a2206206994597C13D831ec7%2C0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2%2C0x7f39C581F595B5"
            "3c5cb19bD0b3f8dA6c935E2Ca0\",\"https://kit.karpatkey.com/api/v1/permissions/eth/cowswap/swap?sell=ETH%"
            "2C0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48%2C0xdC035D45d973E3EC169d2276DDab16f1e407384F%2C0xdAC17F"
            "958D2ee523a2206206994597C13D831ec7&buy=ETH%2C0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48%2C0xdC035D45"
            "d973E3EC169d2276DDab16f1e407384F%2C0xdAC17F958D2ee523a2206206994597C13D831ec7&twap=true&receiver=0x4"
            "F2083f5fBede34C2714aFfb3105539775f7FE64\",\"https://kit.karpatkey.com/api/v1/permissions/eth/spark/dep"
            "osit?targets=USDC\",\"https://kit.karpatkey.com/api/v1/permissions/eth/spark/deposit?targets=USDS\",\"ht"
            "tps://kit.karpatkey.com/api/v1/permissions/eth/spark/deposit?targets=USDT\",\"https://kit.karpatkey.co"
            "m/api/v1/permissions/eth/spark/deposit?targets=wstETH\"]}]}";
        return _packTx(
            address(ANNOTATION_REGISTRY),
            abi.encodeWithSelector(IAnnotationRegistry.post.selector, annotationJson, "ROLES_PERMISSION_ANNOTATION")
        );
    }


    // ====================================================================
    // Condition Helpers
    // ====================================================================

    function _addrComp(address addr) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes32(uint256(uint160(addr))));
    }

    function _c(uint8 parent, uint8 paramType, uint8 operator, bytes memory compValue)
        internal
        pure
        returns (ConditionFlat memory)
    {
        return ConditionFlat({ parent: parent, paramType: paramType, operator: operator, compValue: compValue });
    }

    function _eq(uint8 parent, address addr) internal pure returns (ConditionFlat memory) {
        return _c(parent, PARAM_TYPE_STATIC, OP_EQUAL_TO, _addrComp(addr));
    }

    function _cond_31() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](9);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, 0x000000000022D473030F116dDEE9F6B43aC78BA3);
        c[3] = _eq(1, 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);
        c[4] = _eq(1, 0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1);
        c[5] = _eq(1, 0xB188b1CB84Fb0bA13cb9ee1292769F903A9feC59);
        c[6] = _eq(1, 0xBA12222222228d8Ba445958a75a0704d566BF2C8);
        c[7] = _eq(1, 0xC13e21B648A5Ee794902342038FF3aDAB66BE987);
        c[8] = _eq(1, 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110);
    }

    function _cond_32() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](13);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, 0x000000000022D473030F116dDEE9F6B43aC78BA3);
        c[3] = _eq(1, 0x13f4EA83D0bd40E75C8222255bc855a974568Dd4);
        c[4] = _eq(1, 0x56C526b0159a258887e0d79ec3a80dfb940d0cD7);
        c[5] = _eq(1, 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);
        c[6] = _eq(1, 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
        c[7] = _eq(1, 0xB188b1CB84Fb0bA13cb9ee1292769F903A9feC59);
        c[8] = _eq(1, 0xBA12222222228d8Ba445958a75a0704d566BF2C8);
        c[9] = _eq(1, 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
        c[10] = _eq(1, 0xC13e21B648A5Ee794902342038FF3aDAB66BE987);
        c[11] = _eq(1, 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110);
        c[12] = _eq(1, 0xcc7d5785AD5755B6164e21495E07aDb0Ff11C2A8);
    }

    function _cond_33() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](9);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, 0x16D5A408e807db8eF7c578279BEeEe6b228f1c1C);
        c[3] = _eq(1, 0x56C526b0159a258887e0d79ec3a80dfb940d0cD7);
        c[4] = _eq(1, 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);
        c[5] = _eq(1, 0xB188b1CB84Fb0bA13cb9ee1292769F903A9feC59);
        c[6] = _eq(1, 0xBA12222222228d8Ba445958a75a0704d566BF2C8);
        c[7] = _eq(1, 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110);
        c[8] = _eq(1, 0xe080027Bd47353b5D1639772b4a75E9Ed3658A0d);
    }

    function _cond_34() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](7);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
        c[3] = _eq(1, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        c[4] = _eq(1, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        c[5] = _eq(1, 0xdAC17F958D2ee523a2206206994597C13D831ec7);
        c[6] = _eq(1, 0xdC035D45d973E3EC169d2276DDab16f1e407384F);
    }

    function _cond_35() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](9);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _c(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[3] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[4] = _eq(1, 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
        c[5] = _eq(1, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        c[6] = _eq(1, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        c[7] = _eq(1, 0xdAC17F958D2ee523a2206206994597C13D831ec7);
        c[8] = _eq(1, 0xdC035D45d973E3EC169d2276DDab16f1e407384F);
    }

    function _cond_36() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](9);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _c(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[3] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[4] = _eq(1, 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
        c[5] = _eq(1, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        c[6] = _eq(1, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        c[7] = _eq(1, 0xdAC17F958D2ee523a2206206994597C13D831ec7);
        c[8] = _eq(1, 0xdC035D45d973E3EC169d2276DDab16f1e407384F);
    }

    function _cond_37() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](11);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, 0x000000000022D473030F116dDEE9F6B43aC78BA3);
        c[3] = _eq(1, 0x13f4EA83D0bd40E75C8222255bc855a974568Dd4);
        c[4] = _eq(1, 0x56C526b0159a258887e0d79ec3a80dfb940d0cD7);
        c[5] = _eq(1, 0x59Ab5a5b5d617E478a2479B0cAD80DA7e2831492);
        c[6] = _eq(1, 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);
        c[7] = _eq(1, 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
        c[8] = _eq(1, 0x9F0491B32DBce587c50c4C43AB303b06478193A7);
        c[9] = _eq(1, 0xBA12222222228d8Ba445958a75a0704d566BF2C8);
        c[10] = _eq(1, 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110);
    }

    function _cond_38() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](6);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[3] = _eq(1, 0x3Afdc9BCA9213A35503b077a6072F3D0d5AB0840);
        c[4] = _eq(1, 0x5D409e56D886231aDAf00c8775665AD0f9897b56);
        c[5] = _eq(1, 0xc3d688B66703497DAA19211EEdff47f25384cdc3);
    }

    function _cond_39() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](10);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, 0x000000000022D473030F116dDEE9F6B43aC78BA3);
        c[3] = _eq(1, 0x56C526b0159a258887e0d79ec3a80dfb940d0cD7);
        c[4] = _eq(1, 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);
        c[5] = _eq(1, 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
        c[6] = _eq(1, 0xB188b1CB84Fb0bA13cb9ee1292769F903A9feC59);
        c[7] = _eq(1, 0xBA12222222228d8Ba445958a75a0704d566BF2C8);
        c[8] = _eq(1, 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110);
        c[9] = _eq(1, 0xe080027Bd47353b5D1639772b4a75E9Ed3658A0d);
    }

    function _cond_40() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](7);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _c(1, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"000000000000000000000000000000000000000000000000000000000000006d");
        c[3] = _c(1, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0000000000000000000000000000000000000000000000000000000000000099");
        c[4] = _c(1, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"00000000000000000000000000000000000000000000000000000000000000b3");
        c[5] = _c(1, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"00000000000000000000000000000000000000000000000000000000000000f0");
        c[6] = _c(1, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0000000000000000000000000000000000000000000000000000000000000104");
    }

    function _cond_41() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](11);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, 0x0650CAF159C5A49f711e8169D4336ECB9b950275);
        c[3] = _eq(1, 0x5D409e56D886231aDAf00c8775665AD0f9897b56);
        c[4] = _eq(1, 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);
        c[5] = _eq(1, 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
        c[6] = _eq(1, 0xA188EEC8F81263234dA3622A406892F3D630f98c);
        c[7] = _eq(1, 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD);
        c[8] = _eq(1, 0xC13e21B648A5Ee794902342038FF3aDAB66BE987);
        c[9] = _eq(1, 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110);
        c[10] = _eq(1, 0xf86141a5657Cf52AEB3E30eBccA5Ad3a8f714B89);
    }

    function _cond_42() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](9);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, 0x56C526b0159a258887e0d79ec3a80dfb940d0cD7);
        c[3] = _eq(1, 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);
        c[4] = _eq(1, 0x6bac785889A4127dB0e0CeFEE88E0a9F1Aaf3cC7);
        c[5] = _eq(1, 0x94B17476A93b3262d87B9a326965D1E91f9c13E7);
        c[6] = _eq(1, 0xBA12222222228d8Ba445958a75a0704d566BF2C8);
        c[7] = _eq(1, 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110);
        c[8] = _eq(1, 0xcc7d5785AD5755B6164e21495E07aDb0Ff11C2A8);
    }

    function _cond_44() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](4);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);
        c[3] = _eq(1, 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110);
    }

    function _cond_45() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](3);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[2] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
    }

    function _cond_46() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](11);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _c(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[3] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[4] = _eq(1, 0x6B175474E89094C44Da98b954EedeAC495271d0F);
        c[5] = _eq(1, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        c[6] = _eq(1, 0xA35b1B31Ce002FBF2058D22F30f95D405200A15b);
        c[7] = _eq(1, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        c[8] = _eq(1, 0xdAC17F958D2ee523a2206206994597C13D831ec7);
        c[9] = _eq(1, 0xdC035D45d973E3EC169d2276DDab16f1e407384F);
        c[10] = _eq(1, 0xf1C9acDc66974dFB6dEcB12aA385b9cD01190E38);
    }

    function _cond_47() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](11);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _c(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[3] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[4] = _eq(1, 0x6B175474E89094C44Da98b954EedeAC495271d0F);
        c[5] = _eq(1, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        c[6] = _eq(1, 0xA35b1B31Ce002FBF2058D22F30f95D405200A15b);
        c[7] = _eq(1, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        c[8] = _eq(1, 0xdAC17F958D2ee523a2206206994597C13D831ec7);
        c[9] = _eq(1, 0xdC035D45d973E3EC169d2276DDab16f1e407384F);
        c[10] = _eq(1, 0xf1C9acDc66974dFB6dEcB12aA385b9cD01190E38);
    }

    function _cond_48() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](9);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, 0x6B175474E89094C44Da98b954EedeAC495271d0F);
        c[3] = _eq(1, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        c[4] = _eq(1, 0xA35b1B31Ce002FBF2058D22F30f95D405200A15b);
        c[5] = _eq(1, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        c[6] = _eq(1, 0xdAC17F958D2ee523a2206206994597C13D831ec7);
        c[7] = _eq(1, 0xdC035D45d973E3EC169d2276DDab16f1e407384F);
        c[8] = _eq(1, 0xf1C9acDc66974dFB6dEcB12aA385b9cD01190E38);
    }

    function _cond_49() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _eq(0, 0xd01607c3C5eCABa394D8be377a08590149325722);
    }

    function _cond_50() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](13);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, 0x56C526b0159a258887e0d79ec3a80dfb940d0cD7);
        c[3] = _eq(1, 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);
        c[4] = _eq(1, 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
        c[5] = _eq(1, 0xA188EEC8F81263234dA3622A406892F3D630f98c);
        c[6] = _eq(1, 0xBA12222222228d8Ba445958a75a0704d566BF2C8);
        c[7] = _eq(1, 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
        c[8] = _eq(1, 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
        c[9] = _eq(1, 0xC13e21B648A5Ee794902342038FF3aDAB66BE987);
        c[10] = _eq(1, 0xc3d688B66703497DAA19211EEdff47f25384cdc3);
        c[11] = _eq(1, 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110);
        c[12] = _eq(1, 0xd0A61F2963622e992e6534bde4D52fd0a89F39E0);
    }

    function _cond_51() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](10);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, 0x3Afdc9BCA9213A35503b077a6072F3D0d5AB0840);
        c[3] = _eq(1, 0x56C526b0159a258887e0d79ec3a80dfb940d0cD7);
        c[4] = _eq(1, 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);
        c[5] = _eq(1, 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
        c[6] = _eq(1, 0xBA12222222228d8Ba445958a75a0704d566BF2C8);
        c[7] = _eq(1, 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
        c[8] = _eq(1, 0xC13e21B648A5Ee794902342038FF3aDAB66BE987);
        c[9] = _eq(1, 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110);
    }

    function _cond_52() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](8);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, 0x1f3A4C8115629C33A28bF2F97F22D31d256317F6);
        c[3] = _eq(1, 0x4B891340b51889f438a03DC0e8aAAFB0Bc89e7A6);
        c[4] = _eq(1, 0x5C0F23A5c1be65Fa710d385814a7Fd1Bda480b1C);
        c[5] = _eq(1, 0x70A1c01902DAb7a45dcA1098Ca76A8314dd8aDbA);
        c[6] = _eq(1, 0x79eF6103A513951a3b25743DB509E267685726B7);
        c[7] = _eq(1, 0xc592c33e51A764B94DB0702D8BAf4035eD577aED);
    }

    function _cond_53() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](7);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _c(1, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0000000000000000000000000000000000000000000000000000000000000019");
        c[3] = _c(1, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"00000000000000000000000000000000000000000000000000000000000000ae");
        c[4] = _c(1, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"00000000000000000000000000000000000000000000000000000000000000b1");
        c[5] = _c(1, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"00000000000000000000000000000000000000000000000000000000000000e8");
        c[6] = _c(1, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"000000000000000000000000000000000000000000000000000000000000010c");
    }

    function _cond_54() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](7);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _c(1, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0000000000000000000000000000000000000000000000000000000000000019");
        c[3] = _c(1, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"00000000000000000000000000000000000000000000000000000000000000ae");
        c[4] = _c(1, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"00000000000000000000000000000000000000000000000000000000000000b1");
        c[5] = _c(1, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"00000000000000000000000000000000000000000000000000000000000000e8");
        c[6] = _c(1, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"000000000000000000000000000000000000000000000000000000000000010c");
    }

    function _cond_55() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](7);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _c(1, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0000000000000000000000000000000000000000000000000000000000000019");
        c[3] = _c(1, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"00000000000000000000000000000000000000000000000000000000000000ae");
        c[4] = _c(1, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"00000000000000000000000000000000000000000000000000000000000000b1");
        c[5] = _c(1, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"00000000000000000000000000000000000000000000000000000000000000e8");
        c[6] = _c(1, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"000000000000000000000000000000000000000000000000000000000000010c");
    }

    function _cond_56() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](51);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[2] = _c(1, PARAM_TYPE_NONE, OP_OR, "");
        c[3] = _c(1, PARAM_TYPE_NONE, OP_OR, "");
        c[4] = _c(1, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[5] = _c(1, PARAM_TYPE_STATIC, OP_PASS, "");
        c[6] = _c(1, PARAM_TYPE_STATIC, OP_PASS, "");
        c[7] = _c(1, PARAM_TYPE_STATIC, OP_PASS, "");
        c[8] = _c(1, PARAM_TYPE_STATIC, OP_PASS, "");
        c[9] = _c(1, PARAM_TYPE_STATIC, OP_PASS, "");
        c[10] = _c(1, PARAM_TYPE_STATIC, OP_PASS, "");
        c[11] = _c(1, PARAM_TYPE_STATIC, OP_PASS, "");
        c[12] = _c(1, PARAM_TYPE_STATIC, OP_PASS, "");
        c[13] = _c(1, PARAM_TYPE_STATIC, OP_PASS, "");
        c[14] = _eq(2, 0x48C3399719B582dD63eB5AADf12A40B4C3f52FA2);
        c[15] = _eq(2, 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
        c[16] = _eq(2, 0x58D97B57BB95320F9a05dC918Aef65434969c2B2);
        c[17] = _eq(2, 0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32);
        c[18] = _eq(2, 0x6B175474E89094C44Da98b954EedeAC495271d0F);
        c[19] = _eq(2, 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
        c[20] = _eq(2, 0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3);
        c[21] = _eq(2, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        c[22] = _eq(2, 0xA35b1B31Ce002FBF2058D22F30f95D405200A15b);
        c[23] = _eq(2, 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD);
        c[24] = _eq(2, 0xae78736Cd615f374D3085123A210448E74Fc6393);
        c[25] = _eq(2, 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
        c[26] = _eq(2, 0xba100000625a3754423978a60c9317c58a424e3D);
        c[27] = _eq(2, 0xc00e94Cb662C3520282E6f5717214004A7f26888);
        c[28] = _eq(2, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        c[29] = _eq(2, 0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF);
        c[30] = _eq(2, 0xc20059e0317DE91738d13af027DfC4a50781b066);
        c[31] = _eq(2, 0xD33526068D116cE69F19A9ee46F0bd304F21A51f);
        c[32] = _eq(2, 0xD533a949740bb3306d119CC777fa900bA034cd52);
        c[33] = _eq(2, 0xdAC17F958D2ee523a2206206994597C13D831ec7);
        c[34] = _eq(2, 0xdC035D45d973E3EC169d2276DDab16f1e407384F);
        c[35] = _eq(2, 0xE95A203B1a91a908F9B9CE46459d101078c2c3cb);
        c[36] = _eq(2, 0xf1C9acDc66974dFB6dEcB12aA385b9cD01190E38);
        c[37] = _eq(3, 0x6B175474E89094C44Da98b954EedeAC495271d0F);
        c[38] = _eq(3, 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
        c[39] = _eq(3, 0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3);
        c[40] = _eq(3, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        c[41] = _eq(3, 0xA35b1B31Ce002FBF2058D22F30f95D405200A15b);
        c[42] = _eq(3, 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD);
        c[43] = _eq(3, 0xae78736Cd615f374D3085123A210448E74Fc6393);
        c[44] = _eq(3, 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
        c[45] = _eq(3, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        c[46] = _eq(3, 0xdAC17F958D2ee523a2206206994597C13D831ec7);
        c[47] = _eq(3, 0xdC035D45d973E3EC169d2276DDab16f1e407384F);
        c[48] = _eq(3, 0xE95A203B1a91a908F9B9CE46459d101078c2c3cb);
        c[49] = _eq(3, 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
        c[50] = _eq(3, 0xf1C9acDc66974dFB6dEcB12aA385b9cD01190E38);
    }

    function _cond_57() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](9);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, 0x182B723a58739a9c974cFDB385ceaDb237453c28);
        c[3] = _eq(1, 0x36cC1d791704445A5b6b9c36a667e511d4702F3f);
        c[4] = _eq(1, 0x63037a4e3305d25D48BAED2022b8462b2807351c);
        c[5] = _eq(1, 0x7671299eA7B4bbE4f3fD305A994e6443b4be680E);
        c[6] = _eq(1, 0x79F21BC30632cd40d2aF8134B469a0EB4C9574AA);
        c[7] = _eq(1, 0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A);
        c[8] = _eq(1, 0xd03BE91b1932715709e18021734fcB91BB431715);
    }

    function _cond_58() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](47);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[3] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[4] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[5] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[6] = _c(0, PARAM_TYPE_ARRAY, OP_PASS, "");
        c[7] = _c(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[8] = _c(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[9] = _c(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[10] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0000000000000000000000000000000000000000000000000000000000000000");
        c[11] = _eq(1, 0x21E27a5E5513D6e65C4f830167390997aA84843a);
        c[12] = _eq(1, 0x59Ab5a5b5d617E478a2479B0cAD80DA7e2831492);
        c[13] = _eq(1, 0x94B17476A93b3262d87B9a326965D1E91f9c13E7);
        c[14] = _eq(1, 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
        c[15] = _eq(1, 0xcc7d5785AD5755B6164e21495E07aDb0Ff11C2A8);
        c[16] = _eq(1, 0xDC24316b9AE028F1497c275EB9192a3Ea0f67022);
        c[17] = _eq(1, 0xe080027Bd47353b5D1639772b4a75E9Ed3658A0d);
        c[18] = _eq(2, 0x06325440D014e39736583c165C2963BA99fAf14E);
        c[19] = _eq(2, 0x21E27a5E5513D6e65C4f830167390997aA84843a);
        c[20] = _eq(2, 0x59Ab5a5b5d617E478a2479B0cAD80DA7e2831492);
        c[21] = _eq(2, 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
        c[22] = _eq(2, 0x94B17476A93b3262d87B9a326965D1E91f9c13E7);
        c[23] = _eq(2, 0xcc7d5785AD5755B6164e21495E07aDb0Ff11C2A8);
        c[24] = _eq(2, 0xe080027Bd47353b5D1639772b4a75E9Ed3658A0d);
        c[25] = _eq(3, 0x182B723a58739a9c974cFDB385ceaDb237453c28);
        c[26] = _eq(3, 0x36cC1d791704445A5b6b9c36a667e511d4702F3f);
        c[27] = _eq(3, 0x63037a4e3305d25D48BAED2022b8462b2807351c);
        c[28] = _eq(3, 0x7671299eA7B4bbE4f3fD305A994e6443b4be680E);
        c[29] = _eq(3, 0x79F21BC30632cd40d2aF8134B469a0EB4C9574AA);
        c[30] = _eq(3, 0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A);
        c[31] = _eq(3, 0xd03BE91b1932715709e18021734fcB91BB431715);
        c[32] = _c(4, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0000000000000000000000000000000000000000000000000000000000000002");
        c[33] = _c(4, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0000000000000000000000000000000000000000000000000000000000000003");
        c[34] = _c(5, PARAM_TYPE_ARRAY, OP_EQUAL_TO, hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000002000000000000000000000000856c4efb76c1d1ae02e20ceb03a2a6a08b0b8dc3000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2");
        c[35] = _c(5, PARAM_TYPE_ARRAY, OP_EQUAL_TO, hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000002000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee000000000000000000000000856c4efb76c1d1ae02e20ceb03a2a6a08b0b8dc3");
        c[36] = _c(5, PARAM_TYPE_ARRAY, OP_EQUAL_TO, hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000002000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee000000000000000000000000a35b1b31ce002fbf2058d22f30f95d405200a15b");
        c[37] = _c(5, PARAM_TYPE_ARRAY, OP_EQUAL_TO, hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000002000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee000000000000000000000000ae7ab96520de3a18e5e111b5eaab095312d7fe84");
        c[38] = _c(5, PARAM_TYPE_ARRAY, OP_EQUAL_TO, hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000002000000000000000000000000f1c9acdc66974dfb6decb12aa385b9cd01190e38000000000000000000000000ae78736cd615f374d3085123a210448e74fc6393");
        c[39] = _c(5, PARAM_TYPE_ARRAY, OP_EQUAL_TO, hex"000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000030000000000000000000000006b175474e89094c44da98b954eedeac495271d0f000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec7");
        c[40] = _c(6, PARAM_TYPE_STATIC, OP_PASS, "");
        c[41] = _c(34, PARAM_TYPE_STATIC, OP_PASS, "");
        c[42] = _c(35, PARAM_TYPE_STATIC, OP_PASS, "");
        c[43] = _c(36, PARAM_TYPE_STATIC, OP_PASS, "");
        c[44] = _c(37, PARAM_TYPE_STATIC, OP_PASS, "");
        c[45] = _c(38, PARAM_TYPE_STATIC, OP_PASS, "");
        c[46] = _c(39, PARAM_TYPE_STATIC, OP_PASS, "");
    }

    function _cond_59() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](87);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[3] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[4] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[5] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[6] = _c(2, PARAM_TYPE_NONE, OP_OR, "");
        c[7] = _c(2, PARAM_TYPE_NONE, OP_OR, "");
        c[8] = _c(2, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0000000000000000000000000000000000000000000000000000000000000064");
        c[9] = _c(2, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[10] = _c(2, PARAM_TYPE_STATIC, OP_PASS, "");
        c[11] = _c(2, PARAM_TYPE_STATIC, OP_PASS, "");
        c[12] = _c(2, PARAM_TYPE_STATIC, OP_PASS, "");
        c[13] = _c(3, PARAM_TYPE_NONE, OP_OR, "");
        c[14] = _c(3, PARAM_TYPE_NONE, OP_OR, "");
        c[15] = _c(3, PARAM_TYPE_NONE, OP_OR, "");
        c[16] = _c(3, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[17] = _c(3, PARAM_TYPE_STATIC, OP_PASS, "");
        c[18] = _c(3, PARAM_TYPE_STATIC, OP_PASS, "");
        c[19] = _c(3, PARAM_TYPE_STATIC, OP_PASS, "");
        c[20] = _c(4, PARAM_TYPE_NONE, OP_OR, "");
        c[21] = _c(4, PARAM_TYPE_NONE, OP_OR, "");
        c[22] = _c(4, PARAM_TYPE_NONE, OP_OR, "");
        c[23] = _c(4, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[24] = _c(4, PARAM_TYPE_STATIC, OP_PASS, "");
        c[25] = _c(4, PARAM_TYPE_STATIC, OP_PASS, "");
        c[26] = _c(4, PARAM_TYPE_STATIC, OP_PASS, "");
        c[27] = _c(5, PARAM_TYPE_NONE, OP_OR, "");
        c[28] = _c(5, PARAM_TYPE_NONE, OP_OR, "");
        c[29] = _c(5, PARAM_TYPE_STATIC, OP_PASS, "");
        c[30] = _c(5, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[31] = _c(5, PARAM_TYPE_STATIC, OP_PASS, "");
        c[32] = _c(5, PARAM_TYPE_STATIC, OP_PASS, "");
        c[33] = _c(5, PARAM_TYPE_STATIC, OP_PASS, "");
        c[34] = _eq(6, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        c[35] = _eq(6, 0xdAC17F958D2ee523a2206206994597C13D831ec7);
        c[36] = _eq(7, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        c[37] = _eq(7, 0xdAC17F958D2ee523a2206206994597C13D831ec7);
        c[38] = _eq(13, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        c[39] = _eq(13, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        c[40] = _eq(14, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        c[41] = _eq(14, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        c[42] = _c(15, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"00000000000000000000000000000000000000000000000000000000000001f4");
        c[43] = _c(15, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0000000000000000000000000000000000000000000000000000000000000bb8");
        c[44] = _eq(20, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        c[45] = _eq(20, 0xdAC17F958D2ee523a2206206994597C13D831ec7);
        c[46] = _eq(21, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        c[47] = _eq(21, 0xdAC17F958D2ee523a2206206994597C13D831ec7);
        c[48] = _c(22, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0000000000000000000000000000000000000000000000000000000000000064");
        c[49] = _c(22, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"00000000000000000000000000000000000000000000000000000000000001f4");
        c[50] = _c(22, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0000000000000000000000000000000000000000000000000000000000000bb8");
        c[51] = _eq(27, 0x48C3399719B582dD63eB5AADf12A40B4C3f52FA2);
        c[52] = _eq(27, 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
        c[53] = _eq(27, 0x58D97B57BB95320F9a05dC918Aef65434969c2B2);
        c[54] = _eq(27, 0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32);
        c[55] = _eq(27, 0x6B175474E89094C44Da98b954EedeAC495271d0F);
        c[56] = _eq(27, 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
        c[57] = _eq(27, 0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3);
        c[58] = _eq(27, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        c[59] = _eq(27, 0xA35b1B31Ce002FBF2058D22F30f95D405200A15b);
        c[60] = _eq(27, 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD);
        c[61] = _eq(27, 0xae78736Cd615f374D3085123A210448E74Fc6393);
        c[62] = _eq(27, 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
        c[63] = _eq(27, 0xba100000625a3754423978a60c9317c58a424e3D);
        c[64] = _eq(27, 0xc00e94Cb662C3520282E6f5717214004A7f26888);
        c[65] = _eq(27, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        c[66] = _eq(27, 0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF);
        c[67] = _eq(27, 0xc20059e0317DE91738d13af027DfC4a50781b066);
        c[68] = _eq(27, 0xD33526068D116cE69F19A9ee46F0bd304F21A51f);
        c[69] = _eq(27, 0xD533a949740bb3306d119CC777fa900bA034cd52);
        c[70] = _eq(27, 0xdAC17F958D2ee523a2206206994597C13D831ec7);
        c[71] = _eq(27, 0xdC035D45d973E3EC169d2276DDab16f1e407384F);
        c[72] = _eq(27, 0xE95A203B1a91a908F9B9CE46459d101078c2c3cb);
        c[73] = _eq(27, 0xf1C9acDc66974dFB6dEcB12aA385b9cD01190E38);
        c[74] = _eq(28, 0x6B175474E89094C44Da98b954EedeAC495271d0F);
        c[75] = _eq(28, 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
        c[76] = _eq(28, 0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3);
        c[77] = _eq(28, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        c[78] = _eq(28, 0xA35b1B31Ce002FBF2058D22F30f95D405200A15b);
        c[79] = _eq(28, 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD);
        c[80] = _eq(28, 0xae78736Cd615f374D3085123A210448E74Fc6393);
        c[81] = _eq(28, 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
        c[82] = _eq(28, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        c[83] = _eq(28, 0xdAC17F958D2ee523a2206206994597C13D831ec7);
        c[84] = _eq(28, 0xdC035D45d973E3EC169d2276DDab16f1e407384F);
        c[85] = _eq(28, 0xE95A203B1a91a908F9B9CE46459d101078c2c3cb);
        c[86] = _eq(28, 0xf1C9acDc66974dFB6dEcB12aA385b9cD01190E38);
    }

    function _cond_61() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](3);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _eq(0, 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
        c[2] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
    }

    function _cond_62() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](4);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _eq(0, 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
        c[2] = _c(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[3] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
    }

    function _cond_64() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _eq(0, 0xdC035D45d973E3EC169d2276DDab16f1e407384F);
    }

    function _cond_65() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _eq(0, 0xdC035D45d973E3EC169d2276DDab16f1e407384F);
    }

    function _cond_67() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](4);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, 0x7671299eA7B4bbE4f3fD305A994e6443b4be680E);
        c[3] = _eq(1, 0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
    }

    function _cond_73() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _eq(0, 0x399e111c7209a741B06F8F86Ef0Fdd88fC198D20);
    }

    function _cond_78() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
    }

    function _cond_80() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](4);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, 0x63037a4e3305d25D48BAED2022b8462b2807351c);
        c[3] = _eq(1, 0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
    }

    function _cond_86() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _eq(0, 0xBA7eBDEF7723e55c909Ac44226FB87a93625c44e);
    }

    function _cond_91() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
    }

    function _cond_93() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](4);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);
        c[3] = _eq(1, 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110);
    }

    function _cond_95() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](4);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);
        c[3] = _eq(1, 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110);
    }

    function _cond_96() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _eq(0, 0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7);
    }

    function _cond_98() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _eq(0, 0x2f55e8b20D0B9FEFA187AA7d00B6Cbe563605bF5);
    }

    function _cond_99() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](3);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"c078f884a2676e1345748b1feace7b0abee5d00ecadb6e574dcdd109a63e8943");
        c[2] = _eq(0, 0xfdaFc9d1902f4e0b84f65F49f244b32b31013b74);
    }

    function _cond_101() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](20);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[2] = _eq(0, 0x52eD56Da04309Aca4c3FECC595298d80C2f16BAc);
        c[3] = _c(0, PARAM_TYPE_DYNAMIC, OP_EQUAL_TO, hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000");
        c[4] = _eq(1, 0x6cF1e9cA41f7611dEf408122793c358a3d11E5a5);
        c[5] = _c(1, PARAM_TYPE_STATIC, OP_PASS, "");
        c[6] = _c(1, PARAM_TYPE_ABI_ENCODED, OP_MATCHES, "");
        c[7] = _c(6, PARAM_TYPE_NONE, OP_OR, "");
        c[8] = _c(6, PARAM_TYPE_NONE, OP_OR, "");
        c[9] = _c(6, PARAM_TYPE_NONE, OP_OR, "");
        c[10] = _eq(7, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        c[11] = _eq(7, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        c[12] = _eq(7, 0xdAC17F958D2ee523a2206206994597C13D831ec7);
        c[13] = _eq(7, 0xdC035D45d973E3EC169d2276DDab16f1e407384F);
        c[14] = _eq(8, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        c[15] = _eq(8, 0xdAC17F958D2ee523a2206206994597C13D831ec7);
        c[16] = _eq(8, 0xdC035D45d973E3EC169d2276DDab16f1e407384F);
        c[17] = _eq(8, 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
        c[18] = _c(9, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[19] = _c(9, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0000000000000000000000000000000000000000000000000000000000000000");
    }

    function _cond_103() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
    }

    function _cond_104() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
    }

    function _cond_106() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
    }

    function _cond_107() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
    }

    function _cond_108() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
    }

    function _cond_110() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _eq(0, 0xd0A61F2963622e992e6534bde4D52fd0a89F39E0);
    }

    function _cond_112() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](5);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, 0x4B891340b51889f438a03DC0e8aAAFB0Bc89e7A6);
        c[3] = _eq(1, 0xA57b8d98dAE62B26Ec3bcC4a365338157060B234);
        c[4] = _eq(1, 0xb21A277466e7dB6934556a1Ce12eb3F032815c8A);
    }

    function _cond_116() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
    }

    function _cond_118() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](5);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, 0x70A1c01902DAb7a45dcA1098Ca76A8314dd8aDbA);
        c[3] = _eq(1, 0xA57b8d98dAE62B26Ec3bcC4a365338157060B234);
        c[4] = _eq(1, 0xb21A277466e7dB6934556a1Ce12eb3F032815c8A);
    }

    function _cond_122() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
    }

    function _cond_124() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](7);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(0, 0xb21A277466e7dB6934556a1Ce12eb3F032815c8A);
        c[3] = _eq(1, 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
        c[4] = _eq(1, 0xA35b1B31Ce002FBF2058D22F30f95D405200A15b);
        c[5] = _eq(1, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        c[6] = _eq(1, 0xf1C9acDc66974dFB6dEcB12aA385b9cD01190E38);
    }

    function _cond_126() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](5);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, 0x4AB7aB316D43345009B2140e0580B072eEc7DF16);
        c[3] = _eq(1, 0x57c23c58B1D8C3292c15BEcF07c62C5c52457A42);
        c[4] = _eq(1, 0xc4Ce391d82D164c166dF9c8336DDF84206b2F812);
    }

    function _cond_127() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](5);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, 0x4AB7aB316D43345009B2140e0580B072eEc7DF16);
        c[3] = _eq(1, 0x57c23c58B1D8C3292c15BEcF07c62C5c52457A42);
        c[4] = _eq(1, 0xc4Ce391d82D164c166dF9c8336DDF84206b2F812);
    }

    function _cond_128() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](5);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, 0x4AB7aB316D43345009B2140e0580B072eEc7DF16);
        c[3] = _eq(1, 0x57c23c58B1D8C3292c15BEcF07c62C5c52457A42);
        c[4] = _eq(1, 0xc4Ce391d82D164c166dF9c8336DDF84206b2F812);
    }

    function _cond_138() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](4);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, 0x1f3A4C8115629C33A28bF2F97F22D31d256317F6);
        c[3] = _eq(1, 0xb21A277466e7dB6934556a1Ce12eb3F032815c8A);
    }

    function _cond_144() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _eq(0, 0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A);
    }

    function _cond_159() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _eq(0, 0x36cC1d791704445A5b6b9c36a667e511d4702F3f);
    }

    function _cond_165() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](32);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _c(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[3] = _c(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[4] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[5] = _c(0, PARAM_TYPE_DYNAMIC, OP_EQUAL_TO, hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000");
        c[6] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[7] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[8] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[9] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[10] = _eq(6, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        c[11] = _eq(6, 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
        c[12] = _eq(6, 0xDddd770BADd886dF3864029e4B377B5F6a2B6b83);
        c[13] = _eq(6, 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC);
        c[14] = _c(6, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0000000000000000000000000000000000000000000000000bef55718ad60000");
        c[15] = _eq(7, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        c[16] = _eq(7, 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
        c[17] = _eq(7, 0x48F7E36EB6B826B2dF4B2E630B62Cd25e89E40e2);
        c[18] = _eq(7, 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC);
        c[19] = _c(7, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0000000000000000000000000000000000000000000000000bef55718ad60000");
        c[20] = _eq(8, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        c[21] = _eq(8, 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf);
        c[22] = _eq(8, 0xA6D6950c9F177F1De7f7757FB33539e3Ec60182a);
        c[23] = _eq(8, 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC);
        c[24] = _c(8, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0000000000000000000000000000000000000000000000000bef55718ad60000");
        c[25] = _eq(9, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        c[26] = _eq(9, 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
        c[27] = _eq(9, 0xbD60A6770b27E084E8617335ddE769241B0e71D8);
        c[28] = _eq(9, 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC);
        c[29] = _c(9, PARAM_TYPE_NONE, OP_OR, "");
        c[30] = _c(29, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0000000000000000000000000000000000000000000000000d1d507e40be8000");
        c[31] = _c(29, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0000000000000000000000000000000000000000000000000d645e6320408000");
    }

    function _cond_166() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](32);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _c(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[3] = _c(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[4] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[5] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[6] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[7] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[8] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[9] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[10] = _eq(6, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        c[11] = _eq(6, 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
        c[12] = _eq(6, 0xDddd770BADd886dF3864029e4B377B5F6a2B6b83);
        c[13] = _eq(6, 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC);
        c[14] = _c(6, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0000000000000000000000000000000000000000000000000bef55718ad60000");
        c[15] = _eq(7, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        c[16] = _eq(7, 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
        c[17] = _eq(7, 0x48F7E36EB6B826B2dF4B2E630B62Cd25e89E40e2);
        c[18] = _eq(7, 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC);
        c[19] = _c(7, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0000000000000000000000000000000000000000000000000bef55718ad60000");
        c[20] = _eq(8, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        c[21] = _eq(8, 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf);
        c[22] = _eq(8, 0xA6D6950c9F177F1De7f7757FB33539e3Ec60182a);
        c[23] = _eq(8, 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC);
        c[24] = _c(8, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0000000000000000000000000000000000000000000000000bef55718ad60000");
        c[25] = _eq(9, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        c[26] = _eq(9, 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
        c[27] = _eq(9, 0xbD60A6770b27E084E8617335ddE769241B0e71D8);
        c[28] = _eq(9, 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC);
        c[29] = _c(9, PARAM_TYPE_NONE, OP_OR, "");
        c[30] = _c(29, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0000000000000000000000000000000000000000000000000d1d507e40be8000");
        c[31] = _c(29, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0000000000000000000000000000000000000000000000000d645e6320408000");
    }

    function _cond_168() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
    }

    function _cond_170() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](12);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _c(1, PARAM_TYPE_ARRAY, OP_EQUAL_TO, hex"000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000010000000000000000000000004f2083f5fbede34c2714affb3105539775f7fe64");
        c[3] = _c(1, PARAM_TYPE_ARRAY, OP_EQUAL_TO, hex"000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000020000000000000000000000004f2083f5fbede34c2714affb3105539775f7fe640000000000000000000000004f2083f5fbede34c2714affb3105539775f7fe64");
        c[4] = _c(1, PARAM_TYPE_ARRAY, OP_EQUAL_TO, hex"000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000030000000000000000000000004f2083f5fbede34c2714affb3105539775f7fe640000000000000000000000004f2083f5fbede34c2714affb3105539775f7fe640000000000000000000000004f2083f5fbede34c2714affb3105539775f7fe64");
        c[5] = _c(1, PARAM_TYPE_ARRAY, OP_EQUAL_TO, hex"000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000040000000000000000000000004f2083f5fbede34c2714affb3105539775f7fe640000000000000000000000004f2083f5fbede34c2714affb3105539775f7fe640000000000000000000000004f2083f5fbede34c2714affb3105539775f7fe640000000000000000000000004f2083f5fbede34c2714affb3105539775f7fe64");
        c[6] = _c(1, PARAM_TYPE_ARRAY, OP_EQUAL_TO, hex"000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000050000000000000000000000004f2083f5fbede34c2714affb3105539775f7fe640000000000000000000000004f2083f5fbede34c2714affb3105539775f7fe640000000000000000000000004f2083f5fbede34c2714affb3105539775f7fe640000000000000000000000004f2083f5fbede34c2714affb3105539775f7fe640000000000000000000000004f2083f5fbede34c2714affb3105539775f7fe64");
        c[7] = _c(2, PARAM_TYPE_STATIC, OP_PASS, "");
        c[8] = _c(3, PARAM_TYPE_STATIC, OP_PASS, "");
        c[9] = _c(4, PARAM_TYPE_STATIC, OP_PASS, "");
        c[10] = _c(5, PARAM_TYPE_STATIC, OP_PASS, "");
        c[11] = _c(6, PARAM_TYPE_STATIC, OP_PASS, "");
    }

    function _cond_172() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](3);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[2] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
    }


    // ====================================================================

    function _isProposalSubmitted() public view override returns (bool) {
        return true;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-6-23";
    }



}
