# Adding a New DAO to the Repository

This guide walks through adding a new DAO to the governance calldata verification system. By the end, you'll have a
working test infrastructure that can verify any proposal for this DAO.

## Quick Start (AI Agent)

If you're an AI agent, use the `dao-scaffold` skill — it will interactively guide you through the process.

## Manual Process

### 1. Gather Information

Before starting, collect:

| Info                      | Example (ENS)     | Where to Find                           |
| ------------------------- | ----------------- | --------------------------------------- |
| DAO name                  | ENS               | Tally governance page                   |
| Governance type           | Governor+Timelock | Check contracts on Etherscan            |
| Governor address          | `0x323A76...`     | Tally or Etherscan                      |
| Timelock/Treasury address | `0xFe89cc...`     | Governor contract's `timelock()` method |
| Token address             | `0xC18360...`     | Governor contract's `token()` method    |
| Chain                     | mainnet           | Tally                                   |
| Tally slug                | `ens`             | URL: `tally.xyz/gov/{slug}`             |
| Proposer address          | `0x5BFCB4...`     | Any delegate with enough tokens         |
| Voter addresses (10+)     | See ens.t.sol     | Top delegates on Tally                  |

### 2. Create Directory Structure

```bash
mkdir -p src/{dao-name}/interfaces
mkdir -p src/{dao-name}/helpers
mkdir -p src/{dao-name}/proposals
```

### 3. Add Remapping

In `remappings.txt`, add:

```
@{dao-name}/=src/{dao-name}/
```

### 4. Extract Interfaces

Use `cast interface` to generate Solidity interfaces from deployed contracts:

```bash
cast interface {GOVERNOR_ADDRESS} --chain mainnet -n IGovernor > src/{dao-name}/interfaces/IGovernor.sol
cast interface {TIMELOCK_ADDRESS} --chain mainnet -n ITimelock > src/{dao-name}/interfaces/ITimelock.sol
cast interface {TOKEN_ADDRESS} --chain mainnet -n IToken > src/{dao-name}/interfaces/IToken.sol
```

Clean up each generated file:

- Add `// SPDX-License-Identifier: MIT` header
- Set `pragma solidity >=0.8.25 <0.9.0;`
- Keep only the functions needed for governance testing
- Add NatDoc comments for clarity

### 5. Write Base Test Class

Copy the closest existing base class as a starting point:

- For **OZ Governor+Timelock** DAOs: copy `src/ens/ens.t.sol`
- For **Azorius** DAOs: copy `src/shutter/shutter.t.sol`

Create `src/{dao-name}/{dao-name}.t.sol` and adapt:

- Replace governance contract addresses
- Replace token interface methods (e.g., `getVotes` vs `getCurrentVotes` vs `delegate`)
- Replace governance parameters (voting delay, voting period, quorum)
- Replace default voter/proposer addresses
- Import `CalldataComparison` from `@contracts/base/CalldataComparison.sol` for JSON comparison

### 6. Add to DAO Registry

Add a new key under the `daos` object in `src/dao-registry.json`. The key should be the lowercase DAO identifier. Use
existing entries as a template. All fields are required:

```json
{
  "daos": {
    "mydao": {
      "name": "MyDAO",
      "governanceType": "governor-timelock",
      "chain": "mainnet",
      "basePath": "src/mydao",
      "baseTestContract": "MyDAO_Governance",
      "baseTestFile": "src/mydao/mydao.t.sol",
      "contracts": {
        "governor": "0x...",
        "timelock": "0x...",
        "token": "0x..."
      },
      "tallySlug": "mydao",
      "proposalPrefix": "proposal",
      "contractNaming": "Proposal_MyDAO_{number}_Test",
      "helpers": [],
      "interfacesPath": "src/mydao/interfaces",
      "proposalsPath": "src/mydao/proposals",
      "constantsFile": null
    }
  }
}
```

### 7. Write First Proposal Test

Use an existing live proposal to validate the infrastructure works end-to-end:

1. Find a recently executed proposal on Tally
2. Fetch its data: `node src/utils/fetchLiveProposal.js {URL} src/{dao-name}/proposals/{id}`
3. Write a `calldataCheck.t.sol` that reconstructs the calldata from interfaces
4. Run: `forge test --match-path "src/{dao-name}/proposals/{id}/*" -vv`

If the test passes, the infrastructure is working correctly.

### 8. Verify Everything

```bash
# Build entire project
forge build --skip script

# Run new DAO tests
forge test --match-path "src/{dao-name}/**" -vv

# Run existing tests (check for regressions)
forge test --match-path "src/ens/**" -vv
```

### 9. Commit and PR

```bash
git checkout -b feat/{dao-name}-scaffold
git add src/{dao-name}/ remappings.txt src/dao-registry.json
git commit -m "feat({dao-name}): scaffold DAO governance test infrastructure"
git push origin feat/{dao-name}-scaffold
```

Open a PR targeting `main` with:

- Summary of the DAO and its governance type
- Link to the first proposal test
- Build and test verification

## Governance Type Reference

| Type                    | Propose                                                                 | Vote                                     | Queue                        | Execute                        | Example      |
| ----------------------- | ----------------------------------------------------------------------- | ---------------------------------------- | ---------------------------- | ------------------------------ | ------------ |
| OZ Governor + Timelock  | `governor.propose(targets, values, calldatas, description)`             | `governor.castVote(proposalId, support)` | `governor.queue(...)`        | `governor.execute(...)`        | ENS, Uniswap |
| Azorius + LinearERC20   | `azorius.submitProposal(strategy, data, transactions, metadata)`        | `voting.vote(proposalId, support)`       | N/A                          | `azorius.executeProposal(...)` | Shutter      |
| Compound Governor Alpha | `governor.propose(targets, values, signatures, calldatas, description)` | `governor.castVote(proposalId, support)` | `governor.queue(proposalId)` | `governor.execute(proposalId)` | (future)     |

## Key Differences to Watch

| Aspect       | OZ Governor                                           | Azorius                    | Compound Alpha                        |
| ------------ | ----------------------------------------------------- | -------------------------- | ------------------------------------- |
| Quorum check | `governor.quorum(blockNumber)`                        | `voting.quorumNumerator()` | `governor.quorumVotes()`              |
| Voting power | `token.getVotes(account)`                             | `IVotes.delegate()` first  | `token.getPriorVotes(account, block)` |
| Queue target | Timelock                                              | N/A (direct execution)     | Timelock                              |
| Execute by   | Anyone                                                | Anyone                     | Anyone                                |
| Proposal ID  | Hash of (targets, values, calldatas, descriptionHash) | Sequential counter         | Sequential counter                    |

## Checklist

- [ ] Directory structure created (`interfaces/`, `helpers/`, `proposals/`)
- [ ] Remapping added to `remappings.txt`
- [ ] Interfaces extracted and cleaned (SPDX, pragma, minimal)
- [ ] Base test class written and inherits CalldataComparison
- [ ] DAO registry entry added to `src/dao-registry.json`
- [ ] First proposal test passes end-to-end
- [ ] `forge build --skip script` succeeds
- [ ] No regressions in existing DAO tests
- [ ] PR opened and merged
