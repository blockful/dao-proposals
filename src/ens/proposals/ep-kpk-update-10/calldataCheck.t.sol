// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { ENS_Governance } from "@ens/ens.t.sol";
import { SafeHelper } from "@ens/helpers/SafeHelper.sol";
import { ZodiacRolesHelper } from "@ens/helpers/ZodiacRolesHelper.sol";
import { IZodiacRoles } from "@ens/interfaces/IZodiacRoles.sol";
import { IRolesModifier, ConditionFlat } from "@ens/interfaces/IRolesModifier.sol";
import { IMultiSend } from "@ens/interfaces/IMultiSend.sol";
import { IAnnotationRegistry } from "@ens/interfaces/IAnnotationRegistry.sol";
import { IMetaMorphoV1 } from "@ens/interfaces/IMetaMorphoV1.sol";
import { ICowSwapOrderSigner } from "@ens/interfaces/ICowSwapOrderSigner.sol";
import { IERC20 } from "@forge-std/src/interfaces/IERC20.sol";

// ─── Minimal interfaces for targets touched by this proposal ─────────────

/// @notice Zodiac ModuleProxyFactory (0x000000000000aDdB49795b0f9bA5BC298cDda236)
interface IModuleProxyFactory {
    function deployModule(
        address masterCopy,
        bytes memory initializer,
        uint256 saltNonce
    )
        external
        returns (address proxy);
}

/// @notice Admin surface of a Zodiac Roles Modifier (both the existing one and the new sub-instance)
interface IRolesAdmin {
    function setUp(bytes memory initParams) external;
    function enableModule(address module) external;
    function setDefaultRole(address module, bytes32 roleKey) external;
    function assignRoles(address module, bytes32[] memory roleKeys, bool[] memory memberOf) external;
    function setTarget(address _target) external;
    function transferOwnership(address newOwner) external;
    function owner() external view returns (address);
    function avatar() external view returns (address);
    function target() external view returns (address);
    function isModuleEnabled(address module) external view returns (bool);
    function defaultRoles(address module) external view returns (bytes32);
    function allowTarget(bytes32 roleKey, address targetAddress, uint8 options) external;
}

/// @notice Aave v3 Horizon Pool
interface IAaveV3Pool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}

/// @notice Pendle Router V4 (ActionMisc / ActionSwapPT / ActionAddRemoveLiq facets)
interface IPendleRouterV4 {
    struct SwapData {
        uint8 swapType;
        address extRouter;
        bytes extCalldata;
        bool needScale;
    }

    struct TokenInput {
        address tokenIn;
        uint256 netTokenIn;
        address tokenMintSy;
        address pendleSwap;
        SwapData swapData;
    }

    struct TokenOutput {
        address tokenOut;
        uint256 minTokenOut;
        address tokenRedeemSy;
        address pendleSwap;
        SwapData swapData;
    }

    struct ApproxParams {
        uint256 guessMin;
        uint256 guessMax;
        uint256 guessOffchain;
        uint256 maxIteration;
        uint256 eps;
    }

    struct Order {
        uint256 salt;
        uint256 expiry;
        uint256 nonce;
        uint8 orderType;
        address token;
        address YT;
        address maker;
        address receiver;
        uint256 makingAmount;
        uint256 lnImpliedRate;
        uint256 failSafeRate;
        bytes permit;
    }

    struct FillOrderParams {
        Order order;
        bytes signature;
        uint256 makingAmount;
    }

    struct LimitOrderData {
        address limitRouter;
        uint256 epsSkipMarket;
        FillOrderParams[] normalFills;
        FillOrderParams[] flashFills;
        bytes optData;
    }

    function swapExactTokenForPt(
        address receiver,
        address market,
        uint256 minPtOut,
        ApproxParams calldata guessPtOut,
        TokenInput calldata input,
        LimitOrderData calldata limit
    )
        external
        payable
        returns (uint256 netPtOut, uint256 netSyFee, uint256 netSyInterm);

    function swapExactPtForToken(
        address receiver,
        address market,
        uint256 exactPtIn,
        TokenOutput calldata output,
        LimitOrderData calldata limit
    )
        external
        returns (uint256 netTokenOut, uint256 netSyFee, uint256 netSyInterm);

    function redeemPyToToken(
        address receiver,
        address YT,
        uint256 netPyIn,
        TokenOutput calldata output
    )
        external
        returns (uint256 netTokenOut, uint256 netSyInterm);
}

/// @notice Merkl / Fluid style reward distributors named in the forum specification
interface IMerklDistributor {
    function claim(
        address[] calldata users,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    )
        external;
}

/**
 * @title Endowment permissions to kpk — Update #10 (pre-draft)
 * @notice Pre-draft calldata review for
 *     https://discuss.ens.domains/t/draft-endowment-permissions-to-kpk-update-10/22323
 *
 * The executable payload published with the forum post is
 *     karpatkey/client-configs @ ens-dao-manager-harvest-rwa-yield
 *     clients/ens-dao/mainnet/payloads/ensPermissionsUpdate10.json
 * a 54-transaction Safe Transaction Builder batch, delegatecalled through MultiSend
 * by the Endowment Safe. `expectedMultiSend.txt` is that payload re-encoded byte for
 * byte; `_generateCallData()` below rebuilds it from the published specification and
 * Solidity interfaces, and `_assertDerivedPayloadMatches()` proves the two agree.
 *
 *   TX  0     ModuleProxyFactory.deployModule   -- new "sub-Roles" Modifier instance
 *   TX  1     roles.enableModule(subRoles)
 *   TX  2-3   subRoles.setTransactionUnwrapper  -- MultiSend unwrappers
 *   TX  4     roles.setDefaultRole(subRoles, MANAGER)
 *   TX  5     roles.assignRoles(subRoles, [MANAGER], [true])
 *   TX  6     subRoles.setTarget(roles)
 *   TX  7     subRoles.transferOwnership(karpatkey)
 *   TX  8-11  scopeFunction approve()           -- WETH, USDS, sUSDS, USDC spender lists
 *   TX 12-15  kpk ETH Yield vault               -- scopeTarget + deposit/withdraw/redeem
 *   TX 16-19  kpk USDC Yield vault
 *   TX 20-21  PYUSD                             -- scopeTarget + approve(Sentora PYUSD)
 *   TX 22-25  Sentora PYUSD Main vault
 *   TX 26-27  RLUSD                             -- scopeTarget + approve(Sentora RLUSD, Horizon)
 *   TX 28-31  Sentora RLUSD Main vault
 *   TX 32-35  Smokehouse USDC vault
 *   TX 36-39  Steakhouse High Yield USDC vault
 *   TX 40-42  Aave v3 Horizon Pool              -- supply/withdraw pinned to RLUSD
 *   TX 43-46  kpk USDC Prime RWA (Euler) vault
 *   TX 47-48  PT-sUSDS-26NOV2026                -- scopeTarget + approve(Pendle Router)
 *   TX 49-52  Pendle Router V4                  -- swapExactTokenForPt / swapExactPtForToken /
 *                                                  redeemPyToToken, pinned to the sUSDS market
 *   TX 53     annotationRegistry.post           -- Morpho vault annotations
 */
contract Proposal_ENS_KPK_Update_10_Test is ENS_Governance, SafeHelper, ZodiacRolesHelper {
    // ─── Infrastructure
    // ──────────────────────────────────────────

    // Zodiac condition param types not declared by ZodiacRolesHelper
    uint8 private constant PARAM_TYPE_DYNAMIC = 2;
    uint8 private constant PARAM_TYPE_ARRAY = 4;

    address private constant MULTISEND = 0x40A2aCCbd92BCA938b02010E17A5b8929b49130D;
    address private constant ANNOTATION_REGISTRY = 0x000000000000cd17345801aa8147b8D3950260FF;
    address private constant MODULE_PROXY_FACTORY = 0x000000000000aDdB49795b0f9bA5BC298cDda236;

    /// @dev Zodiac Roles v2.1.1 mastercopy the new sub-instance is cloned from
    address private constant ROLES_MASTERCOPY = 0xF2964CE6161ce0e75964Fe7927cE114cb0B283D5;
    /// @dev EIP-1167 clone address the payload assumes for the new sub-Roles Modifier
    address private constant SUB_ROLES = 0xa5dd28EC9C69627A96202897b35B88827854bd3b;

    /// @dev Harvest role as defined in karpatkey's configuration repository: role key
    ///      and the single member listed in roles/HARVEST/members.ts
    bytes32 private constant HARVEST_ROLE = 0x4841525645535400000000000000000000000000000000000000000000000000;
    address private constant HARVEST_MEMBER = 0x14C2d2D64C4860ACF7CF39068eb467D7556197de;
    uint256 private constant SUB_ROLES_SALT_NONCE = 1_785_329_888_804;

    /// @dev MultiSend handlers registered as transaction unwrappers on the sub-instance
    address private constant MULTISEND_HANDLER_A = 0x38869bf66a61cF6bDB996A6aE40D5853Fd43B526;
    address private constant MULTISEND_HANDLER_B = 0x9641d764fc13c8B624c04430C7356C1C7C8102e2;
    address private constant MULTISEND_UNWRAPPER = 0xB4Cd4bb764C089f20DA18700CE8bc5e49F369efD;
    bytes4 private constant MULTISEND_SELECTOR = IMultiSend.multiSend.selector;

    // ─── Tokens
    // ──────────────────────────────────────────────────

    address private constant PYUSD = 0x6c3ea9036406852006290770BEdFcAbA0e23A0e8;
    address private constant RLUSD = 0x8292Bb45bf1Ee4d140127049757C2E0fF06317eD;
    address private constant SUSDS = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    address private constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private constant USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant PT_SUSDS_26NOV2026 = 0xdC169AbE56461A2E0c034Da431Ac2a3ebf596094;
    address private constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address private constant NATIVE_ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @dev CowSwap order signer (delegatecall target for `signOrder`) and a token known
    ///      to be on the current sell list, used as a control for the item 5 probes
    address private constant COWSWAP_ORDER_SIGNER = 0x23dA9AdE38E4477b23770DeD512fD37b12381FAB;

    /// @dev Named in the forum specification but absent from the published payload
    address private constant SYRUP_USDC = 0x80ac24aA929eaF5013f6436cdA2a7ba190f5Cc0b;
    address private constant SYRUP_USDT = 0x356B8d89c1e1239Cbbb9dE4815c39A1474d5BA7D;

    // ─── Yield / RWA venues
    // ──────────────────────────────────────

    address private constant KPK_ETH_YIELD = 0x5dbf760b4fd0cDdDe0366b33aEb338b2A6d77725;
    address private constant KPK_USDC_YIELD = 0xD5cCe260E7a755DDf0Fb9cdF06443d593AaeaA13;
    address private constant SENTORA_PYUSD_MAIN = 0xb576765fB15505433aF24FEe2c0325895C559FB2;
    address private constant SENTORA_RLUSD_MAIN = 0x6dC58a0FdfC8D694e571DC59B9A52EEEa780E6bf;
    address private constant SMOKEHOUSE_USDC = 0xBEeFFF209270748ddd194831b3fa287a5386f5bC;
    address private constant STEAKHOUSE_HIGH_YIELD_USDC = 0xbeeff2C5bF38f90e3482a8b19F12E5a6D2FCa757;
    address private constant KPK_USDC_PRIME_RWA = 0x2B47c128b35DDDcB66Ce2FA5B33c95314a7de245;
    address private constant AAVE_V3_HORIZON_POOL = 0xAe05Cd22df81871bc7cC2a04BeCfb516bFe332C8;

    /// @dev Address printed in the forum specification for Steakhouse High Yield USDC.
    ///      It holds no code on mainnet; the payload uses STEAKHOUSE_HIGH_YIELD_USDC instead.
    address private constant STEAKHOUSE_ADDRESS_IN_FORUM_POST = 0xbeeff7aE5E00Aae3Db302e4B0d8C883810a58100;

    // ─── Pendle
    // ──────────────────────────────────────────────────

    address private constant PENDLE_ROUTER_V4 = 0x888888888889758F76e7103c6CbF23ABbF58F946;
    address private constant PENDLE_MARKET_SUSDS = 0x9C560eBaF78e596cbcC27411d633a74D628dd7dC;
    address private constant PENDLE_YT_SUSDS = 0xC7B8551C6B286Ce0b44952320e940Bd3Dee58A09;

    // ─── Reward distributors named in the forum specification ────

    address private constant FLUID_DISTRIBUTOR = 0x7060FE0Dd3E31be01EFAc6B28C8D38018fD163B0;
    address private constant FLUID_GHO_DISTRIBUTOR = 0xF398E66B1273a34558AeBbEC550DccaF4AcC7714;
    address private constant MERKL_DISTRIBUTOR = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;

    // ─── Pre-existing spenders retained by the approve() rescopes ─

    address private constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address private constant UNISWAP_V3_ROUTER = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address private constant AAVE_V3_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address private constant BALANCER_V2_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address private constant GPV2_VAULT_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;
    address private constant MORPHO_BLUE = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address private constant AAVE_V3_POOL_L1_BRIDGE = 0xC13e21B648A5Ee794902342038FF3aDAB66BE987;
    address private constant CURVE_3POOL = 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7;
    address private constant ETHERFI_DEPOSIT_ADAPTER = 0xcfC6d9Bd7411962Bfe7145451A7EF71A24b6A7A2;

    // ─── Fork / Metadata
    // ─────────────────────────────────────────

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 25_647_900, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0x5BFCB4BE4d7B43437d5A0c57E908c048a4418390; // fireeyesdao.eth (pre-draft placeholder)
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return false;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-kpk-update-10";
    }

    // ─── Before: none of the new venues are reachable yet ────────

    function _beforeProposal() public override {
        // The sub-Roles Modifier does not exist yet.
        assertEq(SUB_ROLES.code.length, 0, "sub-Roles instance already deployed");

        // New targets are not scoped for the MANAGER role.
        _assertTargetNotAllowed(KPK_ETH_YIELD, _depositCall());
        _assertTargetNotAllowed(KPK_USDC_YIELD, _depositCall());
        _assertTargetNotAllowed(SENTORA_PYUSD_MAIN, _depositCall());
        _assertTargetNotAllowed(SENTORA_RLUSD_MAIN, _depositCall());
        _assertTargetNotAllowed(SMOKEHOUSE_USDC, _depositCall());
        _assertTargetNotAllowed(STEAKHOUSE_HIGH_YIELD_USDC, _depositCall());
        _assertTargetNotAllowed(KPK_USDC_PRIME_RWA, _depositCall());
        _assertTargetNotAllowed(PYUSD, _approveCall(SENTORA_PYUSD_MAIN));
        _assertTargetNotAllowed(RLUSD, _approveCall(SENTORA_RLUSD_MAIN));
        _assertTargetNotAllowed(PT_SUSDS_26NOV2026, _approveCall(PENDLE_ROUTER_V4));
        _assertTargetNotAllowed(
            AAVE_V3_HORIZON_POOL,
            abi.encodeWithSelector(IAaveV3Pool.supply.selector, RLUSD, uint256(1), address(endowmentSafe), uint16(0))
        );
        _assertTargetNotAllowed(PENDLE_ROUTER_V4, _redeemPyToTokenCall(SUSDS));

        // sUSDS is already a scoped target; only the Pendle spender is new.
        _assertBlocked(SUSDS, _approveCall(PENDLE_ROUTER_V4), IZodiacRoles.Status.OrViolation);

        // Item 5 is not yet in force: syrup routing and syrup approvals are unreachable.
        _assertCowSwapOrderBlocked(SYRUP_USDC, USDC);
        _assertCowSwapOrderBlocked(SYRUP_USDT, USDT);
        _assertTargetNotAllowed(SYRUP_USDC, _approveCall(GPV2_VAULT_RELAYER));
        _assertTargetNotAllowed(SYRUP_USDT, _approveCall(GPV2_VAULT_RELAYER));

        // The three "Harvest role" distributors are already reachable today.
        _assertDistributorClaimsUnchanged();

        // Existing approvals that the rescopes must preserve.
        _assertAllowed(WETH, _approveCall(GPV2_VAULT_RELAYER));
        _assertAllowed(WETH, _approveCall(AAVE_V3_POOL));
        _assertAllowed(USDC, _approveCall(GPV2_VAULT_RELAYER));
        _assertAllowed(USDC, _approveCall(AAVE_V3_POOL));
        _assertAllowed(USDC, _approveCall(MORPHO_BLUE));
        _assertAllowed(USDC, _approveCall(CURVE_3POOL));
        _assertAllowed(USDS, _approveCall(GPV2_VAULT_RELAYER));
        _assertAllowed(USDS, _approveCall(SUSDS));
        _assertAllowed(SUSDS, _approveCall(GPV2_VAULT_RELAYER));
    }

    // ─── After: new permissions are live and correctly pinned ────

    function _afterExecution() public override {
        _assertSubRolesWiring();
        _assertMorphoStyleVaults();
        _assertTokenApprovals();
        _assertAaveHorizon();
        _assertPendle();
        _assertNoSilentRemovals();
        _assertSyrupRoutingAndDistributors();
        _assertAssumedHarvestArchitecture();
    }

    /// @dev TX 0-7: the new sub-Roles Modifier and how it is chained to the existing one.
    function _assertSubRolesWiring() internal view {
        assertGt(SUB_ROLES.code.length, 0, "sub-Roles instance not deployed at the predicted address");

        IRolesAdmin sub = IRolesAdmin(SUB_ROLES);
        // Conditions on the sub-instance resolve `Avatar` to the Endowment Safe...
        assertEq(sub.avatar(), address(endowmentSafe), "sub-Roles avatar");
        // ...but execution is routed through the existing Roles Modifier.
        assertEq(sub.target(), address(roles), "sub-Roles target");
        // Ownership — and therefore the power to define roles and members on the
        // sub-instance — sits with karpatkey, not with the DAO Timelock.
        assertEq(sub.owner(), karpatkey, "sub-Roles owner");

        IRolesAdmin main = IRolesAdmin(address(roles));
        assertTrue(main.isModuleEnabled(SUB_ROLES), "sub-Roles not enabled on the main Roles Modifier");
        assertEq(main.defaultRoles(SUB_ROLES), MANAGER_ROLE, "sub-Roles default role");
    }

    /// @dev TX 12-19, 22-25, 28-39, 43-46: ERC-4626 style deposit/withdraw/redeem scopes.
    function _assertMorphoStyleVaults() internal {
        _assertVaultScope(KPK_ETH_YIELD);
        _assertVaultScope(KPK_USDC_YIELD);
        _assertVaultScope(SENTORA_PYUSD_MAIN);
        _assertVaultScope(SENTORA_RLUSD_MAIN);
        _assertVaultScope(SMOKEHOUSE_USDC);
        _assertVaultScope(STEAKHOUSE_HIGH_YIELD_USDC);
        _assertVaultScope(KPK_USDC_PRIME_RWA);
    }

    function _assertVaultScope(address vault) internal {
        // deposit(assets, receiver) — receiver must be the Safe
        _assertAllowed(vault, _depositCall());
        _assertBlocked(
            vault,
            abi.encodeWithSelector(IMetaMorphoV1.deposit.selector, uint256(1), address(0xdead)),
            IZodiacRoles.Status.ParameterNotAllowed
        );
        // withdraw(assets, receiver, owner) — both must be the Safe
        _assertAllowed(
            vault,
            abi.encodeWithSelector(
                IMetaMorphoV1.withdraw.selector, uint256(1), address(endowmentSafe), address(endowmentSafe)
            )
        );
        _assertBlocked(
            vault,
            abi.encodeWithSelector(
                IMetaMorphoV1.withdraw.selector, uint256(1), address(0xdead), address(endowmentSafe)
            ),
            IZodiacRoles.Status.ParameterNotAllowed
        );
        _assertBlocked(
            vault,
            abi.encodeWithSelector(
                IMetaMorphoV1.withdraw.selector, uint256(1), address(endowmentSafe), address(0xdead)
            ),
            IZodiacRoles.Status.ParameterNotAllowed
        );
        // redeem(shares, receiver, owner) — both must be the Safe
        _assertAllowed(
            vault,
            abi.encodeWithSelector(
                IMetaMorphoV1.redeem.selector, uint256(1), address(endowmentSafe), address(endowmentSafe)
            )
        );
        _assertBlocked(
            vault,
            abi.encodeWithSelector(IMetaMorphoV1.redeem.selector, uint256(1), address(0xdead), address(endowmentSafe)),
            IZodiacRoles.Status.ParameterNotAllowed
        );
        _assertBlocked(
            vault,
            abi.encodeWithSelector(IMetaMorphoV1.redeem.selector, uint256(1), address(endowmentSafe), address(0xdead)),
            IZodiacRoles.Status.ParameterNotAllowed
        );
        // The vaults are scoped, not allowed wholesale: transfer() stays blocked.
        _assertBlocked(
            vault,
            abi.encodeWithSelector(IERC20.transfer.selector, address(0xdead), uint256(1)),
            IZodiacRoles.Status.FunctionNotAllowed
        );
    }

    /// @dev TX 8-11, 20-21, 26-27, 47-48: approve() spender pinning.
    function _assertTokenApprovals() internal {
        // New spenders reachable
        _assertAllowed(WETH, _approveCall(KPK_ETH_YIELD));
        _assertAllowed(USDC, _approveCall(KPK_USDC_YIELD));
        _assertAllowed(USDC, _approveCall(SMOKEHOUSE_USDC));
        _assertAllowed(USDC, _approveCall(STEAKHOUSE_HIGH_YIELD_USDC));
        _assertAllowed(USDC, _approveCall(KPK_USDC_PRIME_RWA));
        _assertAllowed(USDS, _approveCall(PENDLE_ROUTER_V4));
        _assertAllowed(SUSDS, _approveCall(PENDLE_ROUTER_V4));
        _assertAllowed(PYUSD, _approveCall(SENTORA_PYUSD_MAIN));
        _assertAllowed(RLUSD, _approveCall(SENTORA_RLUSD_MAIN));
        _assertAllowed(RLUSD, _approveCall(AAVE_V3_HORIZON_POOL));
        _assertAllowed(PT_SUSDS_26NOV2026, _approveCall(PENDLE_ROUTER_V4));

        // Arbitrary spenders remain blocked on every rescoped token
        _assertBlocked(WETH, _approveCall(address(0xdead)), IZodiacRoles.Status.OrViolation);
        _assertBlocked(USDC, _approveCall(address(0xdead)), IZodiacRoles.Status.OrViolation);
        _assertBlocked(USDS, _approveCall(address(0xdead)), IZodiacRoles.Status.OrViolation);
        _assertBlocked(SUSDS, _approveCall(address(0xdead)), IZodiacRoles.Status.OrViolation);
        _assertBlocked(RLUSD, _approveCall(address(0xdead)), IZodiacRoles.Status.OrViolation);
        // Single-spender scopes use a bare EqualTo instead of an Or group
        _assertBlocked(PYUSD, _approveCall(address(0xdead)), IZodiacRoles.Status.ParameterNotAllowed);
        _assertBlocked(PT_SUSDS_26NOV2026, _approveCall(address(0xdead)), IZodiacRoles.Status.ParameterNotAllowed);

        // The newly scoped tokens expose approve() only — no transfers out of the Safe
        _assertBlocked(
            PYUSD,
            abi.encodeWithSelector(IERC20.transfer.selector, address(0xdead), uint256(1)),
            IZodiacRoles.Status.FunctionNotAllowed
        );
        _assertBlocked(
            RLUSD,
            abi.encodeWithSelector(IERC20.transfer.selector, address(0xdead), uint256(1)),
            IZodiacRoles.Status.FunctionNotAllowed
        );
        _assertBlocked(
            PT_SUSDS_26NOV2026,
            abi.encodeWithSelector(IERC20.transfer.selector, address(0xdead), uint256(1)),
            IZodiacRoles.Status.FunctionNotAllowed
        );
    }

    /// @dev TX 40-42: Aave v3 Horizon, restricted to the RLUSD reserve.
    function _assertAaveHorizon() internal {
        _assertAllowed(
            AAVE_V3_HORIZON_POOL,
            abi.encodeWithSelector(IAaveV3Pool.supply.selector, RLUSD, uint256(1), address(endowmentSafe), uint16(0))
        );
        _assertAllowed(
            AAVE_V3_HORIZON_POOL,
            abi.encodeWithSelector(IAaveV3Pool.withdraw.selector, RLUSD, uint256(1), address(endowmentSafe))
        );
        // Any other reserve is blocked — this is the stablecoin supply side only.
        _assertBlocked(
            AAVE_V3_HORIZON_POOL,
            abi.encodeWithSelector(IAaveV3Pool.supply.selector, USDC, uint256(1), address(endowmentSafe), uint16(0)),
            IZodiacRoles.Status.ParameterNotAllowed
        );
        // Supplying or withdrawing on behalf of / to a third party is blocked.
        _assertBlocked(
            AAVE_V3_HORIZON_POOL,
            abi.encodeWithSelector(IAaveV3Pool.supply.selector, RLUSD, uint256(1), address(0xdead), uint16(0)),
            IZodiacRoles.Status.ParameterNotAllowed
        );
        _assertBlocked(
            AAVE_V3_HORIZON_POOL,
            abi.encodeWithSelector(IAaveV3Pool.withdraw.selector, RLUSD, uint256(1), address(0xdead)),
            IZodiacRoles.Status.ParameterNotAllowed
        );
        // Borrowing was not granted.
        _assertBlocked(
            AAVE_V3_HORIZON_POOL,
            abi.encodeWithSignature(
                "borrow(address,uint256,uint256,uint16,address)",
                RLUSD,
                uint256(1),
                uint256(2),
                uint16(0),
                address(endowmentSafe)
            ),
            IZodiacRoles.Status.FunctionNotAllowed
        );
    }

    /// @dev TX 49-52: Pendle Router, pinned to the PT-sUSDS-26NOV2026 market.
    function _assertPendle() internal {
        // redeemPyToToken — receiver = Safe, YT pinned, tokenOut in {sUSDS, USDS}
        _assertAllowed(PENDLE_ROUTER_V4, _redeemPyToTokenCall(SUSDS));
        _assertAllowed(PENDLE_ROUTER_V4, _redeemPyToTokenCall(USDS));
        _assertBlocked(PENDLE_ROUTER_V4, _redeemPyToTokenCall(USDC), IZodiacRoles.Status.OrViolation);
        _assertBlocked(
            PENDLE_ROUTER_V4,
            abi.encodeWithSelector(
                IPendleRouterV4.redeemPyToToken.selector,
                address(0xdead),
                PENDLE_YT_SUSDS,
                uint256(1),
                _tokenOutput(SUSDS)
            ),
            IZodiacRoles.Status.ParameterNotAllowed
        );
        // A different YT (i.e. a different maturity/asset) is blocked.
        _assertBlocked(
            PENDLE_ROUTER_V4,
            abi.encodeWithSelector(
                IPendleRouterV4.redeemPyToToken.selector,
                address(endowmentSafe),
                address(0xdead),
                uint256(1),
                _tokenOutput(SUSDS)
            ),
            IZodiacRoles.Status.ParameterNotAllowed
        );

        // swapExactPtForToken — market pinned
        _assertAllowed(PENDLE_ROUTER_V4, _swapExactPtForTokenCall(PENDLE_MARKET_SUSDS, SUSDS));
        _assertBlocked(
            PENDLE_ROUTER_V4, _swapExactPtForTokenCall(address(0xdead), SUSDS), IZodiacRoles.Status.ParameterNotAllowed
        );

        // swapExactTokenForPt — market pinned, tokenIn restricted
        _assertAllowed(PENDLE_ROUTER_V4, _swapExactTokenForPtCall(PENDLE_MARKET_SUSDS, SUSDS));
        _assertAllowed(PENDLE_ROUTER_V4, _swapExactTokenForPtCall(PENDLE_MARKET_SUSDS, USDS));
        _assertBlocked(
            PENDLE_ROUTER_V4, _swapExactTokenForPtCall(PENDLE_MARKET_SUSDS, USDC), IZodiacRoles.Status.OrViolation
        );
        _assertBlocked(
            PENDLE_ROUTER_V4, _swapExactTokenForPtCall(address(0xdead), SUSDS), IZodiacRoles.Status.ParameterNotAllowed
        );

        // The external-aggregator escape hatch inside TokenInput is pinned shut:
        // a non-zero pendleSwap would let the router call arbitrary calldata.
        IPendleRouterV4.TokenInput memory input = _tokenInput(SUSDS);
        input.pendleSwap = address(0xdead);
        _assertBlocked(
            PENDLE_ROUTER_V4,
            abi.encodeWithSelector(
                IPendleRouterV4.swapExactTokenForPt.selector,
                address(endowmentSafe),
                PENDLE_MARKET_SUSDS,
                uint256(0),
                _approxParams(),
                input,
                _limitOrderData()
            ),
            IZodiacRoles.Status.ParameterNotAllowed
        );

        // Liquidity provision on the Pendle market was not granted.
        _assertBlocked(
            PENDLE_ROUTER_V4,
            abi.encodeWithSignature("redeemDueInterestAndRewards(address,address[],address[],address[])"),
            IZodiacRoles.Status.FunctionNotAllowed
        );
    }

    /// @dev Spot-check that the four approve() rescopes did not drop existing spenders.
    function _assertNoSilentRemovals() internal {
        _assertAllowed(WETH, _approveCall(GPV2_VAULT_RELAYER));
        _assertAllowed(WETH, _approveCall(AAVE_V3_POOL));
        _assertAllowed(WETH, _approveCall(PERMIT2));
        _assertAllowed(WETH, _approveCall(BALANCER_V2_VAULT));
        _assertAllowed(WETH, _approveCall(UNISWAP_V3_ROUTER));
        _assertAllowed(WETH, _approveCall(MORPHO_BLUE));
        _assertAllowed(WETH, _approveCall(ETHERFI_DEPOSIT_ADAPTER));
        _assertAllowed(USDC, _approveCall(GPV2_VAULT_RELAYER));
        _assertAllowed(USDC, _approveCall(AAVE_V3_POOL));
        _assertAllowed(USDC, _approveCall(MORPHO_BLUE));
        _assertAllowed(USDC, _approveCall(CURVE_3POOL));
        _assertAllowed(USDC, _approveCall(BALANCER_V2_VAULT));
        _assertAllowed(USDC, _approveCall(UNISWAP_V3_ROUTER));
        _assertAllowed(USDS, _approveCall(GPV2_VAULT_RELAYER));
        _assertAllowed(USDS, _approveCall(SUSDS));
        _assertAllowed(USDS, _approveCall(AAVE_V3_POOL));
        _assertAllowed(USDS, _approveCall(UNISWAP_V3_ROUTER));
        _assertAllowed(SUSDS, _approveCall(GPV2_VAULT_RELAYER));
        _assertAllowed(SUSDS, _approveCall(UNISWAP_V3_ROUTER));
    }

    /// @dev Item 5 as implemented by the regenerated payload, and item 6 as left unchanged.
    function _assertSyrupRoutingAndDistributors() internal {
        // Item 6 — "Reward Claims (new Harvest role)": the payload still adds no distributor
        // permission. The three claims remain reachable exactly as they were before, with
        // payouts pinned to the Safe; the sub-Roles Modifier is deployed empty.
        _assertDistributorClaimsUnchanged();

        // Item 5 — the syrup tokens are tradable, but only against their own underlying.
        _assertCowSwapOrderPermitted(SYRUP_USDC, USDC);
        _assertCowSwapOrderPermitted(USDC, SYRUP_USDC);
        _assertCowSwapOrderPermitted(SYRUP_USDT, USDT);
        _assertCowSwapOrderPermitted(USDT, SYRUP_USDT);
        // The pre-existing general lists still work.
        _assertCowSwapOrderPermitted(USDC, WETH);

        // Cross-pair and unrelated routes are rejected: syrup tokens were NOT merged into
        // the general sell/buy lists, so no syrup-for-anything-else order can be signed.
        _assertCowSwapOrderBlocked(SYRUP_USDC, WETH);
        _assertCowSwapOrderBlocked(SYRUP_USDC, USDT);
        _assertCowSwapOrderBlocked(SYRUP_USDT, WETH);
        _assertCowSwapOrderBlocked(SYRUP_USDT, USDC);
        _assertCowSwapOrderBlocked(SYRUP_USDC, SYRUP_USDT);
        // Receiver pinning still applies inside the new pair branches.
        _assertCowSwapOrderBlockedTo(SYRUP_USDC, USDC, address(0xdead));

        // The syrup tokens are scoped targets whose only permitted call is approve() to
        // the CoW vault relayer.
        _assertAllowed(SYRUP_USDC, _approveCall(GPV2_VAULT_RELAYER));
        _assertAllowed(SYRUP_USDT, _approveCall(GPV2_VAULT_RELAYER));
        _assertBlocked(SYRUP_USDC, _approveCall(address(0xdead)), IZodiacRoles.Status.ParameterNotAllowed);
        _assertBlocked(SYRUP_USDT, _approveCall(address(0xdead)), IZodiacRoles.Status.ParameterNotAllowed);
        _assertBlocked(
            SYRUP_USDC,
            abi.encodeWithSelector(IERC20.transfer.selector, address(0xdead), uint256(1)),
            IZodiacRoles.Status.FunctionNotAllowed
        );
        _assertBlocked(
            SYRUP_USDT,
            abi.encodeWithSelector(IERC20.transfer.selector, address(0xdead), uint256(1)),
            IZodiacRoles.Status.FunctionNotAllowed
        );
    }

    /// @dev Working assumption for finding 1: the sub-Roles instance will host the
    ///      Harvest role of item 6, configured by kpk (its owner) after execution and
    ///      outside the DAO vote. This simulates that configuration and proves the
    ///      resulting two-layer permission chain:
    ///
    ///        HARVEST_MEMBER -> sub-Roles (HARVEST conditions)
    ///                       -> main Roles (MANAGER conditions, as sub's default role)
    ///                       -> Endowment Safe
    ///
    ///      The sub-role is configured deliberately permissively (whole distributor
    ///      targets allowed, no argument conditions) to show that even a lax or
    ///      malicious configuration cannot redirect payouts: the existing MANAGER
    ///      conditions on the main modifier independently pin the recipient.
    function _assertAssumedHarvestArchitecture() internal {
        // kpk, as owner of the sub-instance, configures the Harvest role.
        bytes32[] memory keys = new bytes32[](1);
        keys[0] = HARVEST_ROLE;
        bool[] memory member = new bool[](1);
        member[0] = true;
        vm.startPrank(karpatkey);
        IRolesAdmin(SUB_ROLES).assignRoles(HARVEST_MEMBER, keys, member);
        IRolesAdmin(SUB_ROLES).allowTarget(HARVEST_ROLE, FLUID_DISTRIBUTOR, EXEC_NONE);
        IRolesAdmin(SUB_ROLES).allowTarget(HARVEST_ROLE, FLUID_GHO_DISTRIBUTOR, EXEC_NONE);
        IRolesAdmin(SUB_ROLES).allowTarget(HARVEST_ROLE, MERKL_DISTRIBUTOR, EXEC_NONE);
        vm.stopPrank();

        vm.startPrank(HARVEST_MEMBER);

        // Claims with the payout directed to the Safe pass both layers.
        uint256 snap = vm.snapshot();
        IZodiacRoles(SUB_ROLES)
            .execTransactionWithRole(
                FLUID_DISTRIBUTOR,
                0,
                _fluidClaimCall(address(endowmentSafe)),
                IZodiacRoles.Operation.Call,
                HARVEST_ROLE,
                false
            );
        vm.revertTo(snap);
        snap = vm.snapshot();
        IZodiacRoles(SUB_ROLES)
            .execTransactionWithRole(
                MERKL_DISTRIBUTOR,
                0,
                _merklClaimCall(address(endowmentSafe)),
                IZodiacRoles.Operation.Call,
                HARVEST_ROLE,
                false
            );
        vm.revertTo(snap);

        // A redirected payout is rejected by the MAIN layer even though the sub-role
        // allows the whole target: defense in depth holds.
        _expectConditionViolation(IZodiacRoles.Status.ParameterNotAllowed);
        IZodiacRoles(SUB_ROLES)
            .execTransactionWithRole(
                FLUID_DISTRIBUTOR, 0, _fluidClaimCall(address(0xdead)), IZodiacRoles.Operation.Call, HARVEST_ROLE, false
            );
        _expectConditionViolation(IZodiacRoles.Status.OrViolation);
        IZodiacRoles(SUB_ROLES)
            .execTransactionWithRole(
                MERKL_DISTRIBUTOR, 0, _merklClaimCall(address(0xdead)), IZodiacRoles.Operation.Call, HARVEST_ROLE, false
            );

        // Anything beyond the distributors is rejected by the SUB layer: the Harvest
        // member holds no access to the wider Endowment Manager permission set.
        _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
        IZodiacRoles(SUB_ROLES)
            .execTransactionWithRole(
                KPK_USDC_YIELD, 0, _depositCall(), IZodiacRoles.Operation.Call, HARVEST_ROLE, false
            );
        _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
        IZodiacRoles(SUB_ROLES)
            .execTransactionWithRole(
                USDC, 0, _approveCall(GPV2_VAULT_RELAYER), IZodiacRoles.Operation.Call, HARVEST_ROLE, false
            );

        vm.stopPrank();
    }

    // ─── Assertion primitives
    // ────────────────────────────────────

    function _assertCowSwapOrderBlockedTo(address sell, address buy, address receiver) internal {
        vm.startPrank(karpatkey);
        _expectConditionViolation(IZodiacRoles.Status.OrViolation);
        roles.execTransactionWithRole(
            COWSWAP_ORDER_SIGNER,
            0,
            abi.encodeWithSelector(
                ICowSwapOrderSigner.signOrder.selector, _buildCowSwapOrderTo(sell, buy, receiver), uint32(0), uint256(0)
            ),
            IZodiacRoles.Operation.DelegateCall,
            MANAGER_ROLE,
            false
        );
        vm.stopPrank();
    }

    function _assertCowSwapOrderBlocked(address sell, address buy) internal {
        vm.startPrank(karpatkey);
        _expectConditionViolation(IZodiacRoles.Status.OrViolation);
        roles.execTransactionWithRole(
            COWSWAP_ORDER_SIGNER,
            0,
            abi.encodeWithSelector(
                ICowSwapOrderSigner.signOrder.selector, _buildCowSwapOrder(sell, buy), uint32(0), uint256(0)
            ),
            IZodiacRoles.Operation.DelegateCall,
            MANAGER_ROLE,
            false
        );
        vm.stopPrank();
    }

    function _assertCowSwapOrderPermitted(address sell, address buy) internal {
        vm.startPrank(karpatkey);
        uint256 snap = vm.snapshot();
        roles.execTransactionWithRole(
            COWSWAP_ORDER_SIGNER,
            0,
            abi.encodeWithSelector(
                ICowSwapOrderSigner.signOrder.selector, _buildCowSwapOrder(sell, buy), uint32(0), uint256(0)
            ),
            IZodiacRoles.Operation.DelegateCall,
            MANAGER_ROLE,
            false
        );
        vm.revertTo(snap);
        vm.stopPrank();
    }

    function _buildCowSwapOrder(address sell, address buy) internal view returns (ICowSwapOrderSigner.Data memory) {
        return _buildCowSwapOrderTo(sell, buy, address(endowmentSafe));
    }

    function _buildCowSwapOrderTo(
        address sell,
        address buy,
        address receiver
    )
        internal
        pure
        returns (ICowSwapOrderSigner.Data memory)
    {
        return ICowSwapOrderSigner.Data({
            sellToken: IERC20(sell),
            buyToken: IERC20(buy),
            receiver: receiver,
            sellAmount: 0,
            buyAmount: 0,
            validTo: 0,
            appData: bytes32(0),
            feeAmount: 0,
            kind: bytes32(0),
            partiallyFillable: false,
            sellTokenBalance: bytes32(0),
            buyTokenBalance: bytes32(0)
        });
    }

    function _assertTargetNotAllowed(address target, bytes memory data) internal {
        _assertBlocked(target, data, IZodiacRoles.Status.TargetAddressNotAllowed);
    }

    /// @dev A distributor is unreachable either because the target is unscoped or because
    ///      `claim` was never permissioned on it. Both outcomes mean the forum's Harvest
    ///      role is not in force; the distinction is recorded for the report.
    /// @dev The three distributors named under the forum's "new Harvest role" are already
    ///      reachable on the MANAGER role, with the payout recipient pinned to the Safe.
    ///      This proposal changes none of that.
    function _assertDistributorClaimsUnchanged() internal {
        _assertAllowed(FLUID_DISTRIBUTOR, _fluidClaimCall(address(endowmentSafe)));
        _assertAllowed(FLUID_GHO_DISTRIBUTOR, _fluidClaimCall(address(endowmentSafe)));
        _assertAllowed(MERKL_DISTRIBUTOR, _merklClaimCall(address(endowmentSafe)));

        // A foreign payout recipient is rejected on all three, either by a bare
        // EqualTo on the recipient or by an Or group of permitted recipients.
        _assertRecipientRejected(FLUID_DISTRIBUTOR, _fluidClaimCall(address(0xdead)));
        _assertRecipientRejected(FLUID_GHO_DISTRIBUTOR, _fluidClaimCall(address(0xdead)));
        _assertRecipientRejected(MERKL_DISTRIBUTOR, _merklClaimCall(address(0xdead)));
    }

    function _assertRecipientRejected(address distributor, bytes memory data) internal {
        vm.prank(karpatkey);
        try roles.execTransactionWithRole(distributor, 0, data, IZodiacRoles.Operation.Call, MANAGER_ROLE, false) {
            revert("foreign payout recipient unexpectedly permitted");
        } catch (bytes memory err) {
            bytes memory args = new bytes(err.length - 4);
            for (uint256 i = 4; i < err.length; i++) {
                args[i - 4] = err[i];
            }
            (IZodiacRoles.Status status,) = abi.decode(args, (IZodiacRoles.Status, bytes32));
            assertTrue(
                status == IZodiacRoles.Status.ParameterNotAllowed || status == IZodiacRoles.Status.OrViolation,
                "foreign recipient blocked for an unexpected reason"
            );
        }
    }

    function _assertBlocked(address target, bytes memory data, IZodiacRoles.Status status) internal {
        vm.startPrank(karpatkey);
        if (status == IZodiacRoles.Status.FunctionNotAllowed) {
            // FunctionNotAllowed carries the selector in the `info` field.
            vm.expectRevert(
                abi.encodeWithSelector(IZodiacRoles.ConditionViolation.selector, status, bytes32(bytes4(data)))
            );
        } else {
            _expectConditionViolation(status);
        }
        roles.execTransactionWithRole(target, 0, data, IZodiacRoles.Operation.Call, MANAGER_ROLE, false);
        vm.stopPrank();
    }

    function _assertAllowed(address target, bytes memory data) internal {
        vm.startPrank(karpatkey);
        _safeExecuteTransaction(target, data);
        vm.stopPrank();
    }

    // ─── Call builders used by the assertions ────────────────────

    function _approveCall(address spender) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(IERC20.approve.selector, spender, uint256(1));
    }

    function _depositCall() internal view returns (bytes memory) {
        return abi.encodeWithSelector(IMetaMorphoV1.deposit.selector, uint256(1), address(endowmentSafe));
    }

    /// @dev Fluid Merkle distributor: claim(recipient, cumulativeAmount, positionType,
    ///      positionId, cycle, merkleProof, metadata)
    function _fluidClaimCall(address recipient) internal pure returns (bytes memory) {
        return abi.encodeWithSignature(
            "claim(address,uint256,uint8,bytes32,uint256,bytes32[],bytes)",
            recipient,
            uint256(0),
            uint8(0),
            bytes32(0),
            uint256(0),
            new bytes32[](0),
            bytes("")
        );
    }

    function _merklClaimCall(address user) internal pure returns (bytes memory) {
        address[] memory users = new address[](1);
        users[0] = user;
        return abi.encodeWithSelector(
            IMerklDistributor.claim.selector, users, new address[](1), new uint256[](1), new bytes32[][](1)
        );
    }

    function _swapData() internal pure returns (IPendleRouterV4.SwapData memory) {
        return IPendleRouterV4.SwapData({ swapType: 0, extRouter: address(0), extCalldata: "", needScale: false });
    }

    function _tokenInput(address token) internal pure returns (IPendleRouterV4.TokenInput memory) {
        return IPendleRouterV4.TokenInput({
            tokenIn: token, netTokenIn: 1, tokenMintSy: token, pendleSwap: address(0), swapData: _swapData()
        });
    }

    function _tokenOutput(address token) internal pure returns (IPendleRouterV4.TokenOutput memory) {
        return IPendleRouterV4.TokenOutput({
            tokenOut: token, minTokenOut: 0, tokenRedeemSy: token, pendleSwap: address(0), swapData: _swapData()
        });
    }

    function _approxParams() internal pure returns (IPendleRouterV4.ApproxParams memory) {
        return IPendleRouterV4.ApproxParams({ guessMin: 0, guessMax: 0, guessOffchain: 0, maxIteration: 0, eps: 0 });
    }

    function _limitOrderData() internal pure returns (IPendleRouterV4.LimitOrderData memory) {
        return IPendleRouterV4.LimitOrderData({
            limitRouter: address(0),
            epsSkipMarket: 0,
            normalFills: new IPendleRouterV4.FillOrderParams[](0),
            flashFills: new IPendleRouterV4.FillOrderParams[](0),
            optData: ""
        });
    }

    function _redeemPyToTokenCall(address tokenOut) internal view returns (bytes memory) {
        return abi.encodeWithSelector(
            IPendleRouterV4.redeemPyToToken.selector,
            address(endowmentSafe),
            PENDLE_YT_SUSDS,
            uint256(1),
            _tokenOutput(tokenOut)
        );
    }

    function _swapExactPtForTokenCall(address market, address tokenOut) internal view returns (bytes memory) {
        return abi.encodeWithSelector(
            IPendleRouterV4.swapExactPtForToken.selector,
            address(endowmentSafe),
            market,
            uint256(1),
            _tokenOutput(tokenOut),
            _limitOrderData()
        );
    }

    function _swapExactTokenForPtCall(address market, address tokenIn) internal view returns (bytes memory) {
        return abi.encodeWithSelector(
            IPendleRouterV4.swapExactTokenForPt.selector,
            address(endowmentSafe),
            market,
            uint256(0),
            _approxParams(),
            _tokenInput(tokenIn),
            _limitOrderData()
        );
    }

    // ─── Generated Calldata
    // ──────────────────────────────────────

    function _generateCallData()
        public
        override
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory, string memory)
    {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        signatures = new string[](1);

        bytes memory multiSendTransactions = _buildMultiSendTransactions();
        _assertDerivedPayloadMatches(multiSendTransactions);

        bytes memory multiSendData = abi.encodeWithSelector(IMultiSend.multiSend.selector, multiSendTransactions);

        (targets[0], calldatas[0]) =
            _buildSafeExecDelegateCalldata(address(endowmentSafe), MULTISEND, multiSendData, address(timelock));
        values[0] = 0;
        signatures[0] = "";
        description = "Pre-draft: [Executable] Endowment permissions to kpk - Update #10";

        return (targets, values, signatures, calldatas, description);
    }

    /// @notice Diff the manually derived MultiSend body against the payload published
    ///         with the forum post (re-encoded verbatim into expectedMultiSend.txt).
    function _assertDerivedPayloadMatches(bytes memory derived) internal view {
        bytes memory expected = vm.parseBytes(vm.readFile(string.concat(dirPath(), "/expectedMultiSend.txt")));
        assertEq(derived.length, expected.length, "derived MultiSend length differs from published payload");
        assertEq(keccak256(derived), keccak256(expected), "derived MultiSend differs from published payload");
    }

    // ─── MultiSend Bundle Assembly
    // ───────────────────────────────

    function _buildMultiSendTransactions() internal returns (bytes memory) {
        return bytes.concat(
            _buildSubRolesSetup(), // TX  0-7
            _buildApproveRescopes(), // TX  8-12 (CoW signOrder rescope sits at TX 11)
            _buildSyrupScopes(), // TX 13-16
            _buildEthAndUsdcYieldVaults(), // TX 17-24
            _buildPyusdAndSentora(), // TX 25-30
            _buildRlusdAndSentora(), // TX 31-36
            _buildUsdcVaults(), // TX 37-44
            _buildAaveHorizon(), // TX 45-47
            _buildEulerRwaVault(), // TX 48-51
            _buildPendle(), // TX 52-57
            _buildAnnotationAddition() // TX 58
        );
    }

    /// @dev TX 0-7 — deploy the sub-Roles Modifier and chain it under MANAGER.
    function _buildSubRolesSetup() internal view returns (bytes memory) {
        // Roles.setUp(abi.encode(owner, avatar, target)); all three start as the Safe.
        bytes memory initializer = abi.encodeWithSelector(
            IRolesAdmin.setUp.selector,
            abi.encode(address(endowmentSafe), address(endowmentSafe), address(endowmentSafe))
        );

        bytes32[] memory roleKeys = new bytes32[](1);
        roleKeys[0] = MANAGER_ROLE;
        bool[] memory memberOf = new bool[](1);
        memberOf[0] = true;

        return bytes.concat(
            _packTx(
                MODULE_PROXY_FACTORY,
                abi.encodeWithSelector(
                    IModuleProxyFactory.deployModule.selector, ROLES_MASTERCOPY, initializer, SUB_ROLES_SALT_NONCE
                )
            ),
            _packTx(address(roles), abi.encodeWithSelector(IRolesAdmin.enableModule.selector, SUB_ROLES)),
            _packTx(
                SUB_ROLES,
                abi.encodeWithSelector(
                    IRolesModifier.setTransactionUnwrapper.selector,
                    MULTISEND_HANDLER_A,
                    MULTISEND_SELECTOR,
                    MULTISEND_UNWRAPPER
                )
            ),
            _packTx(
                SUB_ROLES,
                abi.encodeWithSelector(
                    IRolesModifier.setTransactionUnwrapper.selector,
                    MULTISEND_HANDLER_B,
                    MULTISEND_SELECTOR,
                    MULTISEND_UNWRAPPER
                )
            ),
            _packTx(
                address(roles), abi.encodeWithSelector(IRolesAdmin.setDefaultRole.selector, SUB_ROLES, MANAGER_ROLE)
            ),
            _packTx(
                    address(roles),
                    abi.encodeWithSelector(IRolesAdmin.assignRoles.selector, SUB_ROLES, roleKeys, memberOf)
                ),
            _packTx(SUB_ROLES, abi.encodeWithSelector(IRolesAdmin.setTarget.selector, address(roles))),
            _packTx(SUB_ROLES, abi.encodeWithSelector(IRolesAdmin.transferOwnership.selector, karpatkey))
        );
    }

    /// @dev TX 8-12 — approve() spender lists for WETH, USDS, sUSDS, USDC, with the
    ///      CoW signOrder rescope interleaved at TX 11.
    function _buildApproveRescopes() internal pure returns (bytes memory) {
        return bytes.concat(
            _scopeApprove(WETH, _wethApproveSpenders()),
            _scopeApprove(USDS, _usdsApproveSpenders()),
            _scopeApprove(SUSDS, _susdsApproveSpenders()),
            _buildCowSwapSignOrderScope(),
            _scopeApprove(USDC, _usdcApproveSpenders())
        );
    }

    /// @dev TX 11 — CoW Protocol signOrder, delegatecall-scoped. The syrup tokens are NOT
    ///      merged into the general sell/buy lists: they are added as two isolated pairs,
    ///      so syrupUSDC may only be traded against USDC and syrupUSDT only against USDT.
    function _buildCowSwapSignOrderScope() internal pure returns (bytes memory) {
        return _packTx(
            address(roles),
            abi.encodeWithSelector(
                IRolesModifier.scopeFunction.selector,
                MANAGER_ROLE,
                COWSWAP_ORDER_SIGNER,
                ICowSwapOrderSigner.signOrder.selector,
                _buildCowSwapSignOrderConditions(),
                EXEC_DELEGATE_CALL
            )
        );
    }

    /// @dev TX 13-16 — the syrup tokens become scoped targets whose only permitted call is
    ///      approve() to the CoW vault relayer.
    function _buildSyrupScopes() internal pure returns (bytes memory) {
        address[] memory relayer = new address[](1);
        relayer[0] = GPV2_VAULT_RELAYER;
        return bytes.concat(
            _scopeTarget(SYRUP_USDC),
            _scopeApprove(SYRUP_USDC, relayer),
            _scopeTarget(SYRUP_USDT),
            _scopeApprove(SYRUP_USDT, relayer)
        );
    }

    /// @dev signOrder condition tree, 93 nodes. Root MATCHES over a single Data tuple
    ///      parameter, which is an OR of three alternative shapes:
    ///        [2] syrupUSDT/USDT pair, receiver = Avatar
    ///        [3] syrupUSDC/USDC pair, receiver = Avatar
    ///        [4] the pre-existing general lists (27 sell, 17 buy), receiver = Avatar
    function _buildCowSwapSignOrderConditions() internal pure returns (ConditionFlat[] memory) {
        address[] memory sell = _cowSwapSellTokens();
        address[] memory buy = _cowSwapBuyTokens();
        ConditionFlat[] memory c = new ConditionFlat[](93);
        uint256 i = 0;

        c[i++] = ConditionFlat(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[i++] = ConditionFlat(0, PARAM_TYPE_NONE, OP_OR, "");
        // [2-4] the three alternative Data shapes
        for (uint8 v = 0; v < 3; v++) {
            c[i++] = ConditionFlat(1, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        }
        // [5-40] each variant: sellToken OR, buyToken OR, receiver = Avatar, 9 x PASS
        for (uint8 v = 2; v <= 4; v++) {
            c[i++] = ConditionFlat(v, PARAM_TYPE_NONE, OP_OR, "");
            c[i++] = ConditionFlat(v, PARAM_TYPE_NONE, OP_OR, "");
            c[i++] = ConditionFlat(v, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
            for (uint256 j = 0; j < 9; j++) {
                c[i++] = ConditionFlat(v, PARAM_TYPE_STATIC, OP_PASS, "");
            }
        }
        // [41-48] the two isolated pairs, sell then buy for each variant
        i = _appendPair(c, i, 5, SYRUP_USDT, USDT);
        i = _appendPair(c, i, 6, SYRUP_USDT, USDT);
        i = _appendPair(c, i, 17, SYRUP_USDC, USDC);
        i = _appendPair(c, i, 18, SYRUP_USDC, USDC);
        // [49-92] the pre-existing general lists
        for (uint256 j = 0; j < sell.length; j++) {
            c[i++] = ConditionFlat(29, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(sell[j]));
        }
        for (uint256 j = 0; j < buy.length; j++) {
            c[i++] = ConditionFlat(30, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(buy[j]));
        }

        require(i == 93, "signOrder condition count");
        return c;
    }

    function _appendPair(
        ConditionFlat[] memory c,
        uint256 i,
        uint8 parent,
        address a,
        address b
    )
        internal
        pure
        returns (uint256)
    {
        c[i++] = ConditionFlat(parent, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(a));
        c[i++] = ConditionFlat(parent, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(b));
        return i;
    }

    /// @dev 27 sell tokens, unchanged from Update #9, sorted ascending.
    function _cowSwapSellTokens() internal pure returns (address[] memory) {
        address[] memory t = new address[](27);
        t[0] = 0x35fA164735182de50811E8e2E824cFb9B6118ac2; // eETH
        t[1] = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f; // GHO
        t[2] = 0x48C3399719B582dD63eB5AADf12A40B4C3f52FA2; // SWISE
        t[3] = 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B; // CVX
        t[4] = 0x58D97B57BB95320F9a05dC918Aef65434969c2B2; // MORPHO
        t[5] = 0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32; // LDO
        t[6] = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // DAI
        t[7] = 0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb; // FLUID
        t[8] = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0; // wstETH
        t[9] = 0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3; // OETH
        t[10] = USDC;
        t[11] = 0xA35b1B31Ce002FBF2058D22F30f95D405200A15b; // ETHx
        t[12] = SUSDS;
        t[13] = 0xae78736Cd615f374D3085123A210448E74Fc6393; // rETH
        t[14] = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84; // stETH
        t[15] = 0xba100000625a3754423978a60c9317c58a424e3D; // BAL
        t[16] = 0xc00e94Cb662C3520282E6f5717214004A7f26888; // COMP
        t[17] = WETH;
        t[18] = 0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF; // AURA
        t[19] = 0xc20059e0317DE91738d13af027DfC4a50781b066; // SPK
        t[20] = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee; // weETH
        t[21] = 0xD33526068D116cE69F19A9ee46F0bd304F21A51f; // RPL
        t[22] = 0xD533a949740bb3306d119CC777fa900bA034cd52; // CRV
        t[23] = USDT;
        t[24] = USDS;
        t[25] = 0xE95A203B1a91a908F9B9CE46459d101078c2c3cb; // ankrETH
        t[26] = 0xf1C9acDc66974dFB6dEcB12aA385b9cD01190E38; // osETH
        return t;
    }

    /// @dev 17 buy tokens, unchanged from Update #9, sorted ascending.
    function _cowSwapBuyTokens() internal pure returns (address[] memory) {
        address[] memory t = new address[](17);
        t[0] = 0x35fA164735182de50811E8e2E824cFb9B6118ac2;
        t[1] = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;
        t[2] = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        t[3] = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
        t[4] = 0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3;
        t[5] = USDC;
        t[6] = 0xA35b1B31Ce002FBF2058D22F30f95D405200A15b;
        t[7] = SUSDS;
        t[8] = 0xae78736Cd615f374D3085123A210448E74Fc6393;
        t[9] = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
        t[10] = WETH;
        t[11] = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
        t[12] = USDT;
        t[13] = USDS;
        t[14] = 0xE95A203B1a91a908F9B9CE46459d101078c2c3cb;
        t[15] = NATIVE_ETH;
        t[16] = 0xf1C9acDc66974dFB6dEcB12aA385b9cD01190E38;
        return t;
    }

    /// @dev TX 12-19
    function _buildEthAndUsdcYieldVaults() internal pure returns (bytes memory) {
        return bytes.concat(_scopeVault(KPK_ETH_YIELD), _scopeVault(KPK_USDC_YIELD));
    }

    /// @dev TX 20-25
    function _buildPyusdAndSentora() internal pure returns (bytes memory) {
        address[] memory spenders = new address[](1);
        spenders[0] = SENTORA_PYUSD_MAIN;
        return bytes.concat(_scopeTarget(PYUSD), _scopeApprove(PYUSD, spenders), _scopeVault(SENTORA_PYUSD_MAIN));
    }

    /// @dev TX 26-31
    function _buildRlusdAndSentora() internal pure returns (bytes memory) {
        address[] memory spenders = new address[](2);
        spenders[0] = SENTORA_RLUSD_MAIN;
        spenders[1] = AAVE_V3_HORIZON_POOL;
        return bytes.concat(_scopeTarget(RLUSD), _scopeApprove(RLUSD, spenders), _scopeVault(SENTORA_RLUSD_MAIN));
    }

    /// @dev TX 32-39
    function _buildUsdcVaults() internal pure returns (bytes memory) {
        return bytes.concat(_scopeVault(SMOKEHOUSE_USDC), _scopeVault(STEAKHOUSE_HIGH_YIELD_USDC));
    }

    /// @dev TX 40-42 — supply/withdraw pinned to the RLUSD reserve, beneficiary = Avatar.
    function _buildAaveHorizon() internal pure returns (bytes memory) {
        ConditionFlat[] memory supplyConditions = new ConditionFlat[](4);
        supplyConditions[0] = ConditionFlat(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        supplyConditions[1] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(RLUSD));
        supplyConditions[2] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_PASS, "");
        supplyConditions[3] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");

        return bytes.concat(
            _scopeTarget(AAVE_V3_HORIZON_POOL),
            _scopeFunction(AAVE_V3_HORIZON_POOL, IAaveV3Pool.supply.selector, supplyConditions),
            // withdraw(asset, amount, to) has the same three leading params
            _scopeFunction(AAVE_V3_HORIZON_POOL, IAaveV3Pool.withdraw.selector, supplyConditions)
        );
    }

    /// @dev TX 43-46
    function _buildEulerRwaVault() internal pure returns (bytes memory) {
        return _scopeVault(KPK_USDC_PRIME_RWA);
    }

    /// @dev TX 47-52
    function _buildPendle() internal pure returns (bytes memory) {
        address[] memory ptSpender = new address[](1);
        ptSpender[0] = PENDLE_ROUTER_V4;

        return bytes.concat(
            _scopeTarget(PT_SUSDS_26NOV2026),
            _scopeApprove(PT_SUSDS_26NOV2026, ptSpender),
            _scopeTarget(PENDLE_ROUTER_V4),
            _scopeFunction(
                PENDLE_ROUTER_V4, IPendleRouterV4.swapExactTokenForPt.selector, _swapExactTokenForPtConditions()
            ),
            _scopeFunction(
                PENDLE_ROUTER_V4, IPendleRouterV4.swapExactPtForToken.selector, _swapExactPtForTokenConditions()
            ),
            _scopeFunction(PENDLE_ROUTER_V4, IPendleRouterV4.redeemPyToToken.selector, _redeemPyToTokenConditions())
        );
    }

    /// @dev TX 53
    function _buildAnnotationAddition() internal view returns (bytes memory) {
        string memory payload = vm.readFile(string.concat(dirPath(), "/annotationAddition.json"));
        return _packTx(
            ANNOTATION_REGISTRY,
            abi.encodeWithSelector(IAnnotationRegistry.post.selector, payload, "ROLES_PERMISSION_ANNOTATION")
        );
    }

    // ─── Scoping primitives
    // ──────────────────────────────────────

    function _scopeTarget(address target) internal pure returns (bytes memory) {
        return
            _packTx(address(roles), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, target));
    }

    function _scopeFunction(
        address target,
        bytes4 selector,
        ConditionFlat[] memory conditions
    )
        internal
        pure
        returns (bytes memory)
    {
        return _packTx(
            address(roles),
            abi.encodeWithSelector(
                IRolesModifier.scopeFunction.selector, MANAGER_ROLE, target, selector, conditions, EXEC_NONE
            )
        );
    }

    /// @dev approve(spender, amount) with the spender pinned to a whitelist.
    ///      A single entry is expressed as a bare EqualTo; two or more as an Or group.
    function _scopeApprove(address token, address[] memory spenders) internal pure returns (bytes memory) {
        ConditionFlat[] memory conditions;
        if (spenders.length == 1) {
            conditions = new ConditionFlat[](2);
            conditions[0] = ConditionFlat(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
            conditions[1] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(spenders[0]));
        } else {
            conditions = new ConditionFlat[](2 + spenders.length);
            conditions[0] = ConditionFlat(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
            conditions[1] = ConditionFlat(0, PARAM_TYPE_NONE, OP_OR, "");
            for (uint256 i = 0; i < spenders.length; i++) {
                conditions[2 + i] = ConditionFlat(1, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(spenders[i]));
            }
        }
        return _scopeFunction(token, IERC20.approve.selector, conditions);
    }

    /// @dev scopeTarget + deposit/withdraw/redeem with receiver and owner pinned to the Avatar.
    function _scopeVault(address vault) internal pure returns (bytes memory) {
        ConditionFlat[] memory depositConditions = new ConditionFlat[](3);
        depositConditions[0] = ConditionFlat(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        depositConditions[1] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_PASS, "");
        depositConditions[2] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");

        ConditionFlat[] memory exitConditions = new ConditionFlat[](4);
        exitConditions[0] = ConditionFlat(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        exitConditions[1] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_PASS, "");
        exitConditions[2] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        exitConditions[3] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");

        return bytes.concat(
            _scopeTarget(vault),
            _scopeFunction(vault, IMetaMorphoV1.deposit.selector, depositConditions),
            _scopeFunction(vault, IMetaMorphoV1.withdraw.selector, exitConditions),
            _scopeFunction(vault, IMetaMorphoV1.redeem.selector, exitConditions)
        );
    }

    // ─── Pendle condition trees
    // ──────────────────────────────────
    //
    // Shared shape across the three Pendle functions:
    //   receiver          = Avatar
    //   market / YT       = pinned to the PT-sUSDS-26NOV2026 instance
    //   tokenIn/tokenOut  } in {sUSDS, USDS}
    //   tokenMintSy/RedeemSy
    //   pendleSwap        = address(0)   -- no external aggregator
    //   swapData.swapType = 0, extRouter = address(0), extCalldata = ""
    //   limit.limitRouter = address(0), normalFills = flashFills = []

    /// @dev abi.encode of an empty dynamic value: offset 0x20 followed by length 0.
    function _emptyDynamic() internal pure returns (bytes memory) {
        return abi.encode(bytes(""));
    }

    /// @dev SwapData tuple, children of `parent`: swapType == 0, extRouter == 0, extCalldata == "".
    ///      `needScale` is left unconstrained as a trailing parameter.
    function _appendSwapData(ConditionFlat[] memory c, uint256 i, uint8 parent) internal pure returns (uint256) {
        c[i++] = ConditionFlat(parent, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(uint256(0)));
        c[i++] = ConditionFlat(parent, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(address(0)));
        c[i++] = ConditionFlat(parent, PARAM_TYPE_DYNAMIC, OP_EQUAL_TO, _emptyDynamic());
        return i;
    }

    /// @dev FillOrderParams[] element template: Order tuple + signature + makingAmount, all PASS.
    function _appendFillOrderTemplate(
        ConditionFlat[] memory c,
        uint256 i,
        uint8 orderTupleParent
    )
        internal
        pure
        returns (uint256)
    {
        for (uint256 j = 0; j < 11; j++) {
            c[i++] = ConditionFlat(orderTupleParent, PARAM_TYPE_STATIC, OP_PASS, "");
        }
        c[i++] = ConditionFlat(orderTupleParent, PARAM_TYPE_DYNAMIC, OP_PASS, "");
        return i;
    }

    /// @dev swapExactTokenForPt(receiver, market, minPtOut, guessPtOut, input, limit) — 60 nodes.
    function _swapExactTokenForPtConditions() internal pure returns (ConditionFlat[] memory) {
        ConditionFlat[] memory c = new ConditionFlat[](60);
        uint256 i = 0;

        // [0-6] root and its six parameters
        c[i++] = ConditionFlat(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[i++] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, ""); // receiver
        c[i++] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(PENDLE_MARKET_SUSDS)); // market
        c[i++] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_PASS, ""); // minPtOut
        c[i++] = ConditionFlat(0, PARAM_TYPE_TUPLE, OP_PASS, ""); // guessPtOut
        c[i++] = ConditionFlat(0, PARAM_TYPE_TUPLE, OP_MATCHES, ""); // input
        c[i++] = ConditionFlat(0, PARAM_TYPE_TUPLE, OP_MATCHES, ""); // limit

        // [7-11] ApproxParams — five unconstrained fields
        for (uint256 j = 0; j < 5; j++) {
            c[i++] = ConditionFlat(4, PARAM_TYPE_STATIC, OP_PASS, "");
        }

        // [12-16] TokenInput
        c[i++] = ConditionFlat(5, PARAM_TYPE_NONE, OP_OR, ""); // tokenIn
        c[i++] = ConditionFlat(5, PARAM_TYPE_STATIC, OP_PASS, ""); // netTokenIn
        c[i++] = ConditionFlat(5, PARAM_TYPE_NONE, OP_OR, ""); // tokenMintSy
        c[i++] = ConditionFlat(5, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(address(0))); // pendleSwap
        c[i++] = ConditionFlat(5, PARAM_TYPE_TUPLE, OP_MATCHES, ""); // swapData

        // [17-20] LimitOrderData
        c[i++] = ConditionFlat(6, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(address(0))); // limitRouter
        c[i++] = ConditionFlat(6, PARAM_TYPE_STATIC, OP_PASS, ""); // epsSkipMarket
        c[i++] = ConditionFlat(6, PARAM_TYPE_ARRAY, OP_EQUAL_TO, _emptyDynamic()); // normalFills == []
        c[i++] = ConditionFlat(6, PARAM_TYPE_ARRAY, OP_EQUAL_TO, _emptyDynamic()); // flashFills == []

        // [21-24] token whitelists
        i = _appendTokenPair(c, i, 12);
        i = _appendTokenPair(c, i, 14);

        // [25-27] swapData children
        i = _appendSwapData(c, i, 16);

        // [28-29] array element templates
        c[i++] = ConditionFlat(19, PARAM_TYPE_TUPLE, OP_PASS, "");
        c[i++] = ConditionFlat(20, PARAM_TYPE_TUPLE, OP_PASS, "");

        // [30-35] FillOrderParams fields
        c[i++] = ConditionFlat(28, PARAM_TYPE_TUPLE, OP_PASS, ""); // order
        c[i++] = ConditionFlat(28, PARAM_TYPE_DYNAMIC, OP_PASS, ""); // signature
        c[i++] = ConditionFlat(28, PARAM_TYPE_STATIC, OP_PASS, ""); // makingAmount
        c[i++] = ConditionFlat(29, PARAM_TYPE_TUPLE, OP_PASS, "");
        c[i++] = ConditionFlat(29, PARAM_TYPE_DYNAMIC, OP_PASS, "");
        c[i++] = ConditionFlat(29, PARAM_TYPE_STATIC, OP_PASS, "");

        // [36-59] Order struct templates
        i = _appendFillOrderTemplate(c, i, 30);
        i = _appendFillOrderTemplate(c, i, 33);

        require(i == 60, "swapExactTokenForPt condition count");
        return c;
    }

    /// @dev swapExactPtForToken(receiver, market, exactPtIn, output, limit) — 54 nodes.
    function _swapExactPtForTokenConditions() internal pure returns (ConditionFlat[] memory) {
        ConditionFlat[] memory c = new ConditionFlat[](54);
        uint256 i = 0;

        c[i++] = ConditionFlat(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[i++] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, ""); // receiver
        c[i++] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(PENDLE_MARKET_SUSDS)); // market
        c[i++] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_PASS, ""); // exactPtIn
        c[i++] = ConditionFlat(0, PARAM_TYPE_TUPLE, OP_MATCHES, ""); // output
        c[i++] = ConditionFlat(0, PARAM_TYPE_TUPLE, OP_MATCHES, ""); // limit

        // [6-10] TokenOutput
        c[i++] = ConditionFlat(4, PARAM_TYPE_NONE, OP_OR, ""); // tokenOut
        c[i++] = ConditionFlat(4, PARAM_TYPE_STATIC, OP_PASS, ""); // minTokenOut
        c[i++] = ConditionFlat(4, PARAM_TYPE_NONE, OP_OR, ""); // tokenRedeemSy
        c[i++] = ConditionFlat(4, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(address(0))); // pendleSwap
        c[i++] = ConditionFlat(4, PARAM_TYPE_TUPLE, OP_MATCHES, ""); // swapData

        // [11-14] LimitOrderData
        c[i++] = ConditionFlat(5, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(address(0)));
        c[i++] = ConditionFlat(5, PARAM_TYPE_STATIC, OP_PASS, "");
        c[i++] = ConditionFlat(5, PARAM_TYPE_ARRAY, OP_EQUAL_TO, _emptyDynamic());
        c[i++] = ConditionFlat(5, PARAM_TYPE_ARRAY, OP_EQUAL_TO, _emptyDynamic());

        // [15-18] token whitelists
        i = _appendTokenPair(c, i, 6);
        i = _appendTokenPair(c, i, 8);

        // [19-21] swapData children
        i = _appendSwapData(c, i, 10);

        // [22-23] array element templates
        c[i++] = ConditionFlat(13, PARAM_TYPE_TUPLE, OP_PASS, "");
        c[i++] = ConditionFlat(14, PARAM_TYPE_TUPLE, OP_PASS, "");

        // [24-29] FillOrderParams fields
        c[i++] = ConditionFlat(22, PARAM_TYPE_TUPLE, OP_PASS, "");
        c[i++] = ConditionFlat(22, PARAM_TYPE_DYNAMIC, OP_PASS, "");
        c[i++] = ConditionFlat(22, PARAM_TYPE_STATIC, OP_PASS, "");
        c[i++] = ConditionFlat(23, PARAM_TYPE_TUPLE, OP_PASS, "");
        c[i++] = ConditionFlat(23, PARAM_TYPE_DYNAMIC, OP_PASS, "");
        c[i++] = ConditionFlat(23, PARAM_TYPE_STATIC, OP_PASS, "");

        // [30-53] Order struct templates
        i = _appendFillOrderTemplate(c, i, 24);
        i = _appendFillOrderTemplate(c, i, 27);

        require(i == 54, "swapExactPtForToken condition count");
        return c;
    }

    /// @dev redeemPyToToken(receiver, YT, netPyIn, output) — 17 nodes.
    function _redeemPyToTokenConditions() internal pure returns (ConditionFlat[] memory) {
        ConditionFlat[] memory c = new ConditionFlat[](17);
        uint256 i = 0;

        c[i++] = ConditionFlat(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[i++] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, ""); // receiver
        c[i++] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(PENDLE_YT_SUSDS)); // YT
        c[i++] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_PASS, ""); // netPyIn
        c[i++] = ConditionFlat(0, PARAM_TYPE_TUPLE, OP_MATCHES, ""); // output

        // [5-9] TokenOutput
        c[i++] = ConditionFlat(4, PARAM_TYPE_NONE, OP_OR, ""); // tokenOut
        c[i++] = ConditionFlat(4, PARAM_TYPE_STATIC, OP_PASS, ""); // minTokenOut
        c[i++] = ConditionFlat(4, PARAM_TYPE_NONE, OP_OR, ""); // tokenRedeemSy
        c[i++] = ConditionFlat(4, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(address(0))); // pendleSwap
        c[i++] = ConditionFlat(4, PARAM_TYPE_TUPLE, OP_MATCHES, ""); // swapData

        // [10-13] token whitelists
        i = _appendTokenPair(c, i, 5);
        i = _appendTokenPair(c, i, 7);

        // [14-16] swapData children
        i = _appendSwapData(c, i, 9);

        require(i == 17, "redeemPyToToken condition count");
        return c;
    }

    /// @dev The {sUSDS, USDS} pair used for every Pendle token whitelist.
    function _appendTokenPair(ConditionFlat[] memory c, uint256 i, uint8 parent) internal pure returns (uint256) {
        c[i++] = ConditionFlat(parent, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(SUSDS));
        c[i++] = ConditionFlat(parent, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(USDS));
        return i;
    }

    // ─── approve() spender lists (sorted ascending, as emitted by the payload) ───

    /// @dev WETH — 15 spenders: the 14 in place since Update #9 plus kpk ETH Yield.
    function _wethApproveSpenders() internal pure returns (address[] memory) {
        address[] memory s = new address[](15);
        s[0] = PERMIT2;
        s[1] = 0x13f4EA83D0bd40E75C8222255bc855a974568Dd4;
        s[2] = 0x56C526b0159a258887e0d79ec3a80dfb940d0cD7;
        s[3] = KPK_ETH_YIELD; // new
        s[4] = UNISWAP_V3_ROUTER;
        s[5] = AAVE_V3_POOL;
        s[6] = 0xB188b1CB84Fb0bA13cb9ee1292769F903A9feC59; // Aura RewardPoolDepositWrapper
        s[7] = BALANCER_V2_VAULT;
        s[8] = 0xBb50A5341368751024ddf33385BA8cf61fE65FF9;
        s[9] = MORPHO_BLUE;
        s[10] = AAVE_V3_POOL_L1_BRIDGE;
        s[11] = GPV2_VAULT_RELAYER;
        s[12] = 0xcc7d5785AD5755B6164e21495E07aDb0Ff11C2A8;
        s[13] = ETHERFI_DEPOSIT_ADAPTER;
        s[14] = 0xd564F765F9aD3E7d2d6cA782100795a885e8e7C8;
        return s;
    }

    /// @dev USDS — 10 spenders, adding the Pendle Router.
    function _usdsApproveSpenders() internal pure returns (address[] memory) {
        address[] memory s = new address[](10);
        s[0] = 0x0650CAF159C5A49f711e8169D4336ECB9b950275;
        s[1] = 0x5D409e56D886231aDAf00c8775665AD0f9897b56;
        s[2] = UNISWAP_V3_ROUTER;
        s[3] = AAVE_V3_POOL;
        s[4] = PENDLE_ROUTER_V4; // new
        s[5] = 0xA188EEC8F81263234dA3622A406892F3D630f98c;
        s[6] = SUSDS;
        s[7] = AAVE_V3_POOL_L1_BRIDGE;
        s[8] = GPV2_VAULT_RELAYER;
        s[9] = 0xf86141a5657Cf52AEB3E30eBccA5Ad3a8f714B89;
        return s;
    }

    /// @dev sUSDS — 3 spenders, adding the Pendle Router.
    function _susdsApproveSpenders() internal pure returns (address[] memory) {
        address[] memory s = new address[](3);
        s[0] = UNISWAP_V3_ROUTER;
        s[1] = PENDLE_ROUTER_V4; // new
        s[2] = GPV2_VAULT_RELAYER;
        return s;
    }

    /// @dev USDC — 18 spenders, adding the four new USDC-denominated vaults.
    function _usdcApproveSpenders() internal pure returns (address[] memory) {
        address[] memory s = new address[](18);
        s[0] = KPK_USDC_PRIME_RWA; // new
        s[1] = 0x4Ef53d2cAa51C447fdFEEedee8F07FD1962C9ee6;
        s[2] = 0x56C526b0159a258887e0d79ec3a80dfb940d0cD7;
        s[3] = UNISWAP_V3_ROUTER;
        s[4] = AAVE_V3_POOL;
        s[5] = 0x9Fb7b4477576Fe5B32be4C1843aFB1e55F251B33;
        s[6] = 0xA188EEC8F81263234dA3622A406892F3D630f98c;
        s[7] = BALANCER_V2_VAULT;
        s[8] = MORPHO_BLUE;
        s[9] = CURVE_3POOL;
        s[10] = STEAKHOUSE_HIGH_YIELD_USDC; // new
        s[11] = SMOKEHOUSE_USDC; // new
        s[12] = AAVE_V3_POOL_L1_BRIDGE;
        s[13] = 0xc3d688B66703497DAA19211EEdff47f25384cdc3;
        s[14] = GPV2_VAULT_RELAYER;
        s[15] = 0xd0A61F2963622e992e6534bde4D52fd0a89F39E0;
        s[16] = KPK_USDC_YIELD; // new
        s[17] = 0xe108fbc04852B5df72f9E44d7C29F47e7A993aDd;
        return s;
    }
}
