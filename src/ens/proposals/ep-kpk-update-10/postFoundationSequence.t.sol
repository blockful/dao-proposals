// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";
import { SafeHelper } from "@ens/helpers/SafeHelper.sol";
import { ZodiacRolesHelper } from "@ens/helpers/ZodiacRolesHelper.sol";
import { IZodiacRoles } from "@ens/interfaces/IZodiacRoles.sol";
import { IMultiSend } from "@ens/interfaces/IMultiSend.sol";
import { IMetaMorphoV1 } from "@ens/interfaces/IMetaMorphoV1.sol";
import { IERC20 } from "@forge-std/src/interfaces/IERC20.sol";

interface ISafeOwners {
    function isOwner(address owner) external view returns (bool);
    function swapOwner(address prevOwner, address oldOwner, address newOwner) external;
}

interface IOZTimelock {
    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    )
        external;
    function execute(
        address target,
        uint256 value,
        bytes calldata payload,
        bytes32 predecessor,
        bytes32 salt
    )
        external
        payable;
    function getMinDelay() external view returns (uint256);
}

interface IRolesModule {
    function owner() external view returns (address);
    function avatar() external view returns (address);
    function target() external view returns (address);
}

interface IAaveV3PoolMin {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
}

/**
 * @title Update #10 sequenced after "Empowering the ENS Foundation"
 * @notice LOCAL SIMULATION (not part of the published review). Assumes the currently
 *         active proposal (on-chain id 0x80619211...810120, "Next Era of ENS DAO:
 *         Empowering the ENS Foundation") passes and executes BEFORE the Update #10
 *         payload reaches execution.
 *
 *         The Foundation proposal's second call replaces the DAO Timelock with the
 *         new EndowmentTimelock as the sole owner of the Endowment Safe. Update #10
 *         executes on that Safe using a pre-approved owner signature from the DAO
 *         Timelock, so ordering is decisive:
 *
 *           1. Control: before the swap, the Update #10 transaction executes.
 *           2. After the swap, the same transaction reverts with GS026 (invalid
 *              owner signature): a DAO proposal carrying today's Update #10 calldata
 *              is unexecutable.
 *           3. The payload remains executable if routed through the new stack:
 *              Foundation Safe schedules it on the EndowmentTimelock (9-day delay),
 *              signed by the EndowmentTimelock as owner.
 *           4. After the rerouted execution, the Update #10 permissions behave
 *              exactly as verified in the main review.
 */
contract Update10_After_FoundationEmpowerment_Test is Test, SafeHelper, ZodiacRolesHelper {
    address private constant DAO_TIMELOCK = 0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7;
    address private constant ENDOWMENT_TIMELOCK = 0x0bcC3dA6aD796F59288C0961602675E88A2B406C;
    address private constant FOUNDATION_SAFE = 0x9C7dB6B1085ec4D07f75c0BD91AD3FcD368fA19E;
    address private constant SENTINEL = address(0x1);
    address private constant MULTISEND = 0x40A2aCCbd92BCA938b02010E17A5b8929b49130D;

    address private constant SUB_ROLES = 0xa5dd28EC9C69627A96202897b35B88827854bd3b;
    address private constant KPK_USDC_YIELD = 0xD5cCe260E7a755DDf0Fb9cdF06443d593AaeaA13;
    address private constant SENTORA_RLUSD_MAIN = 0x6dC58a0FdfC8D694e571DC59B9A52EEEa780E6bf;
    address private constant AAVE_V3_HORIZON_POOL = 0xAe05Cd22df81871bc7cC2a04BeCfb516bFe332C8;
    address private constant RLUSD = 0x8292Bb45bf1Ee4d140127049757C2E0fF06317eD;

    function setUp() public {
        vm.createSelectFork({ blockNumber: 25_676_000, urlOrAlias: "mainnet" });
    }

    function test_update10AfterFoundationEmpowerment() public {
        bytes memory update10ByDao = _buildUpdate10ExecData(DAO_TIMELOCK);

        // ── Control: on today's state the Update #10 transaction executes ──
        uint256 snap = vm.snapshot();
        vm.prank(DAO_TIMELOCK);
        (bool okBefore,) = address(endowmentSafe).call(update10ByDao);
        assertTrue(okBefore, "control: Update #10 must execute before the owner swap");
        assertGt(SUB_ROLES.code.length, 0, "control: sub-Roles deployed");
        vm.revertTo(snap);

        // ── Step 1: the Foundation proposal executes first (owner swap) ──
        // Its first call (1,000,000 ENS to the Foundation Safe) does not touch the
        // Endowment; only the second call matters here. Reconstructed manually and
        // already byte-verified against the live proposal in PR #101.
        bytes memory swapOwnerData =
            abi.encodeWithSelector(ISafeOwners.swapOwner.selector, SENTINEL, DAO_TIMELOCK, ENDOWMENT_TIMELOCK);
        (, bytes memory foundationExec) =
            _buildSafeExecCalldata(address(endowmentSafe), address(endowmentSafe), swapOwnerData, DAO_TIMELOCK);
        vm.prank(DAO_TIMELOCK);
        (bool okSwap,) = address(endowmentSafe).call(foundationExec);
        assertTrue(okSwap, "foundation owner swap failed");
        assertFalse(ISafeOwners(address(endowmentSafe)).isOwner(DAO_TIMELOCK), "DAO timelock still owner");
        assertTrue(ISafeOwners(address(endowmentSafe)).isOwner(ENDOWMENT_TIMELOCK), "EndowmentTimelock not owner");

        // ── Step 2: the same Update #10 transaction is now unexecutable ──
        vm.prank(DAO_TIMELOCK);
        vm.expectRevert(bytes("GS026"));
        address(endowmentSafe).call(update10ByDao);

        // ── Step 3: rerouted through the Foundation-controlled stack, it executes ──
        bytes memory update10ByEndowmentTimelock = _buildUpdate10ExecData(ENDOWMENT_TIMELOCK);
        bytes32 salt = keccak256("ensPermissionsUpdate10");
        uint256 delay = IOZTimelock(ENDOWMENT_TIMELOCK).getMinDelay();
        assertEq(delay, 9 days, "unexpected EndowmentTimelock min delay");

        vm.prank(FOUNDATION_SAFE);
        IOZTimelock(ENDOWMENT_TIMELOCK)
            .schedule(address(endowmentSafe), 0, update10ByEndowmentTimelock, bytes32(0), salt, delay);
        vm.warp(block.timestamp + delay + 1);
        vm.roll(block.number + delay / 12);
        // The EndowmentTimelock's executor role is open, so anyone may execute.
        IOZTimelock(ENDOWMENT_TIMELOCK)
            .execute(address(endowmentSafe), 0, update10ByEndowmentTimelock, bytes32(0), salt);

        // ── Step 4: Update #10 permissions behave exactly as in the main review ──
        assertGt(SUB_ROLES.code.length, 0, "sub-Roles not deployed");
        assertEq(IRolesModule(SUB_ROLES).owner(), karpatkey, "sub-Roles owner");
        assertEq(IRolesModule(SUB_ROLES).avatar(), address(endowmentSafe), "sub-Roles avatar");
        assertEq(IRolesModule(SUB_ROLES).target(), address(roles), "sub-Roles target");

        // Vault deposit pinned to the Safe
        vm.startPrank(karpatkey);
        _safeExecuteTransaction(
            KPK_USDC_YIELD, abi.encodeWithSelector(IMetaMorphoV1.deposit.selector, uint256(1), address(endowmentSafe))
        );
        _expectConditionViolation(IZodiacRoles.Status.ParameterNotAllowed);
        roles.execTransactionWithRole(
            KPK_USDC_YIELD,
            0,
            abi.encodeWithSelector(IMetaMorphoV1.deposit.selector, uint256(1), address(0xdead)),
            IZodiacRoles.Operation.Call,
            MANAGER_ROLE,
            false
        );

        // RLUSD approvals pinned to the named contracts
        _safeExecuteTransaction(RLUSD, abi.encodeWithSelector(IERC20.approve.selector, SENTORA_RLUSD_MAIN, uint256(1)));
        _expectConditionViolation(IZodiacRoles.Status.OrViolation);
        roles.execTransactionWithRole(
            RLUSD,
            0,
            abi.encodeWithSelector(IERC20.approve.selector, address(0xdead), uint256(1)),
            IZodiacRoles.Operation.Call,
            MANAGER_ROLE,
            false
        );

        // Aave v3 Horizon restricted to RLUSD with the Safe as beneficiary
        _safeExecuteTransaction(
            AAVE_V3_HORIZON_POOL,
            abi.encodeWithSelector(IAaveV3PoolMin.supply.selector, RLUSD, uint256(1), address(endowmentSafe), uint16(0))
        );
        _expectConditionViolation(IZodiacRoles.Status.ParameterNotAllowed);
        roles.execTransactionWithRole(
            AAVE_V3_HORIZON_POOL,
            0,
            abi.encodeWithSelector(IAaveV3PoolMin.supply.selector, RLUSD, uint256(1), address(0xdead), uint16(0)),
            IZodiacRoles.Operation.Call,
            MANAGER_ROLE,
            false
        );
        vm.stopPrank();
    }

    /// @dev The verified Update #10 payload (expectedMultiSend.txt is byte-identical to
    ///      the manual derivation, proven in calldataCheck.t.sol), wrapped for execution
    ///      by `owner` via a pre-approved signature.
    function _buildUpdate10ExecData(address owner) internal view returns (bytes memory execData) {
        bytes memory transactions =
            vm.parseBytes(vm.readFile("src/ens/proposals/ep-kpk-update-10/expectedMultiSend.txt"));
        bytes memory multiSendData = abi.encodeWithSelector(IMultiSend.multiSend.selector, transactions);
        (, execData) = _buildSafeExecDelegateCalldata(address(endowmentSafe), MULTISEND, multiSendData, owner);
    }
}
