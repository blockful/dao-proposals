---
name: live-review
description: Review a live on-chain DAO proposal. Use when a proposal has been submitted to the Governor contract, the user shares a Tally URL containing /proposal/, or when transitioning a draft to live.
argument-hint: <TALLY_URL>
---

# Live Calldata Review

Review a proposal that is **live on-chain** (submitted to the Governor).

**Before proceeding, read the full guide:** `src/ens/CALLDATA_REVIEW_GUIDE.md`

The guide is the source of truth for the review process, assertion baseline, troubleshooting, and key addresses. This skill summarizes the workflow — the guide has the details.

## Critical Objective

- The goal is to catch calldata bugs. A false positive review is the **worst possible outcome**.
- Build `_generateCallData()` from **manual derivation** of proposal intent and interfaces.
- Never copy from `proposalCalldata.json`. It is validation, not source.
- Any mismatch between manually derived and live calldata = **security finding**. Stop approval.

## Workflow

### 1. Create branch

```bash
git checkout -b ens/ep-X-Y
```

If continuing from a draft: `mv src/ens/proposals/ep-topic-name src/ens/proposals/ep-X-Y`

### 2. Fetch live proposal data

```bash
node src/utils/fetchLiveProposal.js $ARGUMENTS src/ens/proposals/ep-X-Y
```

This creates `proposalCalldata.json` (with `blockNumber`) and `proposalDescription.md`.

### 3. Update test file

Update `calldataCheck.t.sol` per the template in `src/ens/CALLDATA_REVIEW_GUIDE.md`:

```solidity
contract Proposal_ENS_EP_X_Y_Test is ENS_Governance {
    function _selectFork() public override {
        // Use blockNumber from proposalCalldata.json
        vm.createSelectFork({ blockNumber: BLOCK_NUMBER, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return PROPOSER_ADDRESS; // On-chain proposer from Tally
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true; // Live proposal
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-X-Y";
    }
}
```

**What changes from draft to live:**

| Field | Draft | Live |
|-------|-------|------|
| `_isProposalSubmitted()` | `false` | `true` |
| `_selectFork()` | Recent block | `blockNumber` from JSON |
| `_proposer()` | Draft proposer | On-chain proposer |
| Contract name | `_Draft_Test` | `_Test` |

### 4. Run test

```bash
forge test --match-path "src/ens/proposals/ep-X-Y/*" -vv
```

### 5. Commit and PR

```bash
git add src/ens/proposals/ep-X-Y/
git commit -m "test(ens): EP X.Y — update to live proposal"
git push origin ens/ep-X-Y
```

### 6. Forum post

Use the template from `src/ens/CALLDATA_REVIEW_GUIDE.md` section 6.

## Assertion Baseline

See `src/ens/CALLDATA_REVIEW_GUIDE.md` — "Minimum Assertion Baseline" section. Both `_beforeProposal()` and `_afterExecution()` must have substantive checks. Empty hooks are never acceptable.

## Troubleshooting

See `src/ens/CALLDATA_REVIEW_GUIDE.md` — "Troubleshooting" section for:
- Description mismatch ("Governor: unknown proposal id")
- Calldata mismatch
- Stack too deep
- Fork block issues

## For Non-ENS DAOs

For Uniswap: use `src/uniswap/uniswap.t.sol` as the base class and `src/uniswap/proposals/` as the proposals directory. The fetch script auto-detects the DAO from the Tally URL.

Consult `src/dao-registry.json` for DAO-specific configuration.
