---
name: proposal-review
description: Review a DAO governance proposal end-to-end. Use when the user shares a Tally URL (live or draft), asks to review a proposal, or wants to verify calldata. Accepts a Tally URL as argument.
argument-hint: <TALLY_URL>
---

# Proposal Review

Autonomous end-to-end review of a DAO governance proposal. Detects the DAO and phase from the URL, then runs the full workflow.

## Input

Tally URL or context: $ARGUMENTS

## Step 1: Detect DAO and Phase

Parse the URL to determine the DAO and proposal phase:

- `/gov/{slug}/proposal/{id}` → **Live** proposal
- `/gov/{slug}/draft/{id}` → **Draft** proposal
- No URL → **Pre-draft** — ask the user which DAO

Look up the DAO slug in `src/dao-registry.json` under `daos.{slug}.tallySlug` to load the DAO config (base path, governor address, test contract, etc.).

**Currently supported:** ENS (`ens`), Uniswap (`uniswap`). Shutter has no Tally integration.

## Step 2: Route to the Correct Workflow

Based on the detected phase, follow the corresponding DAO-specific review guide:

| Phase | ENS Guide | What to Do |
|-------|-----------|------------|
| **Live** | `src/ens/CALLDATA_REVIEW_GUIDE.md` | Fetch live data → update test → verify calldata matches |
| **Draft** | `src/ens/DRAFT_CALLDATA_REVIEW_GUIDE.md` | Fetch draft data → write/update test → verify calldata matches |
| **Pre-draft** | `src/ens/PRE_DRAFT_GUIDE.md` | Create test from proposal spec → verify execution |

**Read the full guide before proceeding.** The guides contain critical information about manual derivation requirements, assertion baselines, and anti-patterns.

## Step 3: Execute the Workflow

### For Live proposals:
```bash
# Fetch data (script auto-detects DAO from URL)
node src/utils/fetchLiveProposal.js $ARGUMENTS src/ens/proposals/ep-X-Y

# Run test
forge test --match-path "src/ens/proposals/ep-X-Y/*" -vv
```

### For Draft proposals:
```bash
# Fetch data
node src/utils/fetchTallyDraft.js $ARGUMENTS src/ens/proposals/ep-topic-name

# Run test
forge test --match-path "src/ens/proposals/ep-topic-name/*" -vv
```

## Step 4: Critical Rules

These rules are non-negotiable. Read `CLAUDE.md` for the full list.

1. **Manual derivation only.** Build `_generateCallData()` from the proposal specification and Solidity interfaces. Never copy from `proposalCalldata.json`.
2. **No hex blobs.** Every selector from `Interface.method.selector`. Every address from a named constant.
3. **Meaningful assertions.** Both `_beforeProposal()` and `_afterExecution()` must contain substantive state checks. Empty hooks are never acceptable.
4. **Mismatch = finding.** If manually derived calldata differs from `proposalCalldata.json`, stop. Do not approve.

## Step 5: Produce Report

After the test passes, produce a structured security report:

1. **Proposal Summary** — What it does (1-3 sentences)
2. **Calldata Verification** — PASS/FAIL per executable call with target and selector
3. **Assertion Results** — What `_beforeProposal()` and `_afterExecution()` checked
4. **Findings** — CRITICAL / IMPORTANT / INFO
5. **Recommendation** — APPROVE / REJECT / NEEDS_REVIEW
6. **Reproduction** — `git clone` + `forge test` commands

## Step 6: Commit, Push, PR

Follow commit conventions from the review guide. Open PR targeting `main`.
