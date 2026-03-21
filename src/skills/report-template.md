# Security Report Template

Use this template after completing a proposal review. Fill in all sections.

---

## Proposal: {DAO} EP {number} — {title}

**DAO:** {DAO name}
**Phase:** {Pre-draft | Draft | Live}
**Tally URL:** {url or N/A}
**Reviewer:** Claude Code (autonomous)
**Date:** {YYYY-MM-DD}

---

### Summary

{1-3 sentences describing what the proposal does}

### Calldata Verification

| # | Target | Selector | Status | Notes |
|---|--------|----------|--------|-------|
| 0 | `{address}` | `{function(args)}` | MATCH / MISMATCH | {details if mismatch} |
| 1 | ... | ... | ... | ... |

**Overall:** {N}/{N} calls match — PASS / FAIL

### Pre-Execution Assertions (`_beforeProposal`)

- {assertion description}: PASS / FAIL
- {assertion description}: PASS / FAIL

### Post-Execution Assertions (`_afterExecution`)

- {assertion description}: PASS / FAIL
- {assertion description}: PASS / FAIL

### Findings

#### CRITICAL
{None found, or list each finding with:}
{- Description of the issue}
{- Impact assessment}
{- Recommendation}

#### IMPORTANT
{None found, or list each finding}

#### INFO
{None found, or list each finding}

### Recommendation

**{APPROVE / REJECT / NEEDS_REVIEW}**

{1-2 sentences justifying the recommendation. Reference specific findings if REJECT or NEEDS_REVIEW.}

### Reproduction

```bash
git clone https://github.com/blockful/dao-proposals.git
cd dao-proposals
git checkout {commit_hash}
forge test --match-path "{test_path}" -vv
```

### Forum Post (copy-paste ready)

```markdown
## {Phase} proposal calldata security verification

{The appropriate forum post text, following the phase-specific template from the sub-skill.}
```
