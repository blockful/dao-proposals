// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { ISafe } from "@ens/interfaces/ISafe.sol";
import { IZodiacRoles } from "@ens/interfaces/IZodiacRoles.sol";
import { IRolesModifier, ConditionFlat } from "@ens/interfaces/IRolesModifier.sol";
import { IUniversalRewardsDistributor } from "@ens/interfaces/IUniversalRewardsDistributor.sol";
import { IFluidVaultV2 } from "@ens/interfaces/IFluidVaultV2.sol";
import { IFluidMerkleDistributor } from "@ens/interfaces/IFluidMerkleDistributor.sol";
import { IMetaMorphoV1 } from "@ens/interfaces/IMetaMorphoV1.sol";
import { IMultiSend } from "@ens/interfaces/IMultiSend.sol";
import { IAnnotationRegistry } from "@ens/interfaces/IAnnotationRegistry.sol";
import { ENS_Governance } from "@ens/ens.t.sol";
import { SafeHelper } from "@ens/helpers/SafeHelper.sol";
import { ZodiacRolesHelper } from "@ens/helpers/ZodiacRolesHelper.sol";
import { console2 } from "@forge-std/src/console2.sol";
import { IERC20 } from "@forge-std/src/interfaces/IERC20.sol";

/// @dev Morpho Blue core contract interface — supply and withdraw selectors only.
interface IMorphoBlue {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supply(MarketParams memory, uint256, uint256, address, bytes memory) external returns (uint256, uint256);
    function withdraw(MarketParams memory, uint256, uint256, address, address) external returns (uint256, uint256);
}

contract Proposal_ENS_EP_6_27_Test is ENS_Governance, SafeHelper, ZodiacRolesHelper {
    // ─── Core Addresses
    // ─────────────────────────────────────────────────
    address private safe = 0x4F2083f5fBede34C2714aFfb3105539775f7FE64;
    IRolesModifier private constant ROLES_MOD = IRolesModifier(0x703806E61847984346d2D7DDd853049627e50A40);

    // ─── MultiSend used by this proposal (differs from the default in MultiSendHelper) ──
    IMultiSend private constant PROPOSAL_MULTI_SEND = IMultiSend(0x9641d764fc13c8B624c04430C7356C1C7C8102e2);

    // ─── Annotation Registry
    // ────────────────────────────────────────────
    IAnnotationRegistry private constant ANNOTATION_REGISTRY =
        IAnnotationRegistry(0x000000000000cd17345801aa8147b8D3950260FF);

    // ─── Protocol Targets
    // ───────────────────────────────────────────────
    address private UniversalRewardsDistributor = 0x330eefa8a787552DC5cAd3C3cA644844B1E61Ddb;
    address private USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address private FluidUSDT = 0x5C20B550819128074FD538Edf79791733ccEdd18;
    address private kpkUSDCv2 = 0x4Ef53d2cAa51C447fdFEEedee8F07FD1962C9ee6;
    address private GHO = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;
    address private FluidGHO = 0x6A29A46E21C730DcA1d8b23d637c101cec605C5B;
    address private FluidUSDC = 0x9Fb7b4477576Fe5B32be4C1843aFB1e55F251B33;
    address private USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private kpkETHv2 = 0xBb50A5341368751024ddf33385BA8cf61fE65FF9;
    address private WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private kpkETHPrime = 0xd564F765F9aD3E7d2d6cA782100795a885e8e7C8;
    address private kpkUSDCPrime = 0xe108fbc04852B5df72f9E44d7C29F47e7A993aDd;
    address private FluidMerklDistributor = 0x7060FE0Dd3E31be01EFAc6B28C8D38018fD163B0;

    // ─── Morpho Blue
    // ────────────────────────────────────────────────────
    IMorphoBlue private constant MORPHO_BLUE = IMorphoBlue(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);

    // ─── Additional DeFi Addresses (used in approve conditions) ────────
    address private constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address private constant SPARK_LEND_V3 = 0x13f4EA83D0bd40E75C8222255bc855a974568Dd4;
    address private constant ONE_INCH_V6 = 0x56C526b0159a258887e0d79ec3a80dfb940d0cD7;
    address private constant UNISWAP_V3_ROUTER = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address private constant AAVE_V3_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address private constant AURA_REWARDS = 0xB188b1CB84Fb0bA13cb9ee1292769F903A9feC59;
    address private constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address private constant EULER_V2 = 0xC13e21B648A5Ee794902342038FF3aDAB66BE987;
    address private constant COWSWAP_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;
    address private constant CC7D_ADDR = 0xcc7d5785AD5755B6164e21495E07aDb0Ff11C2A8;
    address private constant A188_ADDR = 0xA188EEC8F81263234dA3622A406892F3D630f98c;
    address private constant CURVE_3POOL = 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7;
    address private constant COMPOUND_USDC = 0xc3d688B66703497DAA19211EEdff47f25384cdc3;
    address private constant D0A6_ADDR = 0xd0A61F2963622e992e6534bde4D52fd0a89F39E0;
    address private constant AAVE_USDT = 0x3Afdc9BCA9213A35503b077a6072F3D0d5AB0840;

    // ─── Zodiac Condition: Additional Param Types
    // ─────────────────────
    uint8 private constant PARAM_TYPE_DYNAMIC = 2;

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 24_023_538, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0x1D5460F896521aD685Ea4c3F2c679Ec0b6806359; // coltron.eth
    }

    function _beforeProposal() public override {
        vm.startPrank(karpatkey);
        vm.pauseGasMetering();

        // REVOKE FUNCTION
        {
            _safeExecuteTransaction(
                UniversalRewardsDistributor,
                abi.encodeWithSelector(
                    IUniversalRewardsDistributor.claim.selector, safe, ensToken, new bytes32[](1), 1 ether
                )
            );
        }

        // REVOKE TARGET
        {
            _safeExecuteTransaction(
                UniversalRewardsDistributor,
                abi.encodeWithSelector(
                    IUniversalRewardsDistributor.claim.selector, safe, ensToken, new bytes32[](1), 1 ether
                )
            );
        }

        // SCOPE FUNCTION
        {
            {
                {
                    vm.expectRevert();
                    _safeExecuteTransaction(USDT, abi.encodeWithSelector(IERC20.approve.selector, FluidUSDT, 1 ether));
                }
                {
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                    _safeExecuteTransaction(
                        kpkUSDCv2, abi.encodeWithSelector(IFluidVaultV2.deposit.selector, 1 ether, safe)
                    );
                }
                {
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                    _safeExecuteTransaction(
                        kpkUSDCv2, abi.encodeWithSelector(IFluidVaultV2.redeem.selector, 1 ether, safe, safe)
                    );
                }
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(
                    kpkUSDCv2, abi.encodeWithSelector(IFluidVaultV2.redeem.selector, 1 ether, safe, safe)
                );
            }
            {
                _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                _safeExecuteTransaction(GHO, abi.encodeWithSelector(IERC20.approve.selector, FluidGHO, 1 ether));
            }
            {
                {
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                    _safeExecuteTransaction(
                        FluidGHO, abi.encodeWithSelector(IFluidVaultV2.deposit.selector, 1 ether, safe)
                    );
                }
                {
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                    _safeExecuteTransaction(
                        FluidGHO, abi.encodeWithSelector(IFluidVaultV2.withdraw.selector, 1 ether, safe, safe)
                    );
                }
                {
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                    _safeExecuteTransaction(
                        FluidGHO, abi.encodeWithSelector(IFluidVaultV2.redeem.selector, 1 ether, safe, safe)
                    );
                }
            }
            {
                {
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                    _safeExecuteTransaction(
                        FluidMerklDistributor,
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
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                    _safeExecuteTransaction(
                        FluidUSDC, abi.encodeWithSelector(IFluidVaultV2.deposit.selector, 1 ether, safe)
                    );
                }
                {
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                    _safeExecuteTransaction(
                        FluidUSDC, abi.encodeWithSelector(IFluidVaultV2.withdraw.selector, 1 ether, safe, safe)
                    );
                }
                {
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                    _safeExecuteTransaction(
                        FluidUSDC, abi.encodeWithSelector(IFluidVaultV2.redeem.selector, 1 ether, safe, safe)
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
                    _safeExecuteTransaction(USDC, abi.encodeWithSelector(IERC20.approve.selector, kpkUSDCv2, 1 ether));
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(USDC, abi.encodeWithSelector(IERC20.approve.selector, FluidUSDC, 1 ether));
                }
                {
                    vm.expectRevert(
                        abi.encodeWithSelector(
                            IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                        )
                    );
                    _safeExecuteTransaction(
                        USDC, abi.encodeWithSelector(IERC20.approve.selector, kpkUSDCPrime, 1 ether)
                    );
                }
            }
            {
                {
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                    _safeExecuteTransaction(
                        kpkETHv2, abi.encodeWithSelector(IFluidVaultV2.deposit.selector, 1 ether, safe)
                    );
                }
                {
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                    _safeExecuteTransaction(
                        kpkETHv2, abi.encodeWithSelector(IFluidVaultV2.withdraw.selector, 1 ether, safe, safe)
                    );
                }
                {
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                    _safeExecuteTransaction(
                        kpkETHv2, abi.encodeWithSelector(IFluidVaultV2.redeem.selector, 1 ether, safe, safe)
                    );
                }
            }
            {
                {
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                    _safeExecuteTransaction(
                        kpkUSDCPrime, abi.encodeWithSelector(IMetaMorphoV1.deposit.selector, 1 ether, safe)
                    );
                }
                {
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                    _safeExecuteTransaction(
                        kpkUSDCPrime, abi.encodeWithSelector(IMetaMorphoV1.withdraw.selector, 1 ether, safe, safe)
                    );
                }
                {
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                    _safeExecuteTransaction(
                        kpkUSDCPrime, abi.encodeWithSelector(IMetaMorphoV1.redeem.selector, 1 ether, safe, safe)
                    );
                }
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                    )
                );
                _safeExecuteTransaction(USDT, abi.encodeWithSelector(IERC20.approve.selector, FluidUSDT, 1 ether));
            }
            {
                {
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                    _safeExecuteTransaction(
                        kpkETHPrime, abi.encodeWithSelector(IMetaMorphoV1.deposit.selector, 1 ether, safe)
                    );
                }
                {
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                    _safeExecuteTransaction(
                        kpkETHPrime, abi.encodeWithSelector(IMetaMorphoV1.withdraw.selector, 1 ether, safe, safe)
                    );
                }
                {
                    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
                    _safeExecuteTransaction(
                        kpkETHPrime, abi.encodeWithSelector(IMetaMorphoV1.redeem.selector, 1 ether, safe, safe)
                    );
                }
            }
            {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                    )
                );
                _safeExecuteTransaction(WETH, abi.encodeWithSelector(IERC20.approve.selector, kpkETHv2, 1 ether));
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.OrViolation, bytes32(0)
                    )
                );
                _safeExecuteTransaction(WETH, abi.encodeWithSelector(IERC20.approve.selector, kpkETHPrime, 1 ether));
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
                _safeExecuteTransaction(USDT, abi.encodeWithSelector(IERC20.approve.selector, FluidUSDT, 1 ether));
            }
            {
                {
                    _safeExecuteTransaction(
                        kpkUSDCv2, abi.encodeWithSelector(IFluidVaultV2.deposit.selector, 1 ether, safe)
                    );
                }
                {
                    _safeExecuteTransaction(
                        kpkUSDCv2, abi.encodeWithSelector(IFluidVaultV2.redeem.selector, 1 ether, safe, safe)
                    );
                }
                {
                    _safeExecuteTransaction(
                        kpkUSDCv2, abi.encodeWithSelector(IFluidVaultV2.redeem.selector, 1 ether, safe, safe)
                    );
                }
            }
            {
                _safeExecuteTransaction(GHO, abi.encodeWithSelector(IERC20.approve.selector, FluidGHO, 1 ether));
            }
            {
                _safeExecuteTransaction(FluidGHO, abi.encodeWithSelector(IFluidVaultV2.deposit.selector, 1 ether, safe));
                _safeExecuteTransaction(
                    FluidGHO, abi.encodeWithSelector(IFluidVaultV2.withdraw.selector, 1 ether, safe, safe)
                );
                _safeExecuteTransaction(
                    FluidGHO, abi.encodeWithSelector(IFluidVaultV2.redeem.selector, 1 ether, safe, safe)
                );
            }
            {
                _safeExecuteTransaction(
                    FluidMerklDistributor,
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
                        FluidUSDC, abi.encodeWithSelector(IFluidVaultV2.deposit.selector, 1 ether, safe)
                    );
                }
                {
                    _safeExecuteTransaction(
                        FluidUSDC, abi.encodeWithSelector(IFluidVaultV2.withdraw.selector, 1 ether, safe, safe)
                    );
                }
                {
                    _safeExecuteTransaction(
                        FluidUSDC, abi.encodeWithSelector(IFluidVaultV2.redeem.selector, 1 ether, safe, safe)
                    );
                }
            }
            {
                {
                    _safeExecuteTransaction(USDC, abi.encodeWithSelector(IERC20.approve.selector, kpkUSDCv2, 1 ether));
                }
                {
                    _safeExecuteTransaction(USDC, abi.encodeWithSelector(IERC20.approve.selector, FluidUSDC, 1 ether));
                }
                {
                    _safeExecuteTransaction(
                        USDC, abi.encodeWithSelector(IERC20.approve.selector, kpkUSDCPrime, 1 ether)
                    );
                }
            }
            {
                {
                    _safeExecuteTransaction(
                        kpkETHv2, abi.encodeWithSelector(IFluidVaultV2.deposit.selector, 1 ether, safe)
                    );
                }
                {
                    _safeExecuteTransaction(
                        kpkETHv2, abi.encodeWithSelector(IFluidVaultV2.withdraw.selector, 1 ether, safe, safe)
                    );
                }
                {
                    _safeExecuteTransaction(
                        kpkETHv2, abi.encodeWithSelector(IFluidVaultV2.redeem.selector, 1 ether, safe, safe)
                    );
                }
            }
            {
                {
                    _safeExecuteTransaction(
                        kpkUSDCPrime, abi.encodeWithSelector(IMetaMorphoV1.deposit.selector, 1 ether, safe)
                    );
                }
                {
                    _safeExecuteTransaction(
                        kpkUSDCPrime, abi.encodeWithSelector(IMetaMorphoV1.withdraw.selector, 1 ether, safe, safe)
                    );
                }
                {
                    _safeExecuteTransaction(
                        kpkUSDCPrime, abi.encodeWithSelector(IMetaMorphoV1.redeem.selector, 1 ether, safe, safe)
                    );
                }
            }
            {
                _safeExecuteTransaction(USDT, abi.encodeWithSelector(IERC20.approve.selector, FluidUSDT, 1 ether));
            }
            {
                {
                    _safeExecuteTransaction(
                        kpkETHPrime, abi.encodeWithSelector(IMetaMorphoV1.deposit.selector, 1 ether, safe)
                    );
                }
                {
                    _safeExecuteTransaction(
                        kpkETHPrime, abi.encodeWithSelector(IMetaMorphoV1.withdraw.selector, 1 ether, safe, safe)
                    );
                }
                {
                    _safeExecuteTransaction(
                        kpkETHPrime, abi.encodeWithSelector(IMetaMorphoV1.redeem.selector, 1 ether, safe, safe)
                    );
                }
            }
            {
                _safeExecuteTransaction(WETH, abi.encodeWithSelector(IERC20.approve.selector, kpkETHv2, 1 ether));
                _safeExecuteTransaction(WETH, abi.encodeWithSelector(IERC20.approve.selector, kpkETHPrime, 1 ether));
            }
        }

        vm.stopPrank();
    }

    // ─── Calldata Generation
    // ────────────────────────────────────────────

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

    /// @dev Build the complete Safe execTransaction calldata (DelegateCall to MultiSend).
    function _buildFullSafeCalldata() internal view returns (bytes memory) {
        (, bytes memory cd) = _buildSafeExecDelegateCalldata(
            safe, address(PROPOSAL_MULTI_SEND), _buildMultiSendCalldata(), address(timelock)
        );
        return cd;
    }

    /// @dev Build the multiSend(bytes) calldata wrapping all 40 packed transactions.
    function _buildMultiSendCalldata() internal view returns (bytes memory) {
        return abi.encodeWithSelector(IMultiSend.multiSend.selector, _buildPackedTransactions());
    }

    // ─── MultiSend Payload
    // ──────────────────────────────────────────────

    function _buildPackedTransactions() internal view returns (bytes memory) {
        return abi.encodePacked(
            _packRevokeAndApproveBlock(),
            _packMorphoBlock(),
            _packGhoBlock(),
            _packFluidMerklBlock(),
            _packFluidUsdcBlock(),
            _packFluidUsdtBlock(),
            _packKpkEthPrimeBlock(),
            _packKpkEthV2Block(),
            _packKpkUsdcPrimeBlock(),
            _packKpkUsdcV2Block(),
            _packAnnotation()
        );
    }

    // ─── Revoke + Approve Block (TX 1-5)
    // ────────────────────────────────

    function _packRevokeAndApproveBlock() internal view returns (bytes memory) {
        return abi.encodePacked(_packRevokeBlock(), _packApproveBlock());
    }

    // ─── Revoke Block (TX 1-2)
    // ──────────────────────────────────────────

    function _packRevokeBlock() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 1: revokeTarget — remove UniversalRewardsDistributor from MANAGER role
            _packTx(
                address(ROLES_MOD),
                abi.encodeWithSelector(IRolesModifier.revokeTarget.selector, MANAGER_ROLE, UniversalRewardsDistributor)
            ),
            // TX 2: revokeFunction — revoke claim on UniversalRewardsDistributor
            _packTx(
                address(ROLES_MOD),
                abi.encodeWithSelector(
                    IRolesModifier.revokeFunction.selector,
                    MANAGER_ROLE,
                    UniversalRewardsDistributor,
                    IUniversalRewardsDistributor.claim.selector
                )
            )
        );
    }

    // ─── Approve Scope Block (TX 3-5)
    // ───────────────────────────────────

    function _packApproveBlock() internal view returns (bytes memory) {
        return abi.encodePacked(_packWethApprove(), _packUsdcApprove(), _packUsdtApprove());
    }

    function _packWethApprove() internal view returns (bytes memory) {
        // TX 3: scopeFunction — WETH.approve with OR-constrained spenders
        return _packTx(
            address(ROLES_MOD),
            abi.encodeWithSelector(
                IRolesModifier.scopeFunction.selector,
                MANAGER_ROLE,
                WETH,
                IERC20.approve.selector,
                _wethApproveConditions(),
                EXEC_NONE
            )
        );
    }

    function _packUsdcApprove() internal view returns (bytes memory) {
        // TX 4: scopeFunction — USDC.approve with OR-constrained spenders
        return _packTx(
            address(ROLES_MOD),
            abi.encodeWithSelector(
                IRolesModifier.scopeFunction.selector,
                MANAGER_ROLE,
                USDC,
                IERC20.approve.selector,
                _usdcApproveConditions(),
                EXEC_NONE
            )
        );
    }

    function _packUsdtApprove() internal view returns (bytes memory) {
        // TX 5: scopeFunction — USDT.approve with OR-constrained spenders
        return _packTx(
            address(ROLES_MOD),
            abi.encodeWithSelector(
                IRolesModifier.scopeFunction.selector,
                MANAGER_ROLE,
                USDT,
                IERC20.approve.selector,
                _usdtApproveConditions(),
                EXEC_NONE
            )
        );
    }

    // ─── Morpho Blue Block (TX 6-7)
    // ─────────────────────────────────────

    function _packMorphoBlock() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 6: scopeFunction — Morpho Blue supply with market params constraints
            _packTx(
                address(ROLES_MOD),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    address(MORPHO_BLUE),
                    IMorphoBlue.supply.selector,
                    _morphoSupplyConditions(),
                    EXEC_NONE
                )
            ),
            // TX 7: scopeFunction — Morpho Blue withdraw with market params constraints
            _packTx(
                address(ROLES_MOD),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    address(MORPHO_BLUE),
                    IMorphoBlue.withdraw.selector,
                    _morphoWithdrawConditions(),
                    EXEC_NONE
                )
            )
        );
    }

    // ─── GHO Block (TX 8-13)
    // ────────────────────────────────────────────

    function _packGhoBlock() internal view returns (bytes memory) {
        bytes memory a = _packScopeTarget(GHO); // TX 8
        bytes memory b = _packScopeApprove(GHO, _singleSpenderApproveConditions(FluidGHO)); // TX 9
        bytes memory d = _packScopeTarget(FluidGHO); // TX 10
        return abi.encodePacked(a, b, d, _packVaultDWR(FluidGHO, true)); // TX 11-13
    }

    // ─── FluidMerkl Block (TX 14-15)
    // ────────────────────────────────────

    function _packFluidMerklBlock() internal view returns (bytes memory) {
        bytes memory a = _packScopeTarget(FluidMerklDistributor);
        bytes memory b = _packScopeFunction(
            FluidMerklDistributor, IFluidMerkleDistributor.claim.selector, _fluidMerklClaimConditions()
        );
        return abi.encodePacked(a, b);
    }

    // ─── FluidUSDC Block (TX 16-19)
    // ─────────────────────────────────────

    function _packFluidUsdcBlock() internal view returns (bytes memory) {
        bytes memory a = _packScopeTarget(FluidUSDC);
        return abi.encodePacked(a, _packVaultDWR(FluidUSDC, true));
    }

    // ─── FluidUSDT Block (TX 20-23)
    // ─────────────────────────────────────

    function _packFluidUsdtBlock() internal view returns (bytes memory) {
        bytes memory a = _packScopeTarget(FluidUSDT);
        return abi.encodePacked(a, _packVaultDWR(FluidUSDT, true));
    }

    // ─── kpkETHPrime Block (TX 24-27) — MetaMorpho Vault ────────────────

    function _packKpkEthPrimeBlock() internal view returns (bytes memory) {
        bytes memory a = _packScopeTarget(kpkETHPrime);
        return abi.encodePacked(a, _packVaultDWR(kpkETHPrime, false));
    }

    // ─── kpkETHv2 Block (TX 28-31) — Fluid Vault
    // ───────────────────────

    function _packKpkEthV2Block() internal view returns (bytes memory) {
        bytes memory a = _packScopeTarget(kpkETHv2);
        return abi.encodePacked(a, _packVaultDWR(kpkETHv2, true));
    }

    // ─── kpkUSDCPrime Block (TX 32-35) — MetaMorpho Vault ───────────────

    function _packKpkUsdcPrimeBlock() internal view returns (bytes memory) {
        bytes memory a = _packScopeTarget(kpkUSDCPrime);
        return abi.encodePacked(a, _packVaultDWR(kpkUSDCPrime, false));
    }

    // ─── kpkUSDCv2 Block (TX 36-39) — Fluid Vault
    // ──────────────────────

    function _packKpkUsdcV2Block() internal view returns (bytes memory) {
        bytes memory a = _packScopeTarget(kpkUSDCv2);
        return abi.encodePacked(a, _packVaultDWR(kpkUSDCv2, true));
    }

    // ─── Reusable Pack Helpers
    // ────────────────────────────────────────────

    /// @dev Pack a scopeTarget call for the MANAGER role
    function _packScopeTarget(address target) internal pure returns (bytes memory) {
        return _packTx(
            address(ROLES_MOD), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, target)
        );
    }

    /// @dev Pack a scopeFunction call for the MANAGER role (approve with conditions)
    function _packScopeApprove(address target, ConditionFlat[] memory conditions) internal pure returns (bytes memory) {
        return _packTx(
            address(ROLES_MOD),
            abi.encodeWithSelector(
                IRolesModifier.scopeFunction.selector,
                MANAGER_ROLE,
                target,
                IERC20.approve.selector,
                conditions,
                EXEC_NONE
            )
        );
    }

    /// @dev Pack a scopeFunction call for the MANAGER role (arbitrary selector)
    function _packScopeFunction(
        address target,
        bytes4 sel,
        ConditionFlat[] memory conditions
    )
        internal
        pure
        returns (bytes memory)
    {
        return _packTx(
            address(ROLES_MOD),
            abi.encodeWithSelector(
                IRolesModifier.scopeFunction.selector, MANAGER_ROLE, target, sel, conditions, EXEC_NONE
            )
        );
    }

    /// @dev Pack deposit + withdraw + redeem scopeFunction calls for a vault target.
    ///      If isFluid is true, uses IFluidVaultV2 selectors; otherwise uses IMetaMorphoV1 selectors.
    function _packVaultDWR(address vault, bool isFluid) internal pure returns (bytes memory) {
        bytes4 depositSel = isFluid ? IFluidVaultV2.deposit.selector : IMetaMorphoV1.deposit.selector;
        bytes4 withdrawSel = isFluid ? IFluidVaultV2.withdraw.selector : IMetaMorphoV1.withdraw.selector;
        bytes4 redeemSel = isFluid ? IFluidVaultV2.redeem.selector : IMetaMorphoV1.redeem.selector;

        bytes memory a = _packScopeFunction(vault, depositSel, _depositConditions());
        bytes memory b = _packScopeFunction(vault, withdrawSel, _withdrawConditions());
        bytes memory d = _packScopeFunction(vault, redeemSel, _redeemConditions());
        return abi.encodePacked(a, b, d);
    }

    // ─── Annotation (TX 40)
    // ─────────────────────────────────────────────

    function _packAnnotation() internal pure returns (bytes memory) {
        // TX 40: post annotation to AnnotationRegistry
        string memory annotationJson = '{"rolesMod":"0x703806e61847984346d2d7ddd853049627e50a40",'
            '"roleKey":"0x4d414e4147455200000000000000000000000000000000000000000000000000",'
            '"addAnnotations":[{"schema":"https://kit.karpatkey.com/api/v1/openapi.json",' '"uris":['
            '"https://kit.karpatkey.com/api/v1/permissions/eth/fluid/deposit?targets=GHO",'
            '"https://kit.karpatkey.com/api/v1/permissions/eth/fluid/deposit?targets=USDC",'
            '"https://kit.karpatkey.com/api/v1/permissions/eth/fluid/deposit?targets=USDT",'
            '"https://kit.karpatkey.com/api/v1/permissions/eth/morphoMarkets/deposit?targets=0x64d65c9a2d91c36d56fbc42d69e979335320169b3df63bf92789e2c8883fcc64",'
            '"https://kit.karpatkey.com/api/v1/permissions/eth/morphoMarkets/deposit?targets=0xb8fc70e82bc5bb53e773626fcc6a23f7eefa036918d7ef216ecfb1950a94a85e",'
            '"https://kit.karpatkey.com/api/v1/permissions/eth/morphoMarkets/deposit?targets=0xd0e50cdac92fe2172043f5e0c36532c6369d24947e40968f34a5e8819ca9ec5d",'
            '"https://kit.karpatkey.com/api/v1/permissions/eth/morphoMarkets/deposit?targets=0x3a85e619751152991742810df6ec69ce473daef99e28a64ab2340d7b7ccfee49",'
            '"https://kit.karpatkey.com/api/v1/permissions/eth/morphoMarkets/deposit?targets=0xb323495f7e4148be5643a4ea4a8221eef163e4bccfdedc2a6f4696baacbc86cc",'
            '"https://kit.karpatkey.com/api/v1/permissions/eth/morphoVaults/deposit?targets=0xd564F765F9aD3E7d2d6cA782100795a885e8e7C8",'
            '"https://kit.karpatkey.com/api/v1/permissions/eth/morphoVaults/deposit?targets=0xBb50A5341368751024ddf33385BA8cf61fE65FF9",'
            '"https://kit.karpatkey.com/api/v1/permissions/eth/morphoVaults/deposit?targets=0xe108fbc04852B5df72f9E44d7C29F47e7A993aDd",'
            '"https://kit.karpatkey.com/api/v1/permissions/eth/morphoVaults/deposit?targets=0x4Ef53d2cAa51C447fdFEEedee8F07FD1962C9ee6"'
            "]}]}";
        string memory tag = "ROLES_PERMISSION_ANNOTATION";

        return _packTx(
            address(ANNOTATION_REGISTRY), abi.encodeWithSelector(IAnnotationRegistry.post.selector, annotationJson, tag)
        );
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Condition Builders
    // ═══════════════════════════════════════════════════════════════════════

    /// @dev Helper to create a padded address compValue for conditions
    function _addrComp(address addr) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes32(uint256(uint160(addr))));
    }

    /// @dev Compact condition constructor to save stack space
    function _c(
        uint8 parent,
        uint8 paramType,
        uint8 operator,
        bytes memory compValue
    )
        internal
        pure
        returns (ConditionFlat memory)
    {
        return ConditionFlat({ parent: parent, paramType: paramType, operator: operator, compValue: compValue });
    }

    /// @dev Shortcut for a STATIC EQUAL_TO condition with an address compValue
    function _eq(uint8 parent, address addr) internal pure returns (ConditionFlat memory) {
        return _c(parent, PARAM_TYPE_STATIC, OP_EQUAL_TO, _addrComp(addr));
    }

    // ─── approve() Conditions
    // ───────────────────────────────────────────

    /// @dev WETH.approve conditions: spender must be one of 13 whitelisted addresses (OR)
    function _wethApproveConditions() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](15);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, PERMIT2);
        c[3] = _eq(1, SPARK_LEND_V3);
        c[4] = _eq(1, ONE_INCH_V6);
        c[5] = _eq(1, UNISWAP_V3_ROUTER);
        c[6] = _eq(1, AAVE_V3_POOL);
        c[7] = _eq(1, AURA_REWARDS);
        c[8] = _eq(1, BALANCER_VAULT);
        c[9] = _eq(1, kpkETHv2);
        c[10] = _eq(1, address(MORPHO_BLUE));
        c[11] = _eq(1, EULER_V2);
        c[12] = _eq(1, COWSWAP_RELAYER);
        c[13] = _eq(1, CC7D_ADDR);
        c[14] = _eq(1, kpkETHPrime);
    }

    /// @dev USDC.approve conditions: spender must be one of 14 whitelisted addresses (OR)
    function _usdcApproveConditions() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](16);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, kpkUSDCv2);
        c[3] = _eq(1, ONE_INCH_V6);
        c[4] = _eq(1, UNISWAP_V3_ROUTER);
        c[5] = _eq(1, AAVE_V3_POOL);
        c[6] = _eq(1, FluidUSDC);
        c[7] = _eq(1, A188_ADDR);
        c[8] = _eq(1, BALANCER_VAULT);
        c[9] = _eq(1, address(MORPHO_BLUE));
        c[10] = _eq(1, CURVE_3POOL);
        c[11] = _eq(1, EULER_V2);
        c[12] = _eq(1, COMPOUND_USDC);
        c[13] = _eq(1, COWSWAP_RELAYER);
        c[14] = _eq(1, D0A6_ADDR);
        c[15] = _eq(1, kpkUSDCPrime);
    }

    /// @dev USDT.approve conditions: spender must be one of 9 whitelisted addresses (OR)
    function _usdtApproveConditions() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](11);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, AAVE_USDT);
        c[3] = _eq(1, ONE_INCH_V6);
        c[4] = _eq(1, FluidUSDT);
        c[5] = _eq(1, UNISWAP_V3_ROUTER);
        c[6] = _eq(1, AAVE_V3_POOL);
        c[7] = _eq(1, BALANCER_VAULT);
        c[8] = _eq(1, CURVE_3POOL);
        c[9] = _eq(1, EULER_V2);
        c[10] = _eq(1, COWSWAP_RELAYER);
    }

    // ─── Morpho Blue Conditions
    // ─────────────────────────────────────────

    /// @dev Morpho Blue supply conditions — 5 allowed market tuples, onBehalf = avatar, empty callback data
    function _morphoSupplyConditions() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](36);
        _setMorphoSupplyRootConditions(c);
        _setMorphoTupleHeaders(c);
        _setMorphoMarketTuples(c);
    }

    /// @dev Morpho Blue withdraw conditions — same 5 markets, receiver + onBehalf = avatar
    function _morphoWithdrawConditions() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](36);
        _setMorphoWithdrawRootConditions(c);
        _setMorphoTupleHeaders(c);
        _setMorphoMarketTuples(c);
    }

    function _setMorphoSupplyRootConditions(ConditionFlat[] memory c) internal pure {
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _c(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[3] = _c(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[4] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[5] = _c(0, PARAM_TYPE_DYNAMIC, OP_EQUAL_TO, abi.encodePacked(bytes32(uint256(0x20)), bytes32(uint256(0))));
    }

    function _setMorphoWithdrawRootConditions(ConditionFlat[] memory c) internal pure {
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _c(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[3] = _c(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[4] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[5] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
    }

    function _setMorphoTupleHeaders(ConditionFlat[] memory c) internal pure {
        c[6] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[7] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[8] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[9] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[10] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
    }

    function _setMorphoMarketTuples(ConditionFlat[] memory c) internal view {
        _setMorphoMarket1(c);
        _setMorphoMarket2(c);
        _setMorphoMarket3(c);
        _setMorphoMarket4(c);
        _setMorphoMarket5(c);
    }

    function _setMorphoMarket1(ConditionFlat[] memory c) internal view {
        // Market 1: USDC / WBTC
        _setMarketTupleConditions(
            c,
            6,
            11,
            USDC,
            0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599,
            0xDddd770BADd886dF3864029e4B377B5F6a2B6b83,
            0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC,
            0x0bef55718ad60000
        );
    }

    function _setMorphoMarket2(ConditionFlat[] memory c) internal view {
        // Market 2: USDC / wstETH
        _setMarketTupleConditions(
            c,
            7,
            16,
            USDC,
            0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0,
            0x48F7E36EB6B826B2dF4B2E630B62Cd25e89E40e2,
            0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC,
            0x0bef55718ad60000
        );
    }

    function _setMorphoMarket3(ConditionFlat[] memory c) internal view {
        // Market 3: USDC / cbBTC
        _setMarketTupleConditions(
            c,
            8,
            21,
            USDC,
            0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf,
            0xA6D6950c9F177F1De7f7757FB33539e3Ec60182a,
            0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC,
            0x0bef55718ad60000
        );
    }

    function _setMorphoMarket4(ConditionFlat[] memory c) internal view {
        // Market 4: WETH / wstETH
        _setMarketTupleConditions(
            c,
            9,
            26,
            WETH,
            0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0,
            0xbD60A6770b27E084E8617335ddE769241B0e71D8,
            0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC,
            0x0d1d507e40be8000
        );
    }

    function _setMorphoMarket5(ConditionFlat[] memory c) internal view {
        // Market 5: WETH / wstETH (different lltv)
        _setMarketTupleConditions(
            c,
            10,
            31,
            WETH,
            0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0,
            0xbD60A6770b27E084E8617335ddE769241B0e71D8,
            0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC,
            0x0d645e6320408000
        );
    }

    /// @dev Set 5 conditions for a single Morpho market tuple at the given indices
    function _setMarketTupleConditions(
        ConditionFlat[] memory c,
        uint8 parent,
        uint256 startIdx,
        address loanToken,
        address collateralToken,
        address oracle,
        address irm,
        uint256 lltv
    )
        internal
        pure
    {
        c[startIdx] = _eq(parent, loanToken);
        c[startIdx + 1] = _eq(parent, collateralToken);
        c[startIdx + 2] = _eq(parent, oracle);
        c[startIdx + 3] = _eq(parent, irm);
        c[startIdx + 4] = _c(parent, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encodePacked(bytes32(lltv)));
    }

    // ─── Vault Conditions (deposit / withdraw / redeem) ─────────────────

    /// @dev deposit(uint256 amount, address receiver): amount PASS, receiver EQUAL_TO_AVATAR
    function _depositConditions() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](3);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[2] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
    }

    /// @dev withdraw(uint256 amount, address receiver, address owner): amount PASS, receiver + owner EQUAL_TO_AVATAR
    function _withdrawConditions() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](4);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[2] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[3] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
    }

    /// @dev redeem(uint256 shares, address receiver, address owner): shares PASS, receiver + owner EQUAL_TO_AVATAR
    function _redeemConditions() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](4);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[2] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[3] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
    }

    /// @dev Approve conditions for a single spender: spender EQUAL_TO the given address
    function _singleSpenderApproveConditions(address spender) internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _eq(0, spender);
    }

    /// @dev FluidMerklDistributor.claim conditions: recipient EQUAL_TO_AVATAR
    function _fluidMerklClaimConditions() internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
    }

    // ═══════════════════════════════════════════════════════════════════════

    function _isProposalSubmitted() public view override returns (bool) {
        return true;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-6-27";
    }
}
