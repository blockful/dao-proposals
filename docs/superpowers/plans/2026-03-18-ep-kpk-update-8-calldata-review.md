# EP 6.38 — karpatkey Update #8 Calldata Review Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite the EP 6.38 calldata review test so every byte of calldata is independently constructed and every permission change is verified with before/after assertions.

**Architecture:** Single test contract inheriting ENS_Governance + SafeHelper + ZodiacRolesHelper. All 18 multiSend transactions built from named constants and ConditionFlat structs — zero hex blobs except for the two annotation JSON payloads (opaque data, not calldata). Comprehensive _beforeProposal() and _afterExecution() hooks test every permission grant/revocation via dry-run Zodiac Roles calls.

**Tech Stack:** Foundry (forge), Solidity 0.8.25, Gnosis Safe, Zodiac Roles V2

---

## File Structure

- **Modify:** `src/ens/proposals/ep-6-38/calldataCheck.t.sol` — complete rewrite
- **Reference (read-only):**
  - `src/ens/helpers/SafeHelper.sol` — `_buildSafeExecDelegateCalldata`, `_buildPreApprovedSignature`, `endowmentSafe`
  - `src/ens/helpers/ZodiacRolesHelper.sol` — `roles`, `MANAGER_ROLE`, `karpatkey`, `_safeExecuteTransaction`, `_expectConditionViolation`
  - `src/ens/interfaces/IZodiacRoles.sol` — `IZodiacRoles.Status`, `IZodiacRoles.Operation`
  - `src/ens/interfaces/IFluidMerkleDistributor.sol` — claim function signature
  - `src/ens/interfaces/IGHO.sol` — GHO token interface
  - `src/ens/proposals/ep-registrar-manager-endowment/calldataCheck.t.sol` — pattern reference

---

## Key Design Decisions

1. **No hex calldata blobs.** Every `scopeFunction` call is built from `ConditionFlat[]` arrays. Every `revokeTarget`, `revokeFunction`, `scopeTarget`, `allowFunction`, `disableModule`, `setTransactionUnwrapper` is built with `abi.encodeWithSelector`.

2. **Annotation JSON stays as hex.** TX 8 and TX 17 are `post(string, bytes32)` calls to the annotation registry. The string payload is a JSON blob — it's opaque data, not ABI-encoded calldata. Keeping it as hex is correct. But the `post()` encoding itself is manual.

3. **Before/after assertions test every permission.** The test must verify:
   - Before execution: Roles V1 is enabled, old permissions (RocketPool v3 deposit, SPK transfer, SparkRewards claim) work, new permissions (GHO/FLUID approve, FluidMerkle claim, RocketPool v4 deposit, CowSwap signOrder with new tokens) are blocked.
   - After execution: Roles V1 is disabled, old permissions are revoked, new permissions work. CowSwap order signing with GHO/FLUID is allowed. Approvals of GHO to fGHO and GPv2VaultRelayer work. FLUID approval to GPv2VaultRelayer works. FluidMerkle claim (with recipient=Safe) works. RocketPool v4 deposit works.

4. **CowSwap sell/buy token lists as address arrays.** The 25 sell tokens and 15 buy tokens are defined as named constants and assembled into arrays, making the whitelist human-reviewable.

---

## Decoded Transaction Parameters (reference for implementation)

### Zodiac Roles V2 Condition Enums

```
AbiType:  0=None, 1=Static, 3=Tuple, 5=Calldata
Operator: 0=Pass, 2=Or, 5=Matches, 15=EqualToAvatar, 16=EqualTo
ExecutionOptions: 0=None, 1=Send, 2=DelegateCall
```

### TX 9 — CowSwap signOrder conditions (54 conditions)

Target: 0x23dA9AdE38E4477b23770DeD512fD37b12381FAB (CowswapOrderSigner)
Selector: 0x569d3489 (signOrder)
Options: 2 (DelegateCall)

Condition tree:
```
[0]  Calldata Matches         — root
[1]  Tuple Matches            — order struct (param 0)
[2]    None Or                — sellToken: OR group
[3]    None Or                — buyToken: OR group
[4]    Static EqualToAvatar   — receiver must == Safe
[5-13] Static Pass (x9)       — sellAmount, buyAmount, validTo, appData, feeAmount, kind, partiallyFillable, sellTokenBalance, buyTokenBalance
[14-38] Static EqualTo (x25)  — sell token whitelist (children of [2])
[39-53] Static EqualTo (x15)  — buy token whitelist (children of [3])
```

Sell tokens (25): GHO, SWISE, CVX, MORPHO, LDO, DAI, FLUID, wstETH, LUSD, USDC, USR, sDAI, rETH, stETH, BAL, COMP, WETH, AURA, SPK, RPL, CRV, USDT, USDS, sUSDe, sfrxETH

Buy tokens (15): GHO, DAI, wstETH, LUSD, USDC, USR, sDAI, rETH, stETH, WETH, USDT, USDS, sUSDe, ETH(native), sfrxETH

### TX 10 — GHO approve conditions (4 conditions)

Target: GHO (0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f)
Selector: 0x095ea7b3 (approve)
Options: 0 (None)

```
[0] Calldata Matches        — root
[1]   None Or               — spender: OR group
[2]     Static EqualTo fGHO (0x6a29A46E21C730DCA1d8b23d637c101cec605c5b)
[3]     Static EqualTo GPv2VaultRelayer (0xc92E8bDF79f0507f65a392b0ab4667716BFE0110)
```

### TX 12 — FLUID approve conditions (2 conditions)

Target: FLUID (0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb)
Selector: 0x095ea7b3 (approve)
Options: 0 (None)

```
[0] Calldata Matches          — root
[1]   Static EqualTo GPv2VaultRelayer (0xc92E8bDF79f0507f65a392b0ab4667716BFE0110)
```

### TX 16 — FluidMerkle claim conditions (2 conditions)

Target: FluidMerkleDistributor (0xF398E66B1273a34558AeBbEC550DccaF4AcC7714)
Selector: 0xbe5013dc (claim)
Options: 0 (None)

```
[0] Calldata Matches          — root
[1]   Static EqualToAvatar    — recipient must == Safe
```

---

## Chunk 1: Interfaces, Constants, and Scaffolding

### Task 1: Write the contract shell with all interfaces and constants

**Files:**
- Modify: `src/ens/proposals/ep-6-38/calldataCheck.t.sol`

- [ ] **Step 1: Write the full contract shell**

Replace the entire file with the new structure. This includes:
- All imports (ENS_Governance, SafeHelper, ZodiacRolesHelper, IZodiacRoles, IERC20)
- Local `IRoles` interface with all needed functions
- Local `IMultiSend` interface
- `ConditionFlat` struct
- Contract declaration inheriting ENS_Governance, SafeHelper, ZodiacRolesHelper
- All address constants (named, not anonymous hex)
- Zodiac condition enum constants
- `_selectFork`, `_proposer`, `_isProposalSubmitted`, `dirPath` overrides
- Empty `_beforeProposal`, `_afterExecution`, `_generateCallData` stubs
- `_packTx` multiSend helper

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ENS_Governance } from "@ens/ens.t.sol";
import { SafeHelper } from "@ens/helpers/SafeHelper.sol";
import { ZodiacRolesHelper } from "@ens/helpers/ZodiacRolesHelper.sol";
import { IZodiacRoles } from "@ens/interfaces/IZodiacRoles.sol";
import { IERC20 } from "@forge-std/src/interfaces/IERC20.sol";

interface IRoles {
    function setTransactionUnwrapper(address handler, bytes4 selector, address adapter) external;
    function revokeTarget(bytes32 roleKey, address targetAddress) external;
    function revokeFunction(bytes32 roleKey, address targetAddress, bytes4 selector) external;
    function scopeTarget(bytes32 roleKey, address targetAddress) external;
    function scopeFunction(
        bytes32 roleKey,
        address targetAddress,
        bytes4 selector,
        ConditionFlat[] calldata conditions,
        uint8 options
    ) external;
    function allowFunction(bytes32 roleKey, address targetAddress, bytes4 selector, uint8 options) external;
}

interface IMultiSend {
    function multiSend(bytes calldata transactions) external;
}

struct ConditionFlat {
    uint8 parent;
    uint8 paramType;
    uint8 operator;
    bytes compValue;
}

/**
 * @title EP 6.38 — Endowment permissions to karpatkey — Update #8
 * @notice Calldata review for the draft proposal on Tally
 * @dev Draft: https://www.tally.xyz/gov/ens/draft/2810671389726475399
 *
 * Summary of operations (18 transactions in MultiSend):
 *
 *   1. disableModule: Remove Roles V1 (0xf20325cf...) from Endowment Safe
 *   2. setTransactionUnwrapper: Update unwrapper for multiSend adapter on Roles V2
 *   3. revokeTarget(MANAGER, RocketPoolDepositV3): Revoke old RocketPool deposit pool
 *   4. revokeFunction(MANAGER, RocketPoolDepositV3, deposit()): Revoke deposit
 *   5. revokeFunction(MANAGER, SPK, transfer()): Remove SPK transfer permission
 *   6. revokeTarget(MANAGER, SparkRewards): Revoke SparkRewards contract
 *   7. revokeFunction(MANAGER, SparkRewards, claim()): Revoke SparkRewards claim
 *   8. post(): Remove old annotations from annotation registry
 *   9. scopeFunction(MANAGER, CowSwapOrderSigner, signOrder()): CowSwap swap permissions with GHO+FLUID
 *  10. scopeFunction(MANAGER, GHO, approve()): GHO approval scoped to fGHO + GPv2VaultRelayer
 *  11. scopeTarget(MANAGER, FLUID): Scope FLUID token target
 *  12. scopeFunction(MANAGER, FLUID, approve()): FLUID approval scoped to GPv2VaultRelayer
 *  13. scopeTarget(MANAGER, RocketPoolDepositV4): Scope new RocketPool deposit pool
 *  14. allowFunction(MANAGER, RocketPoolDepositV4, deposit()): Allow deposit with ETH
 *  15. scopeTarget(MANAGER, FluidMerkle): Scope Fluid Merkle Distributor
 *  16. scopeFunction(MANAGER, FluidMerkle, claim()): Claim scoped to recipient=Safe
 *  17. post(): Add new annotations to annotation registry
 *  18. setTransactionUnwrapper: Re-apply unwrapper for multiSend adapter
 */
contract Proposal_ENS_EP_KPK_Update_8_Draft_Test is ENS_Governance, SafeHelper, ZodiacRolesHelper {
    // ─── Protocol Addresses ──────────────────────────────────────────────

    address private constant MULTISEND = 0xA83c336B20401Af773B6219BA5027174338D1836;
    address private constant MULTISEND_HANDLER = 0xA238CBeb142c10Ef7Ad8442C6D1f9E89e07e7761;
    address private constant MULTISEND_ADAPTER = 0xB4Cd4bb764C089f20DA18700CE8bc5e49F369efD;
    address private constant ANNOTATION_REGISTRY = 0x000000000000cd17345801aa8147b8D3950260FF;

    // ─── Roles V1 (being disabled) ───────────────────────────────────────

    address private constant ROLES_V1 = 0xf20325cf84b72e8BBF8D8984B8f0059B984B390B;
    address private constant PREV_MODULE = 0xCFbFaC74C26F8647cBDb8c5caf80BB5b32E43134;

    // ─── Revoked Targets ─────────────────────────────────────────────────

    address private constant ROCKET_POOL_DEPOSIT_V3 = 0xDD3f50F8A6CAfBE9b31a427582963f465e745AF8;
    address private constant SPARK_REWARDS = 0x7ac96180c4d6b2A328D3A19ac059d0e7Fc3c6D41;
    address private constant SPK = 0xc20059e0317DE91738d13af027DfC4a50781b066;

    // ─── New Targets ─────────────────────────────────────────────────────

    address private constant ROCKET_POOL_DEPOSIT_V4 = 0xCE15294273CFb9D9b628F4D61636623decDF4fdC;
    address private constant FLUID_MERKLE = 0xF398E66B1273a34558AeBbEC550DccaF4AcC7714;
    address private constant COWSWAP_ORDER_SIGNER = 0x23dA9AdE38E4477b23770DeD512fD37b12381FAB;

    // ─── Tokens ──────────────────────────────────────────────────────────

    address private constant GHO = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;
    address private constant FLUID = 0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb;
    address private constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address private constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address private constant USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
    address private constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address private constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address private constant RETH = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address private constant SDAI = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
    address private constant SFRXETH = 0xac3E018457B222d93114458476f3E3416Abbe38F;
    address private constant SUSDE = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
    address private constant LUSD = 0x5f98805A4E8be255a32880FDeC7F6728C6568bA0;
    address private constant USR = 0x66a1E37c9b0eAddca17d3662D6c05F4DECf3e110;
    address private constant BAL = 0xba100000625a3754423978a60c9317c58a424e3D;
    address private constant COMP = 0xc00e94Cb662C3520282E6f5717214004a7f26888;
    address private constant CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;
    address private constant CVX = 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B;
    address private constant AURA = 0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF;
    address private constant LDO = 0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32;
    address private constant RPL = 0xD33526068D116cE69F19A9ee46F0bd304F21A51f;
    address private constant MORPHO = 0x58D97B57BB95320F9a05dC918Aef65434969c2B2;
    address private constant SWISE = 0x48C3399719B582dD63eB5AADf12A40B4C3f52fA2;
    address private constant NATIVE_ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // ─── Approved Spenders ───────────────────────────────────────────────

    address private constant F_GHO = 0x6a29A46E21C730DCA1d8b23d637c101cec605c5b;
    address private constant GPV2_VAULT_RELAYER = 0xc92E8bDF79f0507f65a392b0ab4667716BFE0110;

    // ─── Function Selectors ──────────────────────────────────────────────

    bytes4 private constant DEPOSIT_SELECTOR = 0xd0e30db0;       // deposit()
    bytes4 private constant TRANSFER_SELECTOR = 0xa9059cbb;      // transfer(address,uint256)
    bytes4 private constant APPROVE_SELECTOR = 0x095ea7b3;       // approve(address,uint256)
    bytes4 private constant SIGN_ORDER_SELECTOR = 0x569d3489;     // signOrder((...),uint32,uint256)
    bytes4 private constant SPARK_CLAIM_SELECTOR = 0xef98231e;    // claim(uint256,address,address,uint256,bytes32,bytes32[])
    bytes4 private constant FLUID_CLAIM_SELECTOR = 0xbe5013dc;    // claim(address,uint256,uint8,bytes32,uint256,bytes32[],bytes)
    bytes4 private constant MULTISEND_SELECTOR = 0x8d80ff0a;      // multiSend(bytes)

    // ─── Zodiac Condition Constants ──────────────────────────────────────

    uint8 private constant PARAM_TYPE_NONE = 0;
    uint8 private constant PARAM_TYPE_STATIC = 1;
    uint8 private constant PARAM_TYPE_TUPLE = 3;
    uint8 private constant PARAM_TYPE_CALLDATA = 5;

    uint8 private constant OP_PASS = 0;
    uint8 private constant OP_OR = 2;
    uint8 private constant OP_MATCHES = 5;
    uint8 private constant OP_EQUAL_TO_AVATAR = 15;
    uint8 private constant OP_EQUAL_TO = 16;

    uint8 private constant EXEC_NONE = 0;
    uint8 private constant EXEC_SEND = 1;
    uint8 private constant EXEC_DELEGATE_CALL = 2;

    // ... (implementation follows in subsequent tasks)
}
```

- [ ] **Step 2: Verify it compiles**

Run: `forge build --match-contract Proposal_ENS_EP_KPK_Update_8_Draft_Test`
Expected: Compiles (with warnings about empty functions)

- [ ] **Step 3: Commit**

```bash
git add src/ens/proposals/ep-6-38/calldataCheck.t.sol
git commit -m "refactor(ens): EP 6.38 — scaffold with named constants and interfaces"
```

---

## Chunk 2: Before/After Permission Assertions

### Task 2: Write _beforeProposal assertions

This tests the state BEFORE execution. Every permission that will change must be checked.

- [ ] **Step 1: Implement _beforeProposal**

```solidity
function _beforeProposal() public override {
    // Roles V1 should still be enabled as a module on the Safe
    (bool ok, bytes memory ret) = address(endowmentSafe).staticcall(
        abi.encodeWithSignature("isModuleEnabled(address)", ROLES_V1)
    );
    assertTrue(ok && abi.decode(ret, (bool)), "Roles V1 should be enabled before execution");

    // --- Permissions that should WORK before execution (will be revoked) ---

    // RocketPool v3 deposit should be allowed
    vm.startPrank(karpatkey);
    _safeExecuteTransaction(
        ROCKET_POOL_DEPOSIT_V3,
        abi.encodeWithSelector(DEPOSIT_SELECTOR)
    );
    vm.stopPrank();

    // SPK transfer should be allowed
    vm.startPrank(karpatkey);
    _safeExecuteTransaction(
        SPK,
        abi.encodeWithSelector(TRANSFER_SELECTOR, address(timelock), uint256(1))
    );
    vm.stopPrank();

    // SparkRewards claim should be allowed (will revert on invalid proof, but not on permission)
    // We test the target is scoped by checking it doesn't revert with TargetAddressNotAllowed
    vm.startPrank(karpatkey);
    _safeExecuteTransaction(
        SPARK_REWARDS,
        abi.encodeWithSelector(SPARK_CLAIM_SELECTOR, uint256(0), address(endowmentSafe), SPK, uint256(0), bytes32(0), new bytes32[](0))
    );
    vm.stopPrank();

    // --- Permissions that should NOT WORK before execution (will be added) ---

    // FLUID token target should not be scoped yet
    vm.startPrank(karpatkey);
    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
    roles.execTransactionWithRole(
        FLUID,
        0,
        abi.encodeWithSelector(APPROVE_SELECTOR, GPV2_VAULT_RELAYER, uint256(1)),
        IZodiacRoles.Operation.Call,
        MANAGER_ROLE,
        false
    );
    vm.stopPrank();

    // FluidMerkle target should not be scoped yet
    vm.startPrank(karpatkey);
    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
    roles.execTransactionWithRole(
        FLUID_MERKLE,
        0,
        abi.encodeWithSelector(FLUID_CLAIM_SELECTOR, address(endowmentSafe), uint256(0), uint8(0), bytes32(0), uint256(0), new bytes32[](0), ""),
        IZodiacRoles.Operation.Call,
        MANAGER_ROLE,
        false
    );
    vm.stopPrank();

    // RocketPool v4 target should not be scoped yet
    vm.startPrank(karpatkey);
    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
    roles.execTransactionWithRole(
        ROCKET_POOL_DEPOSIT_V4,
        0,
        abi.encodeWithSelector(DEPOSIT_SELECTOR),
        IZodiacRoles.Operation.Call,
        MANAGER_ROLE,
        false
    );
    vm.stopPrank();
}
```

Note: The `_safeExecuteTransaction` helper from ZodiacRolesHelper does a snapshot/revert, so state changes from successful calls are rolled back. For expected failures, we use `_expectConditionViolation` + direct `roles.execTransactionWithRole`.

- [ ] **Step 2: Verify it compiles**

Run: `forge build --match-contract Proposal_ENS_EP_KPK_Update_8_Draft_Test`

### Task 3: Write _afterExecution assertions

- [ ] **Step 1: Implement _afterExecution**

```solidity
function _afterExecution() public override {
    // --- Roles V1 should be disabled ---
    (bool ok, bytes memory ret) = address(endowmentSafe).staticcall(
        abi.encodeWithSignature("isModuleEnabled(address)", ROLES_V1)
    );
    assertTrue(ok, "isModuleEnabled call should succeed");
    assertFalse(abi.decode(ret, (bool)), "Roles V1 should be disabled after execution");

    // --- Revoked permissions should NO LONGER work ---

    // RocketPool v3 deposit revoked
    vm.startPrank(karpatkey);
    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
    roles.execTransactionWithRole(
        ROCKET_POOL_DEPOSIT_V3,
        0,
        abi.encodeWithSelector(DEPOSIT_SELECTOR),
        IZodiacRoles.Operation.Call,
        MANAGER_ROLE,
        false
    );
    vm.stopPrank();

    // SPK transfer revoked
    vm.startPrank(karpatkey);
    _expectConditionViolation(IZodiacRoles.Status.FunctionNotAllowed);
    roles.execTransactionWithRole(
        SPK,
        0,
        abi.encodeWithSelector(TRANSFER_SELECTOR, address(timelock), uint256(1)),
        IZodiacRoles.Operation.Call,
        MANAGER_ROLE,
        false
    );
    vm.stopPrank();

    // SparkRewards claim revoked
    vm.startPrank(karpatkey);
    _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
    roles.execTransactionWithRole(
        SPARK_REWARDS,
        0,
        abi.encodeWithSelector(SPARK_CLAIM_SELECTOR, uint256(0), address(endowmentSafe), SPK, uint256(0), bytes32(0), new bytes32[](0)),
        IZodiacRoles.Operation.Call,
        MANAGER_ROLE,
        false
    );
    vm.stopPrank();

    // --- New permissions should WORK ---

    // GHO approve to fGHO should be allowed
    vm.startPrank(karpatkey);
    _safeExecuteTransaction(
        GHO,
        abi.encodeWithSelector(APPROVE_SELECTOR, F_GHO, uint256(1e18))
    );
    vm.stopPrank();

    // GHO approve to GPv2VaultRelayer should be allowed
    vm.startPrank(karpatkey);
    _safeExecuteTransaction(
        GHO,
        abi.encodeWithSelector(APPROVE_SELECTOR, GPV2_VAULT_RELAYER, uint256(1e18))
    );
    vm.stopPrank();

    // GHO approve to a random address should be BLOCKED
    vm.startPrank(karpatkey);
    _expectConditionViolation(IZodiacRoles.Status.ParameterNotAllowed);
    roles.execTransactionWithRole(
        GHO,
        0,
        abi.encodeWithSelector(APPROVE_SELECTOR, address(0xdead), uint256(1e18)),
        IZodiacRoles.Operation.Call,
        MANAGER_ROLE,
        false
    );
    vm.stopPrank();

    // FLUID approve to GPv2VaultRelayer should be allowed
    vm.startPrank(karpatkey);
    _safeExecuteTransaction(
        FLUID,
        abi.encodeWithSelector(APPROVE_SELECTOR, GPV2_VAULT_RELAYER, uint256(1e18))
    );
    vm.stopPrank();

    // FLUID approve to random address should be BLOCKED
    vm.startPrank(karpatkey);
    _expectConditionViolation(IZodiacRoles.Status.ParameterNotAllowed);
    roles.execTransactionWithRole(
        FLUID,
        0,
        abi.encodeWithSelector(APPROVE_SELECTOR, address(0xdead), uint256(1e18)),
        IZodiacRoles.Operation.Call,
        MANAGER_ROLE,
        false
    );
    vm.stopPrank();

    // RocketPool v4 deposit should be allowed (with ETH)
    vm.startPrank(karpatkey);
    _safeExecuteTransaction(
        ROCKET_POOL_DEPOSIT_V4,
        abi.encodeWithSelector(DEPOSIT_SELECTOR)
    );
    vm.stopPrank();

    // FluidMerkle claim with recipient=Safe should be allowed
    vm.startPrank(karpatkey);
    _safeExecuteTransaction(
        FLUID_MERKLE,
        abi.encodeWithSelector(
            FLUID_CLAIM_SELECTOR,
            address(endowmentSafe), // recipient must be the Safe
            uint256(0),
            uint8(0),
            bytes32(0),
            uint256(0),
            new bytes32[](0),
            ""
        )
    );
    vm.stopPrank();

    // FluidMerkle claim with recipient=attacker should be BLOCKED
    vm.startPrank(karpatkey);
    _expectConditionViolation(IZodiacRoles.Status.ParameterNotAllowed);
    roles.execTransactionWithRole(
        FLUID_MERKLE,
        0,
        abi.encodeWithSelector(
            FLUID_CLAIM_SELECTOR,
            address(0xdead), // wrong recipient
            uint256(0),
            uint8(0),
            bytes32(0),
            uint256(0),
            new bytes32[](0),
            ""
        ),
        IZodiacRoles.Operation.Call,
        MANAGER_ROLE,
        false
    );
    vm.stopPrank();
}
```

- [ ] **Step 2: Verify it compiles**

Run: `forge build --match-contract Proposal_ENS_EP_KPK_Update_8_Draft_Test`

- [ ] **Step 3: Commit**

```bash
git add src/ens/proposals/ep-6-38/calldataCheck.t.sol
git commit -m "test(ens): EP 6.38 — add comprehensive before/after permission assertions"
```

---

## Chunk 3: Simple Transaction Builders (TX 1–7, 11, 13–15, 18)

### Task 4: Build the simple transactions and multiSend packing

These 12 transactions are straightforward `abi.encodeWithSelector` calls.

- [ ] **Step 1: Implement _packTx and _buildMultiSendTransactions**

```solidity
function _packTx(address to, bytes memory data) internal pure returns (bytes memory) {
    return abi.encodePacked(uint8(0), to, uint256(0), uint256(data.length), data);
}

function _buildMultiSendTransactions() internal view returns (bytes memory) {
    return bytes.concat(
        _buildRevocationTransactions(),
        _buildAnnotationRemoval(),
        _buildScopingTransactions(),
        _buildAnnotationAddition(),
        _buildFinalUnwrapper()
    );
}
```

- [ ] **Step 2: Implement _buildRevocationTransactions (TX 1–7)**

```solidity
/// @dev TX 1–7: Module removal, unwrapper setup, and revocations
function _buildRevocationTransactions() internal pure returns (bytes memory) {
    return bytes.concat(
        // TX 1: Safe.disableModule — remove Roles V1
        _packTx(
            address(endowmentSafe),
            abi.encodeWithSignature("disableModule(address,address)", PREV_MODULE, ROLES_V1)
        ),
        // TX 2: roles.setTransactionUnwrapper — configure multiSend adapter
        _packTx(
            address(roles),
            abi.encodeWithSelector(
                IRoles.setTransactionUnwrapper.selector,
                MULTISEND_HANDLER,
                MULTISEND_SELECTOR,
                MULTISEND_ADAPTER
            )
        ),
        // TX 3: roles.revokeTarget — RocketPool Deposit V3
        _packTx(
            address(roles),
            abi.encodeWithSelector(IRoles.revokeTarget.selector, MANAGER_ROLE, ROCKET_POOL_DEPOSIT_V3)
        ),
        // TX 4: roles.revokeFunction — RocketPool Deposit V3 deposit()
        _packTx(
            address(roles),
            abi.encodeWithSelector(IRoles.revokeFunction.selector, MANAGER_ROLE, ROCKET_POOL_DEPOSIT_V3, DEPOSIT_SELECTOR)
        ),
        // TX 5: roles.revokeFunction — SPK transfer()
        _packTx(
            address(roles),
            abi.encodeWithSelector(IRoles.revokeFunction.selector, MANAGER_ROLE, SPK, TRANSFER_SELECTOR)
        ),
        // TX 6: roles.revokeTarget — SparkRewards
        _packTx(
            address(roles),
            abi.encodeWithSelector(IRoles.revokeTarget.selector, MANAGER_ROLE, SPARK_REWARDS)
        ),
        // TX 7: roles.revokeFunction — SparkRewards claim()
        _packTx(
            address(roles),
            abi.encodeWithSelector(IRoles.revokeFunction.selector, MANAGER_ROLE, SPARK_REWARDS, SPARK_CLAIM_SELECTOR)
        )
    );
}
```

- [ ] **Step 3: Implement simple scoping transactions (TX 11, 13–15)**

These are part of `_buildScopingTransactions`:

```solidity
// TX 11: roles.scopeTarget — FLUID
_packTx(
    address(roles),
    abi.encodeWithSelector(IRoles.scopeTarget.selector, MANAGER_ROLE, FLUID)
),
// TX 13: roles.scopeTarget — RocketPool Deposit V4
_packTx(
    address(roles),
    abi.encodeWithSelector(IRoles.scopeTarget.selector, MANAGER_ROLE, ROCKET_POOL_DEPOSIT_V4)
),
// TX 14: roles.allowFunction — RocketPool Deposit V4 deposit() with ETH
_packTx(
    address(roles),
    abi.encodeWithSelector(
        IRoles.allowFunction.selector, MANAGER_ROLE, ROCKET_POOL_DEPOSIT_V4, DEPOSIT_SELECTOR, EXEC_SEND
    )
),
// TX 15: roles.scopeTarget — FluidMerkle
_packTx(
    address(roles),
    abi.encodeWithSelector(IRoles.scopeTarget.selector, MANAGER_ROLE, FLUID_MERKLE)
),
```

- [ ] **Step 4: Implement TX 18 (setTransactionUnwrapper — same as TX 2)**

```solidity
function _buildFinalUnwrapper() internal pure returns (bytes memory) {
    // TX 18: roles.setTransactionUnwrapper — re-apply after scoping operations
    return _packTx(
        address(roles),
        abi.encodeWithSelector(
            IRoles.setTransactionUnwrapper.selector,
            MULTISEND_HANDLER,
            MULTISEND_SELECTOR,
            MULTISEND_ADAPTER
        )
    );
}
```

- [ ] **Step 5: Verify it compiles**

Run: `forge build --match-contract Proposal_ENS_EP_KPK_Update_8_Draft_Test`

- [ ] **Step 6: Commit**

```bash
git add src/ens/proposals/ep-6-38/calldataCheck.t.sol
git commit -m "feat(ens): EP 6.38 — build simple transactions manually (TX 1-7, 11, 13-15, 18)"
```

---

## Chunk 4: scopeFunction Condition Builders (TX 9, 10, 12, 16)

### Task 5: Build TX 10 — GHO approve conditions

- [ ] **Step 1: Implement _buildGhoApproveConditions**

```solidity
/// @dev TX 10: GHO approve() — spender must be fGHO OR GPv2VaultRelayer
function _buildGhoApproveConditions() internal pure returns (ConditionFlat[] memory) {
    ConditionFlat[] memory c = new ConditionFlat[](4);
    // [0] Root: Calldata Matches
    c[0] = ConditionFlat(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
    // [1] Param 0 (spender): OR group
    c[1] = ConditionFlat(0, PARAM_TYPE_NONE, OP_OR, "");
    // [2] spender == fGHO
    c[2] = ConditionFlat(1, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(F_GHO));
    // [3] spender == GPv2VaultRelayer
    c[3] = ConditionFlat(1, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(GPV2_VAULT_RELAYER));
    return c;
}
```

Encode into scopeFunction call:

```solidity
// TX 10 in _buildScopingTransactions:
_packTx(
    address(roles),
    abi.encodeWithSelector(
        IRoles.scopeFunction.selector,
        MANAGER_ROLE, GHO, APPROVE_SELECTOR,
        _buildGhoApproveConditions(), EXEC_NONE
    )
),
```

### Task 6: Build TX 12 — FLUID approve conditions

- [ ] **Step 1: Implement _buildFluidApproveConditions**

```solidity
/// @dev TX 12: FLUID approve() — spender must be GPv2VaultRelayer only
function _buildFluidApproveConditions() internal pure returns (ConditionFlat[] memory) {
    ConditionFlat[] memory c = new ConditionFlat[](2);
    // [0] Root: Calldata Matches
    c[0] = ConditionFlat(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
    // [1] Param 0 (spender): must equal GPv2VaultRelayer
    c[1] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(GPV2_VAULT_RELAYER));
    return c;
}
```

### Task 7: Build TX 16 — FluidMerkle claim conditions

- [ ] **Step 1: Implement _buildFluidMerkleClaimConditions**

```solidity
/// @dev TX 16: FluidMerkle claim() — recipient (param 0) must equal the Safe (EqualToAvatar)
function _buildFluidMerkleClaimConditions() internal pure returns (ConditionFlat[] memory) {
    ConditionFlat[] memory c = new ConditionFlat[](2);
    // [0] Root: Calldata Matches
    c[0] = ConditionFlat(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
    // [1] Param 0 (recipient): must equal Avatar (the Safe)
    c[1] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
    return c;
}
```

### Task 8: Build TX 9 — CowSwap signOrder conditions (54 conditions)

This is the largest condition tree. The sell/buy token lists are defined as arrays for reviewability.

- [ ] **Step 1: Implement sell/buy token list helpers**

```solidity
function _cowSwapSellTokens() internal pure returns (address[] memory) {
    address[] memory t = new address[](25);
    t[0]  = GHO;
    t[1]  = SWISE;
    t[2]  = CVX;
    t[3]  = MORPHO;
    t[4]  = LDO;
    t[5]  = DAI;
    t[6]  = FLUID;
    t[7]  = WSTETH;
    t[8]  = LUSD;
    t[9]  = USDC;
    t[10] = USR;
    t[11] = SDAI;
    t[12] = RETH;
    t[13] = STETH;
    t[14] = BAL;
    t[15] = COMP;
    t[16] = WETH;
    t[17] = AURA;
    t[18] = SPK;
    t[19] = RPL;
    t[20] = CRV;
    t[21] = USDT;
    t[22] = USDS;
    t[23] = SUSDE;
    t[24] = SFRXETH;
    return t;
}

function _cowSwapBuyTokens() internal pure returns (address[] memory) {
    address[] memory t = new address[](15);
    t[0]  = GHO;
    t[1]  = DAI;
    t[2]  = WSTETH;
    t[3]  = LUSD;
    t[4]  = USDC;
    t[5]  = USR;
    t[6]  = SDAI;
    t[7]  = RETH;
    t[8]  = STETH;
    t[9]  = WETH;
    t[10] = USDT;
    t[11] = USDS;
    t[12] = SUSDE;
    t[13] = NATIVE_ETH;
    t[14] = SFRXETH;
    return t;
}
```

- [ ] **Step 2: Implement _buildCowSwapSignOrderConditions**

```solidity
/// @dev TX 9: CowSwap signOrder — 54 conditions total
///      Struct: (sellToken, buyToken, receiver, sellAmount, buyAmount, validTo, appData,
///               feeAmount, kind, partiallyFillable, sellTokenBalance, buyTokenBalance)
function _buildCowSwapSignOrderConditions() internal pure returns (ConditionFlat[] memory) {
    address[] memory sellTokens = _cowSwapSellTokens();
    address[] memory buyTokens = _cowSwapBuyTokens();

    // Total: 1 root + 1 tuple + 2 OR groups + 1 avatar + 9 pass + 25 sell + 15 buy = 54
    uint256 numConditions = 4 + 9 + sellTokens.length + buyTokens.length;
    ConditionFlat[] memory c = new ConditionFlat[](numConditions);

    uint256 i = 0;

    // [0] Root: Calldata Matches
    c[i++] = ConditionFlat(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
    // [1] Param 0 (order struct): Tuple Matches
    c[i++] = ConditionFlat(0, PARAM_TYPE_TUPLE, OP_MATCHES, "");
    // [2] sellToken: OR group (children will be sell tokens)
    c[i++] = ConditionFlat(1, PARAM_TYPE_NONE, OP_OR, "");
    // [3] buyToken: OR group (children will be buy tokens)
    c[i++] = ConditionFlat(1, PARAM_TYPE_NONE, OP_OR, "");
    // [4] receiver: must equal Avatar (the Safe)
    c[i++] = ConditionFlat(1, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
    // [5-13] sellAmount, buyAmount, validTo, appData, feeAmount, kind,
    //        partiallyFillable, sellTokenBalance, buyTokenBalance: Pass
    for (uint256 j = 0; j < 9; j++) {
        // parent=1 (the tuple), all unconstrained
        c[i++] = ConditionFlat(1, PARAM_TYPE_STATIC, OP_PASS, "");
    }

    // Omit index 5's paramType: should check if the pass conditions all use paramType=1

    // [14-38] Sell token whitelist (parent=2, the sellToken OR group)
    for (uint256 j = 0; j < sellTokens.length; j++) {
        c[i++] = ConditionFlat(2, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(sellTokens[j]));
    }

    // [39-53] Buy token whitelist (parent=3, the buyToken OR group)
    for (uint256 j = 0; j < buyTokens.length; j++) {
        c[i++] = ConditionFlat(3, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(buyTokens[j]));
    }

    return c;
}
```

- [ ] **Step 3: Assemble _buildScopingTransactions (TX 9–16)**

```solidity
function _buildScopingTransactions() internal view returns (bytes memory) {
    return bytes.concat(
        // TX 9: CowSwap signOrder scoping
        _packTx(
            address(roles),
            abi.encodeWithSelector(
                IRoles.scopeFunction.selector,
                MANAGER_ROLE, COWSWAP_ORDER_SIGNER, SIGN_ORDER_SELECTOR,
                _buildCowSwapSignOrderConditions(), EXEC_DELEGATE_CALL
            )
        ),
        // TX 10: GHO approve scoping
        _packTx(
            address(roles),
            abi.encodeWithSelector(
                IRoles.scopeFunction.selector,
                MANAGER_ROLE, GHO, APPROVE_SELECTOR,
                _buildGhoApproveConditions(), EXEC_NONE
            )
        ),
        // TX 11: scopeTarget FLUID
        _packTx(
            address(roles),
            abi.encodeWithSelector(IRoles.scopeTarget.selector, MANAGER_ROLE, FLUID)
        ),
        // TX 12: FLUID approve scoping
        _packTx(
            address(roles),
            abi.encodeWithSelector(
                IRoles.scopeFunction.selector,
                MANAGER_ROLE, FLUID, APPROVE_SELECTOR,
                _buildFluidApproveConditions(), EXEC_NONE
            )
        ),
        // TX 13: scopeTarget RocketPool Deposit V4
        _packTx(
            address(roles),
            abi.encodeWithSelector(IRoles.scopeTarget.selector, MANAGER_ROLE, ROCKET_POOL_DEPOSIT_V4)
        ),
        // TX 14: allowFunction RocketPool Deposit V4 deposit() with ETH
        _packTx(
            address(roles),
            abi.encodeWithSelector(
                IRoles.allowFunction.selector, MANAGER_ROLE, ROCKET_POOL_DEPOSIT_V4, DEPOSIT_SELECTOR, EXEC_SEND
            )
        ),
        // TX 15: scopeTarget FluidMerkle
        _packTx(
            address(roles),
            abi.encodeWithSelector(IRoles.scopeTarget.selector, MANAGER_ROLE, FLUID_MERKLE)
        ),
        // TX 16: FluidMerkle claim scoping
        _packTx(
            address(roles),
            abi.encodeWithSelector(
                IRoles.scopeFunction.selector,
                MANAGER_ROLE, FLUID_MERKLE, FLUID_CLAIM_SELECTOR,
                _buildFluidMerkleClaimConditions(), EXEC_NONE
            )
        )
    );
}
```

- [ ] **Step 4: Verify it compiles**

Run: `forge build --match-contract Proposal_ENS_EP_KPK_Update_8_Draft_Test`

- [ ] **Step 5: Commit**

```bash
git add src/ens/proposals/ep-6-38/calldataCheck.t.sol
git commit -m "feat(ens): EP 6.38 — build all scopeFunction conditions from structs (TX 9-16)"
```

---

## Chunk 5: Annotation Builders and _generateCallData

### Task 9: Build annotation post() calls (TX 8, 17) and wire _generateCallData

TX 8 and TX 17 call `post(string calldata content, string calldata tag)` on the annotation registry. The content is a JSON string — opaque data that cannot be constructed with ABI encoding. Keep the JSON as a hex-encoded string literal, but build the `post()` call itself manually.

The annotation registry's `post()` function is `post(string,string)` with selector `0x0ae1b13d`. The tag is always `"ROLES_PERMISSION_ANNOTATION"`.

- [ ] **Step 1: Implement annotation helpers**

```solidity
bytes32 private constant ANNOTATION_TAG = "ROLES_PERMISSION_ANNOTATION";

/// @dev TX 8: Remove old annotations (Spark deposit SKY_USDS + old CowSwap swap list)
function _buildAnnotationRemoval() internal pure returns (bytes memory) {
    // JSON payload for removing old annotations — opaque data, verified by reviewing
    // the decoded JSON which contains removeAnnotations URIs for:
    //   - kit.karpatkey.com/.../spark/deposit?targets=SKY_USDS
    //   - kit.karpatkey.com/.../cowswap/swap?sell=<old list without GHO/FLUID>&buy=<old list>
    bytes memory jsonPayload = hex"<the hex-encoded JSON string for TX 8>";
    return _packTx(
        ANNOTATION_REGISTRY,
        abi.encodeWithSignature("post(string,string)", string(jsonPayload), "ROLES_PERMISSION_ANNOTATION")
    );
}

/// @dev TX 17: Add new annotations (updated CowSwap swap list with GHO/FLUID + Spark deposit SKY_sUSDS)
function _buildAnnotationAddition() internal pure returns (bytes memory) {
    bytes memory jsonPayload = hex"<the hex-encoded JSON string for TX 17>";
    return _packTx(
        ANNOTATION_REGISTRY,
        abi.encodeWithSignature("post(string,string)", string(jsonPayload), "ROLES_PERMISSION_ANNOTATION")
    );
}
```

**IMPORTANT**: The JSON hex payloads must be extracted from the original calldata. They are the ONLY hex remaining, and they represent opaque JSON data — not ABI-encoded calldata. Extract these by taking the `post()` calldata, stripping selector + ABI envelope, and getting the raw JSON bytes.

However, there is a subtlety: looking at the original calldata, the annotation calls use `post(bytes calldata, bytes32)` not `post(string, string)`. The selector `0x0ae1b13d` must be verified. The encoding has `bytes32` as the second parameter (the key), not a string. So the actual call is:

```solidity
// post(bytes calldata content, bytes32 key) where key = bytes32("ROLES_PERMISSION_ANNOTATION")
```

The implementer should verify the exact signature by checking the selector `0x0ae1b13d` and matching against the annotation registry ABI.

- [ ] **Step 2: Implement _generateCallData**

```solidity
function _generateCallData()
    public
    override
    returns (
        address[] memory,
        uint256[] memory,
        string[] memory,
        bytes[] memory,
        string memory
    )
{
    targets = new address[](1);
    values = new uint256[](1);
    calldatas = new bytes[](1);
    signatures = new string[](1);

    bytes memory multiSendData = abi.encodeWithSelector(
        IMultiSend.multiSend.selector,
        _buildMultiSendTransactions()
    );

    (targets[0], calldatas[0]) = _buildSafeExecDelegateCalldata(
        address(endowmentSafe),
        MULTISEND,
        multiSendData,
        address(timelock)
    );
    values[0] = 0;
    signatures[0] = "";
    description = getDescriptionFromMarkdown();

    return (targets, values, signatures, calldatas, description);
}
```

- [ ] **Step 3: Run the full test**

Run: `forge test --match-contract Proposal_ENS_EP_KPK_Update_8_Draft_Test -vvv`
Expected: PASS — calldata comparison succeeds, all before/after assertions pass.

If the test FAILS on calldata comparison, that means our independently constructed calldata DIFFERS from the JSON — which is the whole point. Investigate the diff to determine if our construction is wrong or if the proposal calldata is wrong.

- [ ] **Step 4: Commit**

```bash
git add src/ens/proposals/ep-6-38/calldataCheck.t.sol
git commit -m "feat(ens): EP 6.38 — complete calldata review with independent construction and assertions"
```

---

## Notes for the implementer

1. **Token address checksums**: Many token addresses above use mixed-case EIP-55 checksums. Solidity will reject wrong checksums at compile time — this is a feature, not a bug. If a constant doesn't compile, the address is wrong.

2. **`_safeExecuteTransaction` requires `vm.startPrank(karpatkey)`**: The Zodiac Roles module checks `msg.sender` against the role assignment. The `_safeExecuteTransaction` helper does snapshot/revert but doesn't set the caller.

3. **Condition parent indices**: In the CowSwap conditions, the sell token conditions have `parent=2` (the sellToken OR node) and buy token conditions have `parent=3` (the buyToken OR node). The receiver avatar check has `parent=1` (the tuple). Getting these wrong will produce different calldata.

4. **The `ConditionFlat.compValue` for `EqualTo` uses `abi.encode(address)`** which produces a 32-byte left-padded value. This is what Zodiac Roles V2 expects.

5. **Annotation `post()` encoding**: Double-check the function signature. The selector `0x0ae1b13d` corresponds to `post(string,string)` per the Poster contract (EIP-3722). Verify this matches.

6. **If calldata doesn't match**: The test's `callDataComparison()` will show exactly which bytes differ. Use `forge test -vvvv` to see the full trace. Common causes: wrong address checksum, wrong condition parent index, wrong token order in whitelist, wrong paramType/operator enum value.
