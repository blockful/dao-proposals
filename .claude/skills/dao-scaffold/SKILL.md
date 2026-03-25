---
name: dao-scaffold
description: Scaffold a new DAO into the governance calldata verification system. Creates directory structure, interfaces, base test class, and registry entry. Use when adding support for a new DAO.
disable-model-invocation: true
argument-hint: <dao-name>
---

# DAO Scaffold

Scaffold the complete directory structure and boilerplate for adding a new DAO.

**Full guide:** `docs/ADDING_A_NEW_DAO.md`

## Prerequisites

Before starting, gather:
- DAO name and governance type (OZ Governor+Timelock or Azorius)
- Governor/Azorius contract address
- Timelock/Treasury contract address
- Governance token address
- Chain (mainnet, arbitrum, etc.)
- Tally slug (from URL: `tally.xyz/gov/{slug}`)
- Proposer address with enough tokens
- 10+ voter addresses that together achieve quorum

## Steps

### 1. Create directory structure

```bash
mkdir -p src/$ARGUMENTS/interfaces src/$ARGUMENTS/helpers src/$ARGUMENTS/proposals
```

### 2. Add remapping

Append to `remappings.txt`:
```
@$ARGUMENTS/=src/$ARGUMENTS/
```

### 3. Extract interfaces

```bash
cast interface GOVERNOR_ADDRESS --chain mainnet -n IGovernor > src/$ARGUMENTS/interfaces/IGovernor.sol
cast interface TIMELOCK_ADDRESS --chain mainnet -n ITimelock > src/$ARGUMENTS/interfaces/ITimelock.sol
cast interface TOKEN_ADDRESS --chain mainnet -n IToken > src/$ARGUMENTS/interfaces/IToken.sol
```

Clean up: add SPDX header, set `pragma solidity >=0.8.25 <0.9.0;`, keep only needed functions.

### 4. Write base test class

For **Governor+Timelock DAOs**: use `src/ens/ens.t.sol` as the template.
For **Azorius DAOs**: use `src/shutter/shutter.t.sol` as the template.

Create `src/$ARGUMENTS/$ARGUMENTS.t.sol` inheriting `CalldataComparison` from `@contracts/base/CalldataComparison.sol`.

### 5. Add to DAO registry

Add a new key under `daos` in `src/dao-registry.json`. See `docs/ADDING_A_NEW_DAO.md` for the full schema.

### 6. Verify

```bash
forge build --skip script
```

### 7. Validate with first proposal

Find a recently executed proposal on Tally, fetch its data, write a test, verify it passes.

### 8. Commit

```bash
git add src/$ARGUMENTS/ remappings.txt src/dao-registry.json
git commit -m "feat($ARGUMENTS): scaffold DAO governance test infrastructure"
```
