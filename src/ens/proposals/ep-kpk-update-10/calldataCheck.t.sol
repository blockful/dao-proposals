// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";
import { IERC20 } from "@forge-std/src/interfaces/IERC20.sol";

import { ENSConstants } from "@ens/Constants.sol";
import { MultiSendHelper } from "@ens/helpers/MultiSendHelper.sol";
import { ZodiacRolesHelper } from "@ens/helpers/ZodiacRolesHelper.sol";
import { ISafe } from "@ens/interfaces/ISafe.sol";
import { ITimelock } from "@ens/interfaces/ITimelock.sol";
import { IZodiacRoles } from "@ens/interfaces/IZodiacRoles.sol";
import { IMetaMorphoV1 } from "@ens/interfaces/IMetaMorphoV1.sol";
import { ICowSwapOrderSigner } from "@ens/interfaces/ICowSwapOrderSigner.sol";
import { IFluidMerkleDistributor } from "@ens/interfaces/IFluidMerkleDistributor.sol";

interface ISafeModules {
    function disableModule(address prevModule, address module) external;
    function enableModule(address module) external;
    function isModuleEnabled(address module) external view returns (bool);
    function nonce() external view returns (uint256);
}

interface IRolesModifierView {
    function owner() external view returns (address);
    function avatar() external view returns (address);
    function target() external view returns (address);
    function getModulesPaginated(address start, uint256 pageSize) external view returns (address[] memory, address);
    function defaultRoles(address module) external view returns (bytes32);
}

interface IAaveV3Pool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}

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
 * @title Endowment permissions to kpk — Update #10
 * @notice https://discuss.ens.domains/t/draft-endowment-permissions-to-kpk-update-10/22323/4
 *
 * The Endowment Safe replaces its Roles Modifier with a new one that has the same MANAGER
 * permissions plus PUR #10. The Foundation schedules it on the Endowment timelock (not a DAO
 * vote), so the test runs it through the timelock.
 */
contract Proposal_ENS_KPK_Update_10_Test is Test, MultiSendHelper, ZodiacRolesHelper {
    string private constant SWITCH_JSON = "src/ens/proposals/ep-kpk-update-10/ENS_Switch_ZRM.json";

    // ─── Endowment
    address private constant SAFE = ENSConstants.ENDOWMENT_SAFE;
    address private constant OLD_MAIN = ENSConstants.ZODIAC_ROLES;
    address private constant NEW_MAIN = 0xa23BEBFD3628D6Dd7B0638c147db11d9B6FaBD59;
    address private constant SUB_ROLES = 0x48dC0d88766a59E119e3f2585BC1dC5436Ee6ce0;
    address private constant ROLES_MASTERCOPY_V211 = 0xF2964CE6161ce0e75964Fe7927cE114cb0B283D5;
    address private constant POD = ENSConstants.KARPATKEY;
    address private constant SENTINEL = address(0x1);

    // ─── Tokens
    address private constant USDC = ENSConstants.USDC;
    address private constant USDT = ENSConstants.USDT;
    address private constant WETH = ENSConstants.WETH;
    address private constant USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
    address private constant SUSDS = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    address private constant PYUSD = 0x6c3ea9036406852006290770BEdFcAbA0e23A0e8;
    address private constant RLUSD = 0x8292Bb45bf1Ee4d140127049757C2E0fF06317eD;
    address private constant PT_SUSDS_26NOV2026 = 0xdC169AbE56461A2E0c034Da431Ac2a3ebf596094;
    address private constant SYRUP_USDC = 0x80ac24aA929eaF5013f6436cdA2a7ba190f5Cc0b;
    address private constant SYRUP_USDT = 0x356B8d89c1e1239Cbbb9dE4815c39A1474d5BA7D;

    // ─── PUR #10
    address private constant KPK_ETH_YIELD = 0x5dbf760b4fd0cDdDe0366b33aEb338b2A6d77725;
    address private constant KPK_USDC_YIELD = 0xD5cCe260E7a755DDf0Fb9cdF06443d593AaeaA13;
    address private constant SENTORA_PYUSD_MAIN = 0xb576765fB15505433aF24FEe2c0325895C559FB2;
    address private constant SENTORA_RLUSD_MAIN = 0x6dC58a0FdfC8D694e571DC59B9A52EEEa780E6bf;
    address private constant SMOKEHOUSE_USDC = 0xBEeFFF209270748ddd194831b3fa287a5386f5bC;
    address private constant STEAKHOUSE_HIGH_YIELD_USDC = 0xbeeff2C5bF38f90e3482a8b19F12E5a6D2FCa757;
    address private constant KPK_USDC_PRIME_RWA = 0x2B47c128b35DDDcB66Ce2FA5B33c95314a7de245;
    address private constant AAVE_V3_HORIZON_POOL = 0xAe05Cd22df81871bc7cC2a04BeCfb516bFe332C8;
    address private constant PENDLE_ROUTER_V4 = 0x888888888889758F76e7103c6CbF23ABbF58F946;
    address private constant PENDLE_MARKET_SUSDS = 0x9C560eBaF78e596cbcC27411d633a74D628dd7dC;
    address private constant PENDLE_YT_SUSDS = 0xC7B8551C6B286Ce0b44952320e940Bd3Dee58A09;
    address private constant COWSWAP_ORDER_SIGNER = 0x23dA9AdE38E4477b23770DeD512fD37b12381FAB;
    address private constant FLUID_DISTRIBUTOR = 0x7060FE0Dd3E31be01EFAc6B28C8D38018fD163B0;
    address private constant FLUID_GHO_DISTRIBUTOR = 0xF398E66B1273a34558AeBbEC550DccaF4AcC7714;
    address private constant MERKL_DISTRIBUTOR = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;

    // ─── Existing spenders
    address private constant GPV2_VAULT_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;
    address private constant AAVE_V3_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

    ITimelock private constant endowmentTimelock = ITimelock(payable(ENSConstants.ENDOWMENT_TIMELOCK));

    uint256 private safeNonceBefore;

    function setUp() public {
        // After kpk transferred the new Modifier to the Safe (block 26,047,568)
        vm.createSelectFork({ blockNumber: 26_054_000, urlOrAlias: "mainnet" });
    }

    function test_proposal() public {
        _beforeProposal();
        _executeViaEndowmentTimelock(_generateCallData());
        _afterExecution();
    }

    // ─── Before
    // ───────────────────────────────────────────────────

    function _beforeProposal() internal {
        // The timelock owns the Safe and the current Modifier is enabled
        address[] memory owners = ISafe(SAFE).getOwners();
        assertEq(owners.length, 1, "Safe owner count");
        assertEq(owners[0], ENSConstants.ENDOWMENT_TIMELOCK, "Safe owner");
        assertEq(ISafe(SAFE).getThreshold(), 1, "Safe threshold");
        (address[] memory modules,) = ISafe(SAFE).getModulesPaginated(SENTINEL, 10);
        assertEq(modules.length, 2, "Safe module count");
        assertEq(modules[0], OLD_MAIN, "current Modifier heads the list");
        assertEq(modules[1], ENSConstants.ALLOWANCE_MODULE, "Allowance module");
        assertEq(endowmentTimelock.getMinDelay(), 9 days, "timelock delay");
        safeNonceBefore = ISafeModules(SAFE).nonce();

        // New Modifier: Roles v2.1.1, owned by the Safe, pod and Sub as members
        assertEq(
            NEW_MAIN.code,
            abi.encodePacked(hex"363d3d373d3d3d363d73", ROLES_MASTERCOPY_V211, hex"5af43d82803e903d91602b57fd5bf3"),
            "new Modifier is an EIP-1167 clone of Roles v2.1.1"
        );
        IRolesModifierView newMain = IRolesModifierView(NEW_MAIN);
        assertEq(newMain.owner(), SAFE, "new Modifier owner");
        assertEq(newMain.avatar(), SAFE, "new Modifier avatar");
        assertEq(newMain.target(), SAFE, "new Modifier target");
        (address[] memory members,) = newMain.getModulesPaginated(SENTINEL, 10);
        assertEq(members.length, 2, "new Modifier members");
        assertEq(members[0], SUB_ROLES, "Sub is a member");
        assertEq(members[1], POD, "pod is a member");
        assertEq(newMain.defaultRoles(SUB_ROLES), MANAGER_ROLE, "Sub default role");
        assertEq(IRolesModifierView(SUB_ROLES).owner(), POD, "Sub owner");
        assertEq(IRolesModifierView(SUB_ROLES).target(), NEW_MAIN, "Sub target");
        assertFalse(ISafeModules(SAFE).isModuleEnabled(NEW_MAIN), "new Modifier not enabled yet");

        // PUR #10 is not live yet
        _blocked(OLD_MAIN, KPK_USDC_YIELD, _deposit(SAFE), IZodiacRoles.Status.TargetAddressNotAllowed);
        _blocked(OLD_MAIN, AAVE_V3_HORIZON_POOL, _supply(RLUSD, SAFE), IZodiacRoles.Status.TargetAddressNotAllowed);
        _blocked(OLD_MAIN, SUSDS, _approve(PENDLE_ROUTER_V4), IZodiacRoles.Status.OrViolation);
        _blocked(OLD_MAIN, USDC, _approve(KPK_USDC_YIELD), IZodiacRoles.Status.OrViolation);
        _allowed(OLD_MAIN, USDC, _approve(GPV2_VAULT_RELAYER));
    }

    // ─── Calldata
    // ─────────────────────────────────────────────────

    function _generateCallData() internal view returns (bytes memory execData) {
        bytes memory disableCall = abi.encodeCall(ISafeModules.disableModule, (SENTINEL, OLD_MAIN));
        bytes memory enableCall = abi.encodeCall(ISafeModules.enableModule, (NEW_MAIN));

        // Must match kpk's ENS_Switch_ZRM.json
        string memory json = vm.readFile(SWITCH_JSON);
        assertEq(vm.parseJsonUint(json, ".chainId"), 1, "chain");
        assertEq(vm.parseJsonAddress(json, ".meta.createdFromSafeAddress"), SAFE, "batch Safe");
        assertTrue(vm.keyExistsJson(json, ".transactions[1]"), "second call");
        assertFalse(vm.keyExistsJson(json, ".transactions[2]"), "exactly two calls");

        assertEq(vm.parseJsonAddress(json, ".transactions[0].to"), SAFE, "call 1 target");
        assertEq(vm.parseJsonUint(json, ".transactions[0].value"), 0, "call 1 value");
        assertEq(vm.parseJson(json, ".transactions[0].data"), abi.encode(0), "call 1 has no raw data");
        assertEq(_publishedSelector(json, 0), ISafeModules.disableModule.selector, "call 1 selector");
        assertEq(
            abi.encodeCall(
                ISafeModules.disableModule,
                (
                    vm.parseJsonAddress(json, ".transactions[0].contractInputsValues.prevModule"),
                    vm.parseJsonAddress(json, ".transactions[0].contractInputsValues.module")
                )
            ),
            disableCall,
            "call 1 matches disableModule(SENTINEL, current Modifier)"
        );

        assertEq(vm.parseJsonAddress(json, ".transactions[1].to"), SAFE, "call 2 target");
        assertEq(vm.parseJsonUint(json, ".transactions[1].value"), 0, "call 2 value");
        assertEq(vm.parseJson(json, ".transactions[1].data"), abi.encode(0), "call 2 has no raw data");
        assertEq(_publishedSelector(json, 1), ISafeModules.enableModule.selector, "call 2 selector");
        assertEq(
            abi.encodeCall(
                ISafeModules.enableModule, (vm.parseJsonAddress(json, ".transactions[1].contractInputsValues.module"))
            ),
            enableCall,
            "call 2 matches enableModule(new Modifier)"
        );

        // Safe transaction signed by the timelock
        (, execData) = _buildSafeMultiSendCalldata(
            bytes.concat(_packCall(SAFE, disableCall), _packCall(SAFE, enableCall)),
            SAFE,
            ENSConstants.ENDOWMENT_TIMELOCK
        );
    }

    function _executeViaEndowmentTimelock(bytes memory execData) internal {
        bytes32 salt = keccak256("ENS_Switch_ZRM");
        vm.prank(ENSConstants.FOUNDATION_SAFE);
        endowmentTimelock.schedule(SAFE, 0, execData, bytes32(0), salt, 9 days);

        vm.expectRevert(bytes("TimelockController: operation is not ready"));
        endowmentTimelock.execute(SAFE, 0, execData, bytes32(0), salt);

        vm.warp(block.timestamp + 9 days);
        vm.prank(address(0xA11CE)); // anyone can execute
        endowmentTimelock.execute(SAFE, 0, execData, bytes32(0), salt);
    }

    // ─── After
    // ────────────────────────────────────────────────────

    function _afterExecution() internal {
        (address[] memory modules,) = ISafe(SAFE).getModulesPaginated(SENTINEL, 10);
        assertEq(modules.length, 2, "Safe module count");
        assertEq(modules[0], NEW_MAIN, "new Modifier enabled");
        assertEq(modules[1], ENSConstants.ALLOWANCE_MODULE, "Allowance module untouched");
        assertFalse(ISafeModules(SAFE).isModuleEnabled(OLD_MAIN), "current Modifier disabled");
        assertEq(ISafeModules(SAFE).nonce(), safeNonceBefore + 1, "one Safe transaction");
        assertEq(IRolesModifierView(NEW_MAIN).owner(), SAFE, "new Modifier still owned by the Safe");

        // The old Modifier can't execute anymore
        vm.prank(POD);
        vm.expectRevert(bytes("GS104"));
        IZodiacRoles(OLD_MAIN)
            .execTransactionWithRole(
                USDC, 0, _approve(GPV2_VAULT_RELAYER), IZodiacRoles.Operation.Call, MANAGER_ROLE, false
            );

        _assertPur10Permissions();
        _assertExistingPermissions();
    }

    function _assertPur10Permissions() internal {
        // Approvals
        _allowed(NEW_MAIN, SUSDS, _approve(PENDLE_ROUTER_V4));
        _allowed(NEW_MAIN, PT_SUSDS_26NOV2026, _approve(PENDLE_ROUTER_V4));
        _allowed(NEW_MAIN, PYUSD, _approve(SENTORA_PYUSD_MAIN));
        _allowed(NEW_MAIN, RLUSD, _approve(SENTORA_RLUSD_MAIN));
        _allowed(NEW_MAIN, RLUSD, _approve(AAVE_V3_HORIZON_POOL));
        _blocked(NEW_MAIN, SUSDS, _approve(address(0xdead)), IZodiacRoles.Status.OrViolation);
        _blocked(NEW_MAIN, RLUSD, _approve(address(0xdead)), IZodiacRoles.Status.OrViolation);
        _blocked(NEW_MAIN, PYUSD, _approve(address(0xdead)), IZodiacRoles.Status.ParameterNotAllowed);
        _blocked(NEW_MAIN, PT_SUSDS_26NOV2026, _approve(address(0xdead)), IZodiacRoles.Status.ParameterNotAllowed);
        _allowed(NEW_MAIN, USDS, _approve(PENDLE_ROUTER_V4));
        _allowed(NEW_MAIN, WETH, _approve(KPK_ETH_YIELD));
        _allowed(NEW_MAIN, USDC, _approve(KPK_USDC_YIELD));
        _allowed(NEW_MAIN, USDC, _approve(SMOKEHOUSE_USDC));
        _allowed(NEW_MAIN, USDC, _approve(STEAKHOUSE_HIGH_YIELD_USDC));
        _allowed(NEW_MAIN, USDC, _approve(KPK_USDC_PRIME_RWA));

        // Pendle
        _allowed(NEW_MAIN, PENDLE_ROUTER_V4, _pendleBuyPt(SAFE));
        _allowed(NEW_MAIN, PENDLE_ROUTER_V4, _pendleSellPt(SAFE));
        _allowed(NEW_MAIN, PENDLE_ROUTER_V4, _pendleRedeem(SAFE));
        _blocked(NEW_MAIN, PENDLE_ROUTER_V4, _pendleBuyPt(address(0xdead)), IZodiacRoles.Status.ParameterNotAllowed);
        _blocked(NEW_MAIN, PENDLE_ROUTER_V4, _pendleSellPt(address(0xdead)), IZodiacRoles.Status.ParameterNotAllowed);
        _blocked(NEW_MAIN, PENDLE_ROUTER_V4, _pendleRedeem(address(0xdead)), IZodiacRoles.Status.ParameterNotAllowed);

        // Vaults
        address[7] memory vaults = [
            KPK_ETH_YIELD,
            KPK_USDC_YIELD,
            SENTORA_PYUSD_MAIN,
            SENTORA_RLUSD_MAIN,
            SMOKEHOUSE_USDC,
            STEAKHOUSE_HIGH_YIELD_USDC,
            KPK_USDC_PRIME_RWA
        ];
        for (uint256 i; i < vaults.length; i++) {
            _allowed(NEW_MAIN, vaults[i], _deposit(SAFE));
            _allowed(NEW_MAIN, vaults[i], abi.encodeCall(IMetaMorphoV1.withdraw, (1, SAFE, SAFE)));
            _allowed(NEW_MAIN, vaults[i], abi.encodeCall(IMetaMorphoV1.redeem, (1, SAFE, SAFE)));
            _blocked(NEW_MAIN, vaults[i], _deposit(address(0xdead)), IZodiacRoles.Status.ParameterNotAllowed);
            _blocked(
                NEW_MAIN,
                vaults[i],
                abi.encodeCall(IMetaMorphoV1.withdraw, (1, address(0xdead), SAFE)),
                IZodiacRoles.Status.ParameterNotAllowed
            );
            _blocked(
                NEW_MAIN,
                vaults[i],
                abi.encodeCall(IMetaMorphoV1.redeem, (1, address(0xdead), SAFE)),
                IZodiacRoles.Status.ParameterNotAllowed
            );
        }

        // Aave Horizon, RLUSD only
        _allowed(NEW_MAIN, AAVE_V3_HORIZON_POOL, _supply(RLUSD, SAFE));
        _allowed(NEW_MAIN, AAVE_V3_HORIZON_POOL, abi.encodeCall(IAaveV3Pool.withdraw, (RLUSD, 1, SAFE)));
        _blocked(NEW_MAIN, AAVE_V3_HORIZON_POOL, _supply(USDC, SAFE), IZodiacRoles.Status.ParameterNotAllowed);
        _blocked(
            NEW_MAIN, AAVE_V3_HORIZON_POOL, _supply(RLUSD, address(0xdead)), IZodiacRoles.Status.ParameterNotAllowed
        );
        _blocked(
            NEW_MAIN,
            AAVE_V3_HORIZON_POOL,
            abi.encodeCall(IAaveV3Pool.withdraw, (RLUSD, 1, address(0xdead))),
            IZodiacRoles.Status.ParameterNotAllowed
        );

        // CoW, syrup pairs only
        _allowedDelegate(NEW_MAIN, COWSWAP_ORDER_SIGNER, _signOrder(SYRUP_USDC, USDC));
        _allowedDelegate(NEW_MAIN, COWSWAP_ORDER_SIGNER, _signOrder(USDC, SYRUP_USDC));
        _allowedDelegate(NEW_MAIN, COWSWAP_ORDER_SIGNER, _signOrder(SYRUP_USDT, USDT));
        _allowedDelegate(NEW_MAIN, COWSWAP_ORDER_SIGNER, _signOrder(USDT, SYRUP_USDT));
        _blockedDelegate(NEW_MAIN, COWSWAP_ORDER_SIGNER, _signOrder(SYRUP_USDC, WETH));
        _blockedDelegate(NEW_MAIN, COWSWAP_ORDER_SIGNER, _signOrder(SYRUP_USDC, USDT));
        _allowed(NEW_MAIN, SYRUP_USDC, _approve(GPV2_VAULT_RELAYER));
        _allowed(NEW_MAIN, SYRUP_USDT, _approve(GPV2_VAULT_RELAYER));
        _blocked(NEW_MAIN, SYRUP_USDC, _approve(address(0xdead)), IZodiacRoles.Status.ParameterNotAllowed);

        // Reward claims
        _allowed(NEW_MAIN, FLUID_DISTRIBUTOR, _fluidClaim(SAFE));
        _allowed(NEW_MAIN, FLUID_GHO_DISTRIBUTOR, _fluidClaim(SAFE));
        _allowed(NEW_MAIN, MERKL_DISTRIBUTOR, _merklClaim(SAFE));
        _blocked(NEW_MAIN, FLUID_DISTRIBUTOR, _fluidClaim(address(0xdead)), IZodiacRoles.Status.ParameterNotAllowed);
        _blocked(NEW_MAIN, FLUID_GHO_DISTRIBUTOR, _fluidClaim(address(0xdead)), IZodiacRoles.Status.ParameterNotAllowed);
        _blocked(NEW_MAIN, MERKL_DISTRIBUTOR, _merklClaim(address(0xdead)), IZodiacRoles.Status.OrViolation);
    }

    function _assertExistingPermissions() internal {
        _allowed(NEW_MAIN, USDC, _approve(GPV2_VAULT_RELAYER));
        _allowed(NEW_MAIN, WETH, _approve(AAVE_V3_POOL));
        _allowed(NEW_MAIN, USDS, _approve(GPV2_VAULT_RELAYER));
        _allowed(NEW_MAIN, SUSDS, _approve(GPV2_VAULT_RELAYER));
        _allowedDelegate(NEW_MAIN, COWSWAP_ORDER_SIGNER, _signOrder(USDC, WETH));
        _allowed(NEW_MAIN, USDC, abi.encodeCall(IERC20.transfer, (ENSConstants.TIMELOCK, 1)));
        _blocked(
            NEW_MAIN,
            USDC,
            abi.encodeCall(IERC20.transfer, (address(0xdead), 1)),
            IZodiacRoles.Status.ParameterNotAllowed
        );
        _blocked(NEW_MAIN, address(0xdead), "", IZodiacRoles.Status.TargetAddressNotAllowed);

        // ETH to the DAO timelock
        uint256 snapshot = vm.snapshotState();
        vm.prank(POD);
        IZodiacRoles(NEW_MAIN)
            .execTransactionWithRole(ENSConstants.TIMELOCK, 1, "", IZodiacRoles.Operation.Call, MANAGER_ROLE, true);
        vm.revertToState(snapshot);
    }

    // ─── Helpers
    // ──────────────────────────────────────────────────

    function _allowed(address module, address to, bytes memory data) internal {
        uint256 snapshot = vm.snapshotState();
        vm.prank(POD);
        IZodiacRoles(module).execTransactionWithRole(to, 0, data, IZodiacRoles.Operation.Call, MANAGER_ROLE, false);
        vm.revertToState(snapshot);
    }

    function _blocked(address module, address to, bytes memory data, IZodiacRoles.Status status) internal {
        vm.prank(POD);
        _expectConditionViolation(status);
        IZodiacRoles(module).execTransactionWithRole(to, 0, data, IZodiacRoles.Operation.Call, MANAGER_ROLE, false);
    }

    function _allowedDelegate(address module, address to, bytes memory data) internal {
        uint256 snapshot = vm.snapshotState();
        vm.prank(POD);
        IZodiacRoles(module)
            .execTransactionWithRole(to, 0, data, IZodiacRoles.Operation.DelegateCall, MANAGER_ROLE, false);
        vm.revertToState(snapshot);
    }

    function _blockedDelegate(address module, address to, bytes memory data) internal {
        vm.prank(POD);
        _expectConditionViolation(IZodiacRoles.Status.OrViolation);
        IZodiacRoles(module)
            .execTransactionWithRole(to, 0, data, IZodiacRoles.Operation.DelegateCall, MANAGER_ROLE, false);
    }

    // Selector from the method name and input types in kpk's JSON
    function _publishedSelector(string memory json, uint256 i) internal view returns (bytes4) {
        string memory base = string.concat(".transactions[", vm.toString(i), "].contractMethod");
        string memory signature = string.concat(vm.parseJsonString(json, string.concat(base, ".name")), "(");
        for (uint256 j; vm.keyExistsJson(json, string.concat(base, ".inputs[", vm.toString(j), "]")); j++) {
            if (j > 0) signature = string.concat(signature, ",");
            signature = string.concat(
                signature, vm.parseJsonString(json, string.concat(base, ".inputs[", vm.toString(j), "].type"))
            );
        }
        return bytes4(keccak256(bytes(string.concat(signature, ")"))));
    }

    function _approve(address spender) internal pure returns (bytes memory) {
        return abi.encodeCall(IERC20.approve, (spender, 1));
    }

    function _deposit(address receiver) internal pure returns (bytes memory) {
        return abi.encodeCall(IMetaMorphoV1.deposit, (1, receiver));
    }

    function _supply(address asset, address onBehalfOf) internal pure returns (bytes memory) {
        return abi.encodeCall(IAaveV3Pool.supply, (asset, 1, onBehalfOf, 0));
    }

    function _pendleBuyPt(address receiver) internal pure returns (bytes memory) {
        IPendleRouterV4.TokenInput memory input = IPendleRouterV4.TokenInput({
            tokenIn: SUSDS, netTokenIn: 1, tokenMintSy: SUSDS, pendleSwap: address(0), swapData: _noSwap()
        });
        IPendleRouterV4.ApproxParams memory guess;
        return abi.encodeCall(
            IPendleRouterV4.swapExactTokenForPt, (receiver, PENDLE_MARKET_SUSDS, 0, guess, input, _noLimitOrder())
        );
    }

    function _pendleSellPt(address receiver) internal pure returns (bytes memory) {
        return abi.encodeCall(
            IPendleRouterV4.swapExactPtForToken, (receiver, PENDLE_MARKET_SUSDS, 1, _toSusds(), _noLimitOrder())
        );
    }

    function _pendleRedeem(address receiver) internal pure returns (bytes memory) {
        return abi.encodeCall(IPendleRouterV4.redeemPyToToken, (receiver, PENDLE_YT_SUSDS, 1, _toSusds()));
    }

    function _toSusds() internal pure returns (IPendleRouterV4.TokenOutput memory) {
        return IPendleRouterV4.TokenOutput({
            tokenOut: SUSDS, minTokenOut: 0, tokenRedeemSy: SUSDS, pendleSwap: address(0), swapData: _noSwap()
        });
    }

    function _noSwap() internal pure returns (IPendleRouterV4.SwapData memory) {
        return IPendleRouterV4.SwapData({ swapType: 0, extRouter: address(0), extCalldata: "", needScale: false });
    }

    function _noLimitOrder() internal pure returns (IPendleRouterV4.LimitOrderData memory) {
        return IPendleRouterV4.LimitOrderData({
            limitRouter: address(0),
            epsSkipMarket: 0,
            normalFills: new IPendleRouterV4.FillOrderParams[](0),
            flashFills: new IPendleRouterV4.FillOrderParams[](0),
            optData: ""
        });
    }

    function _signOrder(address sell, address buy) internal pure returns (bytes memory) {
        ICowSwapOrderSigner.Data memory order = ICowSwapOrderSigner.Data({
            sellToken: IERC20(sell),
            buyToken: IERC20(buy),
            receiver: SAFE,
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
        return abi.encodeCall(ICowSwapOrderSigner.signOrder, (order, 0, 0));
    }

    function _fluidClaim(address recipient) internal pure returns (bytes memory) {
        return abi.encodeCall(IFluidMerkleDistributor.claim, (recipient, 0, 0, bytes32(0), 0, new bytes32[](0), ""));
    }

    function _merklClaim(address user) internal pure returns (bytes memory) {
        address[] memory users = new address[](1);
        users[0] = user;
        return abi.encodeCall(IMerklDistributor.claim, (users, new address[](1), new uint256[](1), new bytes32[][](1)));
    }
}
