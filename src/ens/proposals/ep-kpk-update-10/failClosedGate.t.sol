// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";
import { Vm } from "@forge-std/src/Vm.sol";
import { ENSConstants } from "@ens/Constants.sol";
import { ISafe } from "@ens/interfaces/ISafe.sol";
import { IMultiSend } from "@ens/interfaces/IMultiSend.sol";
import { IERC20 } from "@forge-std/src/interfaces/IERC20.sol";

interface IRolesRead {
    function owner() external view returns (address);
    function avatar() external view returns (address);
    function target() external view returns (address);
    function defaultRoles(address module) external view returns (bytes32);
    function unwrappers(bytes32 key) external view returns (address);
    function getModulesPaginated(address start, uint256 pageSize) external view returns (address[] memory, address);
}

interface ITimelockRead {
    function getMinDelay() external view returns (uint256);
}

/**
 * @title Fail-closed post-transfer control-surface gate for kpk Update #10
 * @notice Enumerates from BOTH storage and the full event history and reverts on ANY
 *         deviation from the honest transfer-only end state. Intended to be rerun,
 *         unchanged, at three blocks: the transferOwnership block, the CallScheduled
 *         block, and immediately before execution. Green at all three, plus a Security
 *         Council watching for any admin/Safe-config event on the listed contracts, is
 *         the fail-closed condition the review should demand before the switch executes.
 *
 *         Run against a fork (REVIEW_GATE_BLOCK, or the pinned honest fork) with:
 *           forge test --match-path .../failClosedGate.t.sol
 */
contract Proposal_ENS_KPK_Update_10_Fail_Closed_Gate_Test is Test {
    address private constant NEW_MAIN = 0xa23BEBFD3628D6Dd7B0638c147db11d9B6FaBD59;
    address private constant SUB = 0x48dC0d88766a59E119e3f2585BC1dC5436Ee6ce0;
    address private constant OLD_MAIN = ENSConstants.ZODIAC_ROLES;
    address private constant POD = ENSConstants.KARPATKEY;
    address private constant ES = ENSConstants.ENDOWMENT_SAFE;
    address private constant TL = ENSConstants.ENDOWMENT_TIMELOCK;
    address private constant ALLOWANCE = ENSConstants.ALLOWANCE_MODULE;
    address private constant SENTINEL = address(0x1);
    address private constant TEST_SAFE = 0xC01318baB7ee1f5ba734172bF7718b5DC6Ec90E1;
    address private constant MS141 = 0x38869bf66a61cF6bDB996A6aE40D5853Fd43B526;
    address private constant MSCO141 = 0x9641d764fc13c8B624c04430C7356C1C7C8102e2;
    address private constant MS130 = 0xA238CBeb142c10Ef7Ad8442C6D1f9E89e07e7761;
    address private constant UNWRAP_ADAPTER = 0xB4Cd4bb764C089f20DA18700CE8bc5e49F369efD;
    bytes32 private constant MANAGER = 0x4d414e4147455200000000000000000000000000000000000000000000000000;
    bytes4 private constant MULTISEND_SEL = IMultiSend.multiSend.selector;
    bytes4 private constant TRANSFER_SEL = IERC20.transfer.selector;
    bytes4 private constant APPROVE_SEL = IERC20.approve.selector;

    // Configuration is frozen at the deployment/config transaction. Any Roles-admin or
    // module or Module-base (avatar/target) event on NEW_MAIN or SUB after this block,
    // other than the single ownership transfer to the Endowment Safe, is a deviation.
    uint256 private constant CONFIG_BLOCK = 25_941_858;

    // Roles storage slots (v2.1.x): roles mapping at slot 4 -> Role{members,targets,scopeConfig}
    uint256 private constant SLOT_ROLES = 4;
    uint256 private constant SLOT_UNWRAPPERS = 6;
    uint256 private constant SLOT_DEFAULT_ROLES = 7;
    // Safe 1.3.0 fixed slots
    bytes32 private constant SAFE_THRESHOLD_SLOT = bytes32(uint256(4));
    bytes32 private constant SAFE_NONCE_SLOT = bytes32(uint256(5));
    bytes32 private constant GUARD_SLOT = 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8;
    bytes32 private constant FALLBACK_SLOT = 0x6c9a6c4a39284e37ed1cf53d337577d14212a4870fb976a4366c693b939918d5;
    bytes32 private constant EXPECTED_FALLBACK = bytes32(uint256(uint160(0xf48f2B2d2a534e402487b3ee7C18c33Aec0Fe5e4)));

    // Event topic0s
    bytes32 private constant T_ASSIGN = keccak256("AssignRoles(address,bytes32[],bool[])");
    bytes32 private constant T_DEFAULT = keccak256("SetDefaultRole(address,bytes32)");
    bytes32 private constant T_UNWRAP = keccak256("SetUnwrapAdapter(address,bytes4,address)");
    bytes32 private constant T_ALLOWANCE = keccak256("SetAllowance(bytes32,uint128,uint128,uint128,uint64,uint64)");
    bytes32 private constant T_SCOPE_FN =
        keccak256("ScopeFunction(bytes32,address,bytes4,(uint8,uint8,uint8,bytes)[],uint8)");
    bytes32 private constant T_SCOPE_TG = keccak256("ScopeTarget(bytes32,address)");
    bytes32 private constant T_ALLOW_TG = keccak256("AllowTarget(bytes32,address,uint8)");
    bytes32 private constant T_ALLOW_FN = keccak256("AllowFunction(bytes32,address,bytes4,uint8)");
    bytes32 private constant T_REVOKE_TG = keccak256("RevokeTarget(bytes32,address)");
    bytes32 private constant T_REVOKE_FN = keccak256("RevokeFunction(bytes32,address,bytes4)");
    bytes32 private constant T_AVATAR = keccak256("AvatarSet(address,address)");
    bytes32 private constant T_TARGET = keccak256("TargetSet(address,address)");
    bytes32 private constant T_ENABLED = keccak256("EnabledModule(address)");
    bytes32 private constant T_DISABLED = keccak256("DisabledModule(address)");
    bytes32 private constant T_OWNER = keccak256("OwnershipTransferred(address,address)");
    bytes32 private constant T_CALLSCHEDULED =
        keccak256("CallScheduled(bytes32,uint256,address,uint256,bytes,bytes32,uint256)");

    uint256 private gateBlock;

    /// @dev Operational check, not a historical regression: runs only when REVIEW_GATE_BLOCK names
    ///      the block to certify (the transfer block, the CallScheduled block, the block before execute).
    function setUp() public {
        gateBlock = vm.envOr("REVIEW_GATE_BLOCK", uint256(0));
        if (gateBlock != 0) vm.createSelectFork({ blockNumber: gateBlock, urlOrAlias: "mainnet" });
    }

    // ── One entry point: any failing assertion is the fail-closed trigger.
    function test_gate() public {
        vm.skip(gateBlock == 0, "set REVIEW_GATE_BLOCK to run the pre-scheduling/pre-execution gate");
        _checkModuleWiring();
        _checkUnwrappers();
        _checkSafeConfig();
        _checkEventHistory(NEW_MAIN);
        _checkEventHistory(SUB);
        _checkTimelockSchedules();
    }

    // owner/avatar/target and the full module linked lists, from storage
    function _checkModuleWiring() internal view {
        require(IRolesRead(NEW_MAIN).owner() == ES, "newMain owner != Endowment Safe");
        require(IRolesRead(NEW_MAIN).avatar() == ES, "newMain avatar");
        require(IRolesRead(NEW_MAIN).target() == ES, "newMain target");
        require(IRolesRead(SUB).owner() == POD, "sub owner");
        require(IRolesRead(SUB).avatar() == ES, "sub avatar");
        require(IRolesRead(SUB).target() == NEW_MAIN, "sub target");

        address[] memory nm = _modules(NEW_MAIN);
        require(nm.length == 2, "newMain module count");
        require(nm[0] == SUB && nm[1] == POD, "newMain members set");
        require(IRolesRead(NEW_MAIN).defaultRoles(SUB) == MANAGER, "sub default role");
        require(IRolesRead(NEW_MAIN).defaultRoles(POD) == bytes32(0), "pod default role");

        require(_modules(SUB).length == 0, "sub has callers");

        // Endowment Safe: exactly the switch pair, pre- or post-switch, and nothing else.
        address[] memory es = _modules(ES);
        require(es.length == 2, "Safe module count");
        require(es[1] == ALLOWANCE, "allowance module retained");
        require(es[0] == OLD_MAIN || es[0] == NEW_MAIN, "unexpected Safe module head");
    }

    // Unwrapper slots for the two MultiSend 1.4.1 entrypoints must be the adapter, the
    // 1.3.0 slot zero, and NO transfer/approve unwrapper exists on any MANAGER target.
    function _checkUnwrappers() internal view {
        require(_unwrap(NEW_MAIN, MS141, MULTISEND_SEL) == UNWRAP_ADAPTER, "1.4.1 unwrapper");
        require(_unwrap(NEW_MAIN, MSCO141, MULTISEND_SEL) == UNWRAP_ADAPTER, "1.4.1 call-only unwrapper");
        require(_unwrap(NEW_MAIN, MS130, MULTISEND_SEL) == address(0), "stale 1.3.0 unwrapper");
        // No unwrapper may hijack an ERC20 transfer/approve on the sensitive assets.
        address[6] memory assets = [
            0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD, // sUSDS (Spark)
            ENSConstants.USDC,
            0xdC035D45d973E3EC169d2276DDab16f1e407384F, // USDS
            ENSConstants.WETH,
            ENSConstants.USDT,
            0x6c3ea9036406852006290770BEdFcAbA0e23A0e8 // PYUSD
        ];
        for (uint256 i; i < assets.length; i++) {
            require(_unwrap(NEW_MAIN, assets[i], TRANSFER_SEL) == address(0), "rogue transfer unwrapper");
            require(_unwrap(NEW_MAIN, assets[i], APPROVE_SEL) == address(0), "rogue approve unwrapper");
        }
    }

    function _checkSafeConfig() internal view {
        ISafe safe = ISafe(ES);
        require(keccak256(bytes(safe.VERSION())) == keccak256(bytes("1.3.0")), "safe version");
        address[] memory owners = safe.getOwners();
        require(owners.length == 1 && owners[0] == TL, "Safe owner must be the EndowmentTimelock");
        require(safe.getThreshold() == 1, "safe threshold");
        require(vm.load(ES, GUARD_SLOT) == bytes32(0), "a guard was installed on the Endowment Safe");
        require(vm.load(ES, FALLBACK_SLOT) == EXPECTED_FALLBACK, "fallback handler changed");
    }

    // Full event history: after CONFIG_BLOCK the ONLY tolerated event on NEW_MAIN or SUB
    // is OwnershipTransferred(prev -> Endowment Safe). Everything else (AssignRoles,
    // SetDefaultRole, SetUnwrapAdapter, SetAllowance, Scope*/Allow*/Revoke*, Avatar/Target,
    // Enabled/DisabledModule) is a post-config mutation and fails the gate.
    uint256 private constant CHUNK = 5000;

    function _checkEventHistory(address mod) internal {
        for (uint256 from = CONFIG_BLOCK + 1; from <= block.number; from += CHUNK) {
            uint256 to = from + CHUNK - 1;
            if (to > block.number) to = block.number;
            _scanModuleChunk(mod, from, to);
        }
    }

    function _scanModuleChunk(address mod, uint256 from, uint256 to) internal {
        bytes32[] memory anyTopic = new bytes32[](0);
        Vm.EthGetLogs[] memory logs = vm.eth_getLogs(from, to, mod, anyTopic);
        for (uint256 i; i < logs.length; i++) {
            bytes32 t0 = logs[i].topics[0];
            if (t0 == T_OWNER) {
                // topics: [sig, prevOwner, newOwner]; only the honest transfer to ES on NEW_MAIN
                require(mod == NEW_MAIN, "unexpected ownership change on Sub");
                require(
                    address(uint160(uint256(logs[i].topics[2]))) == ES, "ownership not transferred to Endowment Safe"
                );
                continue;
            }
            if (
                t0 == T_ASSIGN || t0 == T_DEFAULT || t0 == T_UNWRAP || t0 == T_ALLOWANCE || t0 == T_SCOPE_FN
                    || t0 == T_SCOPE_TG || t0 == T_ALLOW_TG || t0 == T_ALLOW_FN || t0 == T_REVOKE_TG
                    || t0 == T_REVOKE_FN || t0 == T_AVATAR || t0 == T_TARGET || t0 == T_ENABLED || t0 == T_DISABLED
            ) {
                revert(string.concat("post-config admin event on ", vm.toString(mod), " topic ", vm.toString(t0)));
            }
            // Any other unrecognised event is also a deviation (fail closed on the unknown).
            revert(string.concat("unrecognised post-config event on ", vm.toString(mod)));
        }
    }

    // Every CallScheduled on the Endowment timelock must carry EXACTLY the reviewed Safe
    // wrapper (referenceExecution.json: 868 bytes, keccak 0x24a2088d…): same target, zero
    // value, zero predecessor, delay >= 9 days. A substring match is not enough: extra calls
    // or a nonzero safeTxGas around the same MultiSend body change the failure semantics.
    bytes32 private constant REFERENCE_SAFE_CALLDATA_KECCAK =
        0x24a2088d4064ae77c68c6077caad94f4376809f3a401c451dc7a7525ab501105;

    function _checkTimelockSchedules() internal {
        for (uint256 from = 25_656_954; from <= block.number; from += CHUNK) {
            uint256 to = from + CHUNK - 1;
            if (to > block.number) to = block.number;
            _scanTimelockChunk(from, to);
        }
    }

    function _scanTimelockChunk(uint256 from, uint256 to) internal {
        bytes32[] memory anyTopic = new bytes32[](0);
        Vm.EthGetLogs[] memory logs = vm.eth_getLogs(from, to, TL, anyTopic);
        for (uint256 i; i < logs.length; i++) {
            if (logs[i].topics[0] != T_CALLSCHEDULED) continue;
            // data = (address target, uint256 value, bytes data, bytes32 predecessor, uint256 delay)
            (address target, uint256 value, bytes memory payload, bytes32 predecessor, uint256 delay) =
                abi.decode(logs[i].data, (address, uint256, bytes, bytes32, uint256));
            require(target == ES, "scheduled op targets a non-Endowment address");
            require(value == 0, "scheduled op moves value");
            require(predecessor == bytes32(0), "scheduled op has a predecessor");
            require(delay >= 777_600, "scheduled op delay below nine days");
            require(
                keccak256(payload) == REFERENCE_SAFE_CALLDATA_KECCAK,
                "scheduled Safe wrapper differs from the reviewed reference: review it byte-for-byte"
            );
        }
    }

    // ── helpers
    function _modules(address mod) internal view returns (address[] memory a) {
        (a,) = IRolesRead(mod).getModulesPaginated(SENTINEL, 50);
    }

    function _unwrap(address mod, address to, bytes4 sel) internal view returns (address) {
        bytes32 key = bytes32(bytes20(to)) | (bytes32(sel) >> 160);
        bytes32 slot = keccak256(abi.encode(key, SLOT_UNWRAPPERS));
        return address(uint160(uint256(vm.load(mod, slot))));
    }
}
