// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";
import { console2 } from "@forge-std/src/console2.sol";
import { IERC20 } from "@forge-std/src/interfaces/IERC20.sol";

import { ENSConstants } from "@ens/Constants.sol";
import { MultiSendHelper } from "@ens/helpers/MultiSendHelper.sol";
import { ZodiacRolesHelper } from "@ens/helpers/ZodiacRolesHelper.sol";
import { ISafe } from "@ens/interfaces/ISafe.sol";
import { IZodiacRoles } from "@ens/interfaces/IZodiacRoles.sol";
import { IRolesModifier, ConditionFlat } from "@ens/interfaces/IRolesModifier.sol";
import { IMultiSend } from "@ens/interfaces/IMultiSend.sol";
import { IMetaMorphoV1 } from "@ens/interfaces/IMetaMorphoV1.sol";
import { ICowSwapOrderSigner } from "@ens/interfaces/ICowSwapOrderSigner.sol";
import { ISecurityCouncil } from "@ens/interfaces/ISecurityCouncil.sol";

// Target interfaces shared with the round-1 derivation of the Update #10 permission set.
import { IAaveV3Pool, IPendleRouterV4, IMerklDistributor } from "./update10Payload.t.sol";

// ─── Minimal interfaces
// ──────────────────────────────────────────────────────

/// @notice Safe v1.3.0 module management (the two calls of the switch batch)
interface ISafeModules {
    function disableModule(address prevModule, address module) external;
    function enableModule(address module) external;
    function isModuleEnabled(address module) external view returns (bool);
    function nonce() external view returns (uint256);
}

/// @notice OpenZeppelin TimelockController v4.3.2 (the EndowmentTimelock)
interface IOZTimelock {
    function schedule(address t, uint256 v, bytes calldata d, bytes32 p, bytes32 s, uint256 delay) external;
    function execute(address t, uint256 v, bytes calldata d, bytes32 p, bytes32 s) external payable;
    function hashOperation(address t, uint256 v, bytes calldata d, bytes32 p, bytes32 s) external pure returns (bytes32);
    function isOperationPending(bytes32 id) external view returns (bool);
    function isOperationReady(bytes32 id) external view returns (bool);
    function isOperationDone(bytes32 id) external view returns (bool);
    function getMinDelay() external view returns (uint256);
    function hasRole(bytes32 role, address account) external view returns (bool);
}

/// @notice Admin and read surface of a Zodiac Roles Modifier v2.1.x
interface IRolesAdmin {
    function owner() external view returns (address);
    function avatar() external view returns (address);
    function target() external view returns (address);
    function transferOwnership(address newOwner) external;
    function isModuleEnabled(address module) external view returns (bool);
    function getModulesPaginated(address start, uint256 pageSize) external view returns (address[] memory, address);
    function defaultRoles(address module) external view returns (bytes32);
    function unwrappers(bytes32 key) external view returns (address);
    function allowTarget(bytes32 roleKey, address targetAddress, uint8 options) external;
    function allowFunction(bytes32 roleKey, address targetAddress, bytes4 selector, uint8 options) external;
    function assignRoles(address module, bytes32[] memory roleKeys, bool[] memory memberOf) external;
}

/**
 * @title Endowment permissions to kpk — Update #10, revised execution (module swap)
 * @notice Second-round review of
 *     https://discuss.ens.domains/t/draft-endowment-permissions-to-kpk-update-10/22323/4
 *
 * kpk's revised execution replaces the Endowment's Zodiac Roles Modifier instead of
 * editing it. The artefact to execute is `ENS_Switch_ZRM.json` (karpatkey/client-configs,
 * commit 8f4fb0c34d): a two-transaction batch signed by the Endowment Safe,
 *
 *   TX 0   Safe.disableModule(SENTINEL, oldMain)   oldMain = 0x703806E6…  Roles v2.1.0
 *   TX 1   Safe.enableModule(newMain)              newMain = 0xa23BEBFD…  Roles v2.1.1
 *
 * The new Main was deployed and configured on-chain by kpk (block 25,941,653 and the five
 * configuration transactions that follow it) before this review. It ships the current
 * MANAGER policy plus the Update #10 additions, with the redeployed Sub-Roles Modifier
 * (0x48dC0d88…) enabled as a member. The Endowment Safe's sole owner is the
 * EndowmentTimelock (since "Empowering the ENS Foundation" executed at block 25,729,925),
 * so the batch executes when the ENS Foundation Safe schedules it there and the nine-day
 * delay elapses without a Security Council veto.
 *
 * What this file proves:
 *   - the switch batch, derived from the two Safe calls above, is byte-identical to the
 *     Transaction Builder batch published by kpk (`expectedSwitchMultiSend.txt`);
 *   - executed through the Foundation → EndowmentTimelock → Safe path it swaps the
 *     modules, closes the old Main and leaves the Allowance module untouched;
 *   - the new Main's MANAGER policy equals the old Main's policy with the verified
 *     Update #10 payload applied, checked slot by slot on-chain (`test_structuralEquivalence…`)
 *     and behaviourally for every Update #10 permission (`_afterExecution`);
 *   - the precondition that is NOT yet met on-chain: the new Main is still owned by kpk's
 *     test Safe, not by the Endowment Safe (`test_precondition…`, `test_finding…`).
 */
contract Proposal_ENS_KPK_Update_10_Switch_Test is Test, MultiSendHelper, ZodiacRolesHelper {
    // ─── Actors and infrastructure
    // ───────────────────────────────

    string private constant DIR = "src/ens/proposals/ep-kpk-update-10";

    address private constant OLD_MAIN = 0x703806E61847984346d2D7DDd853049627e50A40; // == roles
    address private constant NEW_MAIN = 0xa23BEBFD3628D6Dd7B0638c147db11d9B6FaBD59;
    address private constant SUB_ROLES = 0x48dC0d88766a59E119e3f2585BC1dC5436Ee6ce0;
    address private constant OLD_SUB_ROLES = 0xa5dd28EC9C69627A96202897b35B88827854bd3b; // superseded, never deployed

    /// @dev Zodiac Roles mastercopies: v2.1.0 (current Main) and v2.1.1 (new Main and Sub)
    address private constant ROLES_MASTERCOPY_V210 = 0x9646fDAD06d3e24444381f44362a3B0eB343D337;
    address private constant ROLES_MASTERCOPY_V211 = 0xF2964CE6161ce0e75964Fe7927cE114cb0B283D5;

    /// @dev kpk's "test" instance Safe (1-of-9), deployer and current owner of the new Main
    address private constant KPK_TEST_SAFE = 0xC01318baB7ee1f5ba734172bF7718b5DC6Ec90E1;

    address private constant DAO_TIMELOCK = ENSConstants.TIMELOCK;
    address private constant ENDOWMENT_TIMELOCK = 0x0bcC3dA6aD796F59288C0961602675E88A2B406C;
    address private constant FOUNDATION_SAFE = 0x9C7dB6B1085ec4D07f75c0BD91AD3FcD368fA19E;
    address private constant SC_VETO = 0x0A9387643ce6291f8C545286675D76bCd0Ba3EdD;
    address private constant SC_SAFE = 0x7101B78638e34444F0a5AdE9e1149fbEeC029931;
    address private constant ALLOWANCE_MODULE = 0xCFbFaC74C26F8647cBDb8c5caf80BB5b32E43134;
    address private constant SENTINEL = address(0x1);

    address private constant MULTISEND_130 = 0xA238CBeb142c10Ef7Ad8442C6D1f9E89e07e7761;
    address private constant MULTISEND_CALL_ONLY_130 = 0x40A2aCCbd92BCA938b02010E17A5b8929b49130D; // == multiSend
    address private constant MULTISEND_141 = 0x38869bf66a61cF6bDB996A6aE40D5853Fd43B526;
    address private constant MULTISEND_CALL_ONLY_141 = 0x9641d764fc13c8B624c04430C7356C1C7C8102e2;
    address private constant MULTISEND_UNWRAPPER = 0xB4Cd4bb764C089f20DA18700CE8bc5e49F369efD;

    bytes32 private constant SALT = keccak256("ENS_Switch_ZRM");

    // ─── Roles v2.1.x storage layout (identical in v2.1.0 and v2.1.1) ─
    //   slot 3 modules, slot 4 roles, slot 6 unwrappers, slot 7 defaultRoles
    //   Role { members (+0), targets (+1), scopeConfig (+2) }
    //   scopeConfig header: count << 240 | options << 224 | isWildcarded << 216 | pointer
    uint256 private constant SLOT_ROLES = 4;
    uint256 private constant SLOT_UNWRAPPERS = 6;
    uint256 private constant SLOT_DEFAULT_ROLES = 7;
    uint256 private constant CLEARANCE_FUNCTION = 2;

    // ─── Update #10 venues (see update10Payload.t.sol) ────────────

    uint8 private constant PARAM_TYPE_DYNAMIC = 2;
    uint8 private constant PARAM_TYPE_ARRAY = 4;

    address private constant PYUSD = 0x6c3ea9036406852006290770BEdFcAbA0e23A0e8;
    address private constant RLUSD = 0x8292Bb45bf1Ee4d140127049757C2E0fF06317eD;
    address private constant SUSDS = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    address private constant USDC = ENSConstants.USDC;
    address private constant USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
    address private constant WETH = ENSConstants.WETH;
    address private constant USDT = ENSConstants.USDT;
    address private constant PT_SUSDS_26NOV2026 = 0xdC169AbE56461A2E0c034Da431Ac2a3ebf596094;
    address private constant SYRUP_USDC = 0x80ac24aA929eaF5013f6436cdA2a7ba190f5Cc0b;
    address private constant SYRUP_USDT = 0x356B8d89c1e1239Cbbb9dE4815c39A1474d5BA7D;
    address private constant COWSWAP_ORDER_SIGNER = 0x23dA9AdE38E4477b23770DeD512fD37b12381FAB;

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

    address private constant FLUID_DISTRIBUTOR = 0x7060FE0Dd3E31be01EFAc6B28C8D38018fD163B0;
    address private constant FLUID_GHO_DISTRIBUTOR = 0xF398E66B1273a34558AeBbEC550DccaF4AcC7714;
    address private constant MERKL_DISTRIBUTOR = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;

    address private constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address private constant UNISWAP_V3_ROUTER = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address private constant AAVE_V3_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address private constant BALANCER_V2_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address private constant GPV2_VAULT_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;
    address private constant MORPHO_BLUE = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address private constant CURVE_3POOL = 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7;
    address private constant AAVE_V3_POOL_L1_BRIDGE = 0xC13e21B648A5Ee794902342038FF3aDAB66BE987;
    address private constant ETHERFI_DEPOSIT_ADAPTER = 0xcfC6d9Bd7411962Bfe7145451A7EF71A24b6A7A2;

    /// @dev Harvest role as published in kpk's configuration repository (roles/HARVEST)
    bytes32 private constant HARVEST_ROLE = 0x4841525645535400000000000000000000000000000000000000000000000000;
    address private constant HARVEST_MEMBER = 0x14C2d2D64C4860ACF7CF39068eb467D7556197de;

    IOZTimelock private constant endowmentTimelock = IOZTimelock(ENDOWMENT_TIMELOCK);

    uint256 private safeNonceBefore;

    // ─── Fork
    // ─────────────────────────────────────────────────────

    function setUp() public {
        // After the new Main's last configuration transaction (block 25,941,858).
        vm.createSelectFork({ blockNumber: 25_984_900, urlOrAlias: "mainnet" });
        vm.label(OLD_MAIN, "oldMain");
        vm.label(NEW_MAIN, "newMain");
        vm.label(SUB_ROLES, "subRoles");
        vm.label(address(endowmentSafe), "endowmentSafe");
        vm.label(ENDOWMENT_TIMELOCK, "endowmentTimelock");
        vm.label(FOUNDATION_SAFE, "foundationSafe");
        vm.label(KPK_TEST_SAFE, "kpkTestSafe");
        vm.label(karpatkey, "kpkPod");
    }

    // ─── The review
    // ───────────────────────────────────────────────

    function test_switch() public {
        _beforeExecution();
        bytes memory execData = _generateCallData();
        _executeViaEndowmentTimelock(execData);
        _afterExecution();
    }

    /// @dev Tripwire for the open precondition: the new Main must be owned by the Endowment
    ///      Safe before the switch executes. Today it is owned by kpk's 1-of-9 test Safe.
    ///      This test is expected to start failing once kpk transfers ownership; update the
    ///      review then rather than deleting it.
    function test_precondition_newMainIsStillOwnedByKpkTestSafe() public view {
        assertEq(IRolesAdmin(NEW_MAIN).owner(), KPK_TEST_SAFE, "new Main owner changed: re-review");
        assertEq(ISafe(KPK_TEST_SAFE).getThreshold(), 1, "kpk test Safe threshold");
        assertEq(ISafe(KPK_TEST_SAFE).getOwners().length, 9, "kpk test Safe owner count");
    }

    /// @dev What the missing ownership transfer means in practice: with the switch executed
    ///      as published, the owner of the new Main rewrites the Endowment's policy at will,
    ///      without the Foundation, the timelock, the Security Council or a DAO vote.
    function test_finding_withoutOwnershipTransferKpkTestSafeRewritesThePolicy() public {
        _executeViaEndowmentTimelock(_generateCallData());
        assertEq(IRolesAdmin(NEW_MAIN).owner(), KPK_TEST_SAFE, "precondition not simulated in this test");

        // The Safe's idle sUSDS at the fork block (about 2.94M sUSDS).
        address sink = address(0xdead);
        uint256 amount = IERC20(SUSDS).balanceOf(address(endowmentSafe));
        assertGt(amount, 1_000_000e18, "Endowment sUSDS balance");
        uint256 sinkBefore = IERC20(SUSDS).balanceOf(sink);

        // Today the pod cannot transfer sUSDS at all (approve only, spender-pinned).
        _blockedVia(NEW_MAIN, SUSDS, _transferCall(sink, amount), IZodiacRoles.Status.FunctionNotAllowed);

        // The test Safe (any 1 of its 9 signers) opens sUSDS.transfer to any recipient...
        vm.prank(KPK_TEST_SAFE);
        IRolesAdmin(NEW_MAIN).allowFunction(MANAGER_ROLE, SUSDS, IERC20.transfer.selector, EXEC_NONE);
        // ...and the pod moves it in the next block, with no delay and no veto window.
        vm.prank(karpatkey);
        IZodiacRoles(NEW_MAIN)
            .execTransactionWithRole(
                SUSDS, 0, _transferCall(sink, amount), IZodiacRoles.Operation.Call, MANAGER_ROLE, true
            );
        assertEq(IERC20(SUSDS).balanceOf(sink) - sinkBefore, amount, "sUSDS left the Endowment");
        assertEq(IERC20(SUSDS).balanceOf(address(endowmentSafe)), 0, "Endowment sUSDS drained");

        // With ownership at the Endowment Safe the same edit is impossible outside the
        // Foundation → EndowmentTimelock path.
        vm.prank(KPK_TEST_SAFE);
        IRolesAdmin(NEW_MAIN).transferOwnership(address(endowmentSafe));
        vm.prank(KPK_TEST_SAFE);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", KPK_TEST_SAFE));
        IRolesAdmin(NEW_MAIN).allowFunction(MANAGER_ROLE, WETH, IERC20.transfer.selector, EXEC_NONE);
    }

    /// @dev The Security Council can cancel the scheduled switch during the nine-day window.
    function test_securityCouncilCanVetoTheScheduledSwitch() public {
        bytes memory execData = _generateCallData();
        bytes32 id = endowmentTimelock.hashOperation(address(endowmentSafe), 0, execData, bytes32(0), SALT);
        vm.prank(FOUNDATION_SAFE);
        endowmentTimelock.schedule(address(endowmentSafe), 0, execData, bytes32(0), SALT, 9 days);
        assertTrue(endowmentTimelock.isOperationPending(id), "not scheduled");

        assertEq(ISecurityCouncil(SC_VETO).owner(), SC_SAFE, "veto wrapper owner");
        assertGt(ISecurityCouncil(SC_VETO).expiration(), block.timestamp + 9 days, "veto expired");
        vm.prank(SC_SAFE);
        ISecurityCouncil(SC_VETO).veto(id);
        assertFalse(endowmentTimelock.isOperationPending(id), "veto did not cancel");

        vm.warp(block.timestamp + 9 days);
        vm.expectRevert(bytes("TimelockController: operation is not ready"));
        endowmentTimelock.execute(address(endowmentSafe), 0, execData, bytes32(0), SALT);
        assertTrue(ISafeModules(address(endowmentSafe)).isModuleEnabled(OLD_MAIN), "old Main still active");
        assertFalse(ISafeModules(address(endowmentSafe)).isModuleEnabled(NEW_MAIN), "new Main not enabled");
    }

    /// @dev The batch is not executable as an ENS DAO proposal: the DAO Timelock is no
    ///      longer an owner of the Endowment Safe, so its pre-approved signature is invalid.
    function test_switchIsNotExecutableByTheDaoTimelock() public {
        (, bytes memory execData) = _buildSafeMultiSendCalldata(_switchBatch(), address(endowmentSafe), DAO_TIMELOCK);
        vm.prank(DAO_TIMELOCK);
        vm.expectRevert(bytes("GS026"));
        ISafe(address(endowmentSafe))
            .execTransaction(
                multiSendTarget(), 0, "", 1, 0, 0, 0, address(0), address(0), _buildPreApprovedSignature(DAO_TIMELOCK)
            );
        vm.prank(DAO_TIMELOCK);
        (bool ok,) = address(endowmentSafe).call(execData);
        assertFalse(ok, "DAO Timelock must not be able to execute the switch");
    }

    /// @dev Operational consequence described in kpk's post: after the switch the pod must
    ///      batch through MultiSend 1.4.1; the 1.3.0 MultiSend is no longer an unwrapper.
    function test_multiSendVersionsBeforeAndAfterTheSwitch() public {
        bytes memory batch = bytes.concat(
            _packCall(USDC, _approveCall(GPV2_VAULT_RELAYER)), _packCall(WETH, _approveCall(GPV2_VAULT_RELAYER))
        );
        bytes memory ms = abi.encodeWithSelector(IMultiSend.multiSend.selector, batch);

        // Before: 1.3.0 unwrapped on the old Main, 1.4.1 rejected as an unknown target.
        _allowedViaDelegate(OLD_MAIN, MULTISEND_130, ms);
        _blockedViaDelegate(OLD_MAIN, MULTISEND_141, ms, IZodiacRoles.Status.TargetAddressNotAllowed);

        _executeViaEndowmentTimelock(_generateCallData());

        // After: 1.4.1 (both MultiSend and MultiSendCallOnly) unwrapped on the new Main,
        // 1.3.0 rejected.
        _allowedViaDelegate(NEW_MAIN, MULTISEND_141, ms);
        _allowedViaDelegate(NEW_MAIN, MULTISEND_CALL_ONLY_141, ms);
        _blockedViaDelegate(NEW_MAIN, MULTISEND_130, ms, IZodiacRoles.Status.TargetAddressNotAllowed);
        _blockedViaDelegate(NEW_MAIN, MULTISEND_CALL_ONLY_130, ms, IZodiacRoles.Status.TargetAddressNotAllowed);
    }

    /// @dev On-chain proof that the new Main's MANAGER policy is the old Main's policy with
    ///      the verified Update #10 payload applied, and nothing else.
    ///
    ///      The Update #10 admin calls (`expectedMultiSend.txt`, byte-identical to the manual
    ///      derivation in update10Payload.t.sol) are replayed onto the old Main here, and the
    ///      two modifiers are then compared slot by slot over every target and every
    ///      (target, selector) pair that either modifier has ever had configured
    ///      (`roleStateKeys.json`, produced by rolesReplay.py from both event histories):
    ///
    ///        targets     raw slot equality (clearance + execution options);
    ///        functions   canonical condition-tree equality, computed here from the packed
    ///                    buffers the modifiers actually evaluate. 316 of the 332 headers are
    ///                    byte-identical; 15 differ only in the order of Or alternatives and
    ///                    one in a trailing unconstrained parameter, both of which the checker
    ///                    treats identically (PermissionChecker._or, Decoder.inspect).
    function test_structuralEquivalence_oldMainPlusUpdate10EqualsNewMain() public {
        string memory json = vm.readFile(string.concat(DIR, "/roleStateKeys.json"));
        address[] memory targets = vm.parseJsonAddressArray(json, ".targets");
        bytes32[] memory functionKeys = vm.parseJsonBytes32Array(json, ".functionKeys");
        bytes32[] memory identical = vm.parseJsonBytes32Array(json, ".identical");
        bytes32[] memory orderOnly = vm.parseJsonBytes32Array(json, ".orderOnly");
        bytes32[] memory trailingPassOnly = vm.parseJsonBytes32Array(json, ".trailingPassOnly");
        assertEq(identical.length + orderOnly.length + trailingPassOnly.length, functionKeys.length, "key classes");

        // Layout probe: USDC is a scoped target on both modifiers today.
        assertEq(uint256(vm.load(OLD_MAIN, _targetSlot(USDC))), CLEARANCE_FUNCTION, "layout probe old");
        assertEq(uint256(vm.load(NEW_MAIN, _targetSlot(USDC))), CLEARANCE_FUNCTION, "layout probe new");

        // Before the delta the two differ (Update #10 targets are unknown to the old Main).
        assertEq(uint256(vm.load(OLD_MAIN, _targetSlot(KPK_USDC_YIELD))), 0, "old Main already scopes a new vault");

        uint256 applied = _applyUpdate10DeltaToOldMain();
        assertEq(applied, 50, "Update #10 Roles admin calls on the Main (14 scopeTarget + 36 scopeFunction)");

        // Targets
        for (uint256 i; i < targets.length; i++) {
            assertEq(
                vm.load(OLD_MAIN, _targetSlot(targets[i])),
                vm.load(NEW_MAIN, _targetSlot(targets[i])),
                string.concat("target clearance differs: ", vm.toString(targets[i]))
            );
        }

        // Functions
        uint256 rawEqual;
        uint256 configured;
        for (uint256 i; i < functionKeys.length; i++) {
            bytes32 ho = vm.load(OLD_MAIN, _scopeConfigSlot(functionKeys[i]));
            bytes32 hn = vm.load(NEW_MAIN, _scopeConfigSlot(functionKeys[i]));
            if (ho == hn) rawEqual++;
            if (hn != bytes32(0)) configured++;
            assertEq(
                _canonicalScopeConfig(OLD_MAIN, functionKeys[i]),
                _canonicalScopeConfig(NEW_MAIN, functionKeys[i]),
                string.concat("condition tree differs: ", vm.toString(functionKeys[i]))
            );
        }
        assertEq(configured, functionKeys.length, "every key configured on the new Main");
        assertEq(rawEqual, identical.length, "byte-identical header count");
        for (uint256 i; i < identical.length; i++) {
            assertEq(
                vm.load(OLD_MAIN, _scopeConfigSlot(identical[i])),
                vm.load(NEW_MAIN, _scopeConfigSlot(identical[i])),
                "identical class"
            );
        }
        for (uint256 i; i < orderOnly.length; i++) {
            assertTrue(
                vm.load(OLD_MAIN, _scopeConfigSlot(orderOnly[i])) != vm.load(NEW_MAIN, _scopeConfigSlot(orderOnly[i])),
                "orderOnly class"
            );
        }
        for (uint256 i; i < trailingPassOnly.length; i++) {
            assertTrue(
                vm.load(OLD_MAIN, _scopeConfigSlot(trailingPassOnly[i]))
                    != vm.load(NEW_MAIN, _scopeConfigSlot(trailingPassOnly[i])),
                "trailingPassOnly class"
            );
        }

        // Members, default roles, unwrappers
        assertEq(uint256(vm.load(OLD_MAIN, _memberSlot(karpatkey))), 1, "pod member old");
        assertEq(uint256(vm.load(NEW_MAIN, _memberSlot(karpatkey))), 1, "pod member new");
        assertEq(uint256(vm.load(OLD_MAIN, _memberSlot(SUB_ROLES))), 0, "sub not a member of old");
        assertEq(uint256(vm.load(NEW_MAIN, _memberSlot(SUB_ROLES))), 1, "sub member of new");
        assertEq(uint256(vm.load(NEW_MAIN, _memberSlot(OLD_SUB_ROLES))), 0, "superseded sub not a member");
        assertEq(uint256(vm.load(NEW_MAIN, _memberSlot(KPK_TEST_SAFE))), 0, "kpk test Safe not a member");
        assertEq(vm.load(NEW_MAIN, _defaultRoleSlot(SUB_ROLES)), MANAGER_ROLE, "sub default role");
        assertEq(vm.load(NEW_MAIN, _defaultRoleSlot(karpatkey)), bytes32(0), "pod has no default role");
        assertEq(
            address(uint160(uint256(vm.load(NEW_MAIN, _unwrapperSlot(MULTISEND_141))))), MULTISEND_UNWRAPPER, "1.4.1"
        );
        assertEq(
            address(uint160(uint256(vm.load(NEW_MAIN, _unwrapperSlot(MULTISEND_CALL_ONLY_141))))),
            MULTISEND_UNWRAPPER,
            "1.4.1 call-only"
        );
        assertEq(vm.load(NEW_MAIN, _unwrapperSlot(MULTISEND_130)), bytes32(0), "no 1.3.0 unwrapper on new");
        assertEq(
            address(uint160(uint256(vm.load(OLD_MAIN, _unwrapperSlot(MULTISEND_130))))),
            MULTISEND_UNWRAPPER,
            "1.3.0 old"
        );

        // The single trailing-Pass difference is exercised behaviourally in test_switch:
        // USDC.transfer stays pinned to the DAO Timelock on the old Main (_beforeExecution)
        // and on the new Main (_afterExecution).

        // Negative controls for the comparison itself.
        bytes32 usdcApprove = _fkey(USDC, IERC20.approve.selector);
        bytes32 before = _canonicalScopeConfig(OLD_MAIN, usdcApprove);
        // (a) re-scoping with the same spender list in reverse order changes the packed
        //     header but not the canonical tree;
        vm.prank(address(endowmentSafe));
        IRolesModifier(OLD_MAIN)
            .scopeFunction(MANAGER_ROLE, USDC, IERC20.approve.selector, _usdcApproveReversed(), EXEC_NONE);
        assertTrue(
            vm.load(OLD_MAIN, _scopeConfigSlot(usdcApprove)) != vm.load(NEW_MAIN, _scopeConfigSlot(usdcApprove)),
            "control (a): header must change"
        );
        assertEq(_canonicalScopeConfig(OLD_MAIN, usdcApprove), before, "control (a): canonical tree must not change");
        // (b) a one-spender change is detected.
        vm.prank(address(endowmentSafe));
        IRolesModifier(OLD_MAIN)
            .scopeFunction(MANAGER_ROLE, USDC, IERC20.approve.selector, _usdcApproveTampered(), EXEC_NONE);
        assertTrue(_canonicalScopeConfig(OLD_MAIN, usdcApprove) != before, "control (b): tampering must be detected");
        // (c) wildcarding is detected.
        vm.prank(address(endowmentSafe));
        IRolesAdmin(OLD_MAIN).allowFunction(MANAGER_ROLE, USDC, IERC20.approve.selector, EXEC_NONE);
        assertTrue(_canonicalScopeConfig(OLD_MAIN, usdcApprove) != before, "control (c): wildcard must be detected");
    }

    /// @dev USDC.approve spender list of the new Main (Update #10 state; 14 pre-existing
    ///      spenders plus the four vaults added by Update #10), as an Or group.
    function _usdcApproveSpenders() internal pure returns (address[] memory t) {
        t = new address[](18);
        t[0] = KPK_USDC_PRIME_RWA;
        t[1] = 0x4Ef53d2cAa51C447fdFEEedee8F07FD1962C9ee6;
        t[2] = 0x56C526b0159a258887e0d79ec3a80dfb940d0cD7;
        t[3] = UNISWAP_V3_ROUTER;
        t[4] = AAVE_V3_POOL;
        t[5] = 0x9Fb7b4477576Fe5B32be4C1843aFB1e55F251B33;
        t[6] = 0xA188EEC8F81263234dA3622A406892F3D630f98c;
        t[7] = BALANCER_V2_VAULT;
        t[8] = MORPHO_BLUE;
        t[9] = CURVE_3POOL;
        t[10] = STEAKHOUSE_HIGH_YIELD_USDC;
        t[11] = SMOKEHOUSE_USDC;
        t[12] = AAVE_V3_POOL_L1_BRIDGE;
        t[13] = 0xc3d688B66703497DAA19211EEdff47f25384cdc3;
        t[14] = GPV2_VAULT_RELAYER;
        t[15] = 0xd0A61F2963622e992e6534bde4D52fd0a89F39E0;
        t[16] = KPK_USDC_YIELD;
        t[17] = 0xe108fbc04852B5df72f9E44d7C29F47e7A993aDd;
    }

    function _approveConditions(address[] memory spenders) internal pure returns (ConditionFlat[] memory c) {
        c = new ConditionFlat[](2 + spenders.length);
        c[0] = ConditionFlat(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = ConditionFlat(0, PARAM_TYPE_NONE, OP_OR, "");
        for (uint256 i; i < spenders.length; i++) {
            c[2 + i] = ConditionFlat(1, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(spenders[i]));
        }
    }

    function _usdcApproveReversed() internal pure returns (ConditionFlat[] memory) {
        address[] memory s = _usdcApproveSpenders();
        address[] memory r = new address[](s.length);
        for (uint256 i; i < s.length; i++) {
            r[i] = s[s.length - 1 - i];
        }
        return _approveConditions(r);
    }

    function _usdcApproveTampered() internal pure returns (ConditionFlat[] memory) {
        address[] memory s = _usdcApproveSpenders();
        s[0] = address(0xdead);
        return _approveConditions(s);
    }

    // ─── Before
    // ───────────────────────────────────────────────────

    function _beforeExecution() internal {
        ISafe safe = ISafe(address(endowmentSafe));
        assertEq(safe.VERSION(), "1.3.0", "Safe version");
        address[] memory owners = safe.getOwners();
        assertEq(owners.length, 1, "Safe owner count");
        assertEq(owners[0], ENDOWMENT_TIMELOCK, "Safe owner");
        assertEq(safe.getThreshold(), 1, "Safe threshold");
        (address[] memory mods,) = safe.getModulesPaginated(SENTINEL, 10);
        assertEq(mods.length, 2, "Safe module count");
        assertEq(mods[0], OLD_MAIN, "old Main is the list head (prevModule = SENTINEL)");
        assertEq(mods[1], ALLOWANCE_MODULE, "Allowance module");
        safeNonceBefore = ISafeModules(address(endowmentSafe)).nonce();

        // EndowmentTimelock: Foundation proposes, Security Council vetoes, anyone executes.
        assertEq(endowmentTimelock.getMinDelay(), 9 days, "min delay");
        assertTrue(endowmentTimelock.hasRole(keccak256("PROPOSER_ROLE"), FOUNDATION_SAFE), "Foundation proposer");
        assertTrue(endowmentTimelock.hasRole(keccak256("PROPOSER_ROLE"), SC_VETO), "SC wrapper proposer");
        assertTrue(endowmentTimelock.hasRole(keccak256("EXECUTOR_ROLE"), address(0)), "open executor");
        assertFalse(endowmentTimelock.hasRole(keccak256("PROPOSER_ROLE"), DAO_TIMELOCK), "DAO Timelock not proposer");

        // Old Main: Roles v2.1.0, owned by the Safe, one member (the pod), MultiSend 1.3.0.
        _assertMinimalProxyOf(OLD_MAIN, ROLES_MASTERCOPY_V210);
        assertEq(IRolesAdmin(OLD_MAIN).owner(), address(endowmentSafe), "old Main owner");
        assertEq(IRolesAdmin(OLD_MAIN).avatar(), address(endowmentSafe), "old Main avatar");
        assertEq(IRolesAdmin(OLD_MAIN).target(), address(endowmentSafe), "old Main target");
        (address[] memory oldMods,) = IRolesAdmin(OLD_MAIN).getModulesPaginated(SENTINEL, 10);
        assertEq(oldMods.length, 1, "old Main callers");
        assertEq(oldMods[0], karpatkey, "old Main caller = pod");
        assertEq(
            IRolesAdmin(OLD_MAIN).unwrappers(_fkey(MULTISEND_130, IMultiSend.multiSend.selector)), MULTISEND_UNWRAPPER
        );
        assertEq(IRolesAdmin(OLD_MAIN).unwrappers(_fkey(MULTISEND_141, IMultiSend.multiSend.selector)), address(0));

        // New Main: Roles v2.1.1, avatar/target = Safe, members = {Sub, pod}, MultiSend 1.4.1.
        _assertMinimalProxyOf(NEW_MAIN, ROLES_MASTERCOPY_V211);
        assertEq(IRolesAdmin(NEW_MAIN).avatar(), address(endowmentSafe), "new Main avatar");
        assertEq(IRolesAdmin(NEW_MAIN).target(), address(endowmentSafe), "new Main target");
        (address[] memory newMods,) = IRolesAdmin(NEW_MAIN).getModulesPaginated(SENTINEL, 10);
        assertEq(newMods.length, 2, "new Main callers");
        assertEq(newMods[0], SUB_ROLES, "new Main caller 0 = Sub");
        assertEq(newMods[1], karpatkey, "new Main caller 1 = pod");
        assertEq(IRolesAdmin(NEW_MAIN).defaultRoles(SUB_ROLES), MANAGER_ROLE, "Sub default role on new Main");
        assertEq(IRolesAdmin(NEW_MAIN).defaultRoles(karpatkey), bytes32(0), "pod default role");
        assertEq(
            IRolesAdmin(NEW_MAIN).unwrappers(_fkey(MULTISEND_141, IMultiSend.multiSend.selector)), MULTISEND_UNWRAPPER
        );
        assertEq(
            IRolesAdmin(NEW_MAIN).unwrappers(_fkey(MULTISEND_CALL_ONLY_141, IMultiSend.multiSend.selector)),
            MULTISEND_UNWRAPPER
        );
        assertEq(IRolesAdmin(NEW_MAIN).unwrappers(_fkey(MULTISEND_130, IMultiSend.multiSend.selector)), address(0));
        assertEq(
            IRolesAdmin(NEW_MAIN).unwrappers(_fkey(MULTISEND_CALL_ONLY_130, IMultiSend.multiSend.selector)), address(0)
        );

        // Sub: Roles v2.1.1 owned by the pod, executing through the new Main, no role yet.
        _assertMinimalProxyOf(SUB_ROLES, ROLES_MASTERCOPY_V211);
        assertEq(IRolesAdmin(SUB_ROLES).owner(), karpatkey, "Sub owner");
        assertEq(IRolesAdmin(SUB_ROLES).avatar(), address(endowmentSafe), "Sub avatar");
        assertEq(IRolesAdmin(SUB_ROLES).target(), NEW_MAIN, "Sub target");
        (address[] memory subMods,) = IRolesAdmin(SUB_ROLES).getModulesPaginated(SENTINEL, 10);
        assertEq(subMods.length, 0, "Sub has no callers yet");
        assertEq(OLD_SUB_ROLES.code.length, 0, "superseded Sub address was never deployed");
        vm.prank(HARVEST_MEMBER);
        vm.expectRevert(abi.encodeWithSignature("NotAuthorized(address)", HARVEST_MEMBER));
        IZodiacRoles(SUB_ROLES)
            .execTransactionWithRole(
                FLUID_DISTRIBUTOR,
                0,
                _fluidClaimCall(address(endowmentSafe)),
                IZodiacRoles.Operation.Call,
                HARVEST_ROLE,
                false
            );

        // The new Main cannot act on the Safe before the switch.
        assertFalse(ISafeModules(address(endowmentSafe)).isModuleEnabled(NEW_MAIN), "new Main already enabled");
        vm.prank(karpatkey);
        vm.expectRevert(bytes("GS104"));
        IZodiacRoles(NEW_MAIN)
            .execTransactionWithRole(
                USDC, 0, _approveCall(GPV2_VAULT_RELAYER), IZodiacRoles.Operation.Call, MANAGER_ROLE, false
            );

        // Today's policy on the old Main: Update #10 venues unreachable, existing calls intact.
        _blockedVia(OLD_MAIN, KPK_USDC_YIELD, _depositCall(), IZodiacRoles.Status.TargetAddressNotAllowed);
        _blockedVia(
            OLD_MAIN, PENDLE_ROUTER_V4, _redeemPyToTokenCall(SUSDS), IZodiacRoles.Status.TargetAddressNotAllowed
        );
        _blockedVia(OLD_MAIN, SUSDS, _approveCall(PENDLE_ROUTER_V4), IZodiacRoles.Status.OrViolation);
        _assertCowSwapOrderBlocked(OLD_MAIN, SYRUP_USDC, USDC);
        _allowedVia(OLD_MAIN, USDC, _approveCall(GPV2_VAULT_RELAYER));
        _allowedVia(OLD_MAIN, USDC, _transferCall(DAO_TIMELOCK, 1));
        _blockedVia(OLD_MAIN, USDC, _transferCall(address(0xdead), 1), IZodiacRoles.Status.ParameterNotAllowed);
        _assertDistributorClaimsPinned(OLD_MAIN);

        // ── Precondition (NOT met on-chain at the fork block) ──
        // The new Main is owned by kpk's test Safe. Ownership must sit with the Endowment
        // Safe before the switch, otherwise the policy is editable outside the
        // Foundation → EndowmentTimelock path (see test_finding_…). Simulated here so the
        // rest of the verification describes the intended end state.
        address ownerAtFork = IRolesAdmin(NEW_MAIN).owner();
        if (ownerAtFork != address(endowmentSafe)) {
            console2.log("PRECONDITION NOT MET: new Main owner is", ownerAtFork);
            console2.log("  simulating transferOwnership(endowmentSafe) before the switch");
            vm.prank(ownerAtFork);
            IRolesAdmin(NEW_MAIN).transferOwnership(address(endowmentSafe));
        }
        assertEq(IRolesAdmin(NEW_MAIN).owner(), address(endowmentSafe), "new Main owner");
    }

    // ─── Calldata
    // ─────────────────────────────────────────────────

    /// @dev The two Safe calls of ENS_Switch_ZRM.json, packed for MultiSend.
    function _switchBatch() internal view returns (bytes memory) {
        return bytes.concat(
            _packCall(
                address(endowmentSafe), abi.encodeWithSelector(ISafeModules.disableModule.selector, SENTINEL, OLD_MAIN)
            ),
            _packCall(address(endowmentSafe), abi.encodeWithSelector(ISafeModules.enableModule.selector, NEW_MAIN))
        );
    }

    /// @notice Derive the Safe transaction and prove it equals the published batch.
    function _generateCallData() internal view returns (bytes memory execData) {
        bytes memory batch = _switchBatch();
        bytes memory expected = vm.parseBytes(vm.readFile(string.concat(DIR, "/expectedSwitchMultiSend.txt")));
        assertEq(batch.length, expected.length, "switch batch length differs from ENS_Switch_ZRM.json");
        assertEq(keccak256(batch), keccak256(expected), "switch batch differs from ENS_Switch_ZRM.json");

        // Safe.execTransaction(MultiSendCallOnly 1.3.0, delegatecall, pre-approved by the
        // EndowmentTimelock, the Safe's sole owner)
        (, execData) = _buildSafeMultiSendCalldata(batch, address(endowmentSafe), ENDOWMENT_TIMELOCK);
    }

    function multiSendTarget() internal pure returns (address) {
        return address(multiSend);
    }

    // ─── Execution: Foundation → EndowmentTimelock → Safe ─────────

    function _executeViaEndowmentTimelock(bytes memory execData) internal {
        uint256 delay = endowmentTimelock.getMinDelay();
        bytes32 id = endowmentTimelock.hashOperation(address(endowmentSafe), 0, execData, bytes32(0), SALT);

        vm.prank(FOUNDATION_SAFE);
        endowmentTimelock.schedule(address(endowmentSafe), 0, execData, bytes32(0), SALT, delay);
        assertTrue(endowmentTimelock.isOperationPending(id), "not pending");

        // The delay is enforced.
        vm.expectRevert(bytes("TimelockController: operation is not ready"));
        endowmentTimelock.execute(address(endowmentSafe), 0, execData, bytes32(0), SALT);

        vm.warp(block.timestamp + delay);
        vm.roll(block.number + delay / 12);
        assertTrue(endowmentTimelock.isOperationReady(id), "not ready");

        // Executor role is open: any address can execute once ready.
        vm.prank(address(0xA11CE));
        endowmentTimelock.execute(address(endowmentSafe), 0, execData, bytes32(0), SALT);
        assertTrue(endowmentTimelock.isOperationDone(id), "not done");
    }

    // ─── After
    // ────────────────────────────────────────────────────

    function _afterExecution() internal {
        // The Safe now has the new Main and the untouched Allowance module.
        (address[] memory mods,) = ISafe(address(endowmentSafe)).getModulesPaginated(SENTINEL, 10);
        assertEq(mods.length, 2, "Safe module count after switch");
        assertEq(mods[0], NEW_MAIN, "new Main enabled");
        assertEq(mods[1], ALLOWANCE_MODULE, "Allowance module untouched");
        assertFalse(ISafeModules(address(endowmentSafe)).isModuleEnabled(OLD_MAIN), "old Main still enabled");
        assertEq(ISafeModules(address(endowmentSafe)).nonce(), safeNonceBefore + 1, "one Safe transaction");
        assertEq(ISafe(address(endowmentSafe)).getOwners()[0], ENDOWMENT_TIMELOCK, "owner unchanged");

        // The old Main is dormant: still owned by the Safe, but it can no longer execute.
        assertEq(IRolesAdmin(OLD_MAIN).owner(), address(endowmentSafe), "old Main owner");
        vm.prank(karpatkey);
        vm.expectRevert(bytes("GS104"));
        IZodiacRoles(OLD_MAIN)
            .execTransactionWithRole(
                USDC, 0, _approveCall(GPV2_VAULT_RELAYER), IZodiacRoles.Operation.Call, MANAGER_ROLE, false
            );

        // The new Main is governed by the Safe and wired as before.
        assertEq(IRolesAdmin(NEW_MAIN).owner(), address(endowmentSafe), "new Main owner");
        assertEq(IRolesAdmin(SUB_ROLES).target(), NEW_MAIN, "Sub target");
        assertEq(IRolesAdmin(SUB_ROLES).owner(), karpatkey, "Sub owner");

        // Existing permissions carried over.
        _allowedVia(NEW_MAIN, USDC, _approveCall(GPV2_VAULT_RELAYER));
        _allowedVia(NEW_MAIN, USDC, _transferCall(DAO_TIMELOCK, 1));
        _blockedVia(NEW_MAIN, USDC, _transferCall(address(0xdead), 1), IZodiacRoles.Status.ParameterNotAllowed);
        _blockedVia(NEW_MAIN, address(0xdead), "", IZodiacRoles.Status.TargetAddressNotAllowed);
        _blockedVia(NEW_MAIN, NEW_MAIN, "", IZodiacRoles.Status.TargetAddressNotAllowed);
        _blockedVia(NEW_MAIN, OLD_MAIN, "", IZodiacRoles.Status.TargetAddressNotAllowed);
        _blockedVia(NEW_MAIN, SUB_ROLES, "", IZodiacRoles.Status.TargetAddressNotAllowed);
        // The Safe itself is a scoped target on both Mains (pre-existing, carried over:
        // setFallbackHandler and the CoW ExtensibleFallbackHandler's setDomainVerifier), so
        // anything else on it is rejected at the function level.
        _blockedVia(NEW_MAIN, address(endowmentSafe), "", IZodiacRoles.Status.FunctionNotAllowed);
        _blockedVia(
            NEW_MAIN,
            address(endowmentSafe),
            abi.encodeWithSelector(ISafeModules.enableModule.selector, address(0xdead)),
            IZodiacRoles.Status.FunctionNotAllowed
        );
        _blockedVia(
            NEW_MAIN,
            address(endowmentSafe),
            abi.encodeWithSelector(ISafeModules.disableModule.selector, SENTINEL, NEW_MAIN),
            IZodiacRoles.Status.FunctionNotAllowed
        );
        _assertNoSilentRemovals(NEW_MAIN);
        _assertDistributorClaimsPinned(NEW_MAIN);

        // Update #10 permissions, as verified in round 1, now live on the new Main.
        _assertMorphoStyleVaults(NEW_MAIN);
        _assertTokenApprovals(NEW_MAIN);
        _assertAaveHorizon(NEW_MAIN);
        _assertPendle(NEW_MAIN);
        _assertSyrupRouting(NEW_MAIN);
        _assertHarvestArchitecture();
    }

    // ─── Update #10 permission assertions (module-parameterised) ──

    function _assertMorphoStyleVaults(address m) internal {
        _assertVaultScope(m, KPK_ETH_YIELD);
        _assertVaultScope(m, KPK_USDC_YIELD);
        _assertVaultScope(m, SENTORA_PYUSD_MAIN);
        _assertVaultScope(m, SENTORA_RLUSD_MAIN);
        _assertVaultScope(m, SMOKEHOUSE_USDC);
        _assertVaultScope(m, STEAKHOUSE_HIGH_YIELD_USDC);
        _assertVaultScope(m, KPK_USDC_PRIME_RWA);
    }

    function _assertVaultScope(address m, address vault) internal {
        address safe = address(endowmentSafe);
        _allowedVia(m, vault, _depositCall());
        _blockedVia(
            m,
            vault,
            abi.encodeWithSelector(IMetaMorphoV1.deposit.selector, uint256(1), address(0xdead)),
            IZodiacRoles.Status.ParameterNotAllowed
        );
        _allowedVia(m, vault, abi.encodeWithSelector(IMetaMorphoV1.withdraw.selector, uint256(1), safe, safe));
        _blockedVia(
            m,
            vault,
            abi.encodeWithSelector(IMetaMorphoV1.withdraw.selector, uint256(1), address(0xdead), safe),
            IZodiacRoles.Status.ParameterNotAllowed
        );
        _blockedVia(
            m,
            vault,
            abi.encodeWithSelector(IMetaMorphoV1.withdraw.selector, uint256(1), safe, address(0xdead)),
            IZodiacRoles.Status.ParameterNotAllowed
        );
        _allowedVia(m, vault, abi.encodeWithSelector(IMetaMorphoV1.redeem.selector, uint256(1), safe, safe));
        _blockedVia(
            m,
            vault,
            abi.encodeWithSelector(IMetaMorphoV1.redeem.selector, uint256(1), address(0xdead), safe),
            IZodiacRoles.Status.ParameterNotAllowed
        );
        _blockedVia(m, vault, _transferCall(address(0xdead), 1), IZodiacRoles.Status.FunctionNotAllowed);
    }

    function _assertTokenApprovals(address m) internal {
        _allowedVia(m, WETH, _approveCall(KPK_ETH_YIELD));
        _allowedVia(m, USDC, _approveCall(KPK_USDC_YIELD));
        _allowedVia(m, USDC, _approveCall(SMOKEHOUSE_USDC));
        _allowedVia(m, USDC, _approveCall(STEAKHOUSE_HIGH_YIELD_USDC));
        _allowedVia(m, USDC, _approveCall(KPK_USDC_PRIME_RWA));
        _allowedVia(m, USDS, _approveCall(PENDLE_ROUTER_V4));
        _allowedVia(m, SUSDS, _approveCall(PENDLE_ROUTER_V4));
        _allowedVia(m, PYUSD, _approveCall(SENTORA_PYUSD_MAIN));
        _allowedVia(m, RLUSD, _approveCall(SENTORA_RLUSD_MAIN));
        _allowedVia(m, RLUSD, _approveCall(AAVE_V3_HORIZON_POOL));
        _allowedVia(m, PT_SUSDS_26NOV2026, _approveCall(PENDLE_ROUTER_V4));

        _blockedVia(m, WETH, _approveCall(address(0xdead)), IZodiacRoles.Status.OrViolation);
        _blockedVia(m, USDC, _approveCall(address(0xdead)), IZodiacRoles.Status.OrViolation);
        _blockedVia(m, USDS, _approveCall(address(0xdead)), IZodiacRoles.Status.OrViolation);
        _blockedVia(m, SUSDS, _approveCall(address(0xdead)), IZodiacRoles.Status.OrViolation);
        _blockedVia(m, RLUSD, _approveCall(address(0xdead)), IZodiacRoles.Status.OrViolation);
        _blockedVia(m, PYUSD, _approveCall(address(0xdead)), IZodiacRoles.Status.ParameterNotAllowed);
        _blockedVia(m, PT_SUSDS_26NOV2026, _approveCall(address(0xdead)), IZodiacRoles.Status.ParameterNotAllowed);

        _blockedVia(m, PYUSD, _transferCall(address(0xdead), 1), IZodiacRoles.Status.FunctionNotAllowed);
        _blockedVia(m, RLUSD, _transferCall(address(0xdead), 1), IZodiacRoles.Status.FunctionNotAllowed);
        _blockedVia(m, PT_SUSDS_26NOV2026, _transferCall(address(0xdead), 1), IZodiacRoles.Status.FunctionNotAllowed);
    }

    function _assertAaveHorizon(address m) internal {
        address safe = address(endowmentSafe);
        _allowedVia(m, AAVE_V3_HORIZON_POOL, abi.encodeWithSelector(IAaveV3Pool.supply.selector, RLUSD, 1, safe, 0));
        _allowedVia(m, AAVE_V3_HORIZON_POOL, abi.encodeWithSelector(IAaveV3Pool.withdraw.selector, RLUSD, 1, safe));
        _blockedVia(
            m,
            AAVE_V3_HORIZON_POOL,
            abi.encodeWithSelector(IAaveV3Pool.supply.selector, USDC, 1, safe, 0),
            IZodiacRoles.Status.ParameterNotAllowed
        );
        _blockedVia(
            m,
            AAVE_V3_HORIZON_POOL,
            abi.encodeWithSelector(IAaveV3Pool.supply.selector, RLUSD, 1, address(0xdead), 0),
            IZodiacRoles.Status.ParameterNotAllowed
        );
        _blockedVia(
            m,
            AAVE_V3_HORIZON_POOL,
            abi.encodeWithSelector(IAaveV3Pool.withdraw.selector, RLUSD, 1, address(0xdead)),
            IZodiacRoles.Status.ParameterNotAllowed
        );
        _blockedVia(
            m,
            AAVE_V3_HORIZON_POOL,
            abi.encodeWithSignature("borrow(address,uint256,uint256,uint16,address)", RLUSD, 1, 2, 0, safe),
            IZodiacRoles.Status.FunctionNotAllowed
        );
    }

    function _assertPendle(address m) internal {
        _allowedVia(m, PENDLE_ROUTER_V4, _redeemPyToTokenCall(SUSDS));
        _allowedVia(m, PENDLE_ROUTER_V4, _redeemPyToTokenCall(USDS));
        _blockedVia(m, PENDLE_ROUTER_V4, _redeemPyToTokenCall(USDC), IZodiacRoles.Status.OrViolation);
        _blockedVia(
            m,
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
        _allowedVia(m, PENDLE_ROUTER_V4, _swapExactPtForTokenCall(PENDLE_MARKET_SUSDS, SUSDS));
        _blockedVia(
            m,
            PENDLE_ROUTER_V4,
            _swapExactPtForTokenCall(address(0xdead), SUSDS),
            IZodiacRoles.Status.ParameterNotAllowed
        );
        _allowedVia(m, PENDLE_ROUTER_V4, _swapExactTokenForPtCall(PENDLE_MARKET_SUSDS, SUSDS));
        _allowedVia(m, PENDLE_ROUTER_V4, _swapExactTokenForPtCall(PENDLE_MARKET_SUSDS, USDS));
        _blockedVia(
            m, PENDLE_ROUTER_V4, _swapExactTokenForPtCall(PENDLE_MARKET_SUSDS, USDC), IZodiacRoles.Status.OrViolation
        );
        _blockedVia(
            m,
            PENDLE_ROUTER_V4,
            _swapExactTokenForPtCall(address(0xdead), SUSDS),
            IZodiacRoles.Status.ParameterNotAllowed
        );

        // External-aggregator escape hatch pinned shut.
        IPendleRouterV4.TokenInput memory input = _tokenInput(SUSDS);
        input.pendleSwap = address(0xdead);
        _blockedVia(
            m,
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
        _blockedVia(
            m,
            PENDLE_ROUTER_V4,
            abi.encodeWithSignature("redeemDueInterestAndRewards(address,address[],address[],address[])"),
            IZodiacRoles.Status.FunctionNotAllowed
        );
    }

    function _assertSyrupRouting(address m) internal {
        _assertCowSwapOrderPermitted(m, SYRUP_USDC, USDC);
        _assertCowSwapOrderPermitted(m, USDC, SYRUP_USDC);
        _assertCowSwapOrderPermitted(m, SYRUP_USDT, USDT);
        _assertCowSwapOrderPermitted(m, USDT, SYRUP_USDT);
        _assertCowSwapOrderPermitted(m, USDC, WETH);
        _assertCowSwapOrderBlocked(m, SYRUP_USDC, WETH);
        _assertCowSwapOrderBlocked(m, SYRUP_USDC, USDT);
        _assertCowSwapOrderBlocked(m, SYRUP_USDT, WETH);
        _assertCowSwapOrderBlocked(m, SYRUP_USDT, USDC);
        _assertCowSwapOrderBlocked(m, SYRUP_USDC, SYRUP_USDT);
        _assertCowSwapOrderBlockedTo(m, SYRUP_USDC, USDC, address(0xdead));
        _allowedVia(m, SYRUP_USDC, _approveCall(GPV2_VAULT_RELAYER));
        _allowedVia(m, SYRUP_USDT, _approveCall(GPV2_VAULT_RELAYER));
        _blockedVia(m, SYRUP_USDC, _approveCall(address(0xdead)), IZodiacRoles.Status.ParameterNotAllowed);
        _blockedVia(m, SYRUP_USDT, _transferCall(address(0xdead), 1), IZodiacRoles.Status.FunctionNotAllowed);
    }

    function _assertNoSilentRemovals(address m) internal {
        _allowedVia(m, WETH, _approveCall(GPV2_VAULT_RELAYER));
        _allowedVia(m, WETH, _approveCall(AAVE_V3_POOL));
        _allowedVia(m, WETH, _approveCall(PERMIT2));
        _allowedVia(m, WETH, _approveCall(BALANCER_V2_VAULT));
        _allowedVia(m, WETH, _approveCall(UNISWAP_V3_ROUTER));
        _allowedVia(m, WETH, _approveCall(MORPHO_BLUE));
        _allowedVia(m, WETH, _approveCall(ETHERFI_DEPOSIT_ADAPTER));
        _allowedVia(m, USDC, _approveCall(GPV2_VAULT_RELAYER));
        _allowedVia(m, USDC, _approveCall(AAVE_V3_POOL));
        _allowedVia(m, USDC, _approveCall(MORPHO_BLUE));
        _allowedVia(m, USDC, _approveCall(CURVE_3POOL));
        _allowedVia(m, USDC, _approveCall(BALANCER_V2_VAULT));
        _allowedVia(m, USDC, _approveCall(UNISWAP_V3_ROUTER));
        _allowedVia(m, USDS, _approveCall(GPV2_VAULT_RELAYER));
        _allowedVia(m, USDS, _approveCall(SUSDS));
        _allowedVia(m, USDS, _approveCall(AAVE_V3_POOL));
        _allowedVia(m, USDS, _approveCall(UNISWAP_V3_ROUTER));
        _allowedVia(m, SUSDS, _approveCall(GPV2_VAULT_RELAYER));
        _allowedVia(m, SUSDS, _approveCall(UNISWAP_V3_ROUTER));
    }

    function _assertDistributorClaimsPinned(address m) internal {
        _allowedVia(m, FLUID_DISTRIBUTOR, _fluidClaimCall(address(endowmentSafe)));
        _allowedVia(m, FLUID_GHO_DISTRIBUTOR, _fluidClaimCall(address(endowmentSafe)));
        _allowedVia(m, MERKL_DISTRIBUTOR, _merklClaimCall(address(endowmentSafe)));
        _blockedVia(m, FLUID_DISTRIBUTOR, _fluidClaimCall(address(0xdead)), IZodiacRoles.Status.ParameterNotAllowed);
        _blockedVia(m, FLUID_GHO_DISTRIBUTOR, _fluidClaimCall(address(0xdead)), IZodiacRoles.Status.ParameterNotAllowed);
        _blockedVia(m, MERKL_DISTRIBUTOR, _merklClaimCall(address(0xdead)), IZodiacRoles.Status.OrViolation);
    }

    /// @dev kpk (owner of the Sub) configures the Harvest role after the switch, per its
    ///      configuration repository. The Sub is deliberately configured permissively to
    ///      show that the new Main's MANAGER conditions still pin every payout to the Safe.
    function _assertHarvestArchitecture() internal {
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
        uint256 snap = vm.snapshotState();
        IZodiacRoles(SUB_ROLES)
            .execTransactionWithRole(
                FLUID_DISTRIBUTOR,
                0,
                _fluidClaimCall(address(endowmentSafe)),
                IZodiacRoles.Operation.Call,
                HARVEST_ROLE,
                false
            );
        IZodiacRoles(SUB_ROLES)
            .execTransactionWithRole(
                MERKL_DISTRIBUTOR,
                0,
                _merklClaimCall(address(endowmentSafe)),
                IZodiacRoles.Operation.Call,
                HARVEST_ROLE,
                false
            );
        vm.revertToState(snap);

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

    // ─── Update #10 delta replay (structural test) ────────────────

    /// @dev Replays the Roles admin calls of the verified Update #10 payload onto the old
    ///      Main, pranked as its owner (the Safe). Calls that concern the superseded Sub
    ///      (deployModule, enableModule, setDefaultRole, assignRoles, setTransactionUnwrapper,
    ///      setTarget, transferOwnership) and the annotation post are skipped.
    function _applyUpdate10DeltaToOldMain() internal returns (uint256 applied) {
        bytes memory txs = vm.parseBytes(vm.readFile(string.concat(DIR, "/expectedMultiSend.txt")));
        uint256 i;
        while (i < txs.length) {
            address to = address(uint160(uint256(_word(txs, i + 1) >> 96)));
            uint256 len = uint256(_word(txs, i + 53));
            bytes memory data = _slice(txs, i + 85, len);
            i += 85 + len;
            bytes4 sel = bytes4(data);
            bool isPolicyCall = sel == IRolesModifier.scopeTarget.selector
                || sel == IRolesModifier.scopeFunction.selector || sel == IRolesModifier.allowFunction.selector
                || sel == IRolesModifier.revokeFunction.selector || sel == IRolesModifier.revokeTarget.selector
                || sel == IRolesAdmin.allowTarget.selector;
            if (to != OLD_MAIN || !isPolicyCall) continue;
            vm.prank(address(endowmentSafe));
            (bool ok,) = OLD_MAIN.call(data);
            require(ok, "delta call failed on old Main");
            applied++;
        }
    }

    // ─── Canonical condition trees from packed storage ────────────

    /// @dev Canonical hash of a scopeConfig entry, computed from the packed buffer the
    ///      modifier evaluates (BufferPacker layout): wildcard entries hash their execution
    ///      options; scoped entries hash the condition tree with And/Or/Nor children sorted
    ///      and trailing Pass leaves of Matches nodes pruned.
    function _canonicalScopeConfig(address module, bytes32 key) internal view returns (bytes32) {
        uint256 header = uint256(vm.load(module, _scopeConfigSlot(key)));
        if (header == 0) return bytes32(0);
        uint8 options = uint8(header >> 224);
        if ((header >> 216) & 1 == 1) return keccak256(abi.encode("wildcard", options));

        uint256 count = header >> 240;
        bytes memory buffer = address(uint160(header)).code; // 0x00 || packed conditions
        uint8[] memory parent = new uint8[](count);
        uint8[] memory paramType = new uint8[](count);
        uint8[] memory operator = new uint8[](count);
        bytes32[] memory compValue = new bytes32[](count);
        uint256 compOffset = 1 + count * 2;
        for (uint256 i; i < count; i++) {
            uint16 bits = uint16(bytes2(_word(buffer, 1 + i * 2)));
            parent[i] = uint8(bits >> 8);
            paramType[i] = uint8((bits >> 5) & 0x07);
            operator[i] = uint8(bits & 0x1f);
            if (operator[i] >= OP_EQUAL_TO) {
                compValue[i] = _word(buffer, compOffset);
                compOffset += 32;
            }
        }
        return keccak256(abi.encode(options, _canonicalNode(0, parent, paramType, operator, compValue)));
    }

    function _canonicalNode(
        uint256 node,
        uint8[] memory parent,
        uint8[] memory paramType,
        uint8[] memory operator,
        bytes32[] memory compValue
    )
        internal
        pure
        returns (bytes32)
    {
        uint256 n = parent.length;
        uint256 childCount;
        for (uint256 j = node + 1; j < n; j++) {
            if (parent[j] == node) childCount++;
        }
        bytes32[] memory children = new bytes32[](childCount);
        bool[] memory inertLeaf = new bool[](childCount);
        uint256 c;
        for (uint256 j = node + 1; j < n; j++) {
            if (parent[j] != node) continue;
            children[c] = _canonicalNode(j, parent, paramType, operator, compValue);
            inertLeaf[c] = operator[j] == OP_PASS && !_hasChildren(j, parent);
            c++;
        }
        if (operator[node] == OP_MATCHES) {
            while (childCount > 0 && inertLeaf[childCount - 1]) childCount--;
            assembly {
                mstore(children, childCount)
            }
        }
        if (operator[node] == 1 || operator[node] == OP_OR || operator[node] == 3) _sort(children);
        bytes32 value = operator[node] >= OP_EQUAL_TO ? compValue[node] : bytes32(0);
        return keccak256(abi.encode(paramType[node], operator[node], value, children));
    }

    function _hasChildren(uint256 node, uint8[] memory parent) internal pure returns (bool) {
        for (uint256 j = node + 1; j < parent.length; j++) {
            if (parent[j] == node) return true;
        }
        return false;
    }

    function _sort(bytes32[] memory a) internal pure {
        for (uint256 i = 1; i < a.length; i++) {
            bytes32 v = a[i];
            uint256 j = i;
            while (j > 0 && a[j - 1] > v) {
                a[j] = a[j - 1];
                j--;
            }
            a[j] = v;
        }
    }

    // ─── Storage slots
    // ────────────────────────────────────────────

    function _roleBase() internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(MANAGER_ROLE, SLOT_ROLES)));
    }

    function _memberSlot(address m) internal pure returns (bytes32) {
        return keccak256(abi.encode(m, _roleBase()));
    }

    function _targetSlot(address t) internal pure returns (bytes32) {
        return keccak256(abi.encode(t, _roleBase() + 1));
    }

    function _scopeConfigSlot(bytes32 key) internal pure returns (bytes32) {
        return keccak256(abi.encode(key, _roleBase() + 2));
    }

    function _unwrapperSlot(address to) internal pure returns (bytes32) {
        return keccak256(abi.encode(_fkey(to, IMultiSend.multiSend.selector), SLOT_UNWRAPPERS));
    }

    function _defaultRoleSlot(address m) internal pure returns (bytes32) {
        return keccak256(abi.encode(m, SLOT_DEFAULT_ROLES));
    }

    /// @dev Roles `_key(target, selector)`: bytes20(target) || selector || 0
    function _fkey(address t, bytes4 sel) internal pure returns (bytes32) {
        return bytes32(bytes20(t)) | (bytes32(sel) >> 160);
    }

    // ─── Probes
    // ───────────────────────────────────────────────────

    function _allowedVia(address module, address target, bytes memory data) internal {
        uint256 snap = vm.snapshotState();
        vm.prank(karpatkey);
        IZodiacRoles(module).execTransactionWithRole(target, 0, data, IZodiacRoles.Operation.Call, MANAGER_ROLE, false);
        vm.revertToState(snap);
    }

    function _blockedVia(address module, address target, bytes memory data, IZodiacRoles.Status status) internal {
        vm.prank(karpatkey);
        if (status == IZodiacRoles.Status.FunctionNotAllowed) {
            vm.expectRevert(
                abi.encodeWithSelector(IZodiacRoles.ConditionViolation.selector, status, bytes32(bytes4(data)))
            );
        } else {
            _expectConditionViolation(status);
        }
        IZodiacRoles(module).execTransactionWithRole(target, 0, data, IZodiacRoles.Operation.Call, MANAGER_ROLE, false);
    }

    function _allowedViaDelegate(address module, address target, bytes memory data) internal {
        uint256 snap = vm.snapshotState();
        vm.prank(karpatkey);
        IZodiacRoles(module)
            .execTransactionWithRole(target, 0, data, IZodiacRoles.Operation.DelegateCall, MANAGER_ROLE, true);
        vm.revertToState(snap);
    }

    function _blockedViaDelegate(
        address module,
        address target,
        bytes memory data,
        IZodiacRoles.Status status
    )
        internal
    {
        vm.prank(karpatkey);
        _expectConditionViolation(status);
        IZodiacRoles(module)
            .execTransactionWithRole(target, 0, data, IZodiacRoles.Operation.DelegateCall, MANAGER_ROLE, true);
    }

    function _assertCowSwapOrderPermitted(address m, address sell, address buy) internal {
        uint256 snap = vm.snapshotState();
        vm.prank(karpatkey);
        IZodiacRoles(m)
            .execTransactionWithRole(
                COWSWAP_ORDER_SIGNER,
                0,
                _signOrderCall(sell, buy, address(endowmentSafe)),
                IZodiacRoles.Operation.DelegateCall,
                MANAGER_ROLE,
                false
            );
        vm.revertToState(snap);
    }

    function _assertCowSwapOrderBlocked(address m, address sell, address buy) internal {
        _assertCowSwapOrderBlockedTo(m, sell, buy, address(endowmentSafe));
    }

    function _assertCowSwapOrderBlockedTo(address m, address sell, address buy, address receiver) internal {
        vm.prank(karpatkey);
        _expectConditionViolation(IZodiacRoles.Status.OrViolation);
        IZodiacRoles(m)
            .execTransactionWithRole(
                COWSWAP_ORDER_SIGNER,
                0,
                _signOrderCall(sell, buy, receiver),
                IZodiacRoles.Operation.DelegateCall,
                MANAGER_ROLE,
                false
            );
    }

    function _assertMinimalProxyOf(address proxy, address implementation) internal view {
        bytes memory expected =
            abi.encodePacked(hex"363d3d373d3d3d363d73", implementation, hex"5af43d82803e903d91602b57fd5bf3");
        assertEq(keccak256(proxy.code), keccak256(expected), "not an EIP-1167 clone of the expected mastercopy");
    }

    // ─── Call builders
    // ────────────────────────────────────────────

    function _approveCall(address spender) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(IERC20.approve.selector, spender, uint256(1));
    }

    function _transferCall(address to, uint256 amount) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(IERC20.transfer.selector, to, amount);
    }

    function _depositCall() internal view returns (bytes memory) {
        return abi.encodeWithSelector(IMetaMorphoV1.deposit.selector, uint256(1), address(endowmentSafe));
    }

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

    function _signOrderCall(address sell, address buy, address receiver) internal pure returns (bytes memory) {
        ICowSwapOrderSigner.Data memory order = ICowSwapOrderSigner.Data({
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
        return abi.encodeWithSelector(ICowSwapOrderSigner.signOrder.selector, order, uint32(0), uint256(0));
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

    // ─── Byte helpers
    // ─────────────────────────────────────────────

    function _word(bytes memory b, uint256 offset) internal pure returns (bytes32 w) {
        require(offset <= b.length, "word out of range");
        assembly {
            w := mload(add(add(b, 32), offset))
        }
    }

    function _slice(bytes memory b, uint256 offset, uint256 len) internal pure returns (bytes memory out) {
        require(offset + len <= b.length, "slice out of range");
        out = new bytes(len);
        for (uint256 i; i < len; i++) {
            out[i] = b[offset + i];
        }
    }
}
