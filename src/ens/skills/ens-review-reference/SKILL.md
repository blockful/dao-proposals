---
name: ens-review-reference
description: Use when working on any ENS DAO proposal review and needing key addresses, helpers, common selectors, or troubleshooting guidance
---

# ENS Review Reference

Shared reference for all ENS proposal calldata reviews.

## Critical Objective

- Detect calldata mistakes before submission or approval. False positives are unacceptable.
- Build `_generateCallData()` from manual derivation of proposal intent, not by copying from JSON/on-chain data.
- No opaque hex blobs. Derive with semantics: `namehash`, `labelhash`, `.selector`, typed args, contract interfaces.
- `callDataComparison()` is validation, not source of truth.
- If manually derived calldata differs from `proposalCalldata.json`, treat as security finding. Do not publish approval text.

## Key Addresses

| Contract | Address |
|----------|---------|
| ENS Token | `0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72` |
| ENS Governor | `0x323A76393544d5ecca80cd6ef2A560C6a395b7E3` |
| ENS Timelock (wallet.ensdao.eth) | `0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7` |
| ENS Endowment Safe | `0x4F2083f5fBede34C2714aFfb3105539775f7FE64` |
| ENS Root | `0xaB528d626EC275E3faD363fF1393A41F581c5897` |
| ENS Registry | `0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e` |
| Zodiac Roles V2 | `0x703806E61847984346d2D7DDd853049627e50A40` |
| USDC | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` |

## Inherited State from ENS_Governance

These are provided by `src/ens/ens.t.sol` -- do NOT redeclare:

| Variable | Type | Notes |
|----------|------|-------|
| `ensToken` | `IENSToken` | ENS governance token |
| `governor` | `IGovernor` | ENS Governor |
| `timelock` | `ITimelock` | Use `address(timelock)` instead of hardcoding |
| `proposer` | `address` | Set by `_proposer()` |
| `voters` | `address[]` | Default voter set with quorum |
| `targets`, `values`, `signatures`, `calldatas`, `description` | -- | Proposal parameters |

## Helpers

| Helper | Import | Provides |
|--------|--------|----------|
| `SafeHelper` | `@ens/helpers/SafeHelper.sol` | `endowmentSafe`, `_buildSafeExecCalldata()`, `_buildSafeExecDelegateCalldata()` |
| `ZodiacRolesHelper` | `@ens/helpers/ZodiacRolesHelper.sol` | `roles`, `karpatkey`, `MANAGER_ROLE`, `_safeExecuteTransaction()`, `_expectConditionViolation()`, `_packTx()`, condition constants |

### When to use which helper

- **Proposal calls the Endowment Safe** (execTransaction): inherit `SafeHelper`
- **Proposal modifies Zodiac Roles permissions**: inherit `ZodiacRolesHelper`
- **Proposal does both**: inherit both
- **Simple governance proposal** (token transfers, ENS registry ops): no helpers needed

### Shared Interfaces

Use imports from `@ens/interfaces/` instead of defining locally:

| Interface | File | Use |
|-----------|------|-----|
| `IRolesModifier` + `ConditionFlat` | `IRolesModifier.sol` | Zodiac Roles scoping/revocation |
| `IMultiSend` | `IMultiSend.sol` | MultiSend packing |
| `ICowSwapOrderSigner` | `ICowSwapOrderSigner.sol` | CowSwap signOrder conditions |
| `ISparkRewards` | `ISparkRewards.sol` | SparkRewards claim |
| `IAnnotationRegistry` | `IAnnotationRegistry.sol` | Annotation registry post |
| `IFluidMerkleDistributor` | `IFluidMerkleDistributor.sol` | Fluid Merkle claim |
| `IWETH` | `IWETH.sol` | WETH deposit/withdraw |

### Selectors

Always derive from interfaces: `IERC20.transfer.selector`, `IWETH.deposit.selector`, etc. Never hardcode hex bytes4 values.

## Troubleshooting

### Calldata mismatch
Treat as critical finding. Check: decimal places (USDC=6, ETH/ENS=18), address checksums, parameter order, re-fetch from Tally if draft was updated.

### Description mismatch ("Governor: unknown proposal id")
Extract exact on-chain description from `ProposalCreated` event:
```bash
cast logs --from-block BLOCK --to-block BLOCK \
  --address 0x323A76393544d5ecca80cd6ef2A560C6a395b7E3 \
  "ProposalCreated(uint256,address,address[],uint256[],string[],bytes[],uint256,uint256,string)" \
  --rpc-url mainnet
```

### Stack Too Deep
```bash
forge test --match-contract ContractName --skip FileName -vvv
```
