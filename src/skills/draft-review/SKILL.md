---
name: draft-review
description: Use when reviewing a DAO proposal that exists as a Tally draft (URL contains /draft/), when fetching draft data, writing or updating calldata review tests, or when the user shares a Tally draft URL
---

# Draft Calldata Review

Review a proposal that exists as a **Tally draft** (URL contains `/draft/`).

**REQUIRED REFERENCE:** Use `review-reference` for key addresses, helpers, and troubleshooting.

## DAO Detection

1. Extract the Tally slug from the URL (e.g., `tally.xyz/gov/{slug}/draft/...`).
2. Look up the slug in `src/dao-registry.json` under `daos[slug].tallySlug`.
3. Use the matched entry to resolve all parameterized values below:
   - `{dao}` -- the registry key (e.g., `ens`, `uniswap`)
   - `{name}` -- human-readable DAO name (e.g., `ENS`, `Uniswap`)
   - `{basePath}` -- e.g., `src/ens`
   - `{proposalsPath}` -- e.g., `src/ens/proposals`
   - `{baseTestContract}` -- e.g., `ENS_Governance`
   - `{baseTestFile}` -- e.g., `src/ens/ens.t.sol`
   - `{chain}` -- e.g., `mainnet`
   - `{proposalPrefix}` -- e.g., `ep`

If no Tally URL is provided, ask the user which DAO this review is for.

## Workflow

### 1. Create branch (if new)

```bash
git checkout -b {dao}/{proposalPrefix}-topic-name
```

If continuing from a pre-draft, use the existing branch.

### 2. Fetch draft data

```bash
node src/utils/fetchTallyDraft.js <DRAFT_URL_OR_ID> <OUTPUT_DIR>
```

Example:
```bash
node src/utils/fetchTallyDraft.js https://www.tally.xyz/gov/{dao}/draft/2786603872288769996 {proposalsPath}/{proposalPrefix}-topic-name
```

This creates:
- `proposalCalldata.json` -- executable calls from the draft
- `proposalDescription.md` -- proposal description

### 3. Write or update test file

Create `calldataCheck.t.sol` (or update from pre-draft phase).

```solidity
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { {baseTestContract} } from "{baseTestFile import}";
// Import helpers based on proposal type (see review-reference)
// Import shared interfaces from {basePath}/interfaces/

contract Proposal_{NAME}_{PREFIX}_Topic_Name_Draft_Test is {baseTestContract} {

    function _selectFork() public override {
        vm.createSelectFork({ urlOrAlias: "{chain}" });
    }

    function _proposer() public pure override returns (address) {
        return PROPOSER_ADDRESS; // From Tally draft
    }

    function _beforeProposal() public override {
        // Assert pre-execution state
        // For revocations: prove permissions currently WORK
        // For additions: prove permissions DON'T work yet
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

        // Reconstruct calldata MANUALLY from spec + interfaces.
        // Must match proposalCalldata.json -- any mismatch is a finding.
        targets[0] = TARGET_ADDRESS;
        calldatas[0] = abi.encodeWithSelector(...);

        description = getDescriptionFromMarkdown();
        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        // Assert expected state changes
        // For revocations: prove permissions NO LONGER work
        // For additions: prove permissions NOW work
        // Include negative tests (unauthorized calls blocked)
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return false; // Draft -- not yet on-chain
    }

    function dirPath() public pure override returns (string memory) {
        return "{proposalsPath}/{proposalPrefix}-topic-name";
    }
}
```

### What the test does

1. Simulates full governance lifecycle (propose -> vote -> queue -> execute)
2. Runs `_beforeProposal()` and `_afterExecution()` assertions
3. Runs `callDataComparison()` -- compares manually generated calldata against `proposalCalldata.json`

**If step 3 fails, this is a security finding. Do not publish approval text.**

### What changes from pre-draft

| Field | Pre-draft | Draft |
|-------|-----------|-------|
| `description` | Hardcoded placeholder | `getDescriptionFromMarkdown()` |
| `dirPath()` | `""` | `"{proposalsPath}/{proposalPrefix}-topic-name"` |
| `_proposer()` | Default | From Tally draft |

### 4. Run test

```bash
forge test --match-path "{proposalsPath}/{proposalPrefix}-topic-name/*" -vv
```

### 5. Commit, push, and open PR

```bash
git add {proposalsPath}/{proposalPrefix}-topic-name/
git commit -m "chore({dao}): add draft calldata review for {PREFIX} X.Y -- topic-name"
git push origin {dao}/{proposalPrefix}-topic-name
```

Open PR targeting `main`. Merge after review.

### 6. Post to forum

```markdown
## Draft proposal calldata security review

The calldata draft executes successfully and achieves the expected outcome of the proposal. All simulations and tests are available [here](https://github.com/blockful/dao-proposals/blob/COMMIT_HASH/{proposalsPath}/{proposalPrefix}-topic-name/calldataCheck.t.sol).

To verify locally:
1. Clone: `git clone https://github.com/blockful/dao-proposals.git`
2. Checkout: `git checkout SHORT_HASH`
3. Run: `forge test --match-path "{proposalsPath}/{proposalPrefix}-topic-name/*" -vv`
```

Replace `COMMIT_HASH` with the full merge commit hash, `SHORT_HASH` with first 7 chars.

## Transitioning to Live

When the proposal is submitted on-chain, use the `live-review` skill. Changes needed:

| Field | Draft | Live |
|-------|-------|------|
| `_isProposalSubmitted()` | `false` | `true` |
| `_selectFork()` | Latest block | Proposal creation block (from JSON `blockNumber`) |
| `_proposer()` | Draft proposer | On-chain proposer |
| Contract name | `_Draft_Test` | `_Test` |
| Data fetch | `fetchTallyDraft.js` | `fetchLiveProposal.js` |
| Directory | May rename to `{proposalPrefix}-X-Y` | Final name |
