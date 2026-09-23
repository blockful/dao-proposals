// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test, Vm } from "@forge-std/src/Test.sol";
import { ENSConstants } from "@ens/Constants.sol";
import { IMultiSend } from "@ens/interfaces/IMultiSend.sol";
import { IZodiacRoles } from "@ens/interfaces/IZodiacRoles.sol";
import { ConditionFlat } from "@ens/interfaces/IRolesModifier.sol";
import { ICowSwapOrderSigner } from "@ens/interfaces/ICowSwapOrderSigner.sol";
import { IERC20 } from "@forge-std/src/interfaces/IERC20.sol";

/// @notice Full onlyOwner surface of a Zodiac Roles Modifier v2.1.x (Roles, PermissionBuilder,
///         Periphery, Modifier, Module, OwnableUpgradeable, FactoryFriendly).
interface IRolesOwnerSurface {
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
    function renounceOwnership() external;
    function setUp(bytes memory initParams) external;
    function setAvatar(address avatar) external;
    function setTarget(address target) external;
    function enableModule(address module) external;
    function disableModule(address prevModule, address module) external;
    function assignRoles(address module, bytes32[] calldata roleKeys, bool[] calldata memberOf) external;
    function setDefaultRole(address module, bytes32 roleKey) external;
    function allowTarget(bytes32 roleKey, address targetAddress, uint8 options) external;
    function scopeTarget(bytes32 roleKey, address targetAddress) external;
    function revokeTarget(bytes32 roleKey, address targetAddress) external;
    function allowFunction(bytes32 roleKey, address targetAddress, bytes4 selector, uint8 options) external;
    function scopeFunction(
        bytes32 roleKey,
        address targetAddress,
        bytes4 selector,
        ConditionFlat[] memory conditions,
        uint8 options
    )
        external;
    function revokeFunction(bytes32 roleKey, address targetAddress, bytes4 selector) external;
    function setAllowance(
        bytes32 key,
        uint128 balance,
        uint128 maxRefill,
        uint128 refill,
        uint64 period,
        uint64 ts
    )
        external;
    function setTransactionUnwrapper(address to, bytes4 selector, address adapter) external;
    function execTransactionFromModule(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation
    )
        external
        returns (bool);
}

/// @notice Safe v1.3.0 self-authorized surface plus the ExtensibleFallbackHandler setters routed via fallback.
interface ISafeSelfSurface {
    function addOwnerWithThreshold(address owner, uint256 threshold) external;
    function removeOwner(address prevOwner, address owner, uint256 threshold) external;
    function swapOwner(address prevOwner, address oldOwner, address newOwner) external;
    function changeThreshold(uint256 threshold) external;
    function enableModule(address module) external;
    function disableModule(address prevModule, address module) external;
    function setGuard(address guard) external;
    function setFallbackHandler(address handler) external;
    function approveHash(bytes32 hashToApprove) external;
    function simulateAndRevert(address targetContract, bytes memory calldataPayload) external;
    function execTransactionFromModule(
        address to,
        uint256 value,
        bytes memory data,
        uint8 operation
    )
        external
        returns (bool);
    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures
    )
        external
        payable
        returns (bool);
    function setup(
        address[] calldata owners,
        uint256 threshold,
        address to,
        bytes calldata data,
        address fallbackHandler,
        address paymentToken,
        uint256 payment,
        address payable paymentReceiver
    )
        external;
    function getOwners() external view returns (address[] memory);
    function getThreshold() external view returns (uint256);
    function getModulesPaginated(address start, uint256 pageSize) external view returns (address[] memory, address);
    function isModuleEnabled(address module) external view returns (bool);
    function nonce() external view returns (uint256);
    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4);
    // ExtensibleFallbackHandler setters (onlySelf), reachable as Safe self-calls once EFH is the handler
    function setSafeMethod(bytes4 selector, bytes32 newMethod) external;
    function setDomainVerifier(bytes32 domainSeparator, address newVerifier) external;
    function setSupportedInterface(bytes4 interfaceId, bool supported) external;
    function addSupportedInterfaceBatch(bytes4 interfaceId, bytes32[] calldata handlerWithSelectors) external;
    function removeSupportedInterfaceBatch(bytes4 interfaceId, bytes4[] calldata selectors) external;
}

interface IEFH {
    function safeMethods(address safe, bytes4 selector) external view returns (bytes32);
    function domainVerifiers(address safe, bytes32 domainSeparator) external view returns (address);
}

interface ICowswapOrderSignerFull {
    function signOrder(ICowSwapOrderSigner.Data calldata order, uint32 validDuration, uint256 feeAmountBP) external;
    function unsignOrder(ICowSwapOrderSigner.Data calldata order) external;
    function signing() external view returns (address);
    function deployedAt() external view returns (address);
}

interface IAllowanceModule {
    function executeAllowanceTransfer(
        address safe,
        address token,
        address payable to,
        uint96 amount,
        address paymentToken,
        uint96 payment,
        address delegate,
        bytes memory signature
    )
        external;
    function getTokenAllowance(address safe, address delegate, address token) external view returns (uint256[5] memory);
    function getTokens(address safe, address delegate) external view returns (address[] memory);
    function getDelegates(address safe, uint48 start, uint8 pageSize) external view returns (address[] memory, uint48);
}

interface ITimelockAdmin {
    function schedule(address t, uint256 v, bytes calldata d, bytes32 p, bytes32 s, uint256 delay) external;
    function execute(address t, uint256 v, bytes calldata d, bytes32 p, bytes32 s) external payable;
    function updateDelay(uint256 newDelay) external;
    function grantRole(bytes32 role, address account) external;
    function hasRole(bytes32 role, address account) external view returns (bool);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function getMinDelay() external view returns (uint256);
    function hashOperation(address, uint256, bytes calldata, bytes32, bytes32) external pure returns (bytes32);
}

interface ISecurityCouncilWrapper {
    function owner() external view returns (address);
    function timelock() external view returns (address);
    function veto(bytes32 proposalId) external;
}

interface IMultiSend141 {
    function multiSend(bytes memory transactions) external payable;
}

/**
 * @title Closure of the post-transfer control surface (kpk Update #10, GAP 3)
 * @notice Proves the remedy of the CRITICAL finding: once new Main `owner()` is the Endowment Safe and the
 *         switch is executed, no pod/Sub member power makes the Safe call any Roles admin function, and none
 *         changes the Safe's owners, threshold, modules, guard or fallback handler, except the carried-over,
 *         parameter-pinned ExtensibleFallbackHandler installation and CoW domain-verifier registration.
 *         Fork: REVIEW_BLOCK (default 26,037,425). Ownership transfer is simulated.
 */
contract Proposal_ENS_KPK_Update_10_Closure_Test is Test {
    // ─── Actors
    // ───────────────────────────────────────────────────
    address private constant SAFE = ENSConstants.ENDOWMENT_SAFE;
    address private constant TIMELOCK = ENSConstants.ENDOWMENT_TIMELOCK;
    address private constant FOUNDATION = ENSConstants.FOUNDATION_SAFE;
    address private constant SC_WRAPPER = ENSConstants.SECURITY_COUNCIL_VETO;
    address private constant SC_SAFE = ENSConstants.SECURITY_COUNCIL_SAFE;
    address private constant TIMELOCK_DEPLOYER = 0x8764f2939aE6ed4EcB5baD2cdB7e2B81aA153bd1;
    address private constant ALLOWANCE_MODULE = ENSConstants.ALLOWANCE_MODULE;
    address private constant ALLOWANCE_DELEGATE = 0x91c32893216dE3eA0a55ABb9851f581d4503d39b;

    address private constant OLD_MAIN = 0x703806E61847984346d2D7DDd853049627e50A40;
    address private constant NEW_MAIN = 0xa23BEBFD3628D6Dd7B0638c147db11d9B6FaBD59;
    address private constant SUB = 0x48dC0d88766a59E119e3f2585BC1dC5436Ee6ce0;
    address private constant POD = 0xb423e0f6E7430fa29500c5cC9bd83D28c8BD8978;
    bytes32 private constant MANAGER = 0x4d414e4147455200000000000000000000000000000000000000000000000000;
    address private constant SENTINEL = address(0x1);

    address private constant MULTISEND_141 = 0x38869bf66a61cF6bDB996A6aE40D5853Fd43B526;
    address private constant CFH_130 = 0xf48f2B2d2a534e402487b3ee7C18c33Aec0Fe5e4; // current fallback handler
    address private constant EFH = 0x2f55e8b20D0B9FEFA187AA7d00B6Cbe563605bF5;
    address private constant COMPOSABLE_COW = 0xfdaFc9d1902f4e0b84f65F49f244b32b31013b74;
    bytes32 private constant COW_DOMAIN = 0xc078f884a2676e1345748b1feace7b0abee5d00ecadb6e574dcdd109a63e8943;
    address private constant ORDER_SIGNER = 0x23dA9AdE38E4477b23770DeD512fD37b12381FAB;
    address private constant GPV2_SETTLEMENT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
    address private constant USDC = ENSConstants.USDC;
    address private constant WETH = ENSConstants.WETH;

    // Safe v1.3.0 storage
    bytes32 private constant GUARD_SLOT = 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8;
    bytes32 private constant FALLBACK_SLOT = 0x6c9a6c4a39284e37ed1cf53d337577d14212a4870fb976a4366c693b939918d5;

    address private constant ATTACKER = address(0xBAD);
    uint256 private constant REVIEW_BLOCK = 26_037_425;

    bytes32[8] private safeConfigBefore;

    function setUp() public {
        vm.createSelectFork({ blockNumber: vm.envOr("REVIEW_BLOCK", REVIEW_BLOCK), urlOrAlias: "mainnet" });

        // Remedy: kpk's owner transfers new Main to the Endowment Safe (simulated).
        address currentOwner = IRolesOwnerSurface(NEW_MAIN).owner();
        if (currentOwner != SAFE) {
            vm.prank(currentOwner);
            IRolesOwnerSurface(NEW_MAIN).transferOwnership(SAFE);
        }
        // Switch (state-equivalent to the timelock-executed batch verified in calldataCheck.t.sol).
        vm.startPrank(SAFE);
        ISafeSelfSurface(SAFE).disableModule(SENTINEL, OLD_MAIN);
        ISafeSelfSurface(SAFE).enableModule(NEW_MAIN);
        vm.stopPrank();

        assertEq(IRolesOwnerSurface(NEW_MAIN).owner(), SAFE, "new Main owner");
        assertEq(IRolesOwnerSurface(OLD_MAIN).owner(), SAFE, "old Main owner");
        assertEq(IRolesOwnerSurface(SUB).owner(), POD, "Sub owner (pod, by design)");
        (address[] memory mods,) = ISafeSelfSurface(SAFE).getModulesPaginated(SENTINEL, 10);
        assertEq(mods.length, 2);
        assertEq(mods[0], NEW_MAIN);
        assertEq(mods[1], ALLOWANCE_MODULE);
        assertEq(address(uint160(uint256(vm.load(SAFE, FALLBACK_SLOT)))), CFH_130, "fallback handler at pin");
        assertEq(vm.load(SAFE, GUARD_SLOT), bytes32(0), "no guard at pin");
        _snapshotSafeConfig();
    }

    // ─── (a) Roles admin surface is not reachable as the Safe ─────

    function test_closure_rolesAdminUnreachableFromManager() public {
        address[3] memory modifiers = [NEW_MAIN, SUB, OLD_MAIN];
        bytes[] memory calls = _rolesAdminCalls();
        for (uint256 m; m < 3; m++) {
            for (uint256 i; i < calls.length; i++) {
                for (uint8 op; op < 2; op++) {
                    _expectViolation(IZodiacRoles.Status.TargetAddressNotAllowed, bytes32(0));
                    vm.prank(POD);
                    IZodiacRoles(NEW_MAIN)
                        .execTransactionWithRole(modifiers[m], 0, calls[i], IZodiacRoles.Operation(op), MANAGER, true);
                }
                // Same call hidden inside a MultiSend 1.4.1 batch (unwrapper path).
                _expectViolation(IZodiacRoles.Status.TargetAddressNotAllowed, bytes32(0));
                vm.prank(POD);
                IZodiacRoles(NEW_MAIN)
                    .execTransactionWithRole(
                        MULTISEND_141,
                        0,
                        abi.encodeCall(IMultiSend141.multiSend, (_pack(0, modifiers[m], calls[i]))),
                        IZodiacRoles.Operation.DelegateCall,
                        MANAGER,
                        true
                    );
            }
        }
        _assertSafeConfigUnchanged();
    }

    /// @dev Strongest Sub-side attacker: the pod owns the Sub, opens it completely, and forwards through it.
    function test_closure_podOwnedSubCannotEscalate() public {
        bytes32 anyRole = keccak256("ANY");
        bytes32[] memory keys = new bytes32[](1);
        keys[0] = anyRole;
        bool[] memory yes = new bool[](1);
        yes[0] = true;
        vm.startPrank(POD);
        IRolesOwnerSurface(SUB).enableModule(POD);
        IRolesOwnerSurface(SUB).assignRoles(POD, keys, yes);
        IRolesOwnerSurface(SUB).allowTarget(anyRole, NEW_MAIN, 3);
        IRolesOwnerSurface(SUB).allowTarget(anyRole, SAFE, 3);
        IRolesOwnerSurface(SUB).allowTarget(anyRole, SUB, 3);
        vm.stopPrank();

        // Sub → new Main.execTransactionFromModule → MANAGER (Sub's default role) rejects the target.
        bytes[] memory calls = _rolesAdminCalls();
        for (uint256 i; i < calls.length; i++) {
            _expectViolation(IZodiacRoles.Status.TargetAddressNotAllowed, bytes32(0));
            vm.prank(POD);
            IZodiacRoles(SUB).execTransactionWithRole(NEW_MAIN, 0, calls[i], IZodiacRoles.Operation.Call, anyRole, true);
        }
        _expectViolation(
            IZodiacRoles.Status.FunctionNotAllowed, bytes32(ISafeSelfSurface.addOwnerWithThreshold.selector)
        );
        vm.prank(POD);
        IZodiacRoles(SUB)
            .execTransactionWithRole(
                SAFE,
                0,
                abi.encodeCall(ISafeSelfSurface.addOwnerWithThreshold, (POD, 1)),
                IZodiacRoles.Operation.Call,
                anyRole,
                true
            );

        // Re-pointing the Sub straight at the Safe fails: the Sub is not a Safe module.
        vm.prank(POD);
        IRolesOwnerSurface(SUB).setTarget(SAFE);
        vm.prank(POD);
        vm.expectRevert(bytes("GS104"));
        IZodiacRoles(SUB)
            .execTransactionWithRole(
                SAFE,
                0,
                abi.encodeCall(ISafeSelfSurface.addOwnerWithThreshold, (POD, 1)),
                IZodiacRoles.Operation.Call,
                anyRole,
                true
            );
        // And the Sub cannot administer new Main directly.
        vm.prank(SUB);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", SUB));
        IRolesOwnerSurface(NEW_MAIN).transferOwnership(POD);
        _assertSafeConfigUnchanged();
    }

    // ─── (b) Safe self-calls are limited to the pinned EFH switch ─

    function test_closure_safeSelfCallsLimitedToPinnedEfhSwitch() public {
        bytes[] memory calls = _safeSelfCalls();
        for (uint256 i; i < calls.length; i++) {
            _assertSafeCallBlocked(calls[i]);
        }
        // Plain ETH / empty calldata to the Safe.
        _expectViolation(IZodiacRoles.Status.FunctionNotAllowed, bytes32(0));
        vm.prank(POD);
        IZodiacRoles(NEW_MAIN).execTransactionWithRole(SAFE, 0, "", IZodiacRoles.Operation.Call, MANAGER, true);

        // setFallbackHandler: only EFH, only Call, no value.
        address[5] memory handlers = [address(0), CFH_130, NEW_MAIN, POD, ATTACKER];
        for (uint256 i; i < handlers.length; i++) {
            _expectViolation(IZodiacRoles.Status.ParameterNotAllowed, bytes32(0));
            vm.prank(POD);
            IZodiacRoles(NEW_MAIN)
                .execTransactionWithRole(
                    SAFE,
                    0,
                    abi.encodeCall(ISafeSelfSurface.setFallbackHandler, (handlers[i])),
                    IZodiacRoles.Operation.Call,
                    MANAGER,
                    true
                );
        }
        _expectViolation(IZodiacRoles.Status.DelegateCallNotAllowed, bytes32(0));
        vm.prank(POD);
        IZodiacRoles(NEW_MAIN)
            .execTransactionWithRole(
                SAFE,
                0,
                abi.encodeCall(ISafeSelfSurface.setFallbackHandler, (EFH)),
                IZodiacRoles.Operation.DelegateCall,
                MANAGER,
                true
            );
        _assertSafeConfigUnchanged();

        // The permitted, carried-over one-way switch.
        _pod(SAFE, abi.encodeCall(ISafeSelfSurface.setFallbackHandler, (EFH)));
        assertEq(address(uint160(uint256(vm.load(SAFE, FALLBACK_SLOT)))), EFH, "EFH installed");
        safeConfigBefore[7] = vm.load(SAFE, FALLBACK_SLOT);
        _assertSafeConfigUnchanged();

        // setDomainVerifier: only (CoW domain, ComposableCoW).
        _expectViolation(IZodiacRoles.Status.ParameterNotAllowed, bytes32(0));
        vm.prank(POD);
        IZodiacRoles(NEW_MAIN)
            .execTransactionWithRole(
                SAFE,
                0,
                abi.encodeCall(ISafeSelfSurface.setDomainVerifier, (keccak256("PERMIT2"), COMPOSABLE_COW)),
                IZodiacRoles.Operation.Call,
                MANAGER,
                true
            );
        _expectViolation(IZodiacRoles.Status.ParameterNotAllowed, bytes32(0));
        vm.prank(POD);
        IZodiacRoles(NEW_MAIN)
            .execTransactionWithRole(
                SAFE,
                0,
                abi.encodeCall(ISafeSelfSurface.setDomainVerifier, (COW_DOMAIN, ATTACKER)),
                IZodiacRoles.Operation.Call,
                MANAGER,
                true
            );
        _pod(SAFE, abi.encodeCall(ISafeSelfSurface.setDomainVerifier, (COW_DOMAIN, COMPOSABLE_COW)));
        assertEq(IEFH(EFH).domainVerifiers(SAFE, COW_DOMAIN), COMPOSABLE_COW);

        // With EFH live, every EFH setter and every Safe admin selector is still blocked,
        // and EFH itself is not a target (onlySelf would accept a direct Safe call).
        for (uint256 i; i < calls.length; i++) {
            _assertSafeCallBlocked(calls[i]);
        }
        _expectViolation(IZodiacRoles.Status.TargetAddressNotAllowed, bytes32(0));
        vm.prank(POD);
        IZodiacRoles(NEW_MAIN)
            .execTransactionWithRole(
                EFH,
                0,
                abi.encodePacked(
                    abi.encodeCall(ISafeSelfSurface.setSafeMethod, (bytes4(0xdeadbeef), bytes32(uint256(1)))), SAFE
                ),
                IZodiacRoles.Operation.Call,
                MANAGER,
                true
            );
        assertEq(IEFH(EFH).safeMethods(SAFE, 0xdeadbeef), bytes32(0));
        _assertSafeConfigUnchanged();
    }

    // ─── EIP-1271: the Safe cannot sign a Roles module transaction ─

    function test_closure_safeEip1271CannotAuthorizeRoles() public {
        // Even a Safe that returned the EIP-1271 magic value for everything is not a Roles module.
        vm.mockCall(
            SAFE,
            abi.encodeWithSelector(ISafeSelfSurface.isValidSignature.selector),
            abi.encode(ISafeSelfSurface.isValidSignature.selector)
        );
        bytes memory inner = abi.encodeCall(
            IZodiacRoles.execTransactionWithRole,
            (
                NEW_MAIN,
                0,
                abi.encodeCall(IRolesOwnerSurface.transferOwnership, (ATTACKER)),
                IZodiacRoles.Operation.Call,
                MANAGER,
                true
            )
        );
        uint256 start = inner.length; // contract signature bytes start after the call
        bytes memory signed = abi.encodePacked(
            inner, bytes32(uint256(1)), bytes32(0), bytes32(uint256(uint160(SAFE))), bytes32(start), uint8(0)
        );
        vm.prank(ATTACKER);
        (bool ok, bytes memory ret) = NEW_MAIN.call(signed);
        assertFalse(ok);
        assertEq(ret, abi.encodeWithSignature("NotAuthorized(address)", ATTACKER));
        vm.clearMockedCalls();

        // onlyOwner reads msg.sender only; appended signatures are irrelevant.
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", ATTACKER));
        IRolesOwnerSurface(NEW_MAIN).transferOwnership(ATTACKER);

        // The real Safe (EFH + ComposableCoW installed) rejects an arbitrary hash.
        _pod(SAFE, abi.encodeCall(ISafeSelfSurface.setFallbackHandler, (EFH)));
        _pod(SAFE, abi.encodeCall(ISafeSelfSurface.setDomainVerifier, (COW_DOMAIN, COMPOSABLE_COW)));
        vm.expectRevert(bytes("Hash not approved"));
        ISafeSelfSurface(SAFE).isValidSignature(keccak256("roles-module-tx"), "");
    }

    // ─── (2) DelegateCall surface: CowswapOrderSigner only ────────

    function test_closure_orderSignerImmutables() public view {
        assertEq(ICowswapOrderSignerFull(ORDER_SIGNER).signing(), GPV2_SETTLEMENT);
        assertEq(ICowswapOrderSignerFull(ORDER_SIGNER).deployedAt(), ORDER_SIGNER);
        assertEq(ORDER_SIGNER.code.length, 1810, "runtime size");
        assertEq(ICowswapOrderSignerFull.signOrder.selector, bytes4(0x569d3489));
        assertEq(ICowswapOrderSignerFull.unsignOrder.selector, bytes4(0x5a66c223));
    }

    function testFuzz_closure_unsignOrderDelegatecallWritesNoSafeStorage(bytes memory tail) public {
        bytes memory data = bytes.concat(ICowswapOrderSignerFull.unsignOrder.selector, tail);
        _delegateAndAssertNoSafeWrites(data);
    }

    function testFuzz_closure_unsignOrderStructuredWritesNoSafeStorage(ICowSwapOrderSigner.Data memory order) public {
        assertTrue(
            _delegateAndAssertNoSafeWrites(abi.encodeCall(ICowswapOrderSignerFull.unsignOrder, (order))),
            "unsignOrder executed"
        );
    }

    function test_closure_signOrderHappyPathWritesNoSafeStorage() public {
        ICowSwapOrderSigner.Data memory order = ICowSwapOrderSigner.Data({
            sellToken: IERC20(USDC),
            buyToken: IERC20(WETH),
            receiver: SAFE,
            sellAmount: 1e6,
            buyAmount: 1,
            validTo: uint32(block.timestamp + 600),
            appData: bytes32(0),
            feeAmount: 0,
            kind: keccak256("sell"),
            partiallyFillable: false,
            sellTokenBalance: keccak256("erc20"),
            buyTokenBalance: keccak256("erc20")
        });
        vm.recordLogs();
        assertTrue(
            _delegateAndAssertNoSafeWrites(abi.encodeCall(ICowswapOrderSignerFull.signOrder, (order, 3600, 0))),
            "signOrder executed"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool presigned;
        for (uint256 i; i < logs.length; i++) {
            if (logs[i].emitter == GPV2_SETTLEMENT) presigned = true;
        }
        assertTrue(presigned, "PreSignature emitted by GPv2Settlement only");
    }

    function testFuzz_closure_signOrderWritesNoSafeStorage(
        uint256 sellAmount,
        uint256 buyAmount,
        uint32 validTo,
        bytes32 appData,
        uint256 feeAmount,
        bytes32 kind,
        bool partiallyFillable,
        uint32 validDuration,
        uint256 feeBP
    )
        public
    {
        ICowSwapOrderSigner.Data memory order = ICowSwapOrderSigner.Data({
            sellToken: IERC20(USDC),
            buyToken: IERC20(WETH),
            receiver: SAFE,
            sellAmount: sellAmount,
            buyAmount: buyAmount,
            validTo: validTo,
            appData: appData,
            feeAmount: feeAmount,
            kind: kind,
            partiallyFillable: partiallyFillable,
            sellTokenBalance: bytes32(0),
            buyTokenBalance: bytes32(0)
        });
        _delegateAndAssertNoSafeWrites(abi.encodeCall(ICowswapOrderSignerFull.signOrder, (order, validDuration, feeBP)));
    }

    // ─── (4) Allowance module
    // ─────────────────────────────────────

    function test_closure_allowanceModuleCannotReachRoles() public {
        (address[] memory delegates,) = IAllowanceModule(ALLOWANCE_MODULE).getDelegates(SAFE, 0, 50);
        assertEq(delegates.length, 1);
        assertEq(delegates[0], ALLOWANCE_DELEGATE);
        address[] memory tokens = IAllowanceModule(ALLOWANCE_MODULE).getTokens(SAFE, ALLOWANCE_DELEGATE);
        assertEq(tokens.length, 1);
        assertEq(tokens[0], address(0), "ETH only");

        // The module can only do (to, amount, "") or token.transfer(to, amount): Roles has no receive().
        address[3] memory modifiers = [NEW_MAIN, SUB, OLD_MAIN];
        for (uint256 i; i < 3; i++) {
            vm.prank(ALLOWANCE_DELEGATE);
            vm.expectRevert(bytes("Could not execute ether transfer"));
            IAllowanceModule(ALLOWANCE_MODULE)
                .executeAllowanceTransfer(
                    SAFE, address(0), payable(modifiers[i]), 1, address(0), 0, ALLOWANCE_DELEGATE, ""
                );
        }
        // A non-configured "token" (e.g. a Roles contract) has zero allowance.
        vm.prank(ALLOWANCE_DELEGATE);
        vm.expectRevert(bytes("newSpent > allowance.spent && newSpent <= allowance.amount"));
        IAllowanceModule(ALLOWANCE_MODULE)
            .executeAllowanceTransfer(SAFE, NEW_MAIN, payable(ATTACKER), 1, address(0), 0, ALLOWANCE_DELEGATE, "");
        // The pod is not a delegate.
        vm.prank(POD);
        vm.expectRevert();
        IAllowanceModule(ALLOWANCE_MODULE)
            .executeAllowanceTransfer(SAFE, address(0), payable(POD), 1, address(0), 0, POD, "");
        // ETH to the Safe itself writes no Safe storage.
        vm.record();
        vm.prank(ALLOWANCE_DELEGATE);
        IAllowanceModule(ALLOWANCE_MODULE)
            .executeAllowanceTransfer(SAFE, address(0), payable(SAFE), 1, address(0), 0, ALLOWANCE_DELEGATE, "");
        (, bytes32[] memory writes) = vm.accesses(SAFE);
        assertEq(writes.length, 0, "Safe storage written");
        _assertSafeConfigUnchanged();
    }

    // ─── (5) Timelock / Security Council
    // ──────────────────────────

    function test_closure_onlyDelayedTimelockReconfigures() public {
        ITimelockAdmin t = ITimelockAdmin(TIMELOCK);
        bytes32 admin = keccak256("TIMELOCK_ADMIN_ROLE");
        bytes32 proposer = keccak256("PROPOSER_ROLE");
        assertEq(t.getMinDelay(), 9 days);
        assertTrue(t.hasRole(admin, TIMELOCK), "self-admin");
        assertFalse(t.hasRole(admin, TIMELOCK_DEPLOYER), "deployer renounced");
        assertFalse(t.hasRole(admin, FOUNDATION));
        assertFalse(t.hasRole(admin, SC_WRAPPER));
        assertFalse(t.hasRole(admin, SAFE));
        assertFalse(t.hasRole(admin, POD));
        assertFalse(t.hasRole(proposer, SAFE));
        assertFalse(t.hasRole(proposer, POD));
        assertEq(t.getRoleAdmin(proposer), admin);

        bytes memory addOwner = abi.encodeCall(ISafeSelfSurface.addOwnerWithThreshold, (ATTACKER, 1));
        vm.startPrank(FOUNDATION);
        vm.expectRevert(bytes("TimelockController: insufficient delay"));
        t.schedule(SAFE, 0, addOwner, bytes32(0), bytes32(0), 9 days - 1);
        vm.expectRevert(bytes("TimelockController: caller must be timelock"));
        t.updateDelay(0);
        vm.expectRevert();
        t.grantRole(proposer, ATTACKER);
        t.schedule(SAFE, 0, addOwner, bytes32(0), bytes32(0), 9 days);
        vm.expectRevert(bytes("TimelockController: operation is not ready"));
        t.execute(SAFE, 0, addOwner, bytes32(0), bytes32(0));
        vm.stopPrank();

        // Security Council wrapper: veto only, owned by the SC Safe, bound to this timelock.
        assertEq(ISecurityCouncilWrapper(SC_WRAPPER).timelock(), TIMELOCK);
        assertEq(ISecurityCouncilWrapper(SC_WRAPPER).owner(), SC_SAFE);
        (bool ok,) = SC_WRAPPER.call(
            abi.encodeCall(ITimelockAdmin.schedule, (SAFE, 0, addOwner, bytes32(0), bytes32(0), 9 days))
        );
        assertFalse(ok, "wrapper exposes schedule");

        // Safe itself: only its owner (the timelock) can execTransaction or approveHash.
        vm.prank(POD);
        vm.expectRevert(bytes("GS030"));
        ISafeSelfSurface(SAFE).approveHash(bytes32(uint256(1)));
        _assertSafeConfigUnchanged();
    }

    // ─── Policy-wide on-chain invariant: no other DelegateCall or wildcard target ─

    function test_closure_policyHasNoOtherDelegateCallOrWildcardTarget() public view {
        string memory json = vm.readFile("src/ens/proposals/ep-kpk-update-10/roleStateKeys.json");
        address[] memory targets = vm.parseJsonAddressArray(json, ".targets");
        bytes32[] memory keys = vm.parseJsonBytes32Array(json, ".functionKeys");
        uint256 roleBase = uint256(keccak256(abi.encode(MANAGER, uint256(4))));
        for (uint256 i; i < targets.length; i++) {
            uint256 clearance = uint256(vm.load(NEW_MAIN, keccak256(abi.encode(targets[i], roleBase + 1)))) & 0xff;
            assertTrue(clearance == 0 || clearance == 2, "wildcard (Target-clearance) target");
            if (_isControlPlane(targets[i])) assertTrue(targets[i] == SAFE, "control-plane contract is a target");
        }
        uint256 delegateCallKeys;
        uint256 safeKeys;
        for (uint256 i; i < keys.length; i++) {
            uint256 header = uint256(vm.load(NEW_MAIN, keccak256(abi.encode(keys[i], roleBase + 2))));
            if (header == 0) continue;
            uint256 options = (header >> 224) & 0xff;
            if (options & 2 != 0) {
                delegateCallKeys++;
                assertEq(address(bytes20(keys[i])), ORDER_SIGNER, "DelegateCall outside CowswapOrderSigner");
            }
            if (address(bytes20(keys[i])) == SAFE) {
                safeKeys++;
                bytes4 sel = bytes4(keys[i] << 160);
                assertTrue(
                    sel == ISafeSelfSurface.setFallbackHandler.selector
                        || sel == ISafeSelfSurface.setDomainVerifier.selector,
                    "unexpected Safe self-call"
                );
                assertEq(options, 0, "Safe self-call with Send/DelegateCall");
            }
        }
        assertEq(delegateCallKeys, 2, "signOrder + unsignOrder");
        assertEq(safeKeys, 2, "setFallbackHandler + setDomainVerifier");
    }

    // ─── Pre-switch window (ownership already transferred, old Main still enabled) ─

    function test_closure_preSwitchWindowOldMainCannotReachAdmin() public {
        vm.startPrank(SAFE);
        ISafeSelfSurface(SAFE).disableModule(SENTINEL, NEW_MAIN);
        ISafeSelfSurface(SAFE).enableModule(OLD_MAIN);
        vm.stopPrank();
        address[3] memory modifiers = [NEW_MAIN, SUB, OLD_MAIN];
        bytes[] memory calls = _rolesAdminCalls();
        for (uint256 m; m < 3; m++) {
            for (uint256 i; i < calls.length; i++) {
                _expectViolation(IZodiacRoles.Status.TargetAddressNotAllowed, bytes32(0));
                vm.prank(POD);
                IZodiacRoles(OLD_MAIN)
                    .execTransactionWithRole(modifiers[m], 0, calls[i], IZodiacRoles.Operation.Call, MANAGER, true);
            }
        }
        bytes[] memory safeCalls = _safeSelfCalls();
        for (uint256 i; i < safeCalls.length; i++) {
            _expectViolation(IZodiacRoles.Status.FunctionNotAllowed, bytes32(bytes4(safeCalls[i])));
            vm.prank(POD);
            IZodiacRoles(OLD_MAIN)
                .execTransactionWithRole(SAFE, 0, safeCalls[i], IZodiacRoles.Operation.Call, MANAGER, true);
        }
    }

    // ─── Negative controls: the detectors above fire on a real escalation ─

    function test_closure_negativeControl_widenedPolicyIsDetected() public {
        // If the owner (Safe, via the timelock) ever made new Main a target, the pod could take it over.
        vm.prank(SAFE);
        IRolesOwnerSurface(NEW_MAIN).allowTarget(MANAGER, NEW_MAIN, 0);
        _pod(NEW_MAIN, abi.encodeCall(IRolesOwnerSurface.transferOwnership, (ATTACKER)));
        assertEq(IRolesOwnerSurface(NEW_MAIN).owner(), ATTACKER, "control: takeover succeeds when widened");
    }

    function test_closure_negativeControl_safeWriteIsDetected() public {
        // A DelegateCall to code that writes Safe storage is caught by vm.accesses (approveHash-style write).
        vm.prank(SAFE);
        IRolesOwnerSurface(NEW_MAIN).allowTarget(MANAGER, SAFE, 3);
        vm.record();
        _pod(SAFE, abi.encodeCall(ISafeSelfSurface.changeThreshold, (1)));
        (, bytes32[] memory writes) = vm.accesses(SAFE);
        assertGt(writes.length, 0, "control: Safe self-call writes are recorded");
    }

    // ─── Helpers
    // ──────────────────────────────────────────────────

    function _isControlPlane(address a) internal pure returns (bool) {
        return a == SAFE || a == NEW_MAIN || a == SUB || a == OLD_MAIN || a == TIMELOCK || a == FOUNDATION
            || a == SC_WRAPPER || a == ALLOWANCE_MODULE || a == EFH || a == CFH_130 || a == POD;
    }

    /// @dev Authorization must pass (no try/catch): the delegatecall is really executed in the Safe's context.
    function _delegateAndAssertNoSafeWrites(bytes memory data) internal returns (bool success) {
        vm.record();
        vm.prank(POD);
        success = IZodiacRoles(NEW_MAIN)
            .execTransactionWithRole(ORDER_SIGNER, 0, data, IZodiacRoles.Operation.DelegateCall, MANAGER, false);
        (, bytes32[] memory writes) = vm.accesses(SAFE);
        assertEq(writes.length, 0, "delegatecall wrote Safe storage");
        _assertSafeConfigUnchanged();
    }

    function _assertSafeCallBlocked(bytes memory data) internal {
        _expectViolation(IZodiacRoles.Status.FunctionNotAllowed, bytes32(bytes4(data)));
        vm.prank(POD);
        IZodiacRoles(NEW_MAIN).execTransactionWithRole(SAFE, 0, data, IZodiacRoles.Operation.Call, MANAGER, true);
        _expectViolation(IZodiacRoles.Status.FunctionNotAllowed, bytes32(bytes4(data)));
        vm.prank(POD);
        IZodiacRoles(NEW_MAIN)
            .execTransactionWithRole(
                MULTISEND_141,
                0,
                abi.encodeCall(IMultiSend141.multiSend, (_pack(0, SAFE, data))),
                IZodiacRoles.Operation.DelegateCall,
                MANAGER,
                true
            );
    }

    function _pod(address to, bytes memory data) internal {
        vm.prank(POD);
        IZodiacRoles(NEW_MAIN).execTransactionWithRole(to, 0, data, IZodiacRoles.Operation.Call, MANAGER, true);
    }

    function _expectViolation(IZodiacRoles.Status status, bytes32 info) internal {
        vm.expectRevert(abi.encodeWithSelector(IZodiacRoles.ConditionViolation.selector, status, info));
    }

    function _pack(uint8 op, address to, bytes memory data) internal pure returns (bytes memory) {
        return abi.encodePacked(op, to, uint256(0), uint256(data.length), data);
    }

    function _snapshotSafeConfig() internal {
        for (uint256 i; i < 6; i++) {
            safeConfigBefore[i] = vm.load(SAFE, bytes32(i));
        }
        safeConfigBefore[6] = vm.load(SAFE, GUARD_SLOT);
        safeConfigBefore[7] = vm.load(SAFE, FALLBACK_SLOT);
    }

    function _assertSafeConfigUnchanged() internal view {
        for (uint256 i; i < 6; i++) {
            assertEq(vm.load(SAFE, bytes32(i)), safeConfigBefore[i], "Safe slot 0-5 changed");
        }
        assertEq(vm.load(SAFE, GUARD_SLOT), safeConfigBefore[6], "guard changed");
        assertEq(vm.load(SAFE, FALLBACK_SLOT), safeConfigBefore[7], "fallback handler changed");
        address[] memory owners = ISafeSelfSurface(SAFE).getOwners();
        assertEq(owners.length, 1);
        assertEq(owners[0], TIMELOCK);
        assertEq(ISafeSelfSurface(SAFE).getThreshold(), 1);
        (address[] memory mods,) = ISafeSelfSurface(SAFE).getModulesPaginated(SENTINEL, 10);
        assertEq(mods.length, 2);
        assertEq(mods[0], NEW_MAIN);
        assertEq(mods[1], ALLOWANCE_MODULE);
        assertEq(IRolesOwnerSurface(NEW_MAIN).owner(), SAFE);
        assertEq(IRolesOwnerSurface(OLD_MAIN).owner(), SAFE);
        assertEq(IRolesOwnerSurface(SUB).owner(), POD);
    }

    function _rolesAdminCalls() internal pure returns (bytes[] memory c) {
        bytes32[] memory keys = new bytes32[](1);
        keys[0] = MANAGER;
        bool[] memory yes = new bool[](1);
        yes[0] = true;
        ConditionFlat[] memory conds = new ConditionFlat[](1);
        conds[0] = ConditionFlat({ parent: 0, paramType: 5, operator: 0, compValue: "" });
        c = new bytes[](17);
        c[0] = abi.encodeCall(IRolesOwnerSurface.transferOwnership, (ATTACKER));
        c[1] = abi.encodeCall(IRolesOwnerSurface.renounceOwnership, ());
        c[2] = abi.encodeCall(IRolesOwnerSurface.setUp, (abi.encode(ATTACKER, SAFE, SAFE)));
        c[3] = abi.encodeCall(IRolesOwnerSurface.setAvatar, (ATTACKER));
        c[4] = abi.encodeCall(IRolesOwnerSurface.setTarget, (ATTACKER));
        c[5] = abi.encodeCall(IRolesOwnerSurface.enableModule, (ATTACKER));
        c[6] = abi.encodeCall(IRolesOwnerSurface.disableModule, (SENTINEL, POD));
        c[7] = abi.encodeCall(IRolesOwnerSurface.assignRoles, (ATTACKER, keys, yes));
        c[8] = abi.encodeCall(IRolesOwnerSurface.setDefaultRole, (ATTACKER, MANAGER));
        c[9] = abi.encodeCall(IRolesOwnerSurface.allowTarget, (MANAGER, USDC, 3));
        c[10] = abi.encodeCall(IRolesOwnerSurface.scopeTarget, (MANAGER, ATTACKER));
        c[11] = abi.encodeCall(IRolesOwnerSurface.revokeTarget, (MANAGER, USDC));
        c[12] = abi.encodeCall(IRolesOwnerSurface.allowFunction, (MANAGER, USDC, IERC20.transfer.selector, 3));
        c[13] = abi.encodeCall(IRolesOwnerSurface.scopeFunction, (MANAGER, USDC, IERC20.transfer.selector, conds, 0));
        c[14] = abi.encodeCall(IRolesOwnerSurface.revokeFunction, (MANAGER, USDC, IERC20.transfer.selector));
        c[15] = abi.encodeCall(IRolesOwnerSurface.setAllowance, (bytes32(uint256(1)), 1, 1, 1, 1, 1));
        c[16] = abi.encodeCall(
            IRolesOwnerSurface.setTransactionUnwrapper, (MULTISEND_141, IMultiSend.multiSend.selector, ATTACKER)
        );
    }

    function _safeSelfCalls() internal pure returns (bytes[] memory c) {
        address[] memory owners = new address[](1);
        owners[0] = ATTACKER;
        c = new bytes[](16);
        c[0] = abi.encodeCall(ISafeSelfSurface.addOwnerWithThreshold, (ATTACKER, 1));
        c[1] = abi.encodeCall(ISafeSelfSurface.removeOwner, (SENTINEL, TIMELOCK, 1));
        c[2] = abi.encodeCall(ISafeSelfSurface.swapOwner, (SENTINEL, TIMELOCK, ATTACKER));
        c[3] = abi.encodeCall(ISafeSelfSurface.changeThreshold, (1));
        c[4] = abi.encodeCall(ISafeSelfSurface.enableModule, (ATTACKER));
        c[5] = abi.encodeCall(ISafeSelfSurface.disableModule, (SENTINEL, NEW_MAIN));
        c[6] = abi.encodeCall(ISafeSelfSurface.setGuard, (ATTACKER));
        c[7] = abi.encodeCall(ISafeSelfSurface.approveHash, (bytes32(uint256(1))));
        c[8] = abi.encodeCall(ISafeSelfSurface.simulateAndRevert, (ATTACKER, ""));
        c[9] = abi.encodeCall(ISafeSelfSurface.execTransactionFromModule, (NEW_MAIN, 0, "", 0));
        c[10] = abi.encodeCall(
            ISafeSelfSurface.execTransaction, (NEW_MAIN, 0, "", 0, 0, 0, 0, address(0), payable(address(0)), "")
        );
        c[11] = abi.encodeCall(
            ISafeSelfSurface.setup, (owners, 1, address(0), "", address(0), address(0), 0, payable(address(0)))
        );
        c[12] = abi.encodeCall(ISafeSelfSurface.setSafeMethod, (bytes4(0xdeadbeef), bytes32(uint256(1))));
        c[13] = abi.encodeCall(ISafeSelfSurface.setSupportedInterface, (bytes4(0xdeadbeef), true));
        c[14] = abi.encodeCall(ISafeSelfSurface.addSupportedInterfaceBatch, (bytes4(0), new bytes32[](0)));
        c[15] = abi.encodeCall(ISafeSelfSurface.removeSupportedInterfaceBatch, (bytes4(0), new bytes4[](0)));
    }
}
