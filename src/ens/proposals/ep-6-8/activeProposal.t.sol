// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";
import { console2 } from "@forge-std/src/console2.sol";

import { IToken } from "@ens/interfaces/IToken.sol";
import { IGovernor } from "@ens/interfaces/IGovernor.sol";
import { ITimelock } from "@ens/interfaces/ITimelock.sol";
import { ISafe } from "@ens/interfaces/ISafe.sol";
import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";

import { ENS_Governance } from "@ens/ens.t.sol";
import { IZodiacRoles } from "@ens/interfaces/IZodiacRoles.sol";
import { IRolesModifier, ConditionFlat } from "@ens/interfaces/IRolesModifier.sol";
import { IMultiSend } from "@ens/interfaces/IMultiSend.sol";
import { IAnnotationRegistry } from "@ens/interfaces/IAnnotationRegistry.sol";
import { SafeHelper } from "@ens/helpers/SafeHelper.sol";
import { ZodiacRolesHelper } from "@ens/helpers/ZodiacRolesHelper.sol";

interface AaveV3 {
    function depositETH(address pool, address onBehalfOf, uint16 referralCode) external payable;
    function withdrawETH(address pool, uint256 amount, address onBehalfOf) external;
    function claimRewards(address[] memory assets, uint256 amount, address to, address rewardAddress) external;
    function supply(address, uint256, address, uint16) external;
    function withdraw(address, uint256, address) external;
    function setUserUseReserveAsCollateral(address, bool) external;
}

interface IAsset {
    // solhint-disable-previous-line no-empty-blocks
}

interface Balancer {
    enum SwapKind {
        GIVEN_IN,
        GIVEN_OUT
    }

    struct SingleSwap {
        bytes32 poolId;
        SwapKind kind;
        IAsset assetIn;
        IAsset assetOut;
        uint256 amount;
        bytes userData;
    }

    struct FundManagement {
        address sender;
        bool fromInternalBalance;
        address payable recipient;
        bool toInternalBalance;
    }

    function gaugeWithdraw(address gauge, address token, address to, uint256 amount) external;
    function gaugeClaimRewards(address[] memory gauges) external;
    function gaugeMint(address[] memory gauges, uint256 amount) external;
    function setRelayerApproval(address sender, address relayer, bool approved) external;
    function swap(SingleSwap memory, FundManagement memory, uint256 limit, uint256 deadline) external;
    function scopeFunction(address, bool) external;
    function setMinterApproval(address, bool) external;
}

interface Uniswap {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams memory) external;
}

interface Curve {
    function add_liquidity(uint256[2] memory amounts, uint256 min_mint_amount) external;
    function remove_liquidity(uint256, uint256[2] memory amounts) external;
    function remove_liquidity_one_coin(uint256 _token_amount, int128 i, uint256 min_amount) external;
    function exchange(int128, int128, uint256, uint256) external;
    function claim_rewards() external;
    function set_approve_deposit(address, bool) external;
    function remove_liquidity_imbalance(uint256[] memory, uint256) external;
    function approve(address, uint256) external;
    function mint(address) external;
    function deposit_and_stake(
        address,
        address,
        address,
        uint256,
        address[] memory,
        uint256[] memory,
        uint256,
        bool,
        bool,
        address
    )
        external;
}

interface Sky {
    function deposit(uint256, address) external;
    function withdraw(uint256, address, address) external;
    function redeem(uint256, address, address) external;
    function migrateDAIToUSDS(address, uint256) external;
    function migrateDAIToSUSDS(address, uint256) external;
    function downgradeUSDSToDAI(address, uint256) external;
    function stake(uint256, uint16) external;
    function withdraw(uint256) external;
    function exit() external;
    function getReward() external;
    function supply(address, uint256) external;
}

interface Convex {
    function stake(uint256) external;
    function withdraw(uint256, bool) external;
    function withdrawAndUnwrap(uint256, bool) external;
    function getReward(address, bool) external;
    function deposit(uint256 pid, uint256 amount, bool stake) external;
    function depositAll(uint256, bool) external;
}

interface Spark {
    function claimAllRewards(address[] memory, address) external;
}

interface CowSwap {
    struct Data {
        IERC20 sellToken;
        IERC20 buyToken;
        address receiver;
        uint256 sellAmount;
        uint256 buyAmount;
        uint32 validTo;
        bytes32 appData;
        uint256 feeAmount;
        bytes32 kind;
        bool partiallyFillable;
        bytes32 sellTokenBalance;
        bytes32 buyTokenBalance;
    }

    function signOrder(Data memory, uint32, uint256) external;
}

interface IOETH {
    function swapExactTokensForTokens(address, address, uint256, uint256, address) external;
    function claimWithdrawals(uint256[] calldata _requestIds) external;
}

interface Origin {
    function requestWithdrawal(uint256) external;
    function claimWithdrawal(uint256) external;
}

contract Proposal_ENS_EP_6_8_Test is ENS_Governance, SafeHelper, ZodiacRolesHelper {
    address safe = 0x4F2083f5fBede34C2714aFfb3105539775f7FE64;
    address AAVE = 0x893411580e590D62dDBca8a703d61Cc4A8c7b2b9;
    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address AaveLendingPool = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address CurvePool = 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7;
    address BalancerVault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address UniswapV3 = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
    address BaseRewardPool = 0x24b65DC1cf053A8D96872c323d29e86ec43eB33A;
    address CowOrderSigner = 0x23dA9AdE38E4477b23770DeD512fD37b12381FAB;
    address OETH = 0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3;
    address osETH = 0xf1C9acDc66974dFB6dEcB12aA385b9cD01190E38;

    // ─── MultiSend + Annotation
    // ────────────────────────────────────────
    IMultiSend private constant PROPOSAL_MULTI_SEND = IMultiSend(0x9641d764fc13c8B624c04430C7356C1C7C8102e2);
    address private constant ANNOTATION_REGISTRY = 0x000000000000cd17345801aa8147b8D3950260FF;

    // ─── Zodiac Roles Modifier
    // ──────────────────────────────────────────
    IRolesModifier private constant ROLES_MOD = IRolesModifier(0x703806E61847984346d2D7DDd853049627e50A40);

    // ─── Protocol Targets
    // ───────────────────────────────────────────────
    address private constant AAVE_REWARDS_CONTROLLER = 0x8164Cc65827dcFe994AB23944CBC90e0aa80bFcb;
    address private constant AAVE_WETH_GATEWAY_V2 = 0xA434D495249abE33E031Fe71a969B81f3c07950D;
    address private constant SKY_USDS_ACTIONS = 0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f;
    address private constant CURVE_3POOL_LP = 0x94B17476A93b3262d87B9a326965D1E91f9c13E7;
    address private constant CURVE_STETH_LP = 0xc2591073629AcD455f2fEc56A398B677F2Ccb80c;
    address private constant LIDO_WSTETH = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    address private constant OSETH_TOKEN = 0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C;
    address private constant SKY_FARM = 0xf86141a5657Cf52AEB3E30eBccA5Ad3a8f714B89;
    address private constant SKY_REWARDS = 0x0650CAF159C5A49f711e8169D4336ECB9b950275;
    address private constant AAVE_USDT_SUPPLY = 0x3Afdc9BCA9213A35503b077a6072F3D0d5AB0840;
    address private constant SKY_VAULT_1 = 0xd03BE91b1932715709e18021734fcB91BB431715;
    address private constant SKY_VAULT_2 = 0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A;
    address private constant SDAI = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
    address private constant CURVE_GAUGE = 0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802;
    address private constant SKY_VAULT_3 = 0xcF5136C67fA8A375BaBbDf13c0307EF994b5681D;
    address private constant WETH_CONTRACT = 0x9858e47BCbBe6fBAC040519B02d7cd4B2C470C66;
    address private constant BALANCER_GAUGE = 0x6bac785889A4127dB0e0CeFEE88E0a9F1Aaf3cC7;
    address private constant BALANCER_MINTER_V1 = 0x39254033945AA2E4809Cc2977E7087BEE48bd7Ab;
    address private constant AAVE_WETH_TOKEN = 0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8;
    address private constant BALANCER_MINTER_V2 = 0x239e55F427D44C3cc793f49bFB507ebe76638a2b;
    address private constant CONVEX_BOOSTER = 0xF403C135812408BFbE8713b5A23a04b3D48AAE31;
    address private constant ORIGIN_VAULT = 0x4370D3b6C9588E02ce9D22e684387859c7Ff5b34;
    address private constant CURVE_MINTER = 0xd061D61a4d941c39E5453435B6345Dc261C2fcE0;
    address private constant ONE_INCH = 0x56C526b0159a258887e0d79ec3a80dfb940d0cD7;

    // ─── Token / Protocol Addresses (used in conditions) ────────────────
    address private constant COWSWAP_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;
    address private constant COWSWAP_VAULT_RELAYER = 0x5C0F23A5c1be65Fa710d385814a7Fd1Bda480b1C;
    address private constant LIDO_WITHDRAWAL = 0x79eF6103A513951a3b25743DB509E267685726B7;
    address private constant COWSWAP_SETTLEMENT = 0xc592c33e51A764B94DB0702D8BAf4035eD577aED;
    address private constant BAL_GAUGE_HELPER = 0x373238337Bfe1146fb49989fc222523f83081dDb;
    address private constant COMPOUND_USDC = 0xc3d688B66703497DAA19211EEdff47f25384cdc3;
    address private constant BAL_TOKEN = 0xba100000625a3754423978a60c9317c58a424e3D;
    address private constant AURA_TOKEN = 0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF;
    address private constant COMP_TOKEN = 0xc00e94Cb662C3520282E6f5717214004A7f26888;
    address private constant RETH = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address private constant ETHx = 0xA35b1B31Ce002FBF2058D22F30f95D405200A15b;
    address private constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address private constant ANKR_ETH = 0xE95A203B1a91a908F9B9CE46459d101078c2c3cb;
    address private constant CRV3CRYPTO = 0x48C3399719B582dD63eB5AADf12A40B4C3f52FA2;
    address private constant CVX_TOKEN = 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B;
    address private constant LDO_TOKEN = 0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32;
    address private constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address private constant RPL_TOKEN = 0xD33526068D116cE69F19A9ee46F0bd304F21A51f;
    address private constant CRV_TOKEN = 0xD533a949740bb3306d119CC777fa900bA034cd52;
    address private constant BALANCER_OSETH_POOL = 0x182B723a58739a9c974cFDB385ceaDb237453c28;
    address private constant AURA_OSETH_REWARDS = 0x79F21BC30632cd40d2aF8134B469a0EB4C9574AA;
    address private constant STETH_ETH_CURVE = 0x21E27a5E5513D6e65C4f830167390997aA84843a;
    address private constant CURVE_STETH_POOL = 0xDC24316b9AE028F1497c275EB9192a3Ea0f67022;
    address private constant CURVE_STETH_TOKEN = 0x06325440D014e39736583c165C2963BA99fAf14E;
    address private constant CURVE_3CRV = 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490;

    function _beforeProposal() public override {
        vm.startPrank(karpatkey);

        uint256[] memory amounts = new uint256[](2);
        address[] memory arg = new address[](1);

        // 0
        {
            _safeExecuteTransaction(
                AAVE, abi.encodeWithSelector(AaveV3.depositETH.selector, AaveLendingPool, safe, 1 ether)
            );
        }
        // 1
        {
            _safeExecuteTransaction(
                AAVE, abi.encodeWithSelector(AaveV3.withdrawETH.selector, AaveLendingPool, 1 ether, safe)
            );
        }
        // 2
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0x8164Cc65827dcFe994AB23944CBC90e0aa80bFcb,
                abi.encodeWithSelector(AaveV3.claimRewards.selector, new address[](0), 1 ether, safe, address(0))
            );
        }
        // 3
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0xA434D495249abE33E031Fe71a969B81f3c07950D,
                abi.encodeWithSelector(AaveV3.depositETH.selector, AaveLendingPool, safe, 1 ether)
            );
        }
        // 4
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0xA434D495249abE33E031Fe71a969B81f3c07950D,
                abi.encodeWithSelector(AaveV3.withdrawETH.selector, AaveLendingPool, 1 ether, safe)
            );
        }
        // 5
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(USDS, abi.encodeWithSelector(IERC20.approve.selector, USDS, 1 ether));
        }
        // 6
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                USDS,
                abi.encodeWithSelector(
                    Balancer.gaugeWithdraw.selector,
                    0x5C0F23A5c1be65Fa710d385814a7Fd1Bda480b1C,
                    0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE,
                    safe,
                    0
                )
            );
        }
        // 7
        {
            arg[0] = 0x5C0F23A5c1be65Fa710d385814a7Fd1Bda480b1C;
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f,
                abi.encodeWithSelector(Balancer.gaugeClaimRewards.selector, arg)
            );
            arg[0] = 0x79eF6103A513951a3b25743DB509E267685726B7;
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f,
                abi.encodeWithSelector(Balancer.gaugeClaimRewards.selector, arg)
            );
            arg[0] = 0xc592c33e51A764B94DB0702D8BAf4035eD577aED;
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f,
                abi.encodeWithSelector(Balancer.gaugeClaimRewards.selector, arg)
            );
        }
        // 8
        {
            arg[0] = 0x5C0F23A5c1be65Fa710d385814a7Fd1Bda480b1C;
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f,
                abi.encodeWithSelector(Balancer.gaugeMint.selector, arg, 1 ether)
            );
            arg[0] = 0x79eF6103A513951a3b25743DB509E267685726B7;
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f,
                abi.encodeWithSelector(Balancer.gaugeMint.selector, arg, 1 ether)
            );
            arg[0] = 0xc592c33e51A764B94DB0702D8BAf4035eD577aED;
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f,
                abi.encodeWithSelector(Balancer.gaugeMint.selector, arg, 1 ether)
            );
        }
        // 9
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0x94B17476A93b3262d87B9a326965D1E91f9c13E7,
                abi.encodeWithSelector(IERC20.approve.selector, 0xd03BE91b1932715709e18021734fcB91BB431715, 1 ether)
            );
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0x94B17476A93b3262d87B9a326965D1E91f9c13E7,
                abi.encodeWithSelector(IERC20.approve.selector, 0xF403C135812408BFbE8713b5A23a04b3D48AAE31, 1 ether)
            );
        }

        // 10
        {
            amounts[0] = 1 ether;
            amounts[1] = 1 ether;
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0x94B17476A93b3262d87B9a326965D1E91f9c13E7,
                abi.encodeWithSelector(Curve.add_liquidity.selector, amounts, 1 ether)
            );
        }
        // 11
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0x94B17476A93b3262d87B9a326965D1E91f9c13E7,
                abi.encodeWithSelector(Curve.remove_liquidity.selector, 1 ether, amounts)
            );
        }
        // 12
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0x94B17476A93b3262d87B9a326965D1E91f9c13E7,
                abi.encodeWithSelector(Curve.remove_liquidity_one_coin.selector, 1 ether, 0, 1 ether)
            );
        }
        // 13
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0x94B17476A93b3262d87B9a326965D1E91f9c13E7,
                abi.encodeWithSelector(Curve.exchange.selector, 0, 1, 1 ether, 1 ether)
            );
        }
        // 14
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0xc2591073629AcD455f2fEc56A398B677F2Ccb80c,
                abi.encodeWithSelector(IERC20.approve.selector, BaseRewardPool, 1 ether)
            );
        }
        // 15
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(BaseRewardPool, abi.encodeWithSelector(Convex.stake.selector, 1 ether));
        }
        // 16
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(BaseRewardPool, abi.encodeWithSelector(Convex.withdraw.selector, 1 ether, false));
        }
        // 17
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                BaseRewardPool, abi.encodeWithSelector(Convex.withdrawAndUnwrap.selector, 1 ether, false)
            );
        }
        // 18
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(BaseRewardPool, abi.encodeWithSelector(Convex.getReward.selector, safe, false));
        }
        // 19
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                OETH,
                abi.encodeWithSelector(IERC20.approve.selector, 0x56C526b0159a258887e0d79ec3a80dfb940d0cD7, 1 ether)
            );
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                OETH,
                abi.encodeWithSelector(IERC20.approve.selector, 0x6bac785889A4127dB0e0CeFEE88E0a9F1Aaf3cC7, 1 ether)
            );
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                OETH,
                abi.encodeWithSelector(IERC20.approve.selector, 0x94B17476A93b3262d87B9a326965D1E91f9c13E7, 1 ether)
            );
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(OETH, abi.encodeWithSelector(IERC20.approve.selector, BalancerVault, 1 ether));
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                OETH,
                abi.encodeWithSelector(IERC20.approve.selector, 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110, 1 ether)
            );
        }
        // 20
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD,
                abi.encodeWithSelector(IERC20.approve.selector, 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110, 1 ether)
            );
        }
        // 21
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD, abi.encodeWithSelector(Sky.deposit.selector, 1 ether, safe)
            );
        }
        // 22
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD,
                abi.encodeWithSelector(bytes4(keccak256("withdraw(uint256,address,address)")), 1 ether, safe, safe)
            );
        }
        // 23
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD,
                abi.encodeWithSelector(Sky.redeem.selector, 1 ether, safe, safe)
            );
        }
        // 24
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C,
                abi.encodeWithSelector(IERC20.approve.selector, 0x56C526b0159a258887e0d79ec3a80dfb940d0cD7, 1 ether)
            );
        }
        // 25
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0xf86141a5657Cf52AEB3E30eBccA5Ad3a8f714B89,
                abi.encodeWithSelector(Sky.migrateDAIToUSDS.selector, safe, 1 ether)
            );
        }
        // 26
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0xf86141a5657Cf52AEB3E30eBccA5Ad3a8f714B89,
                abi.encodeWithSelector(Sky.migrateDAIToSUSDS.selector, safe, 1 ether)
            );
        }
        // 27
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0xf86141a5657Cf52AEB3E30eBccA5Ad3a8f714B89,
                abi.encodeWithSelector(Sky.downgradeUSDSToDAI.selector, safe, 1 ether)
            );
        }
        // 28
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0x0650CAF159C5A49f711e8169D4336ECB9b950275, abi.encodeWithSelector(Sky.stake.selector, 10, 1 ether)
            );
        }
        // 29
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0x0650CAF159C5A49f711e8169D4336ECB9b950275,
                abi.encodeWithSelector(bytes4(keccak256("withdraw(uint256)")), 1 ether)
            );
        }
        // 30
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0x0650CAF159C5A49f711e8169D4336ECB9b950275, abi.encodeWithSelector(Sky.exit.selector)
            );
        }
        // 31
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0x0650CAF159C5A49f711e8169D4336ECB9b950275, abi.encodeWithSelector(Sky.getReward.selector)
            );
        }
        // 32
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0x3Afdc9BCA9213A35503b077a6072F3D0d5AB0840, abi.encodeWithSelector(Sky.supply.selector, USDT, 1 ether)
            );
        }
        // 33
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0x3Afdc9BCA9213A35503b077a6072F3D0d5AB0840,
                abi.encodeWithSelector(bytes4(keccak256("withdraw(address,uint256)")), USDT, 1 ether)
            );
        }
        // 34
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0xd03BE91b1932715709e18021734fcB91BB431715,
                abi.encodeWithSelector(bytes4(keccak256("deposit(uint256)")), 1 ether)
            );
        }
        // 35
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0xd03BE91b1932715709e18021734fcB91BB431715,
                abi.encodeWithSelector(bytes4(keccak256("withdraw(uint256)")), 1 ether)
            );
        }
        // 36
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0xd03BE91b1932715709e18021734fcB91BB431715, abi.encodeWithSelector(Curve.claim_rewards.selector)
            );
        }
        // 37
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A,
                abi.encodeWithSelector(bytes4(keccak256("deposit(uint256)")), 1 ether)
            );
        }
        // 38
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A,
                abi.encodeWithSelector(bytes4(keccak256("withdraw(uint256)")), 1 ether)
            );
        }
        // 39
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A,
                abi.encodeWithSelector(
                    Curve.set_approve_deposit.selector, 0x56C526b0159a258887e0d79ec3a80dfb940d0cD7, true
                )
            );
        }
        // 40
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0x83F20F44975D03b1b09e64809B757c47f942BEeA,
                abi.encodeWithSelector(IERC20.approve.selector, 0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802, 1 ether)
            );
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0x83F20F44975D03b1b09e64809B757c47f942BEeA,
                abi.encodeWithSelector(IERC20.approve.selector, 0x56C526b0159a258887e0d79ec3a80dfb940d0cD7, 1 ether)
            );
        }
        // 41
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802,
                abi.encodeWithSelector(bytes4(keccak256("add_liquidity(uint256[],uint256)")), amounts, 1 ether)
            );
        }
        // 42
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802,
                abi.encodeWithSelector(bytes4(keccak256("remove_liquidity(uint256,uint256[])")), 1 ether, amounts)
            );
        }
        // 43
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802,
                abi.encodeWithSelector(Curve.remove_liquidity_imbalance.selector, amounts, 1 ether)
            );
        }
        // 44
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802,
                abi.encodeWithSelector(Curve.remove_liquidity_one_coin.selector, 1 ether, 0, 1 ether)
            );
        }
        // 45
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802,
                abi.encodeWithSelector(Curve.approve.selector, 0xcF5136C67fA8A375BaBbDf13c0307EF994b5681D, 1 ether)
            );
        }
        // 46
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802,
                abi.encodeWithSelector(Curve.exchange.selector, 0, 1, 1 ether, 0)
            );
        }
        // 47
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0xcF5136C67fA8A375BaBbDf13c0307EF994b5681D,
                abi.encodeWithSelector(bytes4(keccak256("deposit(uint256)")), 1 ether)
            );
        }
        // 48
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0xcF5136C67fA8A375BaBbDf13c0307EF994b5681D,
                abi.encodeWithSelector(bytes4(keccak256("withdraw(uint256)")), 1 ether)
            );
        }
        // 49
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0xcF5136C67fA8A375BaBbDf13c0307EF994b5681D, abi.encodeWithSelector(Curve.claim_rewards.selector)
            );
        }
        // 50
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0x9858e47BCbBe6fBAC040519B02d7cd4B2C470C66, abi.encodeWithSelector(bytes4(keccak256("deposit()")))
            );
        }
        // 51
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0x6bac785889A4127dB0e0CeFEE88E0a9F1Aaf3cC7,
                abi.encodeWithSelector(IOETH.swapExactTokensForTokens.selector, OETH, WETH, 1 ether, 0, safe)
            );
        }
        // 52
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0x39254033945AA2E4809Cc2977E7087BEE48bd7Ab,
                abi.encodeWithSelector(Origin.requestWithdrawal.selector, 1 ether)
            );
        }
        // 53
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0x39254033945AA2E4809Cc2977E7087BEE48bd7Ab,
                abi.encodeWithSelector(Origin.claimWithdrawal.selector, 1 ether)
            );
        }
        // 54
        {
            _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
            _safeExecuteTransaction(
                0x39254033945AA2E4809Cc2977E7087BEE48bd7Ab,
                abi.encodeWithSelector(IOETH.claimWithdrawals.selector, amounts)
            );
        }
        // 55
        {
            _safeExecuteTransaction(
                DAI,
                abi.encodeWithSelector(IERC20.approve.selector, 0x373238337Bfe1146fb49989fc222523f83081dDb, 1 ether)
            );
        }
        // 56
        {
            _expectConditionViolation(IZodiacRoles.Status.OrViolation);
            _safeExecuteTransaction(
                DAI,
                abi.encodeWithSelector(IERC20.approve.selector, 0x56C526b0159a258887e0d79ec3a80dfb940d0cD7, 1 ether)
            );
            _safeExecuteTransaction(DAI, abi.encodeWithSelector(IERC20.approve.selector, UniswapV3, 1 ether));
            _safeExecuteTransaction(DAI, abi.encodeWithSelector(IERC20.approve.selector, AaveLendingPool, 1 ether));
            _safeExecuteTransaction(DAI, abi.encodeWithSelector(IERC20.approve.selector, CurvePool, 1 ether));
            _safeExecuteTransaction(
                DAI,
                abi.encodeWithSelector(IERC20.approve.selector, 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110, 1 ether)
            );
            _expectConditionViolation(IZodiacRoles.Status.OrViolation);
            _safeExecuteTransaction(
                DAI,
                abi.encodeWithSelector(IERC20.approve.selector, 0xf86141a5657Cf52AEB3E30eBccA5Ad3a8f714B89, 1 ether)
            );
        }
        // 57
        {
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.supply.selector, DAI, 1 ether, safe, 0)
            );
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.supply.selector, USDC, 1 ether, safe, 0)
            );
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.supply.selector, WETH, 1 ether, safe, 0)
            );
            _expectConditionViolation(IZodiacRoles.Status.OrViolation);
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.supply.selector, USDT, 1 ether, safe, 0)
            );
            _expectConditionViolation(IZodiacRoles.Status.OrViolation);
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.supply.selector, USDS, 1 ether, safe, 0)
            );
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.supply.selector, osETH, 1 ether, safe, 0)
            );
        }
        // 58
        {
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.withdraw.selector, DAI, 1 ether, safe)
            );
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.withdraw.selector, USDC, 1 ether, safe)
            );
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.withdraw.selector, WETH, 1 ether, safe)
            );
            _expectConditionViolation(IZodiacRoles.Status.OrViolation);
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.withdraw.selector, USDT, 1 ether, safe)
            );
            _expectConditionViolation(IZodiacRoles.Status.OrViolation);
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.withdraw.selector, USDS, 1 ether, safe)
            );
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.withdraw.selector, osETH, 1 ether, safe)
            );
        }
        // 59
        {
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.setUserUseReserveAsCollateral.selector, DAI, true)
            );
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.setUserUseReserveAsCollateral.selector, USDC, true)
            );
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.setUserUseReserveAsCollateral.selector, WETH, true)
            );
            _expectConditionViolation(IZodiacRoles.Status.OrViolation);
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.setUserUseReserveAsCollateral.selector, USDT, true)
            );
            _expectConditionViolation(IZodiacRoles.Status.OrViolation);
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.setUserUseReserveAsCollateral.selector, USDS, true)
            );
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.setUserUseReserveAsCollateral.selector, osETH, true)
            );
        }
        // 60
        {
            _expectConditionViolation(IZodiacRoles.Status.ParameterNotAllowed);
            _safeExecuteTransaction(
                0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8,
                abi.encodeWithSelector(IERC20.approve.selector, 0xA434D495249abE33E031Fe71a969B81f3c07950D, 1 ether)
            );
        }
        // 61
        {
            _expectConditionViolation(IZodiacRoles.Status.OrViolation);
            _safeExecuteTransaction(
                USDC,
                abi.encodeWithSelector(IERC20.approve.selector, 0x56C526b0159a258887e0d79ec3a80dfb940d0cD7, 1 ether)
            );
            _safeExecuteTransaction(USDC, abi.encodeWithSelector(IERC20.approve.selector, UniswapV3, 1 ether));
            _safeExecuteTransaction(USDC, abi.encodeWithSelector(IERC20.approve.selector, AaveLendingPool, 1 ether));
            _expectConditionViolation(IZodiacRoles.Status.OrViolation);
            _safeExecuteTransaction(USDC, abi.encodeWithSelector(IERC20.approve.selector, BalancerVault, 1 ether));
            _safeExecuteTransaction(USDC, abi.encodeWithSelector(IERC20.approve.selector, CurvePool, 1 ether));
            _safeExecuteTransaction(
                USDC,
                abi.encodeWithSelector(IERC20.approve.selector, 0xc3d688B66703497DAA19211EEdff47f25384cdc3, 1 ether)
            );
            _safeExecuteTransaction(
                USDC,
                abi.encodeWithSelector(IERC20.approve.selector, 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110, 1 ether)
            );
        }
        // 62
        {
            _expectConditionViolation(IZodiacRoles.Status.OrViolation);
            _safeExecuteTransaction(
                USDT,
                abi.encodeWithSelector(IERC20.approve.selector, 0x3Afdc9BCA9213A35503b077a6072F3D0d5AB0840, 1 ether)
            );
            _expectConditionViolation(IZodiacRoles.Status.OrViolation);
            _safeExecuteTransaction(
                USDT,
                abi.encodeWithSelector(IERC20.approve.selector, 0x56C526b0159a258887e0d79ec3a80dfb940d0cD7, 1 ether)
            );
            _safeExecuteTransaction(USDT, abi.encodeWithSelector(IERC20.approve.selector, UniswapV3, 1 ether));
            _expectConditionViolation(IZodiacRoles.Status.OrViolation);
            _safeExecuteTransaction(USDT, abi.encodeWithSelector(IERC20.approve.selector, AaveLendingPool, 1 ether));
            _expectConditionViolation(IZodiacRoles.Status.OrViolation);
            _safeExecuteTransaction(USDT, abi.encodeWithSelector(IERC20.approve.selector, BalancerVault, 1 ether));
            _safeExecuteTransaction(USDT, abi.encodeWithSelector(IERC20.approve.selector, CurvePool, 1 ether));
            _safeExecuteTransaction(
                USDT,
                abi.encodeWithSelector(IERC20.approve.selector, 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110, 1 ether)
            );
        }
        // 63
        {
            vm.expectRevert(
                abi.encodeWithSelector(
                    IZodiacRoles.ConditionViolation.selector,
                    IZodiacRoles.Status.FunctionNotAllowed,
                    Balancer.setRelayerApproval.selector
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.setRelayerApproval.selector, safe, 0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f, true
                )
            );
        }
        // 64
        {
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0x0b09dea16768f0799065c475be02919503cb2a3500020000000000000000001a,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(WETH),
                        assetOut: IAsset(DAI),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0x5c6ee304399dbdb9c8ef030ab642b10820db8f56000200000000000000000014,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(0xba100000625a3754423978a60c9317c58a424e3D),
                        assetOut: IAsset(WETH),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0x96646936b91d6b9d7d0c47c496afbf3d6ec7b6f8000200000000000000000019,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(WETH),
                        assetOut: IAsset(USDC),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0xcfca23ca9ca720b6e98e3eb9b6aa0ffc4a5c08b9000200000000000000000274,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF),
                        assetOut: IAsset(WETH),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0xefaa1604e82e1b3af8430b90192c1b9e8197e377000200000000000000000021,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(0xc00e94Cb662C3520282E6f5717214004A7f26888),
                        assetOut: IAsset(WETH),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0x1e19cf2d73a72ef1332c882f20534b6519be0276000200000000000000000112,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        assetOut: IAsset(WETH),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0x1e19cf2d73a72ef1332c882f20534b6519be0276000200000000000000000112,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(WETH),
                        assetOut: IAsset(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0x37b18b10ce5635a84834b26095a0ae5639dcb7520000000000000000000005cb,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(0xA35b1B31Ce002FBF2058D22F30f95D405200A15b),
                        assetOut: IAsset(WETH),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0x37b18b10ce5635a84834b26095a0ae5639dcb7520000000000000000000005cb,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(WETH),
                        assetOut: IAsset(0xA35b1B31Ce002FBF2058D22F30f95D405200A15b),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _expectConditionViolation(IZodiacRoles.Status.OrViolation);
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0x7056c8dfa8182859ed0d4fb0ef0886fdf3d2edcf000200000000000000000623,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(OETH),
                        assetOut: IAsset(WETH),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _expectConditionViolation(IZodiacRoles.Status.OrViolation);
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0x7056c8dfa8182859ed0d4fb0ef0886fdf3d2edcf000200000000000000000623,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(WETH),
                        assetOut: IAsset(OETH),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _expectConditionViolation(IZodiacRoles.Status.OrViolation);
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0x8353157092ed8be69a9df8f95af097bbf33cb2af0000000000000000000005d9,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(USDC),
                        assetOut: IAsset(USDT),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _expectConditionViolation(IZodiacRoles.Status.OrViolation);
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0x8353157092ed8be69a9df8f95af097bbf33cb2af0000000000000000000005d9,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(USDT),
                        assetOut: IAsset(USDC),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0x93d199263632a4ef4bb438f1feb99e57b4b5f0bd0000000000000000000005c2,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        assetOut: IAsset(WETH),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0x93d199263632a4ef4bb438f1feb99e57b4b5f0bd0000000000000000000005c2,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(WETH),
                        assetOut: IAsset(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0xdacf5fa19b1f720111609043ac67a9818262850c000000000000000000000635,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(WETH),
                        assetOut: IAsset(osETH),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0xdacf5fa19b1f720111609043ac67a9818262850c000000000000000000000635,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(osETH),
                        assetOut: IAsset(WETH),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0xdfe6e7e18f6cc65fa13c8d8966013d4fda74b6ba000000000000000000000558,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        assetOut: IAsset(0xE95A203B1a91a908F9B9CE46459d101078c2c3cb),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0xdfe6e7e18f6cc65fa13c8d8966013d4fda74b6ba000000000000000000000558,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(0xE95A203B1a91a908F9B9CE46459d101078c2c3cb),
                        assetOut: IAsset(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0xf01b0684c98cd7ada480bfdf6e43876422fa1fc10002000000000000000005de,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        assetOut: IAsset(WETH),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0xf01b0684c98cd7ada480bfdf6e43876422fa1fc10002000000000000000005de,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(WETH),
                        assetOut: IAsset(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
        }
        // 65
        {
            vm.expectRevert(
                abi.encodeWithSelector(
                    IZodiacRoles.ConditionViolation.selector,
                    IZodiacRoles.Status.FunctionNotAllowed,
                    Balancer.setMinterApproval.selector
                )
            );
            _safeExecuteTransaction(
                0x239e55F427D44C3cc793f49bFB507ebe76638a2b,
                abi.encodeWithSelector(
                    Balancer.setMinterApproval.selector, 0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f, true
                )
            );
        }
        //66
        {
            _safeExecuteTransaction(
                0xF403C135812408BFbE8713b5A23a04b3D48AAE31,
                abi.encodeWithSelector(Convex.deposit.selector, 25, 1 ether, true)
            );
            _expectConditionViolation(IZodiacRoles.Status.OrViolation);
            _safeExecuteTransaction(
                0xF403C135812408BFbE8713b5A23a04b3D48AAE31,
                abi.encodeWithSelector(Convex.deposit.selector, 174, 1 ether, true)
            );
            _safeExecuteTransaction(
                0xF403C135812408BFbE8713b5A23a04b3D48AAE31,
                abi.encodeWithSelector(Convex.deposit.selector, 177, 1 ether, true)
            );
        }
        // 67
        {
            _safeExecuteTransaction(
                0xF403C135812408BFbE8713b5A23a04b3D48AAE31, abi.encodeWithSelector(Convex.depositAll.selector, 25, true)
            );
            _expectConditionViolation(IZodiacRoles.Status.OrViolation);
            _safeExecuteTransaction(
                0xF403C135812408BFbE8713b5A23a04b3D48AAE31,
                abi.encodeWithSelector(Convex.depositAll.selector, 174, true)
            );
            _safeExecuteTransaction(
                0xF403C135812408BFbE8713b5A23a04b3D48AAE31,
                abi.encodeWithSelector(Convex.depositAll.selector, 177, true)
            );
        }
        // 68
        {
            _safeExecuteTransaction(
                0xF403C135812408BFbE8713b5A23a04b3D48AAE31,
                abi.encodeWithSelector(bytes4(keccak256("withdraw(uint256,uint256)")), 25, 1 ether)
            );
            _expectConditionViolation(IZodiacRoles.Status.OrViolation);
            _safeExecuteTransaction(
                0xF403C135812408BFbE8713b5A23a04b3D48AAE31,
                abi.encodeWithSelector(bytes4(keccak256("withdraw(uint256,uint256)")), 174, 1 ether)
            );
            _safeExecuteTransaction(
                0xF403C135812408BFbE8713b5A23a04b3D48AAE31,
                abi.encodeWithSelector(bytes4(keccak256("withdraw(uint256,uint256)")), 177, 1 ether)
            );
        }

        vm.stopPrank();
    }

    function _afterExecution() public override {
        vm.startPrank(karpatkey);
        vm.pauseGasMetering();

        uint256[] memory amounts = new uint256[](2);
        address[] memory arg = new address[](1);

        // 0
        {
            vm.expectRevert(
                abi.encodeWithSelector(
                    IZodiacRoles.ConditionViolation.selector,
                    3,
                    0x474cf53d00000000000000000000000000000000000000000000000000000000
                )
            );
            _safeExecuteTransaction(
                AAVE, abi.encodeWithSelector(AaveV3.depositETH.selector, AaveLendingPool, safe, 1 ether)
            );
        }
        // 1
        {
            vm.expectRevert(
                abi.encodeWithSelector(
                    IZodiacRoles.ConditionViolation.selector,
                    3,
                    0x80500d2000000000000000000000000000000000000000000000000000000000
                )
            );
            _safeExecuteTransaction(
                AAVE, abi.encodeWithSelector(AaveV3.withdrawETH.selector, AaveLendingPool, 1 ether, safe)
            );
        }
        // 2
        {
            _safeExecuteTransaction(
                0x8164Cc65827dcFe994AB23944CBC90e0aa80bFcb,
                abi.encodeWithSelector(AaveV3.claimRewards.selector, new address[](0), 1 ether, safe, address(0))
            );
        }
        // 3
        {
            _safeExecuteTransaction(
                0xA434D495249abE33E031Fe71a969B81f3c07950D,
                abi.encodeWithSelector(AaveV3.depositETH.selector, AaveLendingPool, safe, 1 ether)
            );
        }
        // 4
        {
            _safeExecuteTransaction(
                0xA434D495249abE33E031Fe71a969B81f3c07950D,
                abi.encodeWithSelector(AaveV3.withdrawETH.selector, AaveLendingPool, 1 ether, safe)
            );
        }
        // 5
        {
            _safeExecuteTransaction(
                USDS,
                abi.encodeWithSelector(IERC20.approve.selector, 0x0650CAF159C5A49f711e8169D4336ECB9b950275, 1 ether)
            );
            _safeExecuteTransaction(USDS, abi.encodeWithSelector(IERC20.approve.selector, AaveLendingPool, 1 ether));
            _safeExecuteTransaction(
                USDS,
                abi.encodeWithSelector(IERC20.approve.selector, 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD, 1 ether)
            );
            _safeExecuteTransaction(
                USDS,
                abi.encodeWithSelector(IERC20.approve.selector, 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110, 1 ether)
            );
            _safeExecuteTransaction(
                USDS,
                abi.encodeWithSelector(IERC20.approve.selector, 0xf86141a5657Cf52AEB3E30eBccA5Ad3a8f714B89, 1 ether)
            );
        }
        // 6
        {
            _safeExecuteTransaction(
                0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f,
                abi.encodeWithSelector(
                    Balancer.gaugeWithdraw.selector, 0x5C0F23A5c1be65Fa710d385814a7Fd1Bda480b1C, safe, safe, 1 ether
                )
            );
            _safeExecuteTransaction(
                0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f,
                abi.encodeWithSelector(
                    Balancer.gaugeWithdraw.selector, 0x79eF6103A513951a3b25743DB509E267685726B7, safe, safe, 1 ether
                )
            );
            _safeExecuteTransaction(
                0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f,
                abi.encodeWithSelector(
                    Balancer.gaugeWithdraw.selector, 0xc592c33e51A764B94DB0702D8BAf4035eD577aED, safe, safe, 1 ether
                )
            );
        }
        // 7
        {
            arg[0] = 0x5C0F23A5c1be65Fa710d385814a7Fd1Bda480b1C;
            _safeExecuteTransaction(
                0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f,
                abi.encodeWithSelector(Balancer.gaugeClaimRewards.selector, arg)
            );
            arg[0] = 0x79eF6103A513951a3b25743DB509E267685726B7;
            _safeExecuteTransaction(
                0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f,
                abi.encodeWithSelector(Balancer.gaugeClaimRewards.selector, arg)
            );
            arg[0] = 0xc592c33e51A764B94DB0702D8BAf4035eD577aED;
            _safeExecuteTransaction(
                0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f,
                abi.encodeWithSelector(Balancer.gaugeClaimRewards.selector, arg)
            );
        }
        // 8
        {
            arg[0] = 0x5C0F23A5c1be65Fa710d385814a7Fd1Bda480b1C;
            _safeExecuteTransaction(
                0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f,
                abi.encodeWithSelector(Balancer.gaugeMint.selector, arg, 1 ether)
            );
            arg[0] = 0x79eF6103A513951a3b25743DB509E267685726B7;
            _safeExecuteTransaction(
                0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f,
                abi.encodeWithSelector(Balancer.gaugeMint.selector, arg, 1 ether)
            );
            arg[0] = 0xc592c33e51A764B94DB0702D8BAf4035eD577aED;
            _safeExecuteTransaction(
                0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f,
                abi.encodeWithSelector(Balancer.gaugeMint.selector, arg, 1 ether)
            );
        }
        // 9
        {
            _safeExecuteTransaction(
                0x94B17476A93b3262d87B9a326965D1E91f9c13E7,
                abi.encodeWithSelector(IERC20.approve.selector, 0xd03BE91b1932715709e18021734fcB91BB431715, 1 ether)
            );
            _safeExecuteTransaction(
                0x94B17476A93b3262d87B9a326965D1E91f9c13E7,
                abi.encodeWithSelector(IERC20.approve.selector, 0xF403C135812408BFbE8713b5A23a04b3D48AAE31, 1 ether)
            );
        }

        // 10
        {
            amounts[0] = 1 ether;
            amounts[1] = 1 ether;
            _safeExecuteTransaction(
                0x94B17476A93b3262d87B9a326965D1E91f9c13E7,
                abi.encodeWithSelector(Curve.add_liquidity.selector, amounts, 1 ether)
            );
        }
        // 11
        {
            _safeExecuteTransaction(
                0x94B17476A93b3262d87B9a326965D1E91f9c13E7,
                abi.encodeWithSelector(Curve.remove_liquidity.selector, 1 ether, amounts)
            );
        }
        // 12
        {
            _safeExecuteTransaction(
                0x94B17476A93b3262d87B9a326965D1E91f9c13E7,
                abi.encodeWithSelector(Curve.remove_liquidity_one_coin.selector, 1 ether, 0, 1 ether)
            );

            //19
            _safeExecuteTransaction(
                0x94B17476A93b3262d87B9a326965D1E91f9c13E7,
                abi.encodeWithSelector(Curve.exchange.selector, 0, 1, 1 ether, 1 ether)
            );
        }
        // 13
        {
            _safeExecuteTransaction(
                0xc2591073629AcD455f2fEc56A398B677F2Ccb80c,
                abi.encodeWithSelector(IERC20.approve.selector, BaseRewardPool, 1 ether)
            );
        }
        // 14
        {
            _safeExecuteTransaction(BaseRewardPool, abi.encodeWithSelector(Convex.stake.selector, 1 ether));
        }
        // 15
        {
            _safeExecuteTransaction(BaseRewardPool, abi.encodeWithSelector(Convex.withdraw.selector, 1 ether, false));
        }
        // 16
        {
            _safeExecuteTransaction(
                BaseRewardPool, abi.encodeWithSelector(Convex.withdrawAndUnwrap.selector, 1 ether, false)
            );
        }
        // 17
        {
            _safeExecuteTransaction(BaseRewardPool, abi.encodeWithSelector(Convex.getReward.selector, safe, false));
        }
        // 18
        {
            _safeExecuteTransaction(
                OETH,
                abi.encodeWithSelector(IERC20.approve.selector, 0x56C526b0159a258887e0d79ec3a80dfb940d0cD7, 1 ether)
            );
            _safeExecuteTransaction(
                OETH,
                abi.encodeWithSelector(IERC20.approve.selector, 0x6bac785889A4127dB0e0CeFEE88E0a9F1Aaf3cC7, 1 ether)
            );
            _safeExecuteTransaction(
                OETH,
                abi.encodeWithSelector(IERC20.approve.selector, 0x94B17476A93b3262d87B9a326965D1E91f9c13E7, 1 ether)
            );
            _safeExecuteTransaction(OETH, abi.encodeWithSelector(IERC20.approve.selector, BalancerVault, 1 ether));
            _safeExecuteTransaction(
                OETH,
                abi.encodeWithSelector(IERC20.approve.selector, 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110, 1 ether)
            );
        }
        // 19
        {
            _safeExecuteTransaction(
                0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD,
                abi.encodeWithSelector(IERC20.approve.selector, 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110, 1 ether)
            );
        }
        // 20
        {
            _safeExecuteTransaction(
                0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD, abi.encodeWithSelector(Sky.deposit.selector, 1 ether, safe)
            );
        }
        // 21
        {
            _safeExecuteTransaction(
                0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD,
                abi.encodeWithSelector(bytes4(keccak256("withdraw(uint256,address,address)")), 1 ether, safe, safe)
            );
        }
        // 22
        {
            _safeExecuteTransaction(
                0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD,
                abi.encodeWithSelector(Sky.redeem.selector, 1 ether, safe, safe)
            );
        }
        // 23
        {
            _safeExecuteTransaction(
                0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C,
                abi.encodeWithSelector(IERC20.approve.selector, 0x56C526b0159a258887e0d79ec3a80dfb940d0cD7, 1 ether)
            );
        }
        // 24
        {
            _safeExecuteTransaction(
                0xf86141a5657Cf52AEB3E30eBccA5Ad3a8f714B89,
                abi.encodeWithSelector(Sky.migrateDAIToUSDS.selector, safe, 1 ether)
            );
        }
        // 25
        {
            _safeExecuteTransaction(
                0xf86141a5657Cf52AEB3E30eBccA5Ad3a8f714B89,
                abi.encodeWithSelector(Sky.migrateDAIToSUSDS.selector, safe, 1 ether)
            );
        }
        // 26
        {
            _safeExecuteTransaction(
                0xf86141a5657Cf52AEB3E30eBccA5Ad3a8f714B89,
                abi.encodeWithSelector(Sky.downgradeUSDSToDAI.selector, safe, 1 ether)
            );
        }
        // 27
        {
            _safeExecuteTransaction(
                0x0650CAF159C5A49f711e8169D4336ECB9b950275, abi.encodeWithSelector(Sky.stake.selector, 10, 1 ether)
            );
        }
        // 28
        {
            _safeExecuteTransaction(
                0x0650CAF159C5A49f711e8169D4336ECB9b950275,
                abi.encodeWithSelector(bytes4(keccak256("withdraw(uint256)")), 1 ether)
            );
        }
        // 29
        {
            _safeExecuteTransaction(
                0x0650CAF159C5A49f711e8169D4336ECB9b950275, abi.encodeWithSelector(Sky.exit.selector)
            );
        }
        // 30
        {
            _safeExecuteTransaction(
                0x0650CAF159C5A49f711e8169D4336ECB9b950275, abi.encodeWithSelector(Sky.getReward.selector)
            );
        }
        // 31
        {
            _safeExecuteTransaction(
                0x3Afdc9BCA9213A35503b077a6072F3D0d5AB0840, abi.encodeWithSelector(Sky.supply.selector, USDT, 1 ether)
            );
        }
        // 32
        {
            _safeExecuteTransaction(
                0x3Afdc9BCA9213A35503b077a6072F3D0d5AB0840,
                abi.encodeWithSelector(bytes4(keccak256("withdraw(address,uint256)")), USDT, 1 ether)
            );
        }
        // 33
        {
            _safeExecuteTransaction(
                0xd03BE91b1932715709e18021734fcB91BB431715,
                abi.encodeWithSelector(bytes4(keccak256("deposit(uint256)")), 1 ether)
            );
        }
        // 34
        {
            _safeExecuteTransaction(
                0xd03BE91b1932715709e18021734fcB91BB431715,
                abi.encodeWithSelector(bytes4(keccak256("withdraw(uint256)")), 1 ether)
            );
        }
        // 35
        {
            _safeExecuteTransaction(
                0xd03BE91b1932715709e18021734fcB91BB431715, abi.encodeWithSelector(Curve.claim_rewards.selector)
            );
        }
        // 36
        {
            _safeExecuteTransaction(
                0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A,
                abi.encodeWithSelector(bytes4(keccak256("deposit(uint256)")), 1 ether)
            );
        }
        // 37
        {
            _safeExecuteTransaction(
                0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A,
                abi.encodeWithSelector(bytes4(keccak256("withdraw(uint256)")), 1 ether)
            );
        }
        // 38
        {
            _safeExecuteTransaction(
                0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A,
                abi.encodeWithSelector(
                    Curve.set_approve_deposit.selector, 0x56C526b0159a258887e0d79ec3a80dfb940d0cD7, true
                )
            );
        }
        // 39
        {
            _safeExecuteTransaction(
                0x83F20F44975D03b1b09e64809B757c47f942BEeA,
                abi.encodeWithSelector(IERC20.approve.selector, 0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802, 1 ether)
            );
            _safeExecuteTransaction(
                0x83F20F44975D03b1b09e64809B757c47f942BEeA,
                abi.encodeWithSelector(IERC20.approve.selector, 0x56C526b0159a258887e0d79ec3a80dfb940d0cD7, 1 ether)
            );
        }
        // 40
        {
            _safeExecuteTransaction(
                0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802,
                abi.encodeWithSelector(bytes4(keccak256("add_liquidity(uint256[],uint256)")), amounts, 1 ether)
            );
        }
        // 41
        {
            _safeExecuteTransaction(
                0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802,
                abi.encodeWithSelector(bytes4(keccak256("remove_liquidity(uint256,uint256[])")), 1 ether, amounts)
            );
        }
        // 42
        {
            _safeExecuteTransaction(
                0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802,
                abi.encodeWithSelector(Curve.remove_liquidity_imbalance.selector, amounts, 1 ether)
            );
        }
        // 43
        {
            _safeExecuteTransaction(
                0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802,
                abi.encodeWithSelector(Curve.remove_liquidity_one_coin.selector, 1 ether, 0, 1 ether)
            );
        }
        // 44
        {
            _safeExecuteTransaction(
                0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802,
                abi.encodeWithSelector(Curve.approve.selector, 0xcF5136C67fA8A375BaBbDf13c0307EF994b5681D, 1 ether)
            );
        }
        // 45
        {
            _safeExecuteTransaction(
                0x425BfB93370F14fF525aDb6EaEAcfE1f4e3b5802,
                abi.encodeWithSelector(Curve.exchange.selector, 0, 1, 1 ether, 0)
            );
        }
        // 46
        {
            _safeExecuteTransaction(
                0xcF5136C67fA8A375BaBbDf13c0307EF994b5681D,
                abi.encodeWithSelector(bytes4(keccak256("deposit(uint256)")), 1 ether)
            );
        }
        // 47
        {
            _safeExecuteTransaction(
                0xcF5136C67fA8A375BaBbDf13c0307EF994b5681D,
                abi.encodeWithSelector(bytes4(keccak256("withdraw(uint256)")), 1 ether)
            );
        }
        // 48
        {
            _safeExecuteTransaction(
                0xcF5136C67fA8A375BaBbDf13c0307EF994b5681D, abi.encodeWithSelector(Curve.claim_rewards.selector)
            );
        }
        // 49
        {
            _safeExecuteTransaction(
                0x9858e47BCbBe6fBAC040519B02d7cd4B2C470C66, abi.encodeWithSelector(bytes4(keccak256("deposit()")))
            );
        }
        // 50
        {
            _safeExecuteTransaction(
                0x6bac785889A4127dB0e0CeFEE88E0a9F1Aaf3cC7,
                abi.encodeWithSelector(IOETH.swapExactTokensForTokens.selector, OETH, WETH, 1 ether, 0, safe)
            );
        }
        // 51
        {
            _safeExecuteTransaction(
                0x39254033945AA2E4809Cc2977E7087BEE48bd7Ab,
                abi.encodeWithSelector(Origin.requestWithdrawal.selector, 1 ether)
            );
        }
        // 52
        {
            _safeExecuteTransaction(
                0x39254033945AA2E4809Cc2977E7087BEE48bd7Ab,
                abi.encodeWithSelector(Origin.claimWithdrawal.selector, 1 ether)
            );
        }
        // 53
        {
            _safeExecuteTransaction(
                0x39254033945AA2E4809Cc2977E7087BEE48bd7Ab,
                abi.encodeWithSelector(IOETH.claimWithdrawals.selector, amounts)
            );
        }
        // 54
        {
            _safeExecuteTransaction(
                DAI, // 55
                abi.encodeWithSelector(IERC20.approve.selector, 0x373238337Bfe1146fb49989fc222523f83081dDb, 1 ether)
            );
            _safeExecuteTransaction(
                DAI,
                abi.encodeWithSelector(IERC20.approve.selector, 0x56C526b0159a258887e0d79ec3a80dfb940d0cD7, 1 ether)
            );
            _safeExecuteTransaction(DAI, abi.encodeWithSelector(IERC20.approve.selector, UniswapV3, 1 ether));
            _safeExecuteTransaction(DAI, abi.encodeWithSelector(IERC20.approve.selector, AaveLendingPool, 1 ether));
            _safeExecuteTransaction(DAI, abi.encodeWithSelector(IERC20.approve.selector, CurvePool, 1 ether));
            _safeExecuteTransaction(
                DAI,
                abi.encodeWithSelector(IERC20.approve.selector, 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110, 1 ether)
            );
            _safeExecuteTransaction(
                DAI,
                abi.encodeWithSelector(IERC20.approve.selector, 0xf86141a5657Cf52AEB3E30eBccA5Ad3a8f714B89, 1 ether)
            );
        }
        // 56
        {
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.supply.selector, DAI, 1 ether, safe, 0)
            );
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.supply.selector, USDC, 1 ether, safe, 0)
            );
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.supply.selector, WETH, 1 ether, safe, 0)
            );
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.supply.selector, USDT, 1 ether, safe, 0)
            );
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.supply.selector, USDS, 1 ether, safe, 0)
            );
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.supply.selector, osETH, 1 ether, safe, 0)
            );
        }
        // 57
        {
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.withdraw.selector, DAI, 1 ether, safe)
            );
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.withdraw.selector, USDC, 1 ether, safe)
            );
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.withdraw.selector, WETH, 1 ether, safe)
            );
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.withdraw.selector, USDT, 1 ether, safe)
            );
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.withdraw.selector, USDS, 1 ether, safe)
            );
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.withdraw.selector, osETH, 1 ether, safe)
            );
        }
        // 58
        {
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.setUserUseReserveAsCollateral.selector, DAI, true)
            );
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.setUserUseReserveAsCollateral.selector, USDC, true)
            );
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.setUserUseReserveAsCollateral.selector, WETH, true)
            );
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.setUserUseReserveAsCollateral.selector, USDT, true)
            );
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.setUserUseReserveAsCollateral.selector, USDS, true)
            );
            _safeExecuteTransaction(
                AaveLendingPool, abi.encodeWithSelector(AaveV3.setUserUseReserveAsCollateral.selector, osETH, true)
            );
        }
        // 59
        {
            _safeExecuteTransaction(
                0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8,
                abi.encodeWithSelector(IERC20.approve.selector, 0xA434D495249abE33E031Fe71a969B81f3c07950D, 1 ether)
            );
        }
        // 60
        {
            _safeExecuteTransaction(
                USDC,
                abi.encodeWithSelector(IERC20.approve.selector, 0x56C526b0159a258887e0d79ec3a80dfb940d0cD7, 1 ether)
            );
            _safeExecuteTransaction(USDC, abi.encodeWithSelector(IERC20.approve.selector, UniswapV3, 1 ether));
            _safeExecuteTransaction(USDC, abi.encodeWithSelector(IERC20.approve.selector, AaveLendingPool, 1 ether));
            _safeExecuteTransaction(USDC, abi.encodeWithSelector(IERC20.approve.selector, BalancerVault, 1 ether));
            _safeExecuteTransaction(USDC, abi.encodeWithSelector(IERC20.approve.selector, CurvePool, 1 ether));
            _safeExecuteTransaction(
                USDC,
                abi.encodeWithSelector(IERC20.approve.selector, 0xc3d688B66703497DAA19211EEdff47f25384cdc3, 1 ether)
            );
            _safeExecuteTransaction(
                USDC,
                abi.encodeWithSelector(IERC20.approve.selector, 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110, 1 ether)
            );
        }
        // 61
        {
            _safeExecuteTransaction(
                USDT,
                abi.encodeWithSelector(IERC20.approve.selector, 0x3Afdc9BCA9213A35503b077a6072F3D0d5AB0840, 1 ether)
            );
            _safeExecuteTransaction(
                USDT,
                abi.encodeWithSelector(IERC20.approve.selector, 0x56C526b0159a258887e0d79ec3a80dfb940d0cD7, 1 ether)
            );
            _safeExecuteTransaction(USDT, abi.encodeWithSelector(IERC20.approve.selector, UniswapV3, 1 ether));
            _safeExecuteTransaction(USDT, abi.encodeWithSelector(IERC20.approve.selector, AaveLendingPool, 1 ether));
            _safeExecuteTransaction(USDT, abi.encodeWithSelector(IERC20.approve.selector, BalancerVault, 1 ether));
            _safeExecuteTransaction(USDT, abi.encodeWithSelector(IERC20.approve.selector, CurvePool, 1 ether));
            _safeExecuteTransaction(
                USDT,
                abi.encodeWithSelector(IERC20.approve.selector, 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110, 1 ether)
            );
        }
        // 63
        {
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.setRelayerApproval.selector, safe, 0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f, true
                )
            );
        }
        // 64
        {
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0x0b09dea16768f0799065c475be02919503cb2a3500020000000000000000001a,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(WETH),
                        assetOut: IAsset(DAI),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0x5c6ee304399dbdb9c8ef030ab642b10820db8f56000200000000000000000014,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(0xba100000625a3754423978a60c9317c58a424e3D),
                        assetOut: IAsset(WETH),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0x96646936b91d6b9d7d0c47c496afbf3d6ec7b6f8000200000000000000000019,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(WETH),
                        assetOut: IAsset(USDC),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0xcfca23ca9ca720b6e98e3eb9b6aa0ffc4a5c08b9000200000000000000000274,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF),
                        assetOut: IAsset(WETH),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0xefaa1604e82e1b3af8430b90192c1b9e8197e377000200000000000000000021,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(0xc00e94Cb662C3520282E6f5717214004A7f26888),
                        assetOut: IAsset(WETH),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0x1e19cf2d73a72ef1332c882f20534b6519be0276000200000000000000000112,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        assetOut: IAsset(WETH),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0x1e19cf2d73a72ef1332c882f20534b6519be0276000200000000000000000112,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(WETH),
                        assetOut: IAsset(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0x37b18b10ce5635a84834b26095a0ae5639dcb7520000000000000000000005cb,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(0xA35b1B31Ce002FBF2058D22F30f95D405200A15b),
                        assetOut: IAsset(WETH),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0x37b18b10ce5635a84834b26095a0ae5639dcb7520000000000000000000005cb,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(WETH),
                        assetOut: IAsset(0xA35b1B31Ce002FBF2058D22F30f95D405200A15b),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0x7056c8dfa8182859ed0d4fb0ef0886fdf3d2edcf000200000000000000000623,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(OETH),
                        assetOut: IAsset(WETH),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0x7056c8dfa8182859ed0d4fb0ef0886fdf3d2edcf000200000000000000000623,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(WETH),
                        assetOut: IAsset(OETH),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0x8353157092ed8be69a9df8f95af097bbf33cb2af0000000000000000000005d9,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(USDC),
                        assetOut: IAsset(USDT),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0x8353157092ed8be69a9df8f95af097bbf33cb2af0000000000000000000005d9,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(USDT),
                        assetOut: IAsset(USDC),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0x93d199263632a4ef4bb438f1feb99e57b4b5f0bd0000000000000000000005c2,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        assetOut: IAsset(WETH),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0x93d199263632a4ef4bb438f1feb99e57b4b5f0bd0000000000000000000005c2,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(WETH),
                        assetOut: IAsset(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0xdacf5fa19b1f720111609043ac67a9818262850c000000000000000000000635,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(WETH),
                        assetOut: IAsset(osETH),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0xdacf5fa19b1f720111609043ac67a9818262850c000000000000000000000635,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(osETH),
                        assetOut: IAsset(WETH),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0xdfe6e7e18f6cc65fa13c8d8966013d4fda74b6ba000000000000000000000558,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        assetOut: IAsset(0xE95A203B1a91a908F9B9CE46459d101078c2c3cb),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0xdfe6e7e18f6cc65fa13c8d8966013d4fda74b6ba000000000000000000000558,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(0xE95A203B1a91a908F9B9CE46459d101078c2c3cb),
                        assetOut: IAsset(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0xf01b0684c98cd7ada480bfdf6e43876422fa1fc10002000000000000000005de,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        assetOut: IAsset(WETH),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
            _safeExecuteTransaction(
                BalancerVault,
                abi.encodeWithSelector(
                    Balancer.swap.selector,
                    Balancer.SingleSwap({
                        poolId: 0xf01b0684c98cd7ada480bfdf6e43876422fa1fc10002000000000000000005de,
                        kind: Balancer.SwapKind.GIVEN_IN,
                        assetIn: IAsset(WETH),
                        assetOut: IAsset(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        amount: 1 ether,
                        userData: bytes("")
                    }),
                    Balancer.FundManagement({
                        sender: safe, fromInternalBalance: false, recipient: payable(safe), toInternalBalance: false
                    }),
                    1 ether,
                    1 ether
                )
            );
        }
        // 65
        {
            _safeExecuteTransaction(
                0x239e55F427D44C3cc793f49bFB507ebe76638a2b,
                abi.encodeWithSelector(
                    Balancer.setMinterApproval.selector, 0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f, true
                )
            );
        }
        // 66
        {
            _safeExecuteTransaction(
                0xF403C135812408BFbE8713b5A23a04b3D48AAE31,
                abi.encodeWithSelector(Convex.deposit.selector, 25, 1 ether, true)
            );
            _safeExecuteTransaction(
                0xF403C135812408BFbE8713b5A23a04b3D48AAE31,
                abi.encodeWithSelector(Convex.deposit.selector, 174, 1 ether, true)
            );
            _safeExecuteTransaction(
                0xF403C135812408BFbE8713b5A23a04b3D48AAE31,
                abi.encodeWithSelector(Convex.deposit.selector, 177, 1 ether, true)
            );
            _expectConditionViolation(IZodiacRoles.Status.OrViolation);
            _safeExecuteTransaction(
                0xF403C135812408BFbE8713b5A23a04b3D48AAE31,
                abi.encodeWithSelector(Convex.deposit.selector, 190, 1 ether, true)
            );
        }
        // 67
        {
            _safeExecuteTransaction(
                0xF403C135812408BFbE8713b5A23a04b3D48AAE31, abi.encodeWithSelector(Convex.depositAll.selector, 25, true)
            );
            _safeExecuteTransaction(
                0xF403C135812408BFbE8713b5A23a04b3D48AAE31,
                abi.encodeWithSelector(Convex.depositAll.selector, 174, true)
            );
            _safeExecuteTransaction(
                0xF403C135812408BFbE8713b5A23a04b3D48AAE31,
                abi.encodeWithSelector(Convex.depositAll.selector, 177, true)
            );
            _expectConditionViolation(IZodiacRoles.Status.OrViolation);
            _safeExecuteTransaction(
                0xF403C135812408BFbE8713b5A23a04b3D48AAE31,
                abi.encodeWithSelector(Convex.depositAll.selector, 190, true)
            );
        }
        // 68
        {
            _safeExecuteTransaction(
                0xF403C135812408BFbE8713b5A23a04b3D48AAE31,
                abi.encodeWithSelector(bytes4(keccak256("withdraw(uint256,uint256)")), 25, true)
            );
            _safeExecuteTransaction(
                0xF403C135812408BFbE8713b5A23a04b3D48AAE31,
                abi.encodeWithSelector(bytes4(keccak256("withdraw(uint256,uint256)")), 174, true)
            );
            _safeExecuteTransaction(
                0xF403C135812408BFbE8713b5A23a04b3D48AAE31,
                abi.encodeWithSelector(bytes4(keccak256("withdraw(uint256,uint256)")), 177, true)
            );
        }
        // 69
        {
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B),
                        buyToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B),
                        buyToken: IERC20(OETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B),
                        buyToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B),
                        buyToken: IERC20(USDS),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32),
                        buyToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32),
                        buyToken: IERC20(OETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32),
                        buyToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32),
                        buyToken: IERC20(USDS),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(DAI),
                        buyToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(DAI),
                        buyToken: IERC20(OETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(DAI),
                        buyToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(DAI),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(DAI),
                        buyToken: IERC20(USDS),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        buyToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        buyToken: IERC20(OETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        buyToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        buyToken: IERC20(USDS),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDC),
                        buyToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDC),
                        buyToken: IERC20(OETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDC),
                        buyToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDC),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDC),
                        buyToken: IERC20(USDS),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xA35b1B31Ce002FBF2058D22F30f95D405200A15b),
                        buyToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xA35b1B31Ce002FBF2058D22F30f95D405200A15b),
                        buyToken: IERC20(OETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xA35b1B31Ce002FBF2058D22F30f95D405200A15b),
                        buyToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xA35b1B31Ce002FBF2058D22F30f95D405200A15b),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xA35b1B31Ce002FBF2058D22F30f95D405200A15b),
                        buyToken: IERC20(USDS),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        buyToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        buyToken: IERC20(OETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        buyToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        buyToken: IERC20(USDS),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        buyToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        buyToken: IERC20(OETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        buyToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        buyToken: IERC20(USDS),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xba100000625a3754423978a60c9317c58a424e3D),
                        buyToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xba100000625a3754423978a60c9317c58a424e3D),
                        buyToken: IERC20(OETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xba100000625a3754423978a60c9317c58a424e3D),
                        buyToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xba100000625a3754423978a60c9317c58a424e3D),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xba100000625a3754423978a60c9317c58a424e3D),
                        buyToken: IERC20(USDS),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888),
                        buyToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888),
                        buyToken: IERC20(OETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888),
                        buyToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888),
                        buyToken: IERC20(USDS),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(WETH),
                        buyToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(WETH),
                        buyToken: IERC20(OETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(WETH),
                        buyToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(WETH),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(WETH),
                        buyToken: IERC20(USDS),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF),
                        buyToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF),
                        buyToken: IERC20(OETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF),
                        buyToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF),
                        buyToken: IERC20(USDS),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xD33526068D116cE69F19A9ee46F0bd304F21A51f),
                        buyToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xD33526068D116cE69F19A9ee46F0bd304F21A51f),
                        buyToken: IERC20(OETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xD33526068D116cE69F19A9ee46F0bd304F21A51f),
                        buyToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xD33526068D116cE69F19A9ee46F0bd304F21A51f),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xD33526068D116cE69F19A9ee46F0bd304F21A51f),
                        buyToken: IERC20(USDS),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52),
                        buyToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52),
                        buyToken: IERC20(OETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52),
                        buyToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52),
                        buyToken: IERC20(USDS),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDT),
                        buyToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDT),
                        buyToken: IERC20(OETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDT),
                        buyToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDT),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDT),
                        buyToken: IERC20(USDS),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xE95A203B1a91a908F9B9CE46459d101078c2c3cb),
                        buyToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xE95A203B1a91a908F9B9CE46459d101078c2c3cb),
                        buyToken: IERC20(OETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xE95A203B1a91a908F9B9CE46459d101078c2c3cb),
                        buyToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xE95A203B1a91a908F9B9CE46459d101078c2c3cb),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xE95A203B1a91a908F9B9CE46459d101078c2c3cb),
                        buyToken: IERC20(USDS),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(osETH),
                        buyToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(osETH),
                        buyToken: IERC20(OETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(osETH),
                        buyToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(osETH),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(osETH),
                        buyToken: IERC20(USDS),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(osETH),
                        buyToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(osETH),
                        buyToken: IERC20(OETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(osETH),
                        buyToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(osETH),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(osETH),
                        buyToken: IERC20(USDS),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
        }
        {
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        buyToken: IERC20(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(OETH),
                        buyToken: IERC20(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        buyToken: IERC20(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDT),
                        buyToken: IERC20(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDS),
                        buyToken: IERC20(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        buyToken: IERC20(0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(OETH),
                        buyToken: IERC20(0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        buyToken: IERC20(0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDT),
                        buyToken: IERC20(0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDS),
                        buyToken: IERC20(0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        buyToken: IERC20(DAI),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(OETH),
                        buyToken: IERC20(DAI),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        buyToken: IERC20(DAI),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDT),
                        buyToken: IERC20(DAI),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDS),
                        buyToken: IERC20(DAI),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        buyToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(OETH),
                        buyToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        buyToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDT),
                        buyToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDS),
                        buyToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        buyToken: IERC20(USDC),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(OETH),
                        buyToken: IERC20(USDC),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        buyToken: IERC20(USDC),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDT),
                        buyToken: IERC20(USDC),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDS),
                        buyToken: IERC20(USDC),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        buyToken: IERC20(0xA35b1B31Ce002FBF2058D22F30f95D405200A15b),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(OETH),
                        buyToken: IERC20(0xA35b1B31Ce002FBF2058D22F30f95D405200A15b),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        buyToken: IERC20(0xA35b1B31Ce002FBF2058D22F30f95D405200A15b),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDT),
                        buyToken: IERC20(0xA35b1B31Ce002FBF2058D22F30f95D405200A15b),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDS),
                        buyToken: IERC20(0xA35b1B31Ce002FBF2058D22F30f95D405200A15b),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        buyToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(OETH),
                        buyToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        buyToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDT),
                        buyToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDS),
                        buyToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        buyToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(OETH),
                        buyToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        buyToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDT),
                        buyToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDS),
                        buyToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        buyToken: IERC20(0xba100000625a3754423978a60c9317c58a424e3D),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(OETH),
                        buyToken: IERC20(0xba100000625a3754423978a60c9317c58a424e3D),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        buyToken: IERC20(0xba100000625a3754423978a60c9317c58a424e3D),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDT),
                        buyToken: IERC20(0xba100000625a3754423978a60c9317c58a424e3D),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDS),
                        buyToken: IERC20(0xba100000625a3754423978a60c9317c58a424e3D),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        buyToken: IERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(OETH),
                        buyToken: IERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        buyToken: IERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDT),
                        buyToken: IERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDS),
                        buyToken: IERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        buyToken: IERC20(WETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(OETH),
                        buyToken: IERC20(WETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        buyToken: IERC20(WETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDT),
                        buyToken: IERC20(WETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDS),
                        buyToken: IERC20(WETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        buyToken: IERC20(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(OETH),
                        buyToken: IERC20(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        buyToken: IERC20(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDT),
                        buyToken: IERC20(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDS),
                        buyToken: IERC20(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        buyToken: IERC20(0xD33526068D116cE69F19A9ee46F0bd304F21A51f),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(OETH),
                        buyToken: IERC20(0xD33526068D116cE69F19A9ee46F0bd304F21A51f),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        buyToken: IERC20(0xD33526068D116cE69F19A9ee46F0bd304F21A51f),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDT),
                        buyToken: IERC20(0xD33526068D116cE69F19A9ee46F0bd304F21A51f),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDS),
                        buyToken: IERC20(0xD33526068D116cE69F19A9ee46F0bd304F21A51f),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        buyToken: IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(OETH),
                        buyToken: IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        buyToken: IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDT),
                        buyToken: IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDS),
                        buyToken: IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(OETH),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDT),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDS),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        buyToken: IERC20(0xE95A203B1a91a908F9B9CE46459d101078c2c3cb),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(OETH),
                        buyToken: IERC20(0xE95A203B1a91a908F9B9CE46459d101078c2c3cb),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        buyToken: IERC20(0xE95A203B1a91a908F9B9CE46459d101078c2c3cb),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDT),
                        buyToken: IERC20(0xE95A203B1a91a908F9B9CE46459d101078c2c3cb),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDS),
                        buyToken: IERC20(0xE95A203B1a91a908F9B9CE46459d101078c2c3cb),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        buyToken: IERC20(osETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(OETH),
                        buyToken: IERC20(osETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        buyToken: IERC20(osETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDT),
                        buyToken: IERC20(osETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDS),
                        buyToken: IERC20(osETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C),
                        buyToken: IERC20(osETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(OETH),
                        buyToken: IERC20(osETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD),
                        buyToken: IERC20(osETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDT),
                        buyToken: IERC20(osETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDS),
                        buyToken: IERC20(osETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
        }
        {
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x48C3399719B582dD63eB5AADf12A40B4C3f52FA2),
                        buyToken: IERC20(DAI),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x48C3399719B582dD63eB5AADf12A40B4C3f52FA2),
                        buyToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x48C3399719B582dD63eB5AADf12A40B4C3f52FA2),
                        buyToken: IERC20(USDC),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x48C3399719B582dD63eB5AADf12A40B4C3f52FA2),
                        buyToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x48C3399719B582dD63eB5AADf12A40B4C3f52FA2),
                        buyToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x48C3399719B582dD63eB5AADf12A40B4C3f52FA2),
                        buyToken: IERC20(WETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x48C3399719B582dD63eB5AADf12A40B4C3f52FA2),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );

            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B),
                        buyToken: IERC20(DAI),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B),
                        buyToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B),
                        buyToken: IERC20(USDC),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B),
                        buyToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B),
                        buyToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B),
                        buyToken: IERC20(WETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );

            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32),
                        buyToken: IERC20(DAI),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32),
                        buyToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32),
                        buyToken: IERC20(USDC),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32),
                        buyToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32),
                        buyToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32),
                        buyToken: IERC20(WETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );

            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(DAI),
                        buyToken: IERC20(DAI),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(DAI),
                        buyToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(DAI),
                        buyToken: IERC20(USDC),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(DAI),
                        buyToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(DAI),
                        buyToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(DAI),
                        buyToken: IERC20(WETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(DAI),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );

            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        buyToken: IERC20(DAI),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        buyToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        buyToken: IERC20(USDC),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        buyToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        buyToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        buyToken: IERC20(WETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDC),
                        buyToken: IERC20(DAI),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDC),
                        buyToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDC),
                        buyToken: IERC20(USDC),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDC),
                        buyToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDC),
                        buyToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDC),
                        buyToken: IERC20(WETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDC),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );

            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xA35b1B31Ce002FBF2058D22F30f95D405200A15b),
                        buyToken: IERC20(DAI),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xA35b1B31Ce002FBF2058D22F30f95D405200A15b),
                        buyToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xA35b1B31Ce002FBF2058D22F30f95D405200A15b),
                        buyToken: IERC20(USDC),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xA35b1B31Ce002FBF2058D22F30f95D405200A15b),
                        buyToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xA35b1B31Ce002FBF2058D22F30f95D405200A15b),
                        buyToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xA35b1B31Ce002FBF2058D22F30f95D405200A15b),
                        buyToken: IERC20(WETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xA35b1B31Ce002FBF2058D22F30f95D405200A15b),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );

            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        buyToken: IERC20(DAI),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        buyToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        buyToken: IERC20(USDC),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        buyToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        buyToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        buyToken: IERC20(WETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );

            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        buyToken: IERC20(DAI),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        buyToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        buyToken: IERC20(USDC),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        buyToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        buyToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        buyToken: IERC20(WETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );

            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xba100000625a3754423978a60c9317c58a424e3D),
                        buyToken: IERC20(DAI),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xba100000625a3754423978a60c9317c58a424e3D),
                        buyToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xba100000625a3754423978a60c9317c58a424e3D),
                        buyToken: IERC20(USDC),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xba100000625a3754423978a60c9317c58a424e3D),
                        buyToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xba100000625a3754423978a60c9317c58a424e3D),
                        buyToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xba100000625a3754423978a60c9317c58a424e3D),
                        buyToken: IERC20(WETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xba100000625a3754423978a60c9317c58a424e3D),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );

            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888),
                        buyToken: IERC20(DAI),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888),
                        buyToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888),
                        buyToken: IERC20(USDC),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888),
                        buyToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888),
                        buyToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888),
                        buyToken: IERC20(WETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );

            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(WETH),
                        buyToken: IERC20(DAI),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(WETH),
                        buyToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(WETH),
                        buyToken: IERC20(USDC),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(WETH),
                        buyToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(WETH),
                        buyToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(WETH),
                        buyToken: IERC20(WETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(WETH),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );

            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF),
                        buyToken: IERC20(DAI),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF),
                        buyToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF),
                        buyToken: IERC20(USDC),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF),
                        buyToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF),
                        buyToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF),
                        buyToken: IERC20(WETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );

            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xD33526068D116cE69F19A9ee46F0bd304F21A51f),
                        buyToken: IERC20(DAI),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xD33526068D116cE69F19A9ee46F0bd304F21A51f),
                        buyToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xD33526068D116cE69F19A9ee46F0bd304F21A51f),
                        buyToken: IERC20(USDC),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xD33526068D116cE69F19A9ee46F0bd304F21A51f),
                        buyToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xD33526068D116cE69F19A9ee46F0bd304F21A51f),
                        buyToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xD33526068D116cE69F19A9ee46F0bd304F21A51f),
                        buyToken: IERC20(WETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xD33526068D116cE69F19A9ee46F0bd304F21A51f),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );

            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52),
                        buyToken: IERC20(DAI),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52),
                        buyToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52),
                        buyToken: IERC20(USDC),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52),
                        buyToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52),
                        buyToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52),
                        buyToken: IERC20(WETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );

            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDT),
                        buyToken: IERC20(DAI),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDT),
                        buyToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDT),
                        buyToken: IERC20(USDC),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDT),
                        buyToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDT),
                        buyToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDT),
                        buyToken: IERC20(WETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(USDT),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );

            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xE95A203B1a91a908F9B9CE46459d101078c2c3cb),
                        buyToken: IERC20(DAI),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xE95A203B1a91a908F9B9CE46459d101078c2c3cb),
                        buyToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xE95A203B1a91a908F9B9CE46459d101078c2c3cb),
                        buyToken: IERC20(USDC),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xE95A203B1a91a908F9B9CE46459d101078c2c3cb),
                        buyToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xE95A203B1a91a908F9B9CE46459d101078c2c3cb),
                        buyToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xE95A203B1a91a908F9B9CE46459d101078c2c3cb),
                        buyToken: IERC20(WETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(0xE95A203B1a91a908F9B9CE46459d101078c2c3cb),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );

            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(osETH),
                        buyToken: IERC20(DAI),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(osETH),
                        buyToken: IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(osETH),
                        buyToken: IERC20(USDC),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(osETH),
                        buyToken: IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(osETH),
                        buyToken: IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(osETH),
                        buyToken: IERC20(WETH),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
            _safeExecuteTransaction(
                CowOrderSigner,
                abi.encodeWithSelector(
                    CowSwap.signOrder.selector,
                    CowSwap.Data({
                        sellToken: IERC20(osETH),
                        buyToken: IERC20(USDT),
                        receiver: safe,
                        sellAmount: 1 ether,
                        buyAmount: 1 ether,
                        validTo: 1_729_852_800,
                        appData: bytes32(0),
                        feeAmount: 0,
                        kind: bytes32(0),
                        partiallyFillable: false,
                        sellTokenBalance: bytes32(0),
                        buyTokenBalance: bytes32(0)
                    }),
                    1,
                    1
                )
            );
        }
        // 71
        {
            _safeExecuteTransaction(
                0x4370D3b6C9588E02ce9D22e684387859c7Ff5b34,
                abi.encodeWithSelector(Spark.claimAllRewards.selector, arg, safe)
            );
        }
        // 72
        {
            address CurveTokenMinter = 0xd061D61a4d941c39E5453435B6345Dc261C2fcE0;
            _safeExecuteTransaction(
                CurveTokenMinter,
                abi.encodeWithSelector(Curve.mint.selector, 0x182B723a58739a9c974cFDB385ceaDb237453c28)
            );
            _safeExecuteTransaction(
                CurveTokenMinter,
                abi.encodeWithSelector(Curve.mint.selector, 0x79F21BC30632cd40d2aF8134B469a0EB4C9574AA)
            );
            _safeExecuteTransaction(
                CurveTokenMinter,
                abi.encodeWithSelector(Curve.mint.selector, 0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A)
            );
            _safeExecuteTransaction(
                CurveTokenMinter,
                abi.encodeWithSelector(Curve.mint.selector, 0xcF5136C67fA8A375BaBbDf13c0307EF994b5681D)
            );
            _safeExecuteTransaction(
                CurveTokenMinter,
                abi.encodeWithSelector(Curve.mint.selector, 0xd03BE91b1932715709e18021734fcB91BB431715)
            );
        }
        // 73
        {
            uint256[] memory amounts = new uint256[](3);
            amounts[0] = 1 ether;
            amounts[1] = 1 ether;
            amounts[2] = 1 ether;
            {
                _safeExecuteTransaction(
                    CurvePool,
                    abi.encodeWithSelector(bytes4(keccak256("add_liquidity(uint256[3],uint256)")), amounts, 1 ether)
                );
            }
            // 74
            {
                _safeExecuteTransaction(
                    CurvePool,
                    abi.encodeWithSelector(bytes4(keccak256("remove_liquidity(uint256,uint256[3])")), 1 ether, amounts)
                );
            }
            // 75
            {
                _safeExecuteTransaction(
                    CurvePool,
                    abi.encodeWithSelector(
                        bytes4(keccak256("remove_liquidity_imbalance(uint256[3],uint256)")), amounts, 1 ether
                    )
                );
            }
        }
        // 76
        {
            _safeExecuteTransaction(
                CurvePool, abi.encodeWithSelector(Curve.remove_liquidity_one_coin.selector, 1 ether, 0, 1 ether)
            );
        }
        // 77
        {
            _safeExecuteTransaction(
                CurvePool,
                abi.encodeWithSelector(Curve.approve.selector, 0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A, 1 ether)
            );
        }
        // 78
        {
            address[] memory tokens = new address[](2);
            tokens[0] = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
            tokens[1] = 0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C;
            _safeExecuteTransaction(
                0x56C526b0159a258887e0d79ec3a80dfb940d0cD7,
                abi.encodeWithSelector(
                    Curve.deposit_and_stake.selector,
                    0x21E27a5E5513D6e65C4f830167390997aA84843a,
                    0x06325440D014e39736583c165C2963BA99fAf14E,
                    0x182B723a58739a9c974cFDB385ceaDb237453c28,
                    2,
                    tokens,
                    amounts,
                    1 ether,
                    true,
                    true,
                    address(0)
                )
            );
        }
        // 79
        {
            _safeExecuteTransaction(
                UniswapV3,
                abi.encodeWithSelector(
                    Uniswap.exactInputSingle.selector,
                    Uniswap.ExactInputSingleParams({
                        tokenIn: USDC,
                        tokenOut: USDT,
                        fee: 100,
                        recipient: safe,
                        amountIn: 1 ether,
                        amountOutMinimum: 1 ether,
                        sqrtPriceLimitX96: 0
                    })
                )
            );
        }

        vm.stopPrank();
    }

    function _selectFork() public override {
        vm.createSelectFork({ urlOrAlias: "mainnet", blockNumber: 22_339_715 });
    }

    function _proposer() public view override returns (address) {
        return 0x1D5460F896521aD685Ea4c3F2c679Ec0b6806359; // coltron.eth
    }

    function _isProposalSubmitted() public view override returns (bool) {
        return true;
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

    /// @dev Build the multiSend(bytes) calldata wrapping all 116 packed transactions.
    function _buildMultiSendCalldata() internal view returns (bytes memory) {
        return abi.encodeWithSelector(IMultiSend.multiSend.selector, _buildPackedTransactions());
    }

    // ─── MultiSend Payload
    // ──────────────────────────────────────────────

    function _buildPackedTransactions() internal view returns (bytes memory) {
        return abi.encodePacked(_buildChunk1(), _buildChunk2(), _buildChunk3(), _buildChunk4(), _packAnnotation());
    }

    function _buildChunk1() internal view returns (bytes memory) {
        return abi.encodePacked(
            _pack_Revoke(),
            _pack_AAVE_REWARDS_CONTROLLER(),
            _pack_AAVE_WETH_GATEWAY_V2(),
            _pack_USDS(),
            _pack_SKY_USDS_ACTIONS(),
            _pack_CURVE_3POOL_LP(),
            _pack_CURVE_STETH_LP(),
            _pack_BaseRewardPool(),
            _pack_OETH(),
            _pack_LIDO_WSTETH()
        );
    }

    function _buildChunk2() internal view returns (bytes memory) {
        return abi.encodePacked(
            _pack_OSETH_TOKEN(),
            _pack_SKY_FARM(),
            _pack_SKY_REWARDS(),
            _pack_AAVE_USDT_SUPPLY(),
            _pack_SKY_VAULT_1(),
            _pack_SKY_VAULT_2(),
            _pack_SDAI(),
            _pack_CURVE_GAUGE(),
            _pack_SKY_VAULT_3(),
            _pack_WETH_CONTRACT()
        );
    }

    function _buildChunk3() internal view returns (bytes memory) {
        return abi.encodePacked(
            _pack_BALANCER_GAUGE(),
            _pack_BALANCER_MINTER_V1(),
            _pack_DAI(),
            _pack_AaveLendingPool(),
            _pack_AAVE_WETH_TOKEN(),
            _pack_USDC(),
            _pack_USDT(),
            _pack_BalancerVault(),
            _pack_BALANCER_MINTER_V2(),
            _pack_CONVEX_BOOSTER()
        );
    }

    function _buildChunk4() internal view returns (bytes memory) {
        return abi.encodePacked(
            _pack_CowOrderSigner(),
            _pack_ORIGIN_VAULT(),
            _pack_CURVE_MINTER(),
            _pack_CurvePool(),
            _pack_ONE_INCH(),
            _pack_UniswapV3()
        );
    }

    // ─── Protocol Block Pack Functions
    // ───────────────────────────────────

    /// @dev TX 0-1: Revoke
    function _pack_Revoke() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 0: revokeFunction
            _packTx(
                address(roles),
                abi.encodeWithSelector(IRolesModifier.revokeFunction.selector, MANAGER_ROLE, AAVE, bytes4(0x474cf53d))
            ),
            // TX 1: revokeFunction
            _packTx(
                address(roles),
                abi.encodeWithSelector(IRolesModifier.revokeFunction.selector, MANAGER_ROLE, AAVE, bytes4(0x80500d20))
            )
        );
    }

    /// @dev TX 2-3: AAVE_REWARDS_CONTROLLER
    function _pack_AAVE_REWARDS_CONTROLLER() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 2: scopeTarget
            _packTx(
                address(roles),
                abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, AAVE_REWARDS_CONTROLLER)
            ),
            // TX 3: scopeFunction sel=0x236300dc
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    AAVE_REWARDS_CONTROLLER,
                    bytes4(0x236300dc),
                    _conditions_0(),
                    EXEC_NONE
                )
            )
        );
    }

    /// @dev TX 4-6: AAVE_WETH_GATEWAY_V2
    function _pack_AAVE_WETH_GATEWAY_V2() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 4: scopeTarget
            _packTx(
                address(roles),
                abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, AAVE_WETH_GATEWAY_V2)
            ),
            // TX 5: scopeFunction sel=0x474cf53d
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    AAVE_WETH_GATEWAY_V2,
                    bytes4(0x474cf53d),
                    _conditions_1(),
                    EXEC_SEND
                )
            ),
            // TX 6: scopeFunction sel=0x80500d20
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    AAVE_WETH_GATEWAY_V2,
                    bytes4(0x80500d20),
                    _conditions_2(),
                    EXEC_NONE
                )
            )
        );
    }

    /// @dev TX 7-8: USDS
    function _pack_USDS() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 7: scopeTarget
            _packTx(address(roles), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, USDS)),
            // TX 8: scopeFunction sel=0x095ea7b3
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    USDS,
                    bytes4(0x095ea7b3),
                    _conditions_3(),
                    EXEC_NONE
                )
            )
        );
    }

    /// @dev TX 9-12: SKY_USDS_ACTIONS
    function _pack_SKY_USDS_ACTIONS() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 9: scopeTarget
            _packTx(
                address(roles),
                abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, SKY_USDS_ACTIONS)
            ),
            // TX 10: scopeFunction sel=0x65ca4804
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    SKY_USDS_ACTIONS,
                    bytes4(0x65ca4804),
                    _conditions_4(),
                    EXEC_NONE
                )
            ),
            // TX 11: scopeFunction sel=0x0e248fea
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    SKY_USDS_ACTIONS,
                    bytes4(0x0e248fea),
                    _conditions_5(),
                    EXEC_NONE
                )
            ),
            // TX 12: scopeFunction sel=0x3f85d390
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    SKY_USDS_ACTIONS,
                    bytes4(0x3f85d390),
                    _conditions_6(),
                    EXEC_NONE
                )
            )
        );
    }

    /// @dev TX 13-19: CURVE_3POOL_LP
    function _pack_CURVE_3POOL_LP() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 13: scopeTarget
            _packTx(
                address(roles),
                abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, CURVE_3POOL_LP)
            ),
            // TX 14: scopeFunction sel=0x095ea7b3
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    CURVE_3POOL_LP,
                    bytes4(0x095ea7b3),
                    _conditions_7(),
                    EXEC_NONE
                )
            ),
            // TX 15: allowFunction sel=0x0b4c7e4d
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector, MANAGER_ROLE, CURVE_3POOL_LP, bytes4(0x0b4c7e4d), EXEC_SEND
                )
            ),
            // TX 16: allowFunction sel=0x5b36389c
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector, MANAGER_ROLE, CURVE_3POOL_LP, bytes4(0x5b36389c), EXEC_NONE
                )
            ),
            // TX 17: allowFunction sel=0xe3103273
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector, MANAGER_ROLE, CURVE_3POOL_LP, bytes4(0xe3103273), EXEC_NONE
                )
            ),
            // TX 18: allowFunction sel=0x1a4d01d2
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector, MANAGER_ROLE, CURVE_3POOL_LP, bytes4(0x1a4d01d2), EXEC_NONE
                )
            ),
            // TX 19: allowFunction sel=0x3df02124
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector, MANAGER_ROLE, CURVE_3POOL_LP, bytes4(0x3df02124), EXEC_SEND
                )
            )
        );
    }

    /// @dev TX 20-21: CURVE_STETH_LP
    function _pack_CURVE_STETH_LP() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 20: scopeTarget
            _packTx(
                address(roles),
                abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, CURVE_STETH_LP)
            ),
            // TX 21: scopeFunction sel=0x095ea7b3
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    CURVE_STETH_LP,
                    bytes4(0x095ea7b3),
                    _conditions_8(),
                    EXEC_NONE
                )
            )
        );
    }

    /// @dev TX 22-26: BaseRewardPool
    function _pack_BaseRewardPool() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 22: scopeTarget
            _packTx(
                address(roles),
                abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, BaseRewardPool)
            ),
            // TX 23: allowFunction sel=0xa694fc3a
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector, MANAGER_ROLE, BaseRewardPool, bytes4(0xa694fc3a), EXEC_NONE
                )
            ),
            // TX 24: allowFunction sel=0x38d07436
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector, MANAGER_ROLE, BaseRewardPool, bytes4(0x38d07436), EXEC_NONE
                )
            ),
            // TX 25: allowFunction sel=0xc32e7202
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector, MANAGER_ROLE, BaseRewardPool, bytes4(0xc32e7202), EXEC_NONE
                )
            ),
            // TX 26: scopeFunction sel=0x7050ccd9
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    BaseRewardPool,
                    bytes4(0x7050ccd9),
                    _conditions_9(),
                    EXEC_NONE
                )
            )
        );
    }

    /// @dev TX 27-28: OETH
    function _pack_OETH() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 27: scopeTarget
            _packTx(address(roles), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, OETH)),
            // TX 28: scopeFunction sel=0x095ea7b3
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    OETH,
                    bytes4(0x095ea7b3),
                    _conditions_10(),
                    EXEC_NONE
                )
            )
        );
    }

    /// @dev TX 29-33: LIDO_WSTETH
    function _pack_LIDO_WSTETH() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 29: scopeTarget
            _packTx(
                address(roles), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, LIDO_WSTETH)
            ),
            // TX 30: scopeFunction sel=0x095ea7b3
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    LIDO_WSTETH,
                    bytes4(0x095ea7b3),
                    _conditions_11(),
                    EXEC_NONE
                )
            ),
            // TX 31: scopeFunction sel=0x6e553f65
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    LIDO_WSTETH,
                    bytes4(0x6e553f65),
                    _conditions_12(),
                    EXEC_NONE
                )
            ),
            // TX 32: scopeFunction sel=0xb460af94
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    LIDO_WSTETH,
                    bytes4(0xb460af94),
                    _conditions_13(),
                    EXEC_NONE
                )
            ),
            // TX 33: scopeFunction sel=0xba087652
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    LIDO_WSTETH,
                    bytes4(0xba087652),
                    _conditions_14(),
                    EXEC_NONE
                )
            )
        );
    }

    /// @dev TX 34-35: OSETH_TOKEN
    function _pack_OSETH_TOKEN() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 34: scopeTarget
            _packTx(
                address(roles), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, OSETH_TOKEN)
            ),
            // TX 35: scopeFunction sel=0x095ea7b3
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    OSETH_TOKEN,
                    bytes4(0x095ea7b3),
                    _conditions_15(),
                    EXEC_NONE
                )
            )
        );
    }

    /// @dev TX 36-39: SKY_FARM
    function _pack_SKY_FARM() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 36: scopeTarget
            _packTx(
                address(roles), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, SKY_FARM)
            ),
            // TX 37: scopeFunction sel=0xb9f8aeb2
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    SKY_FARM,
                    bytes4(0xb9f8aeb2),
                    _conditions_16(),
                    EXEC_NONE
                )
            ),
            // TX 38: scopeFunction sel=0x68dea913
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    SKY_FARM,
                    bytes4(0x68dea913),
                    _conditions_17(),
                    EXEC_NONE
                )
            ),
            // TX 39: scopeFunction sel=0x9b67f733
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    SKY_FARM,
                    bytes4(0x9b67f733),
                    _conditions_18(),
                    EXEC_NONE
                )
            )
        );
    }

    /// @dev TX 40-44: SKY_REWARDS
    function _pack_SKY_REWARDS() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 40: scopeTarget
            _packTx(
                address(roles), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, SKY_REWARDS)
            ),
            // TX 41: allowFunction sel=0x42ea02c1
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector, MANAGER_ROLE, SKY_REWARDS, bytes4(0x42ea02c1), EXEC_NONE
                )
            ),
            // TX 42: allowFunction sel=0x2e1a7d4d
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector, MANAGER_ROLE, SKY_REWARDS, bytes4(0x2e1a7d4d), EXEC_NONE
                )
            ),
            // TX 43: allowFunction sel=0xe9fad8ee
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector, MANAGER_ROLE, SKY_REWARDS, bytes4(0xe9fad8ee), EXEC_NONE
                )
            ),
            // TX 44: allowFunction sel=0x3d18b912
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector, MANAGER_ROLE, SKY_REWARDS, bytes4(0x3d18b912), EXEC_NONE
                )
            )
        );
    }

    /// @dev TX 45-47: AAVE_USDT_SUPPLY
    function _pack_AAVE_USDT_SUPPLY() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 45: scopeTarget
            _packTx(
                address(roles),
                abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, AAVE_USDT_SUPPLY)
            ),
            // TX 46: scopeFunction sel=0xf2b9fdb8
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    AAVE_USDT_SUPPLY,
                    bytes4(0xf2b9fdb8),
                    _conditions_19(),
                    EXEC_NONE
                )
            ),
            // TX 47: scopeFunction sel=0xf3fef3a3
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    AAVE_USDT_SUPPLY,
                    bytes4(0xf3fef3a3),
                    _conditions_20(),
                    EXEC_NONE
                )
            )
        );
    }

    /// @dev TX 48-51: SKY_VAULT_1
    function _pack_SKY_VAULT_1() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 48: scopeTarget
            _packTx(
                address(roles), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, SKY_VAULT_1)
            ),
            // TX 49: allowFunction sel=0xb6b55f25
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector, MANAGER_ROLE, SKY_VAULT_1, bytes4(0xb6b55f25), EXEC_NONE
                )
            ),
            // TX 50: allowFunction sel=0x2e1a7d4d
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector, MANAGER_ROLE, SKY_VAULT_1, bytes4(0x2e1a7d4d), EXEC_NONE
                )
            ),
            // TX 51: allowFunction sel=0xe6f1daf2
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector, MANAGER_ROLE, SKY_VAULT_1, bytes4(0xe6f1daf2), EXEC_NONE
                )
            )
        );
    }

    /// @dev TX 52-55: SKY_VAULT_2
    function _pack_SKY_VAULT_2() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 52: scopeTarget
            _packTx(
                address(roles), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, SKY_VAULT_2)
            ),
            // TX 53: allowFunction sel=0xb6b55f25
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector, MANAGER_ROLE, SKY_VAULT_2, bytes4(0xb6b55f25), EXEC_NONE
                )
            ),
            // TX 54: allowFunction sel=0x2e1a7d4d
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector, MANAGER_ROLE, SKY_VAULT_2, bytes4(0x2e1a7d4d), EXEC_NONE
                )
            ),
            // TX 55: scopeFunction sel=0x1d2747d4
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    SKY_VAULT_2,
                    bytes4(0x1d2747d4),
                    _conditions_21(),
                    EXEC_NONE
                )
            )
        );
    }

    /// @dev TX 56-57: SDAI
    function _pack_SDAI() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 56: scopeTarget
            _packTx(address(roles), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, SDAI)),
            // TX 57: scopeFunction sel=0x095ea7b3
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    SDAI,
                    bytes4(0x095ea7b3),
                    _conditions_22(),
                    EXEC_NONE
                )
            )
        );
    }

    /// @dev TX 58-64: CURVE_GAUGE
    function _pack_CURVE_GAUGE() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 58: scopeTarget
            _packTx(
                address(roles), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, CURVE_GAUGE)
            ),
            // TX 59: allowFunction sel=0xb72df5de
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector, MANAGER_ROLE, CURVE_GAUGE, bytes4(0xb72df5de), EXEC_NONE
                )
            ),
            // TX 60: allowFunction sel=0xd40ddb8c
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector, MANAGER_ROLE, CURVE_GAUGE, bytes4(0xd40ddb8c), EXEC_NONE
                )
            ),
            // TX 61: allowFunction sel=0x7706db75
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector, MANAGER_ROLE, CURVE_GAUGE, bytes4(0x7706db75), EXEC_NONE
                )
            ),
            // TX 62: allowFunction sel=0x1a4d01d2
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector, MANAGER_ROLE, CURVE_GAUGE, bytes4(0x1a4d01d2), EXEC_NONE
                )
            ),
            // TX 63: scopeFunction sel=0x095ea7b3
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    CURVE_GAUGE,
                    bytes4(0x095ea7b3),
                    _conditions_23(),
                    EXEC_NONE
                )
            ),
            // TX 64: allowFunction sel=0x3df02124
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector, MANAGER_ROLE, CURVE_GAUGE, bytes4(0x3df02124), EXEC_NONE
                )
            )
        );
    }

    /// @dev TX 65-68: SKY_VAULT_3
    function _pack_SKY_VAULT_3() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 65: scopeTarget
            _packTx(
                address(roles), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, SKY_VAULT_3)
            ),
            // TX 66: allowFunction sel=0xb6b55f25
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector, MANAGER_ROLE, SKY_VAULT_3, bytes4(0xb6b55f25), EXEC_NONE
                )
            ),
            // TX 67: allowFunction sel=0x2e1a7d4d
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector, MANAGER_ROLE, SKY_VAULT_3, bytes4(0x2e1a7d4d), EXEC_NONE
                )
            ),
            // TX 68: allowFunction sel=0xe6f1daf2
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector, MANAGER_ROLE, SKY_VAULT_3, bytes4(0xe6f1daf2), EXEC_NONE
                )
            )
        );
    }

    /// @dev TX 69-70: WETH_CONTRACT
    function _pack_WETH_CONTRACT() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 69: scopeTarget
            _packTx(
                address(roles), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, WETH_CONTRACT)
            ),
            // TX 70: allowFunction sel=0xd0e30db0
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector, MANAGER_ROLE, WETH_CONTRACT, bytes4(0xd0e30db0), EXEC_SEND
                )
            )
        );
    }

    /// @dev TX 71-72: BALANCER_GAUGE
    function _pack_BALANCER_GAUGE() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 71: scopeTarget
            _packTx(
                address(roles),
                abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, BALANCER_GAUGE)
            ),
            // TX 72: scopeFunction sel=0x6c08c57e
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    BALANCER_GAUGE,
                    bytes4(0x6c08c57e),
                    _conditions_24(),
                    EXEC_NONE
                )
            )
        );
    }

    /// @dev TX 73-76: BALANCER_MINTER_V1
    function _pack_BALANCER_MINTER_V1() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 73: scopeTarget
            _packTx(
                address(roles),
                abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, BALANCER_MINTER_V1)
            ),
            // TX 74: allowFunction sel=0x9ee679e8
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector,
                    MANAGER_ROLE,
                    BALANCER_MINTER_V1,
                    bytes4(0x9ee679e8),
                    EXEC_NONE
                )
            ),
            // TX 75: allowFunction sel=0xf8444436
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector,
                    MANAGER_ROLE,
                    BALANCER_MINTER_V1,
                    bytes4(0xf8444436),
                    EXEC_NONE
                )
            ),
            // TX 76: allowFunction sel=0x48e30f54
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector,
                    MANAGER_ROLE,
                    BALANCER_MINTER_V1,
                    bytes4(0x48e30f54),
                    EXEC_NONE
                )
            )
        );
    }

    /// @dev TX 77-78: DAI
    function _pack_DAI() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 77: scopeTarget
            _packTx(address(roles), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, DAI)),
            // TX 78: scopeFunction sel=0x095ea7b3
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    DAI,
                    bytes4(0x095ea7b3),
                    _conditions_25(),
                    EXEC_NONE
                )
            )
        );
    }

    /// @dev TX 79-82: AaveLendingPool
    function _pack_AaveLendingPool() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 79: scopeTarget
            _packTx(
                address(roles),
                abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, AaveLendingPool)
            ),
            // TX 80: scopeFunction sel=0x617ba037
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    AaveLendingPool,
                    bytes4(0x617ba037),
                    _conditions_26(),
                    EXEC_NONE
                )
            ),
            // TX 81: scopeFunction sel=0x69328dec
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    AaveLendingPool,
                    bytes4(0x69328dec),
                    _conditions_27(),
                    EXEC_NONE
                )
            ),
            // TX 82: scopeFunction sel=0x5a3b74b9
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    AaveLendingPool,
                    bytes4(0x5a3b74b9),
                    _conditions_28(),
                    EXEC_NONE
                )
            )
        );
    }

    /// @dev TX 83-84: AAVE_WETH_TOKEN
    function _pack_AAVE_WETH_TOKEN() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 83: scopeTarget
            _packTx(
                address(roles),
                abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, AAVE_WETH_TOKEN)
            ),
            // TX 84: scopeFunction sel=0x095ea7b3
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    AAVE_WETH_TOKEN,
                    bytes4(0x095ea7b3),
                    _conditions_29(),
                    EXEC_NONE
                )
            )
        );
    }

    /// @dev TX 85-86: USDC
    function _pack_USDC() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 85: scopeTarget
            _packTx(address(roles), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, USDC)),
            // TX 86: scopeFunction sel=0x095ea7b3
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    USDC,
                    bytes4(0x095ea7b3),
                    _conditions_30(),
                    EXEC_NONE
                )
            )
        );
    }

    /// @dev TX 87-88: USDT
    function _pack_USDT() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 87: scopeTarget
            _packTx(address(roles), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, USDT)),
            // TX 88: scopeFunction sel=0x095ea7b3
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    USDT,
                    bytes4(0x095ea7b3),
                    _conditions_31(),
                    EXEC_NONE
                )
            )
        );
    }

    /// @dev TX 89-91: BalancerVault
    function _pack_BalancerVault() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 89: scopeTarget
            _packTx(
                address(roles), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, BalancerVault)
            ),
            // TX 90: scopeFunction sel=0xfa6e671d
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    BalancerVault,
                    bytes4(0xfa6e671d),
                    _conditions_32(),
                    EXEC_NONE
                )
            ),
            // TX 91: scopeFunction sel=0x52bbbe29
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    BalancerVault,
                    bytes4(0x52bbbe29),
                    _conditions_33(),
                    EXEC_NONE
                )
            )
        );
    }

    /// @dev TX 92-93: BALANCER_MINTER_V2
    function _pack_BALANCER_MINTER_V2() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 92: scopeTarget
            _packTx(
                address(roles),
                abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, BALANCER_MINTER_V2)
            ),
            // TX 93: scopeFunction sel=0x0de54ba0
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    BALANCER_MINTER_V2,
                    bytes4(0x0de54ba0),
                    _conditions_34(),
                    EXEC_NONE
                )
            )
        );
    }

    /// @dev TX 94-97: CONVEX_BOOSTER
    function _pack_CONVEX_BOOSTER() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 94: scopeTarget
            _packTx(
                address(roles),
                abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, CONVEX_BOOSTER)
            ),
            // TX 95: scopeFunction sel=0x43a0d066
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    CONVEX_BOOSTER,
                    bytes4(0x43a0d066),
                    _conditions_35(),
                    EXEC_NONE
                )
            ),
            // TX 96: scopeFunction sel=0x60759fce
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    CONVEX_BOOSTER,
                    bytes4(0x60759fce),
                    _conditions_36(),
                    EXEC_NONE
                )
            ),
            // TX 97: scopeFunction sel=0x441a3e70
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    CONVEX_BOOSTER,
                    bytes4(0x441a3e70),
                    _conditions_37(),
                    EXEC_NONE
                )
            )
        );
    }

    /// @dev TX 98-100: CowOrderSigner
    function _pack_CowOrderSigner() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 98: scopeTarget
            _packTx(
                address(roles),
                abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, CowOrderSigner)
            ),
            // TX 99: scopeFunction sel=0x569d3489
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    CowOrderSigner,
                    bytes4(0x569d3489),
                    _conditions_38(),
                    EXEC_DELEGATE_CALL
                )
            ),
            // TX 100: allowFunction sel=0x5a66c223
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector,
                    MANAGER_ROLE,
                    CowOrderSigner,
                    bytes4(0x5a66c223),
                    EXEC_DELEGATE_CALL
                )
            )
        );
    }

    /// @dev TX 101-102: ORIGIN_VAULT
    function _pack_ORIGIN_VAULT() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 101: scopeTarget
            _packTx(
                address(roles), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, ORIGIN_VAULT)
            ),
            // TX 102: scopeFunction sel=0xbb492bf5
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    ORIGIN_VAULT,
                    bytes4(0xbb492bf5),
                    _conditions_39(),
                    EXEC_NONE
                )
            )
        );
    }

    /// @dev TX 103-104: CURVE_MINTER
    function _pack_CURVE_MINTER() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 103: scopeTarget
            _packTx(
                address(roles), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, CURVE_MINTER)
            ),
            // TX 104: scopeFunction sel=0x6a627842
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    CURVE_MINTER,
                    bytes4(0x6a627842),
                    _conditions_40(),
                    EXEC_NONE
                )
            )
        );
    }

    /// @dev TX 105-110: CurvePool
    function _pack_CurvePool() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 105: scopeTarget
            _packTx(
                address(roles), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, CurvePool)
            ),
            // TX 106: allowFunction sel=0x4515cef3
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector, MANAGER_ROLE, CurvePool, bytes4(0x4515cef3), EXEC_NONE
                )
            ),
            // TX 107: allowFunction sel=0xecb586a5
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector, MANAGER_ROLE, CurvePool, bytes4(0xecb586a5), EXEC_NONE
                )
            ),
            // TX 108: allowFunction sel=0x9fdaea0c
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector, MANAGER_ROLE, CurvePool, bytes4(0x9fdaea0c), EXEC_NONE
                )
            ),
            // TX 109: allowFunction sel=0x1a4d01d2
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector, MANAGER_ROLE, CurvePool, bytes4(0x1a4d01d2), EXEC_NONE
                )
            ),
            // TX 110: scopeFunction sel=0x095ea7b3
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    CurvePool,
                    bytes4(0x095ea7b3),
                    _conditions_41(),
                    EXEC_NONE
                )
            )
        );
    }

    /// @dev TX 111-112: ONE_INCH
    function _pack_ONE_INCH() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 111: scopeTarget
            _packTx(
                address(roles), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, ONE_INCH)
            ),
            // TX 112: scopeFunction sel=0x26a38e64
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    ONE_INCH,
                    bytes4(0x26a38e64),
                    _conditions_42(),
                    EXEC_SEND
                )
            )
        );
    }

    /// @dev TX 113-114: UniswapV3
    function _pack_UniswapV3() internal view returns (bytes memory) {
        return abi.encodePacked(
            // TX 113: scopeTarget
            _packTx(
                address(roles), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, UniswapV3)
            ),
            // TX 114: scopeFunction sel=0x04e45aaf
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    UniswapV3,
                    bytes4(0x04e45aaf),
                    _conditions_43(),
                    EXEC_NONE
                )
            )
        );
    }

    // ─── Annotation (TX 115)
    // ────────────────────────────────────────────

    function _packAnnotation() internal view returns (bytes memory) {
        // TX 115: post annotation to AnnotationRegistry
        string memory annotationJson = '{"rolesMod":"0x703806e61847984346d2d7ddd853049627e50a40","roleKey":"'
            '0x4d414e4147455200000000000000000000000000000000000000000000000000","removeAnnotations":["'
            'https://kit.karpatkey.com/api/v1/permissions/eth/aave_v3/deposit?targets=DAI","'
            'https://kit.karpatkey.com/api/v1/permissions/eth/aave_v3/deposit?targets=ETH","'
            'https://kit.karpatkey.com/api/v1/permissions/eth/aave_v3/deposit?targets=USDC","'
            'https://kit.karpatkey.com/api/v1/permissions/eth/aave_v3/deposit?targets=WETH"],"addAnnotations":[{"schema":"'
            'https://kit.karpatkey.com/api/v1/openapi.json","uris":["'
            'https://kit.karpatkey.com/api/v1/permissions/eth/aura/deposit?targets=179","'
            'https://kit.karpatkey.com/api/v1/permissions/eth/aave_v3/deposit?market=Core&targets=DAI","'
            'https://kit.karpatkey.com/api/v1/permissions/eth/aave_v3/deposit?market=Core&targets=ETH","'
            'https://kit.karpatkey.com/api/v1/permissions/eth/aave_v3/deposit?market=Core&targets=osETH","'
            'https://kit.karpatkey.com/api/v1/permissions/eth/aave_v3/deposit?market=Core&targets=USDC","'
            'https://kit.karpatkey.com/api/v1/permissions/eth/aave_v3/deposit?market=Core&targets=USDS","'
            'https://kit.karpatkey.com/api/v1/permissions/eth/aave_v3/deposit?market=Core&targets=USDT","'
            'https://kit.karpatkey.com/api/v1/permissions/eth/aave_v3/deposit?market=Core&targets=WETH","'
            'https://kit.karpatkey.com/api/v1/permissions/eth/balancer/deposit?targets=osETH%2FwETH-BPT","'
            'https://kit.karpatkey.com/api/v1/permissions/eth/balancer/stake?targets=osETH%2FwETH-BPT","'
            'https://kit.karpatkey.com/api/v1/permissions/eth/convex/deposit?targets=174","'
            "https://kit.karpatkey.com/api/v1/permissions/eth/cowswap/swap?sell=0xE95A203B1a91a908F9B9CE46459d101078c2c3cb%2C0xC0c293"
            "ce456fF0ED870ADd98a0828Dd4d2903DBF%2C0xba100000625a3754423978a60c9317c58a424e3D%2C0xc00e94Cb662C3520282E6f5717214004A7f2"
            "6888%2C0xD533a949740bb3306d119CC777fa900bA034cd52%2C0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B%2C0x6B175474E89094C44Da98"
            "b954EedeAC495271d0F%2C0xA35b1B31Ce002FBF2058D22F30f95D405200A15b%2C0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32%2C0xf1C9ac"
            "Dc66974dFB6dEcB12aA385b9cD01190E38%2C0xae78736Cd615f374D3085123A210448E74Fc6393%2C0xD33526068D116cE69F19A9ee46F0bd304F21"
            "A51f%2C0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84%2C0x48C3399719B582dD63eB5AADf12A40B4C3f52FA2%2C0xA0b86991c6218b36c1d19"
            "D4a2e9Eb0cE3606eB48%2C0xdAC17F958D2ee523a2206206994597C13D831ec7%2C0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2%2C0x7f39C5"
            "81F595B53c5cb19bD0b3f8dA6c935E2Ca0&buy=0x6B175474E89094C44Da98b954EedeAC495271d0F%2C0xae78736Cd615f374D3085123A210448E74"
            "Fc6393%2C0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48%2C0xdAC17F958D2ee523a2206206994597C13D831ec7%2C0xae7ab96520DE3A18E5e"
            '111B5EaAb095312D7fE84%2C0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2%2C0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0","'
            "https://kit.karpatkey.com/api/v1/permissions/eth/cowswap/swap?sell=0xE95A203B1a91a908F9B9CE46459d101078c2c3cb%2C0xC0c293"
            "ce456fF0ED870ADd98a0828Dd4d2903DBF%2C0xba100000625a3754423978a60c9317c58a424e3D%2C0xc00e94Cb662C3520282E6f5717214004A7f2"
            "6888%2C0xD533a949740bb3306d119CC777fa900bA034cd52%2C0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B%2C0x6B175474E89094C44Da98"
            "b954EedeAC495271d0F%2C0xA35b1B31Ce002FBF2058D22F30f95D405200A15b%2C0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32%2C0xf1C9ac"
            "Dc66974dFB6dEcB12aA385b9cD01190E38%2C0xae78736Cd615f374D3085123A210448E74Fc6393%2C0xD33526068D116cE69F19A9ee46F0bd304F21"
            "A51f%2C0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84%2C0x48C3399719B582dD63eB5AADf12A40B4C3f52FA2%2C0xA0b86991c6218b36c1d19"
            "D4a2e9Eb0cE3606eB48%2C0xdAC17F958D2ee523a2206206994597C13D831ec7%2C0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2%2C0x7f39C5"
            "81F595B53c5cb19bD0b3f8dA6c935E2Ca0&buy=0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3%2C0xa3931d71877C0E7a3148CB7Eb4463524FE"
            "c27fbD%2C0x59d9356e565ab3a36dd77763fc0d87feaf85508c%2C0xdC035D45d973E3EC169d2276DDab16f1e407384F%2C0xdAC17F958D2ee523a22"
            '06206994597C13D831ec7","https://kit.karpatkey.com/api/v1/permissions/eth/cowswap/swap?sell=0x856c4Efb76C1D1AE02e20CEB03A'
            "2A6a08b0b8dC3%2C0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD%2C0x59d9356e565ab3a36dd77763fc0d87feaf85508c%2C0xdC035D45d973"
            "E3EC169d2276DDab16f1e407384F%2C0xdAC17F958D2ee523a2206206994597C13D831ec7&buy=0xE95A203B1a91a908F9B9CE46459d101078c2c3cb"
            "%2C0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF%2C0xba100000625a3754423978a60c9317c58a424e3D%2C0xc00e94Cb662C3520282E6f571"
            "7214004A7f26888%2C0xD533a949740bb3306d119CC777fa900bA034cd52%2C0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B%2C0x6B175474E8"
            "9094C44Da98b954EedeAC495271d0F%2C0xA35b1B31Ce002FBF2058D22F30f95D405200A15b%2C0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32"
            "%2C0xf1C9acDc66974dFB6dEcB12aA385b9cD01190E38%2C0xae78736Cd615f374D3085123A210448E74Fc6393%2C0xD33526068D116cE69F19A9ee4"
            "6F0bd304F21A51f%2C0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84%2C0x48C3399719B582dD63eB5AADf12A40B4C3f52FA2%2C0xA0b86991c6"
            "218b36c1d19D4a2e9Eb0cE3606eB48%2C0xdAC17F958D2ee523a2206206994597C13D831ec7%2C0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
            '%2C0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0","https://kit.karpatkey.com/api/v1/permissions/eth/spark/deposit?targets=S'
            'KY_USDS","https://kit.karpatkey.com/api/v1/permissions/eth/spark/stake?"]}]}';
        string memory tag = "ROLES_PERMISSION_ANNOTATION";

        return
            _packTx(ANNOTATION_REGISTRY, abi.encodeWithSelector(IAnnotationRegistry.post.selector, annotationJson, tag));
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Condition Builders
    // ═══════════════════════════════════════════════════════════════════════

    /// @dev Helper to create a padded address compValue for conditions
    function _addrComp(address addr) internal view returns (bytes memory) {
        return abi.encodePacked(bytes32(uint256(uint160(addr))));
    }

    /// @dev Compact condition constructor
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
    function _eq(uint8 parent, address addr) internal view returns (ConditionFlat memory) {
        return _c(parent, PARAM_TYPE_STATIC, OP_EQUAL_TO, _addrComp(addr));
    }

    function _conditions_0() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](5);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, 4, OP_PASS, "");
        c[2] = _c(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[3] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[4] = _c(1, PARAM_TYPE_STATIC, OP_PASS, "");
    }

    function _conditions_1() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](3);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _eq(0, AaveLendingPool);
        c[2] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
    }

    function _conditions_2() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](4);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _eq(0, AaveLendingPool);
        c[2] = _c(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[3] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
    }

    function _conditions_3() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](7);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, SKY_REWARDS);
        c[3] = _eq(1, AaveLendingPool);
        c[4] = _eq(1, LIDO_WSTETH);
        c[5] = _eq(1, COWSWAP_RELAYER);
        c[6] = _eq(1, SKY_FARM);
    }

    function _conditions_4() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](7);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[3] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[4] = _eq(1, COWSWAP_VAULT_RELAYER);
        c[5] = _eq(1, LIDO_WITHDRAWAL);
        c[6] = _eq(1, COWSWAP_SETTLEMENT);
    }

    function _conditions_5() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](8);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _c(
            1,
            4,
            OP_EQUAL_TO,
            hex"000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000010000000000000000000000005c0f23a5c1be65fa710d385814a7fd1bda480b1c"
        );
        c[3] = _c(
            1,
            4,
            OP_EQUAL_TO,
            hex"0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000079ef6103a513951a3b25743db509e267685726b7"
        );
        c[4] = _c(
            1,
            4,
            OP_EQUAL_TO,
            hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000c592c33e51a764b94db0702d8baf4035ed577aed"
        );
        c[5] = _c(2, PARAM_TYPE_STATIC, OP_PASS, "");
        c[6] = _c(3, PARAM_TYPE_STATIC, OP_PASS, "");
        c[7] = _c(4, PARAM_TYPE_STATIC, OP_PASS, "");
    }

    function _conditions_6() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](8);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _c(
            1,
            4,
            OP_EQUAL_TO,
            hex"000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000010000000000000000000000005c0f23a5c1be65fa710d385814a7fd1bda480b1c"
        );
        c[3] = _c(
            1,
            4,
            OP_EQUAL_TO,
            hex"0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000079ef6103a513951a3b25743db509e267685726b7"
        );
        c[4] = _c(
            1,
            4,
            OP_EQUAL_TO,
            hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000c592c33e51a764b94db0702d8baf4035ed577aed"
        );
        c[5] = _c(2, PARAM_TYPE_STATIC, OP_PASS, "");
        c[6] = _c(3, PARAM_TYPE_STATIC, OP_PASS, "");
        c[7] = _c(4, PARAM_TYPE_STATIC, OP_PASS, "");
    }

    function _conditions_7() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](4);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, SKY_VAULT_1);
        c[3] = _eq(1, CONVEX_BOOSTER);
    }

    function _conditions_8() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _eq(0, BaseRewardPool);
    }

    function _conditions_9() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
    }

    function _conditions_10() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](7);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, ONE_INCH);
        c[3] = _eq(1, BALANCER_GAUGE);
        c[4] = _eq(1, CURVE_3POOL_LP);
        c[5] = _eq(1, BalancerVault);
        c[6] = _eq(1, COWSWAP_RELAYER);
    }

    function _conditions_11() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _eq(0, COWSWAP_RELAYER);
    }

    function _conditions_12() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](3);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[2] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
    }

    function _conditions_13() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](4);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[2] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[3] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
    }

    function _conditions_14() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](4);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[2] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[3] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
    }

    function _conditions_15() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](6);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, CURVE_GAUGE);
        c[3] = _eq(1, ONE_INCH);
        c[4] = _eq(1, UniswapV3);
        c[5] = _eq(1, COWSWAP_RELAYER);
    }

    function _conditions_16() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
    }

    function _conditions_17() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
    }

    function _conditions_18() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
    }

    function _conditions_19() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _eq(0, USDT);
    }

    function _conditions_20() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _eq(0, USDT);
    }

    function _conditions_21() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _eq(0, ONE_INCH);
    }

    function _conditions_22() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](4);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, CURVE_GAUGE);
        c[3] = _eq(1, ONE_INCH);
    }

    function _conditions_23() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _eq(0, SKY_VAULT_3);
    }

    function _conditions_24() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](6);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _eq(0, OETH);
        c[2] = _eq(0, WETH);
        c[3] = _c(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[4] = _c(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[5] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
    }

    function _conditions_25() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](9);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, BAL_GAUGE_HELPER);
        c[3] = _eq(1, ONE_INCH);
        c[4] = _eq(1, UniswapV3);
        c[5] = _eq(1, AaveLendingPool);
        c[6] = _eq(1, CurvePool);
        c[7] = _eq(1, COWSWAP_RELAYER);
        c[8] = _eq(1, SKY_FARM);
    }

    function _conditions_26() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](10);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _c(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[3] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[4] = _eq(1, DAI);
        c[5] = _eq(1, USDC);
        c[6] = _eq(1, WETH);
        c[7] = _eq(1, USDT);
        c[8] = _eq(1, USDS);
        c[9] = _eq(1, osETH);
    }

    function _conditions_27() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](10);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _c(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[3] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[4] = _eq(1, DAI);
        c[5] = _eq(1, USDC);
        c[6] = _eq(1, WETH);
        c[7] = _eq(1, USDT);
        c[8] = _eq(1, USDS);
        c[9] = _eq(1, osETH);
    }

    function _conditions_28() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](8);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, DAI);
        c[3] = _eq(1, USDC);
        c[4] = _eq(1, WETH);
        c[5] = _eq(1, USDT);
        c[6] = _eq(1, USDS);
        c[7] = _eq(1, osETH);
    }

    function _conditions_29() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _eq(0, AAVE_WETH_GATEWAY_V2);
    }

    function _conditions_30() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](9);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, ONE_INCH);
        c[3] = _eq(1, UniswapV3);
        c[4] = _eq(1, AaveLendingPool);
        c[5] = _eq(1, BalancerVault);
        c[6] = _eq(1, CurvePool);
        c[7] = _eq(1, COMPOUND_USDC);
        c[8] = _eq(1, COWSWAP_RELAYER);
    }

    function _conditions_31() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](9);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, AAVE_USDT_SUPPLY);
        c[3] = _eq(1, ONE_INCH);
        c[4] = _eq(1, UniswapV3);
        c[5] = _eq(1, AaveLendingPool);
        c[6] = _eq(1, BalancerVault);
        c[7] = _eq(1, CurvePool);
        c[8] = _eq(1, COWSWAP_RELAYER);
    }

    function _conditions_32() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](3);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[2] = _eq(0, SKY_USDS_ACTIONS);
    }

    function _conditions_33() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](130);
        _conditions_33_chunk0(c);
        _conditions_33_chunk1(c);
        _conditions_33_chunk2(c);
        _conditions_33_chunk3(c);
    }

    function _conditions_33_chunk0(ConditionFlat[] memory c) internal view {
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _c(0, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[3] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[4] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[5] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[6] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[7] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[8] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[9] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[10] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[11] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[12] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[13] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[14] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[15] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[16] = _c(2, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[17] = _c(2, PARAM_TYPE_STATIC, OP_PASS, "");
        c[18] = _c(2, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[19] = _c(2, PARAM_TYPE_STATIC, OP_PASS, "");
        c[20] = _c(
            3, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0b09dea16768f0799065c475be02919503cb2a3500020000000000000000001a"
        );
        c[21] = _c(3, PARAM_TYPE_STATIC, OP_PASS, "");
        c[22] = _eq(3, WETH);
        c[23] = _eq(3, DAI);
        c[24] = _c(3, PARAM_TYPE_STATIC, OP_PASS, "");
        c[25] = _c(3, 2, OP_PASS, "");
        c[26] = _c(
            4, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"5c6ee304399dbdb9c8ef030ab642b10820db8f56000200000000000000000014"
        );
        c[27] = _c(4, PARAM_TYPE_STATIC, OP_PASS, "");
        c[28] = _eq(4, BAL_TOKEN);
        c[29] = _eq(4, WETH);
        c[30] = _c(4, PARAM_TYPE_STATIC, OP_PASS, "");
        c[31] = _c(4, 2, OP_PASS, "");
        c[32] = _c(
            5, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"96646936b91d6b9d7d0c47c496afbf3d6ec7b6f8000200000000000000000019"
        );
        c[33] = _c(5, PARAM_TYPE_STATIC, OP_PASS, "");
        c[34] = _eq(5, WETH);
        c[35] = _eq(5, USDC);
        c[36] = _c(5, PARAM_TYPE_STATIC, OP_PASS, "");
        c[37] = _c(5, 2, OP_PASS, "");
        c[38] = _c(
            6, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"cfca23ca9ca720b6e98e3eb9b6aa0ffc4a5c08b9000200000000000000000274"
        );
        c[39] = _c(6, PARAM_TYPE_STATIC, OP_PASS, "");
    }

    function _conditions_33_chunk1(ConditionFlat[] memory c) internal view {
        c[40] = _eq(6, AURA_TOKEN);
        c[41] = _eq(6, WETH);
        c[42] = _c(6, PARAM_TYPE_STATIC, OP_PASS, "");
        c[43] = _c(6, 2, OP_PASS, "");
        c[44] = _c(
            7, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"efaa1604e82e1b3af8430b90192c1b9e8197e377000200000000000000000021"
        );
        c[45] = _c(7, PARAM_TYPE_STATIC, OP_PASS, "");
        c[46] = _eq(7, COMP_TOKEN);
        c[47] = _eq(7, WETH);
        c[48] = _c(7, PARAM_TYPE_STATIC, OP_PASS, "");
        c[49] = _c(7, 2, OP_PASS, "");
        c[50] = _c(
            8, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"1e19cf2d73a72ef1332c882f20534b6519be0276000200000000000000000112"
        );
        c[51] = _c(8, PARAM_TYPE_STATIC, OP_PASS, "");
        c[52] = _c(8, PARAM_TYPE_NONE, OP_OR, "");
        c[53] = _c(8, PARAM_TYPE_NONE, OP_OR, "");
        c[54] = _c(8, PARAM_TYPE_STATIC, OP_PASS, "");
        c[55] = _c(8, 2, OP_PASS, "");
        c[56] = _c(
            9, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"37b18b10ce5635a84834b26095a0ae5639dcb7520000000000000000000005cb"
        );
        c[57] = _c(9, PARAM_TYPE_STATIC, OP_PASS, "");
        c[58] = _c(9, PARAM_TYPE_NONE, OP_OR, "");
        c[59] = _c(9, PARAM_TYPE_NONE, OP_OR, "");
        c[60] = _c(9, PARAM_TYPE_STATIC, OP_PASS, "");
        c[61] = _c(9, 2, OP_PASS, "");
        c[62] = _c(
            10, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"7056c8dfa8182859ed0d4fb0ef0886fdf3d2edcf000200000000000000000623"
        );
        c[63] = _c(10, PARAM_TYPE_STATIC, OP_PASS, "");
        c[64] = _c(10, PARAM_TYPE_NONE, OP_OR, "");
        c[65] = _c(10, PARAM_TYPE_NONE, OP_OR, "");
        c[66] = _c(10, PARAM_TYPE_STATIC, OP_PASS, "");
        c[67] = _c(10, 2, OP_PASS, "");
        c[68] = _c(
            11, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"8353157092ed8be69a9df8f95af097bbf33cb2af0000000000000000000005d9"
        );
        c[69] = _c(11, PARAM_TYPE_STATIC, OP_PASS, "");
        c[70] = _c(11, PARAM_TYPE_NONE, OP_OR, "");
        c[71] = _c(11, PARAM_TYPE_NONE, OP_OR, "");
        c[72] = _c(11, PARAM_TYPE_STATIC, OP_PASS, "");
        c[73] = _c(11, 2, OP_PASS, "");
        c[74] = _c(
            12, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"93d199263632a4ef4bb438f1feb99e57b4b5f0bd0000000000000000000005c2"
        );
        c[75] = _c(12, PARAM_TYPE_STATIC, OP_PASS, "");
        c[76] = _c(12, PARAM_TYPE_NONE, OP_OR, "");
        c[77] = _c(12, PARAM_TYPE_NONE, OP_OR, "");
        c[78] = _c(12, PARAM_TYPE_STATIC, OP_PASS, "");
        c[79] = _c(12, 2, OP_PASS, "");
    }

    function _conditions_33_chunk2(ConditionFlat[] memory c) internal view {
        c[80] = _c(
            13, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"dacf5fa19b1f720111609043ac67a9818262850c000000000000000000000635"
        );
        c[81] = _c(13, PARAM_TYPE_STATIC, OP_PASS, "");
        c[82] = _c(13, PARAM_TYPE_NONE, OP_OR, "");
        c[83] = _c(13, PARAM_TYPE_NONE, OP_OR, "");
        c[84] = _c(13, PARAM_TYPE_STATIC, OP_PASS, "");
        c[85] = _c(13, 2, OP_PASS, "");
        c[86] = _c(
            14, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"dfe6e7e18f6cc65fa13c8d8966013d4fda74b6ba000000000000000000000558"
        );
        c[87] = _c(14, PARAM_TYPE_STATIC, OP_PASS, "");
        c[88] = _c(14, PARAM_TYPE_NONE, OP_OR, "");
        c[89] = _c(14, PARAM_TYPE_NONE, OP_OR, "");
        c[90] = _c(14, PARAM_TYPE_STATIC, OP_PASS, "");
        c[91] = _c(14, 2, OP_PASS, "");
        c[92] = _c(
            15, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"f01b0684c98cd7ada480bfdf6e43876422fa1fc10002000000000000000005de"
        );
        c[93] = _c(15, PARAM_TYPE_STATIC, OP_PASS, "");
        c[94] = _c(15, PARAM_TYPE_NONE, OP_OR, "");
        c[95] = _c(15, PARAM_TYPE_NONE, OP_OR, "");
        c[96] = _c(15, PARAM_TYPE_STATIC, OP_PASS, "");
        c[97] = _c(15, 2, OP_PASS, "");
        c[98] = _eq(52, RETH);
        c[99] = _eq(52, WETH);
        c[100] = _eq(53, RETH);
        c[101] = _eq(53, WETH);
        c[102] = _eq(58, ETHx);
        c[103] = _eq(58, WETH);
        c[104] = _eq(59, ETHx);
        c[105] = _eq(59, WETH);
        c[106] = _eq(64, OETH);
        c[107] = _eq(64, WETH);
        c[108] = _eq(65, OETH);
        c[109] = _eq(65, WETH);
        c[110] = _eq(70, USDC);
        c[111] = _eq(70, USDT);
        c[112] = _eq(71, USDC);
        c[113] = _eq(71, USDT);
        c[114] = _eq(76, WSTETH);
        c[115] = _eq(76, WETH);
        c[116] = _eq(77, WSTETH);
        c[117] = _eq(77, WETH);
        c[118] = _eq(82, WETH);
        c[119] = _eq(82, osETH);
    }

    function _conditions_33_chunk3(ConditionFlat[] memory c) internal view {
        c[120] = _eq(83, WETH);
        c[121] = _eq(83, osETH);
        c[122] = _eq(88, WSTETH);
        c[123] = _eq(88, ANKR_ETH);
        c[124] = _eq(89, WSTETH);
        c[125] = _eq(89, ANKR_ETH);
        c[126] = _eq(94, WSTETH);
        c[127] = _eq(94, WETH);
        c[128] = _eq(95, WSTETH);
        c[129] = _eq(95, WETH);
    }

    function _conditions_34() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _eq(0, SKY_USDS_ACTIONS);
    }

    function _conditions_35() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](5);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _c(
            1, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0000000000000000000000000000000000000000000000000000000000000019"
        );
        c[3] = _c(
            1, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"00000000000000000000000000000000000000000000000000000000000000ae"
        );
        c[4] = _c(
            1, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"00000000000000000000000000000000000000000000000000000000000000b1"
        );
    }

    function _conditions_36() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](5);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _c(
            1, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0000000000000000000000000000000000000000000000000000000000000019"
        );
        c[3] = _c(
            1, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"00000000000000000000000000000000000000000000000000000000000000ae"
        );
        c[4] = _c(
            1, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"00000000000000000000000000000000000000000000000000000000000000b1"
        );
    }

    function _conditions_37() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](5);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _c(
            1, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0000000000000000000000000000000000000000000000000000000000000019"
        );
        c[3] = _c(
            1, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"00000000000000000000000000000000000000000000000000000000000000ae"
        );
        c[4] = _c(
            1, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"00000000000000000000000000000000000000000000000000000000000000b1"
        );
    }

    function _conditions_38() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](112);
        _conditions_38_chunk0(c);
        _conditions_38_chunk1(c);
        _conditions_38_chunk2(c);
    }

    function _conditions_38_chunk0(ConditionFlat[] memory c) internal view {
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[3] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[4] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[5] = _c(2, PARAM_TYPE_NONE, OP_OR, "");
        c[6] = _c(2, PARAM_TYPE_NONE, OP_OR, "");
        c[7] = _c(2, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[8] = _c(2, PARAM_TYPE_STATIC, OP_PASS, "");
        c[9] = _c(2, PARAM_TYPE_STATIC, OP_PASS, "");
        c[10] = _c(2, PARAM_TYPE_STATIC, OP_PASS, "");
        c[11] = _c(2, PARAM_TYPE_STATIC, OP_PASS, "");
        c[12] = _c(2, PARAM_TYPE_STATIC, OP_PASS, "");
        c[13] = _c(2, PARAM_TYPE_STATIC, OP_PASS, "");
        c[14] = _c(2, PARAM_TYPE_STATIC, OP_PASS, "");
        c[15] = _c(2, PARAM_TYPE_STATIC, OP_PASS, "");
        c[16] = _c(2, PARAM_TYPE_STATIC, OP_PASS, "");
        c[17] = _c(3, PARAM_TYPE_NONE, OP_OR, "");
        c[18] = _c(3, PARAM_TYPE_NONE, OP_OR, "");
        c[19] = _c(3, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[20] = _c(3, PARAM_TYPE_STATIC, OP_PASS, "");
        c[21] = _c(3, PARAM_TYPE_STATIC, OP_PASS, "");
        c[22] = _c(3, PARAM_TYPE_STATIC, OP_PASS, "");
        c[23] = _c(3, PARAM_TYPE_STATIC, OP_PASS, "");
        c[24] = _c(3, PARAM_TYPE_STATIC, OP_PASS, "");
        c[25] = _c(3, PARAM_TYPE_STATIC, OP_PASS, "");
        c[26] = _c(3, PARAM_TYPE_STATIC, OP_PASS, "");
        c[27] = _c(3, PARAM_TYPE_STATIC, OP_PASS, "");
        c[28] = _c(3, PARAM_TYPE_STATIC, OP_PASS, "");
        c[29] = _c(4, PARAM_TYPE_NONE, OP_OR, "");
        c[30] = _c(4, PARAM_TYPE_NONE, OP_OR, "");
        c[31] = _c(4, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[32] = _c(4, PARAM_TYPE_STATIC, OP_PASS, "");
        c[33] = _c(4, PARAM_TYPE_STATIC, OP_PASS, "");
        c[34] = _c(4, PARAM_TYPE_STATIC, OP_PASS, "");
        c[35] = _c(4, PARAM_TYPE_STATIC, OP_PASS, "");
        c[36] = _c(4, PARAM_TYPE_STATIC, OP_PASS, "");
        c[37] = _c(4, PARAM_TYPE_STATIC, OP_PASS, "");
        c[38] = _c(4, PARAM_TYPE_STATIC, OP_PASS, "");
        c[39] = _c(4, PARAM_TYPE_STATIC, OP_PASS, "");
    }

    function _conditions_38_chunk1(ConditionFlat[] memory c) internal view {
        c[40] = _c(4, PARAM_TYPE_STATIC, OP_PASS, "");
        c[41] = _eq(5, CRV3CRYPTO);
        c[42] = _eq(5, CVX_TOKEN);
        c[43] = _eq(5, LDO_TOKEN);
        c[44] = _eq(5, DAI);
        c[45] = _eq(5, WSTETH);
        c[46] = _eq(5, USDC);
        c[47] = _eq(5, ETHx);
        c[48] = _eq(5, RETH);
        c[49] = _eq(5, STETH);
        c[50] = _eq(5, BAL_TOKEN);
        c[51] = _eq(5, COMP_TOKEN);
        c[52] = _eq(5, WETH);
        c[53] = _eq(5, AURA_TOKEN);
        c[54] = _eq(5, RPL_TOKEN);
        c[55] = _eq(5, CRV_TOKEN);
        c[56] = _eq(5, USDT);
        c[57] = _eq(5, ANKR_ETH);
        c[58] = _eq(5, osETH);
        c[59] = _eq(6, OSETH_TOKEN);
        c[60] = _eq(6, OETH);
        c[61] = _eq(6, LIDO_WSTETH);
        c[62] = _eq(6, USDT);
        c[63] = _eq(6, USDS);
        c[64] = _eq(17, OSETH_TOKEN);
        c[65] = _eq(17, OETH);
        c[66] = _eq(17, LIDO_WSTETH);
        c[67] = _eq(17, USDT);
        c[68] = _eq(17, USDS);
        c[69] = _eq(18, CRV3CRYPTO);
        c[70] = _eq(18, CVX_TOKEN);
        c[71] = _eq(18, LDO_TOKEN);
        c[72] = _eq(18, DAI);
        c[73] = _eq(18, WSTETH);
        c[74] = _eq(18, USDC);
        c[75] = _eq(18, ETHx);
        c[76] = _eq(18, RETH);
        c[77] = _eq(18, STETH);
        c[78] = _eq(18, BAL_TOKEN);
        c[79] = _eq(18, COMP_TOKEN);
    }

    function _conditions_38_chunk2(ConditionFlat[] memory c) internal view {
        c[80] = _eq(18, WETH);
        c[81] = _eq(18, AURA_TOKEN);
        c[82] = _eq(18, RPL_TOKEN);
        c[83] = _eq(18, CRV_TOKEN);
        c[84] = _eq(18, USDT);
        c[85] = _eq(18, ANKR_ETH);
        c[86] = _eq(18, osETH);
        c[87] = _eq(29, CRV3CRYPTO);
        c[88] = _eq(29, CVX_TOKEN);
        c[89] = _eq(29, LDO_TOKEN);
        c[90] = _eq(29, DAI);
        c[91] = _eq(29, WSTETH);
        c[92] = _eq(29, USDC);
        c[93] = _eq(29, ETHx);
        c[94] = _eq(29, RETH);
        c[95] = _eq(29, STETH);
        c[96] = _eq(29, BAL_TOKEN);
        c[97] = _eq(29, COMP_TOKEN);
        c[98] = _eq(29, WETH);
        c[99] = _eq(29, AURA_TOKEN);
        c[100] = _eq(29, RPL_TOKEN);
        c[101] = _eq(29, CRV_TOKEN);
        c[102] = _eq(29, USDT);
        c[103] = _eq(29, ANKR_ETH);
        c[104] = _eq(29, osETH);
        c[105] = _eq(30, DAI);
        c[106] = _eq(30, WSTETH);
        c[107] = _eq(30, USDC);
        c[108] = _eq(30, RETH);
        c[109] = _eq(30, STETH);
        c[110] = _eq(30, WETH);
        c[111] = _eq(30, USDT);
    }

    function _conditions_39() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](4);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, 4, OP_PASS, "");
        c[2] = _c(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[3] = _c(1, PARAM_TYPE_STATIC, OP_PASS, "");
    }

    function _conditions_40() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](7);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _eq(1, BALANCER_OSETH_POOL);
        c[3] = _eq(1, AURA_OSETH_REWARDS);
        c[4] = _eq(1, SKY_VAULT_2);
        c[5] = _eq(1, SKY_VAULT_3);
        c[6] = _eq(1, SKY_VAULT_1);
    }

    function _conditions_41() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _eq(0, SKY_VAULT_2);
    }

    function _conditions_42() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](37);
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[3] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[4] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[5] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[6] = _c(0, 4, OP_PASS, "");
        c[7] = _c(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[8] = _c(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[9] = _c(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[10] = _c(
            0, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0000000000000000000000000000000000000000000000000000000000000000"
        );
        c[11] = _eq(1, STETH_ETH_CURVE);
        c[12] = _eq(1, CURVE_GAUGE);
        c[13] = _eq(1, CURVE_3POOL_LP);
        c[14] = _eq(1, CurvePool);
        c[15] = _eq(1, CURVE_STETH_POOL);
        c[16] = _eq(2, CURVE_STETH_TOKEN);
        c[17] = _eq(2, STETH_ETH_CURVE);
        c[18] = _eq(2, CURVE_GAUGE);
        c[19] = _eq(2, CURVE_3CRV);
        c[20] = _eq(2, CURVE_3POOL_LP);
        c[21] = _eq(3, BALANCER_OSETH_POOL);
        c[22] = _eq(3, AURA_OSETH_REWARDS);
        c[23] = _eq(3, SKY_VAULT_2);
        c[24] = _eq(3, SKY_VAULT_3);
        c[25] = _eq(3, SKY_VAULT_1);
        c[26] = _c(
            4, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0000000000000000000000000000000000000000000000000000000000000002"
        );
        c[27] = _c(
            4, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0000000000000000000000000000000000000000000000000000000000000003"
        );
        c[28] = _c(
            5,
            4,
            OP_EQUAL_TO,
            hex"0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000200000000000000000000000083f20f44975d03b1b09e64809b757c47f942beea00000000000000000000000059d9356e565ab3a36dd77763fc0d87feaf85508c"
        );
        c[29] = _c(
            5,
            4,
            OP_EQUAL_TO,
            hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000002000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee000000000000000000000000856c4efb76c1d1ae02e20ceb03a2a6a08b0b8dc3"
        );
        c[30] = _c(
            5,
            4,
            OP_EQUAL_TO,
            hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000002000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee000000000000000000000000ae7ab96520de3a18e5e111b5eaab095312d7fe84"
        );
        c[31] = _c(
            5,
            4,
            OP_EQUAL_TO,
            hex"000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000030000000000000000000000006b175474e89094c44da98b954eedeac495271d0f000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec7"
        );
        c[32] = _c(6, PARAM_TYPE_STATIC, OP_PASS, "");
        c[33] = _c(28, PARAM_TYPE_STATIC, OP_PASS, "");
        c[34] = _c(29, PARAM_TYPE_STATIC, OP_PASS, "");
        c[35] = _c(30, PARAM_TYPE_STATIC, OP_PASS, "");
        c[36] = _c(31, PARAM_TYPE_STATIC, OP_PASS, "");
    }

    function _conditions_43() internal view returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](88);
        _conditions_43_chunk0(c);
        _conditions_43_chunk1(c);
        _conditions_43_chunk2(c);
    }

    function _conditions_43_chunk0(ConditionFlat[] memory c) internal view {
        c[0] = _c(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = _c(0, PARAM_TYPE_NONE, OP_OR, "");
        c[2] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[3] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[4] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[5] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[6] = _c(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        c[7] = _c(2, PARAM_TYPE_NONE, OP_OR, "");
        c[8] = _c(2, PARAM_TYPE_NONE, OP_OR, "");
        c[9] = _c(
            2, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0000000000000000000000000000000000000000000000000000000000000064"
        );
        c[10] = _c(2, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[11] = _c(2, PARAM_TYPE_STATIC, OP_PASS, "");
        c[12] = _c(2, PARAM_TYPE_STATIC, OP_PASS, "");
        c[13] = _c(2, PARAM_TYPE_STATIC, OP_PASS, "");
        c[14] = _c(3, PARAM_TYPE_NONE, OP_OR, "");
        c[15] = _c(3, PARAM_TYPE_NONE, OP_OR, "");
        c[16] = _c(
            3, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"00000000000000000000000000000000000000000000000000000000000001f4"
        );
        c[17] = _c(3, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[18] = _c(3, PARAM_TYPE_STATIC, OP_PASS, "");
        c[19] = _c(3, PARAM_TYPE_STATIC, OP_PASS, "");
        c[20] = _c(3, PARAM_TYPE_STATIC, OP_PASS, "");
        c[21] = _c(4, PARAM_TYPE_NONE, OP_OR, "");
        c[22] = _c(4, PARAM_TYPE_NONE, OP_OR, "");
        c[23] = _c(4, PARAM_TYPE_NONE, OP_OR, "");
        c[24] = _c(4, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[25] = _c(4, PARAM_TYPE_STATIC, OP_PASS, "");
        c[26] = _c(4, PARAM_TYPE_STATIC, OP_PASS, "");
        c[27] = _c(4, PARAM_TYPE_STATIC, OP_PASS, "");
        c[28] = _c(5, PARAM_TYPE_NONE, OP_OR, "");
        c[29] = _c(5, PARAM_TYPE_NONE, OP_OR, "");
        c[30] = _c(5, PARAM_TYPE_NONE, OP_OR, "");
        c[31] = _c(5, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[32] = _c(5, PARAM_TYPE_STATIC, OP_PASS, "");
        c[33] = _c(5, PARAM_TYPE_STATIC, OP_PASS, "");
        c[34] = _c(5, PARAM_TYPE_STATIC, OP_PASS, "");
        c[35] = _c(6, PARAM_TYPE_NONE, OP_OR, "");
        c[36] = _c(6, PARAM_TYPE_NONE, OP_OR, "");
        c[37] = _c(6, PARAM_TYPE_STATIC, OP_PASS, "");
        c[38] = _c(6, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[39] = _c(6, PARAM_TYPE_STATIC, OP_PASS, "");
    }

    function _conditions_43_chunk1(ConditionFlat[] memory c) internal view {
        c[40] = _c(6, PARAM_TYPE_STATIC, OP_PASS, "");
        c[41] = _c(6, PARAM_TYPE_STATIC, OP_PASS, "");
        c[42] = _eq(7, USDC);
        c[43] = _eq(7, USDT);
        c[44] = _eq(8, USDC);
        c[45] = _eq(8, USDT);
        c[46] = _eq(14, OSETH_TOKEN);
        c[47] = _eq(14, USDT);
        c[48] = _eq(15, OSETH_TOKEN);
        c[49] = _eq(15, USDT);
        c[50] = _eq(21, USDC);
        c[51] = _eq(21, WETH);
        c[52] = _eq(22, USDC);
        c[53] = _eq(22, WETH);
        c[54] = _c(
            23, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"00000000000000000000000000000000000000000000000000000000000001f4"
        );
        c[55] = _c(
            23, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0000000000000000000000000000000000000000000000000000000000000bb8"
        );
        c[56] = _eq(28, WETH);
        c[57] = _eq(28, USDT);
        c[58] = _eq(29, WETH);
        c[59] = _eq(29, USDT);
        c[60] = _c(
            30, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0000000000000000000000000000000000000000000000000000000000000064"
        );
        c[61] = _c(
            30, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"00000000000000000000000000000000000000000000000000000000000001f4"
        );
        c[62] = _c(
            30, PARAM_TYPE_STATIC, OP_EQUAL_TO, hex"0000000000000000000000000000000000000000000000000000000000000bb8"
        );
        c[63] = _eq(35, CRV3CRYPTO);
        c[64] = _eq(35, CVX_TOKEN);
        c[65] = _eq(35, LDO_TOKEN);
        c[66] = _eq(35, DAI);
        c[67] = _eq(35, WSTETH);
        c[68] = _eq(35, USDC);
        c[69] = _eq(35, ETHx);
        c[70] = _eq(35, RETH);
        c[71] = _eq(35, STETH);
        c[72] = _eq(35, BAL_TOKEN);
        c[73] = _eq(35, COMP_TOKEN);
        c[74] = _eq(35, WETH);
        c[75] = _eq(35, AURA_TOKEN);
        c[76] = _eq(35, RPL_TOKEN);
        c[77] = _eq(35, CRV_TOKEN);
        c[78] = _eq(35, USDT);
        c[79] = _eq(35, ANKR_ETH);
    }

    function _conditions_43_chunk2(ConditionFlat[] memory c) internal view {
        c[80] = _eq(35, osETH);
        c[81] = _eq(36, DAI);
        c[82] = _eq(36, WSTETH);
        c[83] = _eq(36, USDC);
        c[84] = _eq(36, RETH);
        c[85] = _eq(36, STETH);
        c[86] = _eq(36, WETH);
        c[87] = _eq(36, USDT);
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-6-8";
    }
}
