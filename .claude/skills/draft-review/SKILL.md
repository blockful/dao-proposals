---
name: draft-review
description: Review an ENS DAO proposal that exists as a Tally draft (URL contains /draft/). Use when fetching draft data, writing calldata review tests, or when the user shares a Tally draft URL.
argument-hint: <TALLY_DRAFT_URL>
---

# Draft Calldata Review

Review a proposal that exists as a **Tally draft** (URL contains `/draft/`).

**Before proceeding, read the full guide:** `src/ens/DRAFT_CALLDATA_REVIEW_GUIDE.md`

The guide is the source of truth for the review process, assertion baseline, inherited state, and troubleshooting. This skill summarizes the workflow.

## Critical Objective

- Detect calldata mistakes **before live submission**. A false positive is unacceptable.
- Build `_generateCallData()` from **manual derivation** of proposal intent, not by copying from `proposalCalldata.json`.
- `callDataComparison()` is validation, not source of truth.
- If manually derived calldata differs from JSON, treat as a security finding. Stop approval.

## Workflow

### 1. Create branch

```bash
git checkout -b ens/ep-topic-name
```

### 2. Fetch draft data

```bash
node src/utils/fetchTallyDraft.js $ARGUMENTS src/ens/proposals/ep-topic-name
```

This creates `proposalCalldata.json` and `proposalDescription.md`.

### 3. Write or update test file

Create `calldataCheck.t.sol` per the template in `src/ens/DRAFT_CALLDATA_REVIEW_GUIDE.md`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { ENS_Governance } from "@ens/ens.t.sol";
// Import relevant interfaces from @ens/interfaces/

contract Proposal_ENS_EP_Topic_Name_Draft_Test is ENS_Governance {

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: RECENT_BLOCK, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return PROPOSER_ADDRESS; // From Tally draft
    }

    function _beforeProposal() public override {
        // Capture state before execution — see assertion baseline in guide
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
        // Must match proposalCalldata.json — any mismatch is a finding.
        targets[0] = TARGET_ADDRESS;
        calldatas[0] = abi.encodeWithSelector(IContract.method.selector, args);
        values[0] = 0;
        signatures[0] = "";

        description = getDescriptionFromMarkdown();
        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        // Assert expected state changes — see assertion baseline in guide
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return false; // Draft — not yet on-chain
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-topic-name";
    }
}
```

**Inherited state from `ENS_Governance`** (do NOT redeclare):
`ensToken`, `governor`, `timelock`, `proposer`, `voters`, `targets`, `values`, `signatures`, `calldatas`, `description`

See `src/ens/DRAFT_CALLDATA_REVIEW_GUIDE.md` section 3 for the full table.

### 4. Run test

```bash
forge test --match-path "src/ens/proposals/ep-topic-name/*" -vv
```

### 5. Commit and PR

```bash
git add src/ens/proposals/ep-topic-name/
git commit -m "chore(ens): add draft calldata review for EP X.Y — topic-name"
git push origin ens/ep-topic-name
```

### 6. Forum post

Use the template from `src/ens/DRAFT_CALLDATA_REVIEW_GUIDE.md` section 6.

## Transitioning to Live

When the proposal is submitted on-chain, use the `/live-review` skill. See `src/ens/DRAFT_CALLDATA_REVIEW_GUIDE.md` section 7 for what changes.

## Helpers

| Helper | Import | When to Use |
|--------|--------|-------------|
| `SafeHelper` | `@ens/helpers/SafeHelper.sol` | Proposal calls the Endowment Safe |
| `ZodiacRolesHelper` | `@ens/helpers/ZodiacRolesHelper.sol` | Proposal modifies Zodiac Roles permissions |
| `MultiSendHelper` | `@ens/helpers/MultiSendHelper.sol` | Proposal batches multiple Safe transactions |

## Assertion Baseline

See `src/ens/DRAFT_CALLDATA_REVIEW_GUIDE.md` — "Minimum Assertion Baseline" section.
