---
name: proposal-review
description:
  Review a DAO governance proposal. Use when the user shares a Tally URL (live or draft), asks to review a proposal, or
  wants to verify calldata. Detects the phase automatically from the URL and runs the full review workflow.
argument-hint: [TALLY_URL]
---

# Proposal Review

End-to-end calldata security review of a DAO governance proposal.

**Input:** $ARGUMENTS

## Critical Objective

This system tests proposals that control millions/billions of dollars in DAO treasuries. A false positive (approving bad
calldata) is the **worst possible outcome**.

- Build `_generateCallData()` from **manual derivation** of proposal intent and Solidity interfaces.
- **Never** copy from `proposalCalldata.json`. It is validation, not source.
- No opaque hex blobs. Every selector from `Interface.method.selector`. Every address from a named constant.
- The calldata comparison (`_compareLiveCalldata`) validates your manual derivation against the JSON. If they mismatch,
  **stop — this is a security finding**.
- Both `_beforeProposal()` and `_afterExecution()` must contain substantive state checks. Empty hooks are never
  acceptable.

## Step 1: Detect Phase

Parse the Tally URL to determine the review phase:

| URL Pattern           | Phase         | What It Means                                            |
| --------------------- | ------------- | -------------------------------------------------------- |
| Contains `/proposal/` | **Live**      | Proposal is on-chain, submitted to the Governor          |
| Contains `/draft/`    | **Draft**     | Proposal exists as a Tally draft, not yet on-chain       |
| No URL provided       | **Pre-draft** | Proposal is being discussed/designed, no Tally entry yet |

## Step 2: Follow Phase-Specific Workflow

Based on the detected phase, read and follow the corresponding workflow file:

- **Live:** Read [live-review.md](live-review.md) — fetch on-chain data, update test, verify calldata matches
- **Draft:** Read [draft-review.md](draft-review.md) — fetch draft data, write test, verify calldata matches
- **Pre-draft:** Read [pre-draft-review.md](pre-draft-review.md) — create test from proposal spec, verify execution

Each workflow file has the complete step-by-step process for that phase.

## Step 3: Verify Assertions

Before publishing any approval, verify the assertion baseline. Read [assertion-baseline.md](assertion-baseline.md) for:

- What `_beforeProposal()` must contain
- What `_afterExecution()` must contain
- Required assertion patterns per proposal type
- Anti-patterns to avoid

## Step 4: Produce Security Report

After the test passes, produce a structured report:

1. **Proposal Summary** — What it does (1-3 sentences)
2. **Calldata Verification** — PASS/FAIL per executable call with target and selector
3. **Assertion Results** — What `_beforeProposal()` and `_afterExecution()` checked
4. **Findings** — CRITICAL / IMPORTANT / INFO
5. **Recommendation** — APPROVE / REJECT / NEEDS_REVIEW
6. **Reproduction** — `git clone` + `forge test` commands

## Reference Data

For key addresses, helpers, inherited state, selectors, and troubleshooting, see [reference.md](reference.md).

## Fetch Scripts

The skill bundles two fetch scripts:

```bash
# Fetch live proposal data (auto-detects DAO from Tally URL)
node ${CLAUDE_SKILL_DIR}/scripts/fetchLiveProposal.js <TALLY_URL> <OUTPUT_DIR>

# Fetch draft proposal data
node ${CLAUDE_SKILL_DIR}/scripts/fetchTallyDraft.js <DRAFT_URL> <OUTPUT_DIR>
```
