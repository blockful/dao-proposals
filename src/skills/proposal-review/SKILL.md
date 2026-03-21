---
name: proposal-review
description: Use when reviewing any DAO governance proposal. Accepts a Tally URL or proposal description, detects the DAO and phase, and runs the full autonomous review workflow ending with a structured security report.
---

# Proposal Review — Universal Entry Point

Autonomous end-to-end review of DAO governance proposals. Input: a Tally URL or proposal context. Output: a complete security review with structured findings.

## Step 1: Detect DAO and Phase

**From Tally URL:**
- `/gov/{slug}/proposal/{id}` → **Live** proposal. Look up `slug` in `src/dao-registry.json` field `tallySlug`
- `/gov/{slug}/draft/{id}` → **Draft** proposal. Same lookup.
- No URL provided → **Pre-draft**. Ask the user which DAO.

**Load DAO config from `src/dao-registry.json`:**
- `basePath` — where DAO-specific files live (e.g., `src/ens`)
- `baseTestContract` — the governance base class to inherit
- `proposalsPath` — where proposal directories go
- `contractNaming` — naming convention for test contracts
- `helpers` — available helper contracts
- `interfacesPath` — where to find Solidity interfaces
- `constantsFile` — shared address constants (if available)

## Step 2: Route to Sub-Skill

| Phase | Skill to Invoke | URL Pattern |
|-------|-----------------|-------------|
| Live | `live-review` | URL contains `/proposal/` |
| Draft | `draft-review` | URL contains `/draft/` |
| Pre-draft | `pre-draft-review` | No Tally URL |

The sub-skill handles: branch creation, data fetching, test scaffolding, calldata construction, and test execution.

## Step 3: Run Tests

```bash
forge test --match-path "{proposalsPath}/{proposal-dir}/*" -vv
```

If tests fail:
1. Check the `review-reference` skill for troubleshooting guidance
2. Common issues: description mismatch (trailing whitespace), calldata mismatch (decimal places), stack too deep
3. If calldata mismatches, this is a **security finding** — do not try to make the test pass by copying from JSON

## Step 4: Generate Security Report

After successful test execution, produce a structured report. Use the template at `src/skills/report-template.md`.

The report MUST include:
1. **Proposal Summary** — What the proposal does (1-3 sentences)
2. **Calldata Verification** — PASS/FAIL for each executable call with target and selector
3. **Assertion Results** — What was checked in `_beforeProposal()` and `_afterExecution()`
4. **Findings** — Any mismatches, concerns, or anomalies classified as CRITICAL/IMPORTANT/INFO
5. **Recommendation** — APPROVE / REJECT / NEEDS_REVIEW with justification
6. **Reproduction** — Exact `git clone` + `forge test` commands to reproduce locally

## Step 5: Commit, Push, PR

Follow the commit conventions from the sub-skill:
- Live: `test({dao}): EP X.Y — update to live proposal`
- Draft: `chore({dao}): add draft calldata review for EP X.Y — topic`
- Pre-draft: `chore({dao}): add pre-draft calldata review for EP topic`

Push and open a PR targeting `main`.

## Step 6: Forum Post

Generate the forum post text from the sub-skill's template. Include:
- Link to the test file on GitHub (with commit hash)
- Local reproduction instructions
- For live proposals: link to anticapture.com

## Error Handling

- **Unknown DAO slug**: If the Tally slug is not in `dao-registry.json`, inform the user and suggest using the `dao-scaffold` skill to add the DAO first.
- **Fetch failure**: If `fetchLiveProposal.js` or `fetchTallyDraft.js` fails, check: API key in `.env`, correct URL format, network connectivity.
- **Compilation failure**: If `forge build` fails, check: pragma version, import paths, remappings.
- **Test failure**: See troubleshooting in `review-reference` skill.
