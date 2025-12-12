// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ISafe } from "@ens/interfaces/ISafe.sol";
import { IZodiacRoles } from "@ens/interfaces/IZodiacRoles.sol";
import { IUniversalRewardsDistributor } from "@ens/interfaces/IUniversalRewardsDistributor.sol";
import { IFluidVaultV2 } from "@ens/interfaces/IFluidVaultV2.sol";
import { IFluidMerkleDistributor } from "@ens/interfaces/IFluidMerkleDistributor.sol";
import { IMetaMorphoV1 } from "@ens/interfaces/IMetaMorphoV1.sol";
import { ENS_Governance } from "@ens/ens.t.sol";
import { console2 } from "@forge-std/src/console2.sol";
import { IERC20 } from "@forge-std/src/interfaces/IERC20.sol";

contract Proposal_ENS_EP_KPK_DRAFT_Test is ENS_Governance {
    address private safe = 0x4F2083f5fBede34C2714aFfb3105539775f7FE64;
    address private karpatkey = 0xb423e0f6E7430fa29500c5cC9bd83D28c8BD8978;

    IZodiacRoles roles = IZodiacRoles(0x703806E61847984346d2D7DDd853049627e50A40);
    bytes32 private constant MANAGER_ROLE = 0x4d414e4147455200000000000000000000000000000000000000000000000000;

    address private UniversalRewardsDistributor = 0x330eefa8a787552DC5cAd3C3cA644844B1E61Ddb;
    address private USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address private fToken = 0x5C20B550819128074FD538Edf79791733ccEdd18;
    address private VaultV2 = 0x4Ef53d2cAa51C447fdFEEedee8F07FD1962C9ee6;
    address private GHO = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;
    address private fToken2 = 0x6A29A46E21C730DcA1d8b23d637c101cec605C5B;
    address private fToken3 = 0x9Fb7b4477576Fe5B32be4C1843aFB1e55F251B33;
    address private USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private VaultV2_3 = 0xBb50A5341368751024ddf33385BA8cf61fE65FF9;
    address private WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private MetaMorphoV1_1 = 0xd564F765F9aD3E7d2d6cA782100795a885e8e7C8;
    address private MetaMorphoV1_2 = 0xe108fbc04852B5df72f9E44d7C29F47e7A993aDd;
    address private FluidMerkleDistributor = 0x7060FE0Dd3E31be01EFAc6B28C8D38018fD163B0;

    function _beforeProposal() public override {
        vm.startPrank(karpatkey);
        vm.pauseGasMetering();

        // REVOKE FUNCTION
        {
            _safeExecuteTransaction(
                UniversalRewardsDistributor,
                abi.encodeWithSelector(
                    IUniversalRewardsDistributor.claim.selector,
                    safe,
                    ensToken,
                    new bytes32[](1),
                    1 ether
                )
            );
        }

        // REVOKE TARGET
        {
            _safeExecuteTransaction(
                UniversalRewardsDistributor,
                abi.encodeWithSelector(
                    IUniversalRewardsDistributor.claim.selector,
                    safe,
                    ensToken,
                    new bytes32[](1),
                    1 ether
                )
            );
        }

        // SCOPE FUNCTION
        {
            {
                {
                    vm.expectRevert();
                    _safeExecuteTransaction(
                        USDT,
                        abi.encodeWithSelector(
                            IERC20.approve.selector,
                            fToken,
                            1 ether
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
                        VaultV2,
                        abi.encodeWithSelector(
                            IFluidVaultV2.deposit.selector,
                            1 ether,
                            safe
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
                        VaultV2,
                        abi.encodeWithSelector(
                            IFluidVaultV2.redeem.selector,
                            1 ether,
                            safe,
                            safe
                        )
                    );
                }
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
                    VaultV2,
                    abi.encodeWithSelector(
                        IFluidVaultV2.redeem.selector,
                        1 ether,
                        safe,
                        safe
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
                    GHO,
                    abi.encodeWithSelector(
                        IERC20.approve.selector,
                        fToken2,
                        1 ether
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
                        fToken2,
                        abi.encodeWithSelector(
                            IFluidVaultV2.deposit.selector,
                            1 ether,
                            safe
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
                        fToken2,
                        abi.encodeWithSelector(
                            IFluidVaultV2.withdraw.selector,
                            1 ether,
                            safe,
                            safe
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
                        fToken2,
                        abi.encodeWithSelector(
                            IFluidVaultV2.redeem.selector,
                            1 ether,
                            safe,
                            safe
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
                        FluidMerkleDistributor,
                        abi.encodeWithSelector(
                            IFluidMerkleDistributor.claim.selector,
                            safe,
                            1 ether,
                            0,
                            bytes32(0),
                            0,
                            new bytes32[](0),
                            new bytes(0)
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
                        fToken3,
                        abi.encodeWithSelector(
                            IFluidVaultV2.deposit.selector,
                            1 ether,
                            safe
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
                        fToken3,
                        abi.encodeWithSelector(
                            IFluidVaultV2.withdraw.selector,
                            1 ether,
                            safe,
                            safe
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
                        fToken3,
                        abi.encodeWithSelector(
                            IFluidVaultV2.redeem.selector,
                            1 ether,
                            safe,
                            safe
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
                        USDC,
                        abi.encodeWithSelector(
                            IERC20.approve.selector,
                            VaultV2,
                            1 ether
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
                        USDC,
                        abi.encodeWithSelector(
                            IERC20.approve.selector,
                            fToken3,
                            1 ether
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
                        USDC,
                        abi.encodeWithSelector(
                            IERC20.approve.selector,
                            MetaMorphoV1_2,
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
                        VaultV2_3,
                        abi.encodeWithSelector(
                            IFluidVaultV2.deposit.selector,
                            1 ether,
                            safe
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
                        VaultV2_3,
                        abi.encodeWithSelector(
                            IFluidVaultV2.withdraw.selector,
                            1 ether,
                            safe,
                            safe
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
                        VaultV2_3,
                        abi.encodeWithSelector(
                            IFluidVaultV2.redeem.selector,
                            1 ether,
                            safe,
                            safe
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
                        MetaMorphoV1_2,
                        abi.encodeWithSelector(
                            IMetaMorphoV1.deposit.selector,
                            1 ether,
                            safe
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
                        MetaMorphoV1_2,
                        abi.encodeWithSelector(
                            IMetaMorphoV1.withdraw.selector,
                            1 ether,
                            safe,
                            safe
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
                        MetaMorphoV1_2,
                        abi.encodeWithSelector(
                            IMetaMorphoV1.redeem.selector,
                            1 ether,
                            safe,
                            safe
                        )
                    );
                }
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    USDT,
                    abi.encodeWithSelector(
                        IERC20.approve.selector,
                        fToken,
                        1 ether
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
                        MetaMorphoV1_1,
                        abi.encodeWithSelector(
                            IMetaMorphoV1.deposit.selector,
                            1 ether,
                            safe
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
                        MetaMorphoV1_1,
                        abi.encodeWithSelector(
                            IMetaMorphoV1.withdraw.selector,
                            1 ether,
                            safe,
                            safe
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
                        MetaMorphoV1_1,
                        abi.encodeWithSelector(
                            IMetaMorphoV1.redeem.selector,
                            1 ether,
                            safe,
                            safe
                        )
                    );
                }
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    WETH,
                    abi.encodeWithSelector(
                        IERC20.approve.selector,
                        VaultV2_3,
                        1 ether
                    )
                );
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                    )
                );
                _safeExecuteTransaction(
                    WETH,
                    abi.encodeWithSelector(
                        IERC20.approve.selector,
                        MetaMorphoV1_1,
                        1 ether
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
            vm.expectRevert();
            _safeExecuteTransaction(
                UniversalRewardsDistributor,
                abi.encodeWithSelector(
                    IUniversalRewardsDistributor.claim.selector, safe, ensToken, 1 ether, new bytes32[](1)
                )
            );
        }

        // REVOKE TARGET
        {
            vm.expectRevert();
            _safeExecuteTransaction(
                UniversalRewardsDistributor,
                abi.encodeWithSelector(
                    IUniversalRewardsDistributor.claim.selector, safe, ensToken, 1 ether, new bytes32[](1)
                )
            );
        }

        // SCOPE FUNCTION
        {
            {
                _safeExecuteTransaction(
                    USDT,
                    abi.encodeWithSelector(
                        IERC20.approve.selector,
                        fToken,
                        1 ether
                    )
                );
            }
            {
                {
                    _safeExecuteTransaction(
                        VaultV2,
                        abi.encodeWithSelector(
                            IFluidVaultV2.deposit.selector,
                            1 ether,
                            safe
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        VaultV2,
                        abi.encodeWithSelector(
                            IFluidVaultV2.redeem.selector,
                            1 ether,
                            safe,
                            safe
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        VaultV2,
                        abi.encodeWithSelector(
                            IFluidVaultV2.redeem.selector,
                            1 ether,
                            safe,
                            safe
                        )
                    );
                }
            }
            {
                _safeExecuteTransaction(
                    GHO,
                    abi.encodeWithSelector(
                        IERC20.approve.selector,
                        fToken2,
                        1 ether
                    )
                );
            }
            {
                _safeExecuteTransaction(
                    fToken2,
                    abi.encodeWithSelector(
                        IFluidVaultV2.deposit.selector,
                        1 ether,
                        safe
                    )
                );
                _safeExecuteTransaction(
                    fToken2,
                    abi.encodeWithSelector(
                        IFluidVaultV2.withdraw.selector,
                        1 ether,
                        safe,
                        safe
                    )
                );
                _safeExecuteTransaction(
                    fToken2,
                    abi.encodeWithSelector(
                        IFluidVaultV2.redeem.selector,
                        1 ether,
                        safe,
                        safe
                    )
                );
            }
            {
                _safeExecuteTransaction(
                    FluidMerkleDistributor,
                    abi.encodeWithSelector(
                        IFluidMerkleDistributor.claim.selector,
                        safe,
                        1 ether,
                        0,
                        bytes32(0),
                        0,
                        new bytes32[](0),
                        new bytes(0)
                    )
                );
            }
            {
                {
                    _safeExecuteTransaction(
                        fToken3,
                        abi.encodeWithSelector(
                            IFluidVaultV2.deposit.selector,
                            1 ether,
                            safe
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        fToken3,
                        abi.encodeWithSelector(
                            IFluidVaultV2.withdraw.selector,
                            1 ether,
                            safe,
                            safe
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        fToken3,
                        abi.encodeWithSelector(
                            IFluidVaultV2.redeem.selector,
                            1 ether,
                            safe,
                            safe
                        )
                    );
                }
            }
            {
                {
                    _safeExecuteTransaction(
                        USDC,
                        abi.encodeWithSelector(
                            IERC20.approve.selector,
                            VaultV2,
                            1 ether
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        USDC,
                        abi.encodeWithSelector(
                            IERC20.approve.selector,
                            fToken3,
                            1 ether
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        USDC,
                        abi.encodeWithSelector(
                            IERC20.approve.selector,
                            MetaMorphoV1_2,
                            1 ether
                        )
                    );
                }
            }
            {
                {
                    _safeExecuteTransaction(
                        VaultV2_3,
                        abi.encodeWithSelector(
                            IFluidVaultV2.deposit.selector,
                            1 ether,
                            safe
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        VaultV2_3,
                        abi.encodeWithSelector(
                            IFluidVaultV2.withdraw.selector,
                            1 ether,
                            safe,
                            safe
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        VaultV2_3,
                        abi.encodeWithSelector(
                            IFluidVaultV2.redeem.selector,
                            1 ether,
                            safe,
                            safe
                        )
                    );
                }
            }
            {
                {
                    _safeExecuteTransaction(
                        MetaMorphoV1_2,
                        abi.encodeWithSelector(
                            IMetaMorphoV1.deposit.selector,
                            1 ether,
                            safe
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        MetaMorphoV1_2,
                        abi.encodeWithSelector(
                            IMetaMorphoV1.withdraw.selector,
                            1 ether,
                            safe,
                            safe
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        MetaMorphoV1_2,
                        abi.encodeWithSelector(
                            IMetaMorphoV1.redeem.selector,
                            1 ether,
                            safe,
                            safe
                        )
                    );
                }
            }
            {
                _safeExecuteTransaction(
                    USDT,
                    abi.encodeWithSelector(
                        IERC20.approve.selector,
                        fToken,
                        1 ether
                    )
                );
            }
            {
                {
                    _safeExecuteTransaction(
                        MetaMorphoV1_1,
                        abi.encodeWithSelector(
                            IMetaMorphoV1.deposit.selector,
                            1 ether,
                            safe
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        MetaMorphoV1_1,
                        abi.encodeWithSelector(
                            IMetaMorphoV1.withdraw.selector,
                            1 ether,
                            safe,
                            safe
                        )
                    );
                }
                {
                    _safeExecuteTransaction(
                        MetaMorphoV1_1,
                        abi.encodeWithSelector(
                            IMetaMorphoV1.redeem.selector,
                            1 ether,
                            safe,
                            safe
                        )
                    );
                }
            }
            {
                _safeExecuteTransaction(
                    WETH,
                    abi.encodeWithSelector(
                        IERC20.approve.selector,
                        VaultV2_3,
                        1 ether
                    )
                );
                _safeExecuteTransaction(
                    WETH,
                    abi.encodeWithSelector(
                        IERC20.approve.selector,
                        MetaMorphoV1_1,
                        1 ether
                    )
                );
            }
        }

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
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        signatures = new string[](1);

        targets[0] = safe;
        calldatas[0] = abi.encodeWithSelector(
            ISafe.execTransaction.selector,
            0x40A2aCCbd92BCA938b02010E17A5b8929b49130D,
            0,
            _getSafeCalldata(),
            1,
            0,
            0,
            0,
            0x0000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000,
            hex"000000000000000000000000fe89cc7abb2c4183683ab71653c4cdc9b02d44b7000000000000000000000000000000000000000000000000000000000000000001"
        );
        values[0] = 0;
        signatures[0] = "";
        description = "";

        return (targets, values, signatures, calldatas, description);
    }

    function _isProposalSubmitted() public view override returns (bool) {
        return false;
    }

    function _getSafeCalldata() internal pure returns (bytes memory cd) {
        cd =
            hex"8d80ff0a0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000ca6800703806e61847984346d2d7ddd853049627e50a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000440172a43a4d414e4147455200000000000000000000000000000000000000000000000000000000000000000000000000330eefa8a787552dc5cad3c3ca644844b1e61ddb00703806e61847984346d2d7ddd853049627e50a400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006466523f7d4d414e4147455200000000000000000000000000000000000000000000000000000000000000000000000000330eefa8a787552dc5cad3c3ca644844b1e61ddbfabed4120000000000000000000000000000000000000000000000000000000000703806e61847984346d2d7ddd853049627e50a4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000da47508dd984d414e4147455200000000000000000000000000000000000000000000000000000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2095ea7b30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000000000000000000000000000000000000000000000000000000000001e00000000000000000000000000000000000000000000000000000000000000280000000000000000000000000000000000000000000000000000000000000032000000000000000000000000000000000000000000000000000000000000003e000000000000000000000000000000000000000000000000000000000000004a00000000000000000000000000000000000000000000000000000000000000560000000000000000000000000000000000000000000000000000000000000062000000000000000000000000000000000000000000000000000000000000006e000000000000000000000000000000000000000000000000000000000000007a00000000000000000000000000000000000000000000000000000000000000860000000000000000000000000000000000000000000000000000000000000092000000000000000000000000000000000000000000000000000000000000009e00000000000000000000000000000000000000000000000000000000000000aa00000000000000000000000000000000000000000000000000000000000000b600000000000000000000000000000000000000000000000000000000000000c20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000022d473030f116ddee9f6b43ac78ba30000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000002000000000000000000000000013f4ea83d0bd40e75c8222255bc855a974568dd40000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000002000000000000000000000000056c526b0159a258887e0d79ec3a80dfb940d0cd70000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000002000000000000000000000000068b3465833fb72a70ecdf485e0e4c7bd8665fc450000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000002000000000000000000000000087870bca3f3fd6335c3f4ce8392d69350b4fa4e200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000b188b1cb84fb0ba13cb9ee1292769f903a9fec5900000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000ba12222222228d8ba445958a75a0704d566bf2c800000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000bb50a5341368751024ddf33385ba8cf61fe65ff900000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000bbbbbbbbbb9cc5e90e3b3af64bdaf62c37eeffcb00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000c13e21b648a5ee794902342038ff3adab66be98700000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000c92e8bdf79f0507f65a392b0ab4667716bfe011000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000cc7d5785ad5755b6164e21495e07adb0ff11c2a800000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000d564f765f9ad3e7d2d6ca782100795a885e8e7c800703806e61847984346d2d7ddd853049627e50a4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e847508dd984d414e4147455200000000000000000000000000000000000000000000000000000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48095ea7b30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000002a00000000000000000000000000000000000000000000000000000000000000340000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000004c000000000000000000000000000000000000000000000000000000000000005800000000000000000000000000000000000000000000000000000000000000640000000000000000000000000000000000000000000000000000000000000070000000000000000000000000000000000000000000000000000000000000007c0000000000000000000000000000000000000000000000000000000000000088000000000000000000000000000000000000000000000000000000000000009400000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000ac00000000000000000000000000000000000000000000000000000000000000b800000000000000000000000000000000000000000000000000000000000000c400000000000000000000000000000000000000000000000000000000000000d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000200000000000000000000000004ef53d2caa51c447fdfeeedee8f07fd1962c9ee60000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000002000000000000000000000000056c526b0159a258887e0d79ec3a80dfb940d0cd70000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000002000000000000000000000000068b3465833fb72a70ecdf485e0e4c7bd8665fc450000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000002000000000000000000000000087870bca3f3fd6335c3f4ce8392d69350b4fa4e2000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000200000000000000000000000009fb7b4477576fe5b32be4c1843afb1e55f251b3300000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000a188eec8f81263234da3622a406892f3d630f98c00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000ba12222222228d8ba445958a75a0704d566bf2c800000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000bbbbbbbbbb9cc5e90e3b3af64bdaf62c37eeffcb00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000bebc44782c7db0a1a60cb6fe97d0b483032ff1c700000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000c13e21b648a5ee794902342038ff3adab66be98700000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000c3d688b66703497daa19211eedff47f25384cdc300000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000c92e8bdf79f0507f65a392b0ab4667716bfe011000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000d0a61f2963622e992e6534bde4d52fd0a89f39e000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000e108fbc04852b5df72f9e44d7c29f47e7a993add00703806e61847984346d2d7ddd853049627e50a4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a247508dd984d414e4147455200000000000000000000000000000000000000000000000000000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec7095ea7b30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b0000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000002a00000000000000000000000000000000000000000000000000000000000000360000000000000000000000000000000000000000000000000000000000000042000000000000000000000000000000000000000000000000000000000000004e000000000000000000000000000000000000000000000000000000000000005a00000000000000000000000000000000000000000000000000000000000000660000000000000000000000000000000000000000000000000000000000000072000000000000000000000000000000000000000000000000000000000000007e000000000000000000000000000000000000000000000000000000000000008a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000200000000000000000000000003afdc9bca9213a35503b077a6072f3d0d5ab08400000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000002000000000000000000000000056c526b0159a258887e0d79ec3a80dfb940d0cd7000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000200000000000000000000000005c20b550819128074fd538edf79791733ccedd180000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000002000000000000000000000000068b3465833fb72a70ecdf485e0e4c7bd8665fc450000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000002000000000000000000000000087870bca3f3fd6335c3f4ce8392d69350b4fa4e200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000ba12222222228d8ba445958a75a0704d566bf2c800000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000bebc44782c7db0a1a60cb6fe97d0b483032ff1c700000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000c13e21b648a5ee794902342038ff3adab66be98700000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000c92e8bdf79f0507f65a392b0ab4667716bfe011000703806e61847984346d2d7ddd853049627e50a4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001f247508dd984d414e4147455200000000000000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbb9cc5e90e3b3af64bdaf62c37eeffcba99aad890000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000240000000000000000000000000000000000000000000000000000000000000480000000000000000000000000000000000000000000000000000000000000052000000000000000000000000000000000000000000000000000000000000005c00000000000000000000000000000000000000000000000000000000000000660000000000000000000000000000000000000000000000000000000000000070000000000000000000000000000000000000000000000000000000000000007a00000000000000000000000000000000000000000000000000000000000000880000000000000000000000000000000000000000000000000000000000000092000000000000000000000000000000000000000000000000000000000000009c00000000000000000000000000000000000000000000000000000000000000a600000000000000000000000000000000000000000000000000000000000000b000000000000000000000000000000000000000000000000000000000000000ba00000000000000000000000000000000000000000000000000000000000000c600000000000000000000000000000000000000000000000000000000000000d200000000000000000000000000000000000000000000000000000000000000de00000000000000000000000000000000000000000000000000000000000000ea00000000000000000000000000000000000000000000000000000000000000f60000000000000000000000000000000000000000000000000000000000000102000000000000000000000000000000000000000000000000000000000000010e000000000000000000000000000000000000000000000000000000000000011a00000000000000000000000000000000000000000000000000000000000001260000000000000000000000000000000000000000000000000000000000000132000000000000000000000000000000000000000000000000000000000000013e000000000000000000000000000000000000000000000000000000000000014a00000000000000000000000000000000000000000000000000000000000001560000000000000000000000000000000000000000000000000000000000000162000000000000000000000000000000000000000000000000000000000000016e000000000000000000000000000000000000000000000000000000000000017a00000000000000000000000000000000000000000000000000000000000001860000000000000000000000000000000000000000000000000000000000000192000000000000000000000000000000000000000000000000000000000000019e00000000000000000000000000000000000000000000000000000000000001aa00000000000000000000000000000000000000000000000000000000000001b600000000000000000000000000000000000000000000000000000000000001c200000000000000000000000000000000000000000000000000000000000001ce00000000000000000000000000000000000000000000000000000000000001da00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000200000000000000000000000002260fac5e5542a773aa44fbcfedf7c193bc2c59900000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000dddd770badd886df3864029e4b377b5f6a2b6b8300000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000870ac11d48b15db9a138cf899d20f13f79ba00bc000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000bef55718ad6000000000000000000000000000000000000000000000000000000000000000000070000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000000000000000000700000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000200000000000000000000000007f39c581f595b53c5cb19bd0b3f8da6c935e2ca00000000000000000000000000000000000000000000000000000000000000007000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000002000000000000000000000000048f7e36eb6b826b2df4b2e630b62cd25e89e40e200000000000000000000000000000000000000000000000000000000000000070000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000870ac11d48b15db9a138cf899d20f13f79ba00bc000000000000000000000000000000000000000000000000000000000000000700000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000bef55718ad6000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000cbb7c0000ab88b473b1f5afd9ef808440eed33bf00000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000a6d6950c9f177f1de7f7757fb33539e3ec60182a00000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000870ac11d48b15db9a138cf899d20f13f79ba00bc000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000bef55718ad6000000000000000000000000000000000000000000000000000000000000000000090000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000000000000000000000000000000000000000000900000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000200000000000000000000000007f39c581f595b53c5cb19bd0b3f8da6c935e2ca000000000000000000000000000000000000000000000000000000000000000090000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000bd60a6770b27e084e8617335dde769241b0e71d800000000000000000000000000000000000000000000000000000000000000090000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000870ac11d48b15db9a138cf899d20f13f79ba00bc000000000000000000000000000000000000000000000000000000000000000900000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000d1d507e40be8000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000200000000000000000000000007f39c581f595b53c5cb19bd0b3f8da6c935e2ca0000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000bd60a6770b27e084e8617335dde769241b0e71d8000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000870ac11d48b15db9a138cf899d20f13f79ba00bc000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000d645e632040800000703806e61847984346d2d7ddd853049627e50a4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001ee47508dd984d414e4147455200000000000000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbb9cc5e90e3b3af64bdaf62c37eeffcb5c2bea490000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000240000000000000000000000000000000000000000000000000000000000000480000000000000000000000000000000000000000000000000000000000000052000000000000000000000000000000000000000000000000000000000000005c00000000000000000000000000000000000000000000000000000000000000660000000000000000000000000000000000000000000000000000000000000070000000000000000000000000000000000000000000000000000000000000007a0000000000000000000000000000000000000000000000000000000000000084000000000000000000000000000000000000000000000000000000000000008e000000000000000000000000000000000000000000000000000000000000009800000000000000000000000000000000000000000000000000000000000000a200000000000000000000000000000000000000000000000000000000000000ac00000000000000000000000000000000000000000000000000000000000000b600000000000000000000000000000000000000000000000000000000000000c200000000000000000000000000000000000000000000000000000000000000ce00000000000000000000000000000000000000000000000000000000000000da00000000000000000000000000000000000000000000000000000000000000e600000000000000000000000000000000000000000000000000000000000000f200000000000000000000000000000000000000000000000000000000000000fe000000000000000000000000000000000000000000000000000000000000010a00000000000000000000000000000000000000000000000000000000000001160000000000000000000000000000000000000000000000000000000000000122000000000000000000000000000000000000000000000000000000000000012e000000000000000000000000000000000000000000000000000000000000013a00000000000000000000000000000000000000000000000000000000000001460000000000000000000000000000000000000000000000000000000000000152000000000000000000000000000000000000000000000000000000000000015e000000000000000000000000000000000000000000000000000000000000016a00000000000000000000000000000000000000000000000000000000000001760000000000000000000000000000000000000000000000000000000000000182000000000000000000000000000000000000000000000000000000000000018e000000000000000000000000000000000000000000000000000000000000019a00000000000000000000000000000000000000000000000000000000000001a600000000000000000000000000000000000000000000000000000000000001b200000000000000000000000000000000000000000000000000000000000001be00000000000000000000000000000000000000000000000000000000000001ca00000000000000000000000000000000000000000000000000000000000001d600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f00000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000200000000000000000000000002260fac5e5542a773aa44fbcfedf7c193bc2c59900000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000dddd770badd886df3864029e4b377b5f6a2b6b8300000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000870ac11d48b15db9a138cf899d20f13f79ba00bc000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000bef55718ad6000000000000000000000000000000000000000000000000000000000000000000070000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000000000000000000700000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000200000000000000000000000007f39c581f595b53c5cb19bd0b3f8da6c935e2ca00000000000000000000000000000000000000000000000000000000000000007000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000002000000000000000000000000048f7e36eb6b826b2df4b2e630b62cd25e89e40e200000000000000000000000000000000000000000000000000000000000000070000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000870ac11d48b15db9a138cf899d20f13f79ba00bc000000000000000000000000000000000000000000000000000000000000000700000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000bef55718ad6000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000cbb7c0000ab88b473b1f5afd9ef808440eed33bf00000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000a6d6950c9f177f1de7f7757fb33539e3ec60182a00000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000870ac11d48b15db9a138cf899d20f13f79ba00bc000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000bef55718ad6000000000000000000000000000000000000000000000000000000000000000000090000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000000000000000000000000000000000000000000900000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000200000000000000000000000007f39c581f595b53c5cb19bd0b3f8da6c935e2ca000000000000000000000000000000000000000000000000000000000000000090000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000bd60a6770b27e084e8617335dde769241b0e71d800000000000000000000000000000000000000000000000000000000000000090000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000870ac11d48b15db9a138cf899d20f13f79ba00bc000000000000000000000000000000000000000000000000000000000000000900000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000d1d507e40be8000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000200000000000000000000000007f39c581f595b53c5cb19bd0b3f8da6c935e2ca0000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000bd60a6770b27e084e8617335dde769241b0e71d8000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020000000000000000000000000870ac11d48b15db9a138cf899d20f13f79ba00bc000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000d645e632040800000703806e61847984346d2d7ddd853049627e50a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000440c6c76b84d414e414745520000000000000000000000000000000000000000000000000000000000000000000000000040d16fc0246ad3160ccc09b8d0d3a2cd28ae6c2f00703806e61847984346d2d7ddd853049627e50a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002647508dd984d414e414745520000000000000000000000000000000000000000000000000000000000000000000000000040d16fc0246ad3160ccc09b8d0d3a2cd28ae6c2f095ea7b30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000200000000000000000000000006a29a46e21c730dca1d8b23d637c101cec605c5b00703806e61847984346d2d7ddd853049627e50a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000440c6c76b84d414e41474552000000000000000000000000000000000000000000000000000000000000000000000000006a29a46e21c730dca1d8b23d637c101cec605c5b00703806e61847984346d2d7ddd853049627e50a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003047508dd984d414e41474552000000000000000000000000000000000000000000000000000000000000000000000000006a29a46e21c730dca1d8b23d637c101cec605c5b6e553f650000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000703806e61847984346d2d7ddd853049627e50a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003c47508dd984d414e41474552000000000000000000000000000000000000000000000000000000000000000000000000006a29a46e21c730dca1d8b23d637c101cec605c5bb460af940000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001c00000000000000000000000000000000000000000000000000000000000000260000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000703806e61847984346d2d7ddd853049627e50a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003c47508dd984d414e41474552000000000000000000000000000000000000000000000000000000000000000000000000006a29a46e21c730dca1d8b23d637c101cec605c5bba0876520000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001c00000000000000000000000000000000000000000000000000000000000000260000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000703806e61847984346d2d7ddd853049627e50a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000440c6c76b84d414e41474552000000000000000000000000000000000000000000000000000000000000000000000000007060fe0dd3e31be01efac6b28c8d38018fd163b000703806e61847984346d2d7ddd853049627e50a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002447508dd984d414e41474552000000000000000000000000000000000000000000000000000000000000000000000000007060fe0dd3e31be01efac6b28c8d38018fd163b0be5013dc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000703806e61847984346d2d7ddd853049627e50a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000440c6c76b84d414e41474552000000000000000000000000000000000000000000000000000000000000000000000000009fb7b4477576fe5b32be4c1843afb1e55f251b3300703806e61847984346d2d7ddd853049627e50a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003047508dd984d414e41474552000000000000000000000000000000000000000000000000000000000000000000000000009fb7b4477576fe5b32be4c1843afb1e55f251b336e553f650000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000703806e61847984346d2d7ddd853049627e50a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003c47508dd984d414e41474552000000000000000000000000000000000000000000000000000000000000000000000000009fb7b4477576fe5b32be4c1843afb1e55f251b33b460af940000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001c00000000000000000000000000000000000000000000000000000000000000260000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000703806e61847984346d2d7ddd853049627e50a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003c47508dd984d414e41474552000000000000000000000000000000000000000000000000000000000000000000000000009fb7b4477576fe5b32be4c1843afb1e55f251b33ba0876520000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001c00000000000000000000000000000000000000000000000000000000000000260000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000703806e61847984346d2d7ddd853049627e50a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000440c6c76b84d414e41474552000000000000000000000000000000000000000000000000000000000000000000000000005c20b550819128074fd538edf79791733ccedd1800703806e61847984346d2d7ddd853049627e50a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003047508dd984d414e41474552000000000000000000000000000000000000000000000000000000000000000000000000005c20b550819128074fd538edf79791733ccedd186e553f650000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000703806e61847984346d2d7ddd853049627e50a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003c47508dd984d414e41474552000000000000000000000000000000000000000000000000000000000000000000000000005c20b550819128074fd538edf79791733ccedd18b460af940000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001c00000000000000000000000000000000000000000000000000000000000000260000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000703806e61847984346d2d7ddd853049627e50a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003c47508dd984d414e41474552000000000000000000000000000000000000000000000000000000000000000000000000005c20b550819128074fd538edf79791733ccedd18ba0876520000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001c00000000000000000000000000000000000000000000000000000000000000260000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000703806e61847984346d2d7ddd853049627e50a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000440c6c76b84d414e4147455200000000000000000000000000000000000000000000000000000000000000000000000000d564f765f9ad3e7d2d6ca782100795a885e8e7c800703806e61847984346d2d7ddd853049627e50a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003047508dd984d414e4147455200000000000000000000000000000000000000000000000000000000000000000000000000d564f765f9ad3e7d2d6ca782100795a885e8e7c86e553f650000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000703806e61847984346d2d7ddd853049627e50a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003c47508dd984d414e4147455200000000000000000000000000000000000000000000000000000000000000000000000000d564f765f9ad3e7d2d6ca782100795a885e8e7c8b460af940000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001c00000000000000000000000000000000000000000000000000000000000000260000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000703806e61847984346d2d7ddd853049627e50a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003c47508dd984d414e4147455200000000000000000000000000000000000000000000000000000000000000000000000000d564f765f9ad3e7d2d6ca782100795a885e8e7c8ba0876520000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001c00000000000000000000000000000000000000000000000000000000000000260000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000703806e61847984346d2d7ddd853049627e50a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000440c6c76b84d414e4147455200000000000000000000000000000000000000000000000000000000000000000000000000bb50a5341368751024ddf33385ba8cf61fe65ff900703806e61847984346d2d7ddd853049627e50a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003047508dd984d414e4147455200000000000000000000000000000000000000000000000000000000000000000000000000bb50a5341368751024ddf33385ba8cf61fe65ff96e553f650000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000703806e61847984346d2d7ddd853049627e50a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003c47508dd984d414e4147455200000000000000000000000000000000000000000000000000000000000000000000000000bb50a5341368751024ddf33385ba8cf61fe65ff9b460af940000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001c00000000000000000000000000000000000000000000000000000000000000260000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000703806e61847984346d2d7ddd853049627e50a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003c47508dd984d414e4147455200000000000000000000000000000000000000000000000000000000000000000000000000bb50a5341368751024ddf33385ba8cf61fe65ff9ba0876520000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001c00000000000000000000000000000000000000000000000000000000000000260000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000703806e61847984346d2d7ddd853049627e50a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000440c6c76b84d414e4147455200000000000000000000000000000000000000000000000000000000000000000000000000e108fbc04852b5df72f9e44d7c29f47e7a993add00703806e61847984346d2d7ddd853049627e50a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003047508dd984d414e4147455200000000000000000000000000000000000000000000000000000000000000000000000000e108fbc04852b5df72f9e44d7c29f47e7a993add6e553f650000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000703806e61847984346d2d7ddd853049627e50a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003c47508dd984d414e4147455200000000000000000000000000000000000000000000000000000000000000000000000000e108fbc04852b5df72f9e44d7c29f47e7a993addb460af940000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001c00000000000000000000000000000000000000000000000000000000000000260000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000703806e61847984346d2d7ddd853049627e50a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003c47508dd984d414e4147455200000000000000000000000000000000000000000000000000000000000000000000000000e108fbc04852b5df72f9e44d7c29f47e7a993addba0876520000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001c00000000000000000000000000000000000000000000000000000000000000260000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000703806e61847984346d2d7ddd853049627e50a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000440c6c76b84d414e41474552000000000000000000000000000000000000000000000000000000000000000000000000004ef53d2caa51c447fdfeeedee8f07fd1962c9ee600703806e61847984346d2d7ddd853049627e50a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003047508dd984d414e41474552000000000000000000000000000000000000000000000000000000000000000000000000004ef53d2caa51c447fdfeeedee8f07fd1962c9ee66e553f650000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000703806e61847984346d2d7ddd853049627e50a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003c47508dd984d414e41474552000000000000000000000000000000000000000000000000000000000000000000000000004ef53d2caa51c447fdfeeedee8f07fd1962c9ee6b460af940000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001c00000000000000000000000000000000000000000000000000000000000000260000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000703806e61847984346d2d7ddd853049627e50a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003c47508dd984d414e41474552000000000000000000000000000000000000000000000000000000000000000000000000004ef53d2caa51c447fdfeeedee8f07fd1962c9ee6ba0876520000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001c00000000000000000000000000000000000000000000000000000000000000260000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000cd17345801aa8147b8d3950260ff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007440ae1b13d0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000070000000000000000000000000000000000000000000000000000000000000006987b22726f6c65734d6f64223a22307837303338303665363138343739383433343664326437646464383533303439363237653530613430222c22726f6c654b6579223a22307834643431346534313437343535323030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030222c22616464416e6e6f746174696f6e73223a5b7b22736368656d61223a2268747470733a2f2f6b69742e6b61727061746b65792e636f6d2f6170692f76312f6f70656e6170692e6a736f6e222c2275726973223a5b2268747470733a2f2f6b69742e6b61727061746b65792e636f6d2f6170692f76312f7065726d697373696f6e732f6574682f666c7569642f6465706f7369743f746172676574733d47484f222c2268747470733a2f2f6b69742e6b61727061746b65792e636f6d2f6170692f76312f7065726d697373696f6e732f6574682f666c7569642f6465706f7369743f746172676574733d55534443222c2268747470733a2f2f6b69742e6b61727061746b65792e636f6d2f6170692f76312f7065726d697373696f6e732f6574682f666c7569642f6465706f7369743f746172676574733d55534454222c2268747470733a2f2f6b69742e6b61727061746b65792e636f6d2f6170692f76312f7065726d697373696f6e732f6574682f6d6f7270686f4d61726b6574732f6465706f7369743f746172676574733d307836346436356339613264393163333664353666626334326436396539373933333533323031363962336466363362663932373839653263383838336663633634222c2268747470733a2f2f6b69742e6b61727061746b65792e636f6d2f6170692f76312f7065726d697373696f6e732f6574682f6d6f7270686f4d61726b6574732f6465706f7369743f746172676574733d307862386663373065383262633562623533653737333632366663633661323366376565666130333639313864376566323136656366623139353061393461383565222c2268747470733a2f2f6b69742e6b61727061746b65792e636f6d2f6170692f76312f7065726d697373696f6e732f6574682f6d6f7270686f4d61726b6574732f6465706f7369743f746172676574733d307864306535306364616339326665323137323034336635653063333635333263363336396432343934376534303936386633346135653838313963613965633564222c2268747470733a2f2f6b69742e6b61727061746b65792e636f6d2f6170692f76312f7065726d697373696f6e732f6574682f6d6f7270686f4d61726b6574732f6465706f7369743f746172676574733d307833613835653631393735313135323939313734323831306466366563363963653437336461656639396532386136346162323334306437623763636665653439222c2268747470733a2f2f6b69742e6b61727061746b65792e636f6d2f6170692f76312f7065726d697373696f6e732f6574682f6d6f7270686f4d61726b6574732f6465706f7369743f746172676574733d307862333233343935663765343134386265353634336134656134613832323165656631363365346263636664656463326136663436393662616163626338366363222c2268747470733a2f2f6b69742e6b61727061746b65792e636f6d2f6170692f76312f7065726d697373696f6e732f6574682f6d6f7270686f5661756c74732f6465706f7369743f746172676574733d307864353634463736354639614433453764326436634137383231303037393561383835653865374338222c2268747470733a2f2f6b69742e6b61727061746b65792e636f6d2f6170692f76312f7065726d697373696f6e732f6574682f6d6f7270686f5661756c74732f6465706f7369743f746172676574733d307842623530413533343133363837353130323464646633333338354241386366363166453635464639222c2268747470733a2f2f6b69742e6b61727061746b65792e636f6d2f6170692f76312f7065726d697373696f6e732f6574682f6d6f7270686f5661756c74732f6465706f7369743f746172676574733d307865313038666263303438353242356466373266394534346437433239463437653741393933614464222c2268747470733a2f2f6b69742e6b61727061746b65792e636f6d2f6170692f76312f7065726d697373696f6e732f6574682f6d6f7270686f5661756c74732f6465706f7369743f746172676574733d307834456635336432634161353143343437666446454565646565384630374644313936324339656536225d7d5d7d0000000000000000000000000000000000000000000000000000000000000000000000000000001b524f4c45535f5045524d495353494f4e5f414e4e4f544154494f4e0000000000000000000000000000000000000000000000000000000000";
    }
}
