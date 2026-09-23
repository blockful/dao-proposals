// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";

/// Runtime regression for the zodiac-core Modifier.moduleOnly appended-signature path
/// (ExecutionTracker + SignatureChecker) on the old Main (Roles v2.1.0 clone of
/// 0x9646...D337) and the new Main / Sub (Roles v2.1.1 clone of 0xF296...D5), for ENS
/// Endowment "permissions to kpk, Update #10".
///
/// Appended contract-signature layout (SignatureChecker.moduleTxSignedBy / _splitSignature):
///   data = inner ++ sig ++ salt(32) ++ r(32) ++ s(32) ++ v(1)
///   last 65 bytes parse as r=data[len-65:len-33], s=data[len-33:len-1], v=data[len-1]
///   end   = len - 97 ; salt = data[end:end+32]
///   for a contract signature v==0: start=uint256(s), signer=address(uint160(uint256(r)))
///   hash  = moduleTxHash(data[:start], salt) ; signature = data[start:end]
///   signer.isValidSignature(hash, signature) is staticcalled.
///   v2.1.0 SignatureChecker: return bytes4(returnData) == 0x1626ba7e          (success ignored)
///   v2.1.1 SignatureChecker: return success && bytes4(returnData) == 0x1626ba7e

/// @notice EIP-1271; the magic value is this function's selector
interface IERC1271 {
    function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4);
}

interface IRolesSig {
    function owner() external view returns (address);
    function target() external view returns (address);
    function isModuleEnabled(address) external view returns (bool);
    function assignRoles(address module, bytes32[] calldata roleKeys, bool[] calldata memberOf) external;
    function allowTarget(bytes32 roleKey, address targetAddress, uint8 options) external;
    function moduleTxHash(bytes calldata data, bytes32 salt) external view returns (bytes32);
    function consumed(address signer, bytes32 hash) external view returns (bool);
    function transferOwnership(address newOwner) external;
}

interface ISafe130 {
    function VERSION() external view returns (string memory);
    function enableModule(address module) external;
    function disableModule(address prevModule, address module) external;
    function isModuleEnabled(address module) external view returns (bool);
    function setFallbackHandler(address handler) external;
    function getThreshold() external view returns (uint256);
}

contract Pinger {
    uint256 public count;

    function ping() external {
        count++;
    }
}

/// Mock EIP-1271 signer. mode 0: returns magic iff (hash, signature) match the configured pair.
/// mode 1: reverts with 32 bytes whose leading 4 bytes are the EIP-1271 magic value.
contract Mock1271 {
    uint8 public mode;
    bytes32 private expectedHash;
    bytes32 private expectedSigHash;

    function configure(uint8 mode_, bytes32 hash_, bytes calldata sig_) external {
        mode = mode_;
        expectedHash = hash_;
        expectedSigHash = keccak256(sig_);
    }

    function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4) {
        if (mode == 1) {
            assembly {
                mstore(0x00, shl(224, 0x1626ba7e))
                revert(0x00, 32)
            }
        }
        if (hash == expectedHash && keccak256(signature) == expectedSigHash) return 0x1626ba7e;
        return 0xffffffff;
    }
}

contract Proposal_ENS_KPK_Update_10_EIP1271_Path_Test is Test {
    address private constant ENDOWMENT_SAFE = 0x4F2083f5fBede34C2714aFfb3105539775f7FE64;
    address private constant OLD_MAIN = 0x703806E61847984346d2D7DDd853049627e50A40;
    address private constant NEW_MAIN = 0xa23BEBFD3628D6Dd7B0638c147db11d9B6FaBD59;
    address private constant SUB_ROLES = 0x48dC0d88766a59E119e3f2585BC1dC5436Ee6ce0;
    address private constant POD = 0xb423e0f6E7430fa29500c5cC9bd83D28c8BD8978;
    address private constant KPK_TEST_SAFE = 0xC01318baB7ee1f5ba734172bF7718b5DC6Ec90E1;
    address private constant V210 = 0x9646fDAD06d3e24444381f44362a3B0eB343D337;
    address private constant V211 = 0xF2964CE6161ce0e75964Fe7927cE114cb0B283D5;
    address private constant CFH_130 = 0xf48f2B2d2a534e402487b3ee7C18c33Aec0Fe5e4;
    address private constant SENTINEL = address(0x1);

    bytes32 private constant MANAGER_ROLE = 0x4d414e4147455200000000000000000000000000000000000000000000000000;
    bytes32 private constant TEST_ROLE = keccak256("SWARM_EIP1271_TEST_ROLE");
    bytes32 private constant FALLBACK_HANDLER_SLOT = 0x6c9a6c4a39284e37ed1cf53d337577d14212a4870fb976a4366c693b939918d5;
    bytes32 private constant SALT = keccak256("SWARM_EIP1271_SALT");
    bytes4 private constant MAGIC = IERC1271.isValidSignature.selector;
    bytes private constant SIG = "swarm-eip1271-appended-signature";
    uint256 private constant PIN_BLOCK = 26_037_425;

    // moduleOnly reverts with NotAuthorized(msg.sender) when the recovered signer is not a module.
    bytes4 private constant NOT_AUTHORIZED = bytes4(keccak256("NotAuthorized(address)"));
    bytes4 private constant HASH_CONSUMED = bytes4(keccak256("HashAlreadyConsumed(bytes32)"));

    address private attacker;

    function setUp() public {
        // Code-behavior regression of the v2.1.0/v2.1.1 mastercopies: pinned like the round-1 suites,
        // it does not follow REVIEW_BLOCK (the pre-switch, pre-transfer baseline below is historical).
        vm.createSelectFork({ blockNumber: PIN_BLOCK, urlOrAlias: "mainnet" });
        attacker = makeAddr("attacker");

        // Baseline pinned state this regression depends on.
        assertEq(_clone(OLD_MAIN), V210, "old Main mastercopy v2.1.0");
        assertEq(_clone(NEW_MAIN), V211, "new Main mastercopy v2.1.1");
        assertEq(_clone(SUB_ROLES), V211, "Sub mastercopy v2.1.1");
        assertEq(IRolesSig(OLD_MAIN).owner(), ENDOWMENT_SAFE, "old Main owner = Endowment Safe");
        assertEq(IRolesSig(NEW_MAIN).owner(), KPK_TEST_SAFE, "new Main owner = kpk test Safe (pre-transfer)");
        assertEq(IRolesSig(NEW_MAIN).target(), ENDOWMENT_SAFE, "new Main target = Endowment Safe");
        assertTrue(IRolesSig(OLD_MAIN).isModuleEnabled(POD), "pod is module on old Main");
        assertTrue(IRolesSig(NEW_MAIN).isModuleEnabled(POD), "pod is module on new Main");
        assertTrue(IRolesSig(NEW_MAIN).isModuleEnabled(SUB_ROLES), "Sub is module on new Main");
        assertEq(keccak256(bytes(ISafe130(POD).VERSION())), keccak256("1.3.0"), "pod Safe 1.3.0");
        assertEq(vm.load(POD, FALLBACK_HANDLER_SLOT), bytes32(0), "pod fallback handler zero at pin");
        assertTrue(ISafe130(ENDOWMENT_SAFE).isModuleEnabled(OLD_MAIN), "old Main enabled on Safe");
        assertFalse(ISafe130(ENDOWMENT_SAFE).isModuleEnabled(NEW_MAIN), "new Main not yet enabled on Safe");
    }

    // ───────────────────────── (a) positive control + (d) replay
    // ─────────────────────────

    /// The appended-signature encoding this test builds hashes to exactly what the on-chain
    /// SignatureChecker.moduleTxHash computes on both Mains. Guards against a vacuous encoding.
    function test_a_encodingMatchesOnchainModuleTxHash() public view {
        assertEq(
            keccak256("EIP712Domain(uint256 chainId,address verifyingContract)"),
            0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218,
            "domain typehash preimage"
        );
        assertEq(
            keccak256("ModuleTx(bytes data,bytes32 salt)"),
            0x2939aeeda3ca260200c9f7b436b19e13207547ccc65cfedc857751c5ea6d91d4,
            "module tx typehash preimage"
        );
        bytes memory inner = _inner(address(0xBEEF), TEST_ROLE);
        assertEq(_hash(OLD_MAIN, inner, SALT), IRolesSig(OLD_MAIN).moduleTxHash(inner, SALT), "old Main hash");
        assertEq(_hash(NEW_MAIN, inner, SALT), IRolesSig(NEW_MAIN).moduleTxHash(inner, SALT), "new Main hash");
    }

    function test_a_positiveControl_and_replay_oldMain_v210() public {
        _positiveControlAndReplay(OLD_MAIN, ENDOWMENT_SAFE);
    }

    function test_a_positiveControl_and_replay_newMain_v211_afterSwitch() public {
        _switchAndTransfer();
        _positiveControlAndReplay(NEW_MAIN, ENDOWMENT_SAFE);
    }

    /// An arbitrary EOA drives the module by APPENDING a valid contract signature — the caller
    /// is never a module. Proves the path is live, then proves the same payload cannot replay.
    function _positiveControlAndReplay(address main, address ownerOf) internal {
        Pinger pinger = new Pinger();
        Mock1271 signer = new Mock1271();

        vm.startPrank(ownerOf);
        IRolesSig(main).assignRoles(address(signer), _one(TEST_ROLE), _one(true)); // member + enableModule
        IRolesSig(main).allowTarget(TEST_ROLE, address(pinger), 0); // Clearance.Target, options None
        vm.stopPrank();
        assertTrue(IRolesSig(main).isModuleEnabled(address(signer)), "mock signer enabled as module");

        bytes memory inner = _inner(address(pinger), TEST_ROLE);
        bytes32 hash = IRolesSig(main).moduleTxHash(inner, SALT);
        signer.configure(0, hash, SIG);
        bytes memory data = _append(inner, address(signer), SIG);

        assertFalse(IRolesSig(main).consumed(address(signer), hash), "hash unconsumed before");

        vm.prank(attacker);
        (bool ok,) = main.call(data);
        assertTrue(ok, "appended-signature exec succeeded");
        assertEq(pinger.count(), 1, "inner call executed exactly once");
        assertTrue(IRolesSig(main).consumed(address(signer), hash), "hash consumed after (ExecutionTracker)");

        // (d) replay: identical signed payload is rejected as HashAlreadyConsumed(hash).
        vm.prank(attacker);
        (bool ok2, bytes memory ret2) = main.call(data);
        assertFalse(ok2, "replay rejected");
        assertEq(bytes4(ret2), HASH_CONSUMED, "replay reverts HashAlreadyConsumed");
        assertEq(_errArg(ret2), hash, "replay error carries the consumed hash");
        assertEq(pinger.count(), 1, "no second execution on replay");
    }

    // ───────────────────────── (b) revert-with-magic: the concrete
    // fix ─────────────────────────

    /// A signer whose isValidSignature REVERTS with data starting 0x1626ba7e.
    /// v2.1.0 ignores staticcall success and accepts it; v2.1.1 requires success and rejects it.
    function test_b_revertMagic_acceptedOnOld_rejectedOnNew() public {
        // Old Main (v2.1.0): the reverting-magic signer is accepted -> inner executes.
        {
            Pinger pinger = new Pinger();
            Mock1271 signer = new Mock1271();
            signer.configure(1, bytes32(0), ""); // mode 1: revert with magic
            vm.startPrank(ENDOWMENT_SAFE);
            IRolesSig(OLD_MAIN).assignRoles(address(signer), _one(TEST_ROLE), _one(true));
            IRolesSig(OLD_MAIN).allowTarget(TEST_ROLE, address(pinger), 0);
            vm.stopPrank();

            bytes memory inner = _inner(address(pinger), TEST_ROLE);
            bytes memory data = _append(inner, address(signer), SIG);
            vm.prank(attacker);
            (bool ok,) = OLD_MAIN.call(data);
            assertTrue(ok, "v2.1.0 ACCEPTS a signer that reverts with the magic value");
            assertEq(pinger.count(), 1, "v2.1.0 executed the inner call via the reverting signer");
        }

        // New Main (v2.1.1): same construction is rejected at moduleOnly (signer resolves to 0).
        _switchAndTransfer();
        {
            Pinger pinger = new Pinger();
            Mock1271 signer = new Mock1271();
            signer.configure(1, bytes32(0), "");
            vm.startPrank(ENDOWMENT_SAFE);
            IRolesSig(NEW_MAIN).assignRoles(address(signer), _one(TEST_ROLE), _one(true));
            IRolesSig(NEW_MAIN).allowTarget(TEST_ROLE, address(pinger), 0);
            vm.stopPrank();

            bytes memory inner = _inner(address(pinger), TEST_ROLE);
            bytes memory data = _append(inner, address(signer), SIG);
            vm.prank(attacker);
            (bool ok, bytes memory ret) = NEW_MAIN.call(data);
            assertFalse(ok, "v2.1.1 REJECTS a signer that reverts with the magic value");
            assertEq(bytes4(ret), NOT_AUTHORIZED, "v2.1.1 reverts NotAuthorized");
            assertEq(pinger.count(), 0, "v2.1.1 did not execute the inner call");
        }
    }

    // ───────────────────────── (c) real members, real Safe fallback
    // ─────────────────────────

    /// With the pod's fallback handler ZERO (the pinned interim state), an arbitrary EOA naming
    /// the pod Safe (or the Sub) as the appended signer is rejected on the new Main: the Safe's
    /// empty fallback returns no magic, so the signer resolves to address(0) -> NotAuthorized.
    function test_c_realMembers_zeroHandler_revertNotAuthorized() public {
        _switchAndTransfer();
        assertEq(vm.load(POD, FALLBACK_HANDLER_SLOT), bytes32(0), "pod handler still zero after switch");

        // Name the pod Safe.
        _expectNotAuthorized(NEW_MAIN, POD, MANAGER_ROLE, "pod, zero handler");
        // Name the Sub (a Roles contract with no isValidSignature and no fallback).
        _expectNotAuthorized(NEW_MAIN, SUB_ROLES, MANAGER_ROLE, "Sub, no 1271 fn");
    }

    /// With the pod's fallback handler set to the standard CompatibilityFallbackHandler, an
    /// arbitrary EOA still cannot forge: CFH.isValidSignature calls Safe.checkSignatures, which
    /// reverts without genuine owner signatures. The staticcall fails and returns an error
    /// selector (0x08c379a0), not the magic value — so BOTH versions reject. This shows the
    /// CompatibilityFallbackHandler does NOT return magic on a failed check, so the historical
    /// pod configuration is not, by itself, the reverting-magic case that separates the versions.
    function test_c_realMembers_cfhHandler_stillReverts() public {
        _switchAndTransfer();
        vm.prank(POD);
        ISafe130(POD).setFallbackHandler(CFH_130);
        assertEq(vm.load(POD, FALLBACK_HANDLER_SLOT), bytes32(uint256(uint160(CFH_130))), "pod handler set to CFH");

        _expectNotAuthorized(NEW_MAIN, POD, MANAGER_ROLE, "pod, CFH handler, no valid sigs");

        // The same construction is also rejected on the old Main (v2.1.0): CFH reverts with an
        // error string, whose selector is not the magic value, so v2.1.0's magic-only check fails
        // too. The version gap is only reachable via a handler that returns magic ON REVERT.
        _expectNotAuthorized(OLD_MAIN, POD, TEST_ROLE, "pod, CFH handler, old Main");
    }

    // ───────────────────────── helpers
    // ─────────────────────────

    function _expectNotAuthorized(address main, address namedSigner, bytes32 role, string memory tag) internal {
        Pinger pinger = new Pinger();
        bytes memory inner = _inner(address(pinger), role);
        bytes memory data = _append(inner, namedSigner, SIG);
        vm.prank(attacker);
        (bool ok, bytes memory ret) = main.call(data);
        assertFalse(ok, string.concat("expected revert: ", tag));
        assertEq(bytes4(ret), NOT_AUTHORIZED, string.concat("expected NotAuthorized: ", tag));
        assertEq(pinger.count(), 0, string.concat("no execution: ", tag));
    }

    /// Simulate the switch: enable new Main + disable old Main (Safe self-call), transfer new
    /// Main ownership from the kpk test Safe to the Endowment Safe (the blocking fix).
    function _switchAndTransfer() internal {
        // Batch order: disableModule(0x1, oldMain) then enableModule(newMain), matching the
        // published ENS_Switch_ZRM.json. Disabling first keeps 0x1 as oldMain's prev pointer.
        vm.startPrank(ENDOWMENT_SAFE);
        ISafe130(ENDOWMENT_SAFE).disableModule(SENTINEL, OLD_MAIN);
        ISafe130(ENDOWMENT_SAFE).enableModule(NEW_MAIN);
        vm.stopPrank();
        vm.prank(KPK_TEST_SAFE);
        IRolesSig(NEW_MAIN).transferOwnership(ENDOWMENT_SAFE);
        assertEq(IRolesSig(NEW_MAIN).owner(), ENDOWMENT_SAFE, "ownership transferred to Endowment Safe");
        assertTrue(ISafe130(ENDOWMENT_SAFE).isModuleEnabled(NEW_MAIN), "new Main enabled on Safe");
        assertFalse(ISafe130(ENDOWMENT_SAFE).isModuleEnabled(OLD_MAIN), "old Main disabled on Safe");
    }

    function _inner(address to, bytes32 role) internal pure returns (bytes memory) {
        // execTransactionWithRole(to, 0, ping(), Call=0, role, shouldRevert=false)
        return abi.encodeWithSignature(
            "execTransactionWithRole(address,uint256,bytes,uint8,bytes32,bool)",
            to,
            uint256(0),
            abi.encodeWithSignature("ping()"),
            uint8(0),
            role,
            false
        );
    }

    function _append(bytes memory inner, address signer, bytes memory sig) internal pure returns (bytes memory) {
        // data = inner ++ sig ++ salt ++ r(=signer) ++ s(=inner.length) ++ v(=0)
        return bytes.concat(inner, sig, SALT, bytes32(uint256(uint160(signer))), bytes32(inner.length), bytes1(0x00));
    }

    /// Local recomputation of SignatureChecker.moduleTxHash for `main`.
    function _hash(address main, bytes memory data, bytes32 salt) internal view returns (bytes32) {
        bytes32 domainSeparator = keccak256(
            abi.encode(0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218, block.chainid, main)
        );
        return keccak256(
            abi.encodePacked(
                bytes1(0x19),
                bytes1(0x01),
                domainSeparator,
                keccak256(
                    abi.encode(
                        0x2939aeeda3ca260200c9f7b436b19e13207547ccc65cfedc857751c5ea6d91d4, keccak256(data), salt
                    )
                )
            )
        );
    }

    function _clone(address proxy) internal view returns (address impl) {
        bytes memory code = proxy.code;
        // EIP-1167 minimal proxy: bytes 10..29 hold the implementation address.
        require(code.length >= 45, "not a clone");
        assembly {
            impl := shr(96, mload(add(code, 0x2a)))
        }
    }

    function _errArg(bytes memory ret) internal pure returns (bytes32 arg) {
        assembly {
            arg := mload(add(ret, 0x24))
        }
    }

    function _one(bytes32 v) internal pure returns (bytes32[] memory a) {
        a = new bytes32[](1);
        a[0] = v;
    }

    function _one(bool v) internal pure returns (bool[] memory a) {
        a = new bool[](1);
        a[0] = v;
    }
}
