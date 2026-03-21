---
name: dao-scaffold
description: Use when adding a new DAO to the repository. Scaffolds all required files — base test class, interfaces directory, proposals directory, and registry entry.
---

# DAO Scaffold

Scaffold the complete directory structure and boilerplate for adding a new DAO to the governance calldata verification system.

## Prerequisites

Before starting, gather:
- DAO name and governance type (OZ Governor+Timelock or Azorius)
- Governor/Azorius contract address
- Timelock/Treasury contract address
- Governance token address
- Chain (mainnet, arbitrum, etc.)
- Tally slug (from URL: `tally.xyz/gov/{slug}`)
- At least one proposer address with enough tokens
- At least 10 voter addresses that together achieve quorum

## Step 1: Create Directory Structure

```bash
mkdir -p src/{dao-name}/interfaces
mkdir -p src/{dao-name}/helpers
mkdir -p src/{dao-name}/proposals
```

## Step 2: Add Remapping

Append to `remappings.txt`:
```
@{dao-name}/=src/{dao-name}/
```

## Step 3: Extract Interfaces

Generate Solidity interfaces from deployed contracts:

```bash
cast interface {GOVERNOR_ADDRESS} --chain {chain} -n IGovernor > src/{dao-name}/interfaces/IGovernor.sol
cast interface {TIMELOCK_ADDRESS} --chain {chain} -n ITimelock > src/{dao-name}/interfaces/ITimelock.sol
cast interface {TOKEN_ADDRESS} --chain {chain} -n IToken > src/{dao-name}/interfaces/IToken.sol
```

Clean up each file:
- Add `// SPDX-License-Identifier: MIT` header
- Set `pragma solidity >=0.8.25 <0.9.0;`
- Keep only the functions needed for governance (propose, vote, queue, execute, state, quorum, etc.)

## Step 4: Write Base Test Class

For **Governor+Timelock DAOs**, use `src/ens/ens.t.sol` as the template.
For **Azorius DAOs**, use `src/shutter/shutter.t.sol` as the template.

Create `src/{dao-name}/{dao-name}.t.sol`. The base class MUST implement:

| Method | Purpose |
|--------|---------|
| `setUp()` | Initialize governance contracts, call `_selectFork()`, set proposer/voters |
| `test_proposal()` | Full governance lifecycle (propose → vote → queue → execute) |
| `_selectFork()` | Virtual with default fork |
| `_proposer()` | Virtual with default proposer |
| `_voters()` | Virtual with default voter set achieving quorum |
| `_beforeProposal()` | Abstract — state assertions before execution |
| `_afterExecution()` | Abstract — state assertions after execution |
| `_generateCallData()` | Abstract — build proposal calldata |
| `_isProposalSubmitted()` | Abstract — live vs draft flag |
| `dirPath()` | Virtual, default empty — for JSON comparison |
| `callDataComparison()` | Use `CalldataComparison` from `@contracts/base/CalldataComparison.sol` |

## Step 5: Add to DAO Registry

Add entry to `src/dao-registry.json` with all required fields (see existing entries for structure).

## Step 6: Verify

```bash
forge build --skip script
```

## Step 7: Validate with First Proposal

Find a recently executed proposal on Tally, fetch its data, write a test, and verify it passes. This proves the infrastructure works end-to-end.

## Step 8: Commit

```bash
git add src/{dao-name}/ remappings.txt src/dao-registry.json
git commit -m "feat({dao-name}): scaffold DAO governance test infrastructure"
```
