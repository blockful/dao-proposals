---
name: pre-draft-review
description: Use when a DAO proposal is being discussed or designed but has no Tally draft yet, when the user wants to test a proposal idea, deploy custom contracts, or build calldata before it goes to Tally
---

# Pre-Draft Proposal Review

Review a proposal that is being **discussed or designed** -- no Tally draft exists yet.

**REQUIRED REFERENCE:** Use `review-reference` for key addresses, helpers, and troubleshooting.

## DAO Detection

1. If the user provides a Tally URL, extract the slug (e.g., `tally.xyz/gov/{slug}/...`).
2. Otherwise, ask the user which DAO this review is for.
3. Look up the DAO in `src/dao-registry.json` under `daos[key]`.
4. Use the matched entry to resolve all parameterized values below:
   - `{dao}` -- the registry key (e.g., `ens`, `uniswap`)
   - `{name}` -- human-readable DAO name (e.g., `ENS`, `Uniswap`)
   - `{basePath}` -- e.g., `src/ens`
   - `{proposalsPath}` -- e.g., `src/ens/proposals`
   - `{baseTestContract}` -- e.g., `ENS_Governance`
   - `{baseTestFile}` -- e.g., `src/ens/ens.t.sol`
   - `{chain}` -- e.g., `mainnet`
   - `{proposalPrefix}` -- e.g., `ep`

## Workflow

### 1. Create branch and directory

```bash
git checkout -b {dao}/{proposalPrefix}-topic-name
mkdir -p {proposalsPath}/{proposalPrefix}-topic-name
```

Use a descriptive name (e.g., `{dao}/{proposalPrefix}-registrar-manager-endowment`).

### 2. (Optional) Add custom contracts

If the proposal deploys new contracts:
```
{proposalsPath}/{proposalPrefix}-topic-name/
  contracts/
    MyContract.sol
    MyContract.t.sol    # Unit tests for the contract
  calldataCheck.t.sol   # Proposal governance test
```

### 3. Write test file

Create `calldataCheck.t.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { {baseTestContract} } from "{baseTestFile import}";
// Import helpers based on proposal type (see review-reference)
// Import shared interfaces from {basePath}/interfaces/

contract Proposal_{NAME}_{PREFIX}_Topic_Name_Test is {baseTestContract} {

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: RECENT_BLOCK, urlOrAlias: "{chain}" });
    }

    function _proposer() public pure override returns (address) {
        return DEFAULT_PROPOSER; // See DAO's Constants.sol or registry
    }

    function _beforeProposal() public override {
        // Assert pre-execution state
    }

    function _generateCallData()
        public override
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory, string memory)
    {
        uint256 numTransactions = N;
        targets = new address[](numTransactions);
        values = new uint256[](numTransactions);
        calldatas = new bytes[](numTransactions);
        signatures = new string[](numTransactions);

        // Build transactions manually from interfaces -- NO hex blobs
        targets[0] = TARGET_ADDRESS;
        calldatas[0] = abi.encodeWithSelector(...);

        description = "Pre-draft: proposal description TBD";
        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        // Assert expected state changes
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return false;
    }

    function dirPath() public pure override returns (string memory) {
        return ""; // No JSON/md files yet -- skip calldata comparison
    }
}
```

**Key points:**
- `_isProposalSubmitted()` returns `false` -- test submits via `governor.propose()`
- `dirPath()` returns `""` -- no `proposalCalldata.json` exists, calldata comparison skipped
- `description` is a placeholder
- Use `setUp()` override with `super.setUp()` to deploy custom contracts
- All selectors derived from interfaces (`.selector`), never hardcoded hex

### 4. Run test

```bash
forge test --match-contract Proposal_{NAME}_{PREFIX}_Topic_Name_Test -vvv
```

### 5. Commit

```bash
git add {proposalsPath}/{proposalPrefix}-topic-name/
git commit -m "chore({dao}): add pre-draft calldata review for {PREFIX} topic-name"
git push origin {dao}/{proposalPrefix}-topic-name
```

## Transitioning to Draft

When the proposal is created on Tally, use the `draft-review` skill. Changes needed:

| Field | Pre-draft | Draft |
|-------|-----------|-------|
| `description` | Hardcoded placeholder | `getDescriptionFromMarkdown()` |
| `dirPath()` | `""` | `"{proposalsPath}/{proposalPrefix}-topic-name"` |
| `_proposer()` | Default | From Tally draft |
| New files | None | `proposalCalldata.json`, `proposalDescription.md` (fetched) |
