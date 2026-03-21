---
name: review-reference
description: Use when working on any DAO proposal review and needing key addresses, helpers, common selectors, or troubleshooting guidance
---

# Review Reference

Shared reference for all DAO proposal calldata reviews.

## Critical Objective

- Detect calldata mistakes before submission or approval. False positives are unacceptable.
- Build `_generateCallData()` from manual derivation of proposal intent, not by copying from JSON/on-chain data.
- No opaque hex blobs. Derive with semantics: `namehash`, `labelhash`, `.selector`, typed args, contract interfaces.
- `callDataComparison()` is validation, not source of truth.
- If manually derived calldata differs from `proposalCalldata.json`, treat as security finding. Do not publish approval text.

## DAO-Specific References

All key addresses, contract references, and constants are maintained per-DAO. To find them:

1. Look up the DAO in `src/dao-registry.json` to find its registry entry.
2. The entry provides:
   - `contracts` -- governor, timelock, token, and other core addresses
   - `constantsFile` -- path to the DAO's `Constants.sol` (if it exists) for additional addresses and values
   - `basePath` -- root directory for all DAO-specific files
   - `interfacesPath` -- shared interfaces for the DAO
   - `helpers` -- list of available helper contracts

For example, ENS addresses are in `src/dao-registry.json` under `daos.ens.contracts` and in `src/ens/Constants.sol`.

## Inherited State from Base Test Contract

Each DAO's base test class (specified by `baseTestContract` in the registry) provides these -- do NOT redeclare:

| Variable | Type | Notes |
|----------|------|-------|
| `token` / DAO-specific token var | `IERC20` / DAO-specific | Governance token |
| `governor` | `IGovernor` | DAO Governor |
| `timelock` | `ITimelock` | Use `address(timelock)` instead of hardcoding |
| `proposer` | `address` | Set by `_proposer()` |
| `voters` | `address[]` | Default voter set with quorum |
| `targets`, `values`, `signatures`, `calldatas`, `description` | -- | Proposal parameters |

Refer to the DAO's `{baseTestFile}` (from the registry) for the exact variable names and types.

## Helpers

Check the DAO's `helpers/` directory (under `{basePath}/helpers/`) for available helper contracts. The registry's `helpers` array lists them by name.

Common patterns across DAOs:

| Helper Pattern | Provides |
|----------------|----------|
| `SafeHelper` | Safe multisig interaction: `_buildSafeExecCalldata()`, `_buildSafeExecDelegateCalldata()` |
| `ZodiacRolesHelper` | Zodiac Roles scoping: `_safeExecuteTransaction()`, `_expectConditionViolation()`, `_packTx()`, condition constants |
| `MultiSendHelper` | MultiSend transaction packing |

### When to use which helper

- **Proposal calls a Safe** (execTransaction): look for a `SafeHelper`
- **Proposal modifies Zodiac Roles permissions**: look for a `ZodiacRolesHelper`
- **Proposal does both**: inherit both
- **Simple governance proposal** (token transfers, registry ops): no helpers needed

### Shared Interfaces

Use imports from `{interfacesPath}/` (from the registry) instead of defining locally. Each DAO maintains its own set of interfaces relevant to its ecosystem.

### Selectors

Always derive from interfaces: `IERC20.transfer.selector`, `IWETH.deposit.selector`, etc. Never hardcode hex bytes4 values.

## Troubleshooting

### Calldata mismatch
Treat as critical finding. Check: decimal places (USDC=6, ETH/tokens=18), address checksums, parameter order, re-fetch from Tally if draft was updated.

### Description mismatch ("Governor: unknown proposal id")
Extract exact on-chain description from `ProposalCreated` event:
```bash
cast logs --from-block BLOCK --to-block BLOCK \
  --address GOVERNOR_ADDRESS \
  "ProposalCreated(uint256,address,address[],uint256[],string[],bytes[],uint256,uint256,string)" \
  --rpc-url {chain}
```

Use the governor address from `src/dao-registry.json` for the DAO in question.

### Stack Too Deep
```bash
forge test --match-contract ContractName --skip FileName -vvv
```
