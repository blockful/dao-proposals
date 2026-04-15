# State-of-the-Art DAO Proposals Overhaul

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the dao-proposals repo into an AI-agent-native, composable, production-grade governance calldata
verification system that makes it trivial to add new DAOs and autonomously review proposals worth millions/billions of
dollars.

**Architecture:** Three sequential phases — (C) AI-Agent-Native system with CLAUDE.md orchestration, universal skills,
and structured reporting; (B) Bulletproof ENS with shared constants, enforced assertion baselines, and modernized
calldata; (A) DAO Factory with abstract base governance, pluggable adapters, scaffold tooling, and process
documentation.

**Tech Stack:** Solidity 0.8.25+, Foundry (forge), Claude Code skills, Node.js fetch scripts, Tally API

---

## File Map

### Phase C — AI-Agent-Native

| Action   | Path                                           | Purpose                                                             |
| -------- | ---------------------------------------------- | ------------------------------------------------------------------- |
| Create   | `CLAUDE.md`                                    | Top-level AI agent orchestration instructions                       |
| Create   | `src/dao-registry.json`                        | DAO configuration manifest (addresses, governance type, helpers)    |
| Refactor | `src/ens/skills/ens-live-review/SKILL.md`      | Generalize to DAO-generic with registry lookup                      |
| Refactor | `src/ens/skills/ens-draft-review/SKILL.md`     | Generalize to DAO-generic                                           |
| Refactor | `src/ens/skills/ens-pre-draft-review/SKILL.md` | Generalize to DAO-generic                                           |
| Refactor | `src/ens/skills/ens-review-reference/SKILL.md` | Generalize to DAO-generic                                           |
| Move     | `src/ens/skills/` → `src/skills/`              | Skills are repo-wide, not ENS-specific                              |
| Create   | `src/skills/proposal-review/SKILL.md`          | Universal entry point: URL → detect DAO → route to correct workflow |
| Create   | `src/skills/report-template.md`                | Structured security report template                                 |

### Phase B — Bulletproof ENS

| Action | Path                                            | Purpose                                                                             |
| ------ | ----------------------------------------------- | ----------------------------------------------------------------------------------- |
| Create | `src/ens/Constants.sol`                         | Shared address constants (USDC, Governor, Timelock, etc.)                           |
| Create | `src/ens/helpers/MultiSendHelper.sol`           | Reusable MultiSend + Safe calldata builder                                          |
| Modify | `src/ens/ens.t.sol`                             | Enforce non-empty `dirPath()` for live proposals; enforce non-empty assertion hooks |
| Modify | `src/ens/proposals/ep-5-16/calldataCheck.t.sol` | Modernize hex blob → interface-based                                                |
| Modify | `src/ens/proposals/ep-5-22/calldataCheck.t.sol` | Modernize hex blob → interface-based                                                |
| Modify | `src/ens/proposals/ep-5-25/calldataCheck.t.sol` | Add dirPath, use Constants                                                          |
| Modify | `src/ens/proposals/ep-5-26/calldataCheck.t.sol` | Add dirPath, use Constants                                                          |
| Modify | Multiple proposals                              | Adopt Constants.sol imports, remove redundant Test imports                          |

### Phase A — DAO Factory

| Action   | Path                                            | Purpose                                                          |
| -------- | ----------------------------------------------- | ---------------------------------------------------------------- |
| Create   | `src/base/BaseGovernance.sol`                   | Abstract governance lifecycle (propose → vote → queue → execute) |
| Create   | `src/base/adapters/GovernorTimelockAdapter.sol` | Adapter for OZ Governor + Timelock DAOs                          |
| Create   | `src/base/adapters/AzoriusAdapter.sol`          | Adapter for Azorius-based DAOs (Shutter)                         |
| Create   | `src/base/CalldataComparison.sol`               | Extracted JSON calldata comparison logic                         |
| Refactor | `src/ens/ens.t.sol`                             | Inherit from BaseGovernance + GovernorTimelockAdapter            |
| Refactor | `src/uniswap/uniswap.t.sol`                     | Inherit from BaseGovernance + GovernorTimelockAdapter            |
| Refactor | `src/shutter/shutter.t.sol`                     | Inherit from BaseGovernance + AzoriusAdapter                     |
| Create   | `src/skills/dao-scaffold/SKILL.md`              | AI skill for scaffolding a new DAO                               |
| Create   | `docs/ADDING_A_NEW_DAO.md`                      | Step-by-step process documentation                               |

---

## Phase C: AI-Agent-Native System

### Task 1: Create CLAUDE.md

**Files:**

- Create: `CLAUDE.md`

- [ ] **Step 1: Write CLAUDE.md**

```markdown
# DAO Proposals — Governance Calldata Verification

## What This Repo Does

This repository independently verifies the calldata of DAO governance proposals. For each proposal, we reconstruct the
expected calldata from first principles (interfaces, addresses, parameters) and compare it against the on-chain or draft
calldata. If they match, the proposal does what it claims. If not, it's a security finding.

This system tests proposals that control millions/billions of dollars in DAO treasuries. Correctness is paramount. A
false positive (approving bad calldata) is the worst possible outcome.

## Supported DAOs

See `src/dao-registry.json` for the full list. Currently:

- **ENS** — OZ Governor + Timelock (`src/ens/`)
- **Uniswap** — OZ Governor + Timelock (`src/uniswap/`)
- **Shutter** — Azorius + LinearERC20Voting (`src/shutter/`)

## Repo Structure
```

src/ dao-registry.json # DAO config manifest skills/ # Claude Code skills (review workflows) proposal-review/ #
Universal entry point live-review/ # Live proposal workflow draft-review/ # Draft proposal workflow pre-draft-review/ #
Pre-draft workflow review-reference/ # Shared reference data base/ # Shared governance abstractions (Phase A) ens/ #
ENS-specific proposals, helpers, interfaces uniswap/ # Uniswap-specific proposals shutter/ # Shutter-specific proposals
utils/ # Fetch scripts, shared interfaces

````

## How to Review a Proposal

When given a Tally URL or asked to review a proposal:

1. Use the `proposal-review` skill — it detects the DAO, determines the phase (pre-draft/draft/live), and routes to the correct workflow
2. The skill will guide you through: fetch data → scaffold test → construct calldata → run test → produce report

## Golden Rules

1. **Manual derivation only.** Build `_generateCallData()` from the proposal specification and Solidity interfaces. Never copy from `proposalCalldata.json`.
2. **No hex blobs.** Every selector must come from `Interface.method.selector`. Every address from a named constant or variable.
3. **Meaningful assertions.** Both `_beforeProposal()` and `_afterExecution()` must contain substantive state checks. Empty hooks are never acceptable.
4. **Mismatch = finding.** If manually derived calldata differs from `proposalCalldata.json`, stop. Do not approve. Report the mismatch.
5. **One proposal per test.** Each proposal gets its own directory under `src/<dao>/proposals/`.

## Solidity Conventions

- Pragma: `>=0.8.25 <0.9.0`
- Contract naming: `Proposal_<DAO>_EP_<epoch>_<number>_Test` (e.g., `Proposal_ENS_EP_6_38_Test`)
- File naming: `calldataCheck.t.sol`
- Use shared Constants.sol for known addresses
- Import interfaces from `@<dao>/interfaces/`
- Use helpers (SafeHelper, ZodiacRolesHelper, MultiSendHelper) — don't inline complex encoding

## Commands

```bash
# Run a specific proposal test
forge test --match-path "src/ens/proposals/ep-6-38/*" -vv

# Run all ENS tests
forge test --match-path "src/ens/**" -vv

# Fetch live proposal data
node src/utils/fetchLiveProposal.js <TALLY_URL> <OUTPUT_DIR>

# Fetch draft proposal data
node src/utils/fetchTallyDraft.js <DRAFT_URL> <OUTPUT_DIR>
````

````

- [ ] **Step 2: Verify CLAUDE.md is valid markdown**

Run: `cat CLAUDE.md | head -5`
Expected: Shows the title line

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add CLAUDE.md for AI agent orchestration"
````

---

### Task 2: Create DAO Registry

**Files:**

- Create: `src/dao-registry.json`

- [ ] **Step 1: Write the DAO registry**

```json
{
  "daos": {
    "ens": {
      "name": "ENS",
      "governanceType": "governor-timelock",
      "chain": "mainnet",
      "basePath": "src/ens",
      "baseTestContract": "ENS_Governance",
      "baseTestFile": "src/ens/ens.t.sol",
      "contracts": {
        "governor": "0x323A76393544d5ecca80cd6ef2A560C6a395b7E3",
        "timelock": "0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7",
        "token": "0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72"
      },
      "tallySlug": "ens",
      "proposalPrefix": "ep",
      "contractNaming": "Proposal_ENS_EP_{epoch}_{number}_Test",
      "helpers": ["SafeHelper", "ZodiacRolesHelper", "MultiSendHelper"],
      "interfacesPath": "src/ens/interfaces",
      "proposalsPath": "src/ens/proposals",
      "constantsFile": "src/ens/Constants.sol"
    },
    "uniswap": {
      "name": "Uniswap",
      "governanceType": "governor-timelock",
      "chain": "mainnet",
      "basePath": "src/uniswap",
      "baseTestContract": "UNI_Governance",
      "baseTestFile": "src/uniswap/uniswap.t.sol",
      "contracts": {
        "governor": "0x408ED6354d4973f66138C91495F2f2FCbd8724C3",
        "timelock": "0x1a9C8182C09F50C8318d769245beA52c32BE35BC",
        "token": "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984"
      },
      "tallySlug": "uniswap",
      "proposalPrefix": "proposal",
      "contractNaming": "Proposal_UNI_{number}_Test",
      "helpers": [],
      "interfacesPath": "src/uniswap/interfaces",
      "proposalsPath": "src/uniswap/proposals",
      "constantsFile": null
    },
    "shutter": {
      "name": "Shutter",
      "governanceType": "azorius",
      "chain": "mainnet",
      "basePath": "src/shutter",
      "baseTestContract": "Shutter_Governance",
      "baseTestFile": "src/shutter/shutter.t.sol",
      "contracts": {
        "azorius": "0xAA6BfA174d2f803b517026E93DBBEc1eBa26258e",
        "voting": "0x4b29d8B250B8b442ECfCd3a4e3D91933d2db720F",
        "treasury": "0x36bD3044ab68f600f6d3e081056F34f2a58432c4",
        "token": "0xe485E2f1bab389C08721B291f6b59780feC83Fd7"
      },
      "tallySlug": null,
      "proposalPrefix": "proposal",
      "contractNaming": "Proposal_Shutter_{name}_Test",
      "helpers": [],
      "interfacesPath": "src/shutter/interfaces",
      "proposalsPath": "src/shutter/proposals",
      "constantsFile": null
    }
  }
}
```

- [ ] **Step 2: Verify JSON is valid**

Run: `node -e "console.log(JSON.parse(require('fs').readFileSync('src/dao-registry.json','utf8')).daos.ens.name)"`
Expected: `ENS`

- [ ] **Step 3: Commit**

```bash
git add src/dao-registry.json
git commit -m "feat: add DAO registry manifest for multi-DAO support"
```

---

### Task 3: Move Skills to Repo-Wide Location

**Files:**

- Move: `src/ens/skills/` → `src/skills/`
- Modify: Any references to old skill paths

- [ ] **Step 1: Move the skills directory**

```bash
mv src/ens/skills src/skills
```

- [ ] **Step 2: Verify files moved correctly**

```bash
ls src/skills/
```

Expected: `ens-draft-review/  ens-live-review/  ens-pre-draft-review/  ens-review-reference/`

- [ ] **Step 3: Check for stale references to old path**

```bash
grep -r "src/ens/skills" . --include="*.md" --include="*.json" --include="*.toml" -l
```

Expected: No matches (or fix any found)

- [ ] **Step 4: Commit**

```bash
git add -A src/skills/ src/ens/skills/
git commit -m "refactor: move skills from src/ens/skills to src/skills (repo-wide)"
```

---

### Task 4: Generalize Skills from ENS-Specific to DAO-Generic

This task refactors all 4 existing skills to work with any DAO by referencing the DAO registry instead of hardcoding ENS
addresses and patterns.

**Files:**

- Rename + Modify: `src/skills/ens-live-review/SKILL.md` → `src/skills/live-review/SKILL.md`
- Rename + Modify: `src/skills/ens-draft-review/SKILL.md` → `src/skills/draft-review/SKILL.md`
- Rename + Modify: `src/skills/ens-pre-draft-review/SKILL.md` → `src/skills/pre-draft-review/SKILL.md`
- Rename + Modify: `src/skills/ens-review-reference/SKILL.md` → `src/skills/review-reference/SKILL.md`

- [ ] **Step 1: Rename skill directories**

```bash
mv src/skills/ens-live-review src/skills/live-review
mv src/skills/ens-draft-review src/skills/draft-review
mv src/skills/ens-pre-draft-review src/skills/pre-draft-review
mv src/skills/ens-review-reference src/skills/review-reference
```

- [ ] **Step 2: Rewrite `src/skills/live-review/SKILL.md`**

Update the frontmatter `name` to `live-review` and `description` to cover any DAO. Replace all ENS-specific paths,
addresses, and contract names with parameterized references:

- Replace hardcoded `ENS_Governance` with `{BaseTestContract}` (looked up from dao-registry.json)
- Replace `src/ens/proposals/` with `{proposalsPath}` from the registry
- Replace hardcoded addresses with "See dao-registry.json and the DAO's Constants.sol"
- Add a "DAO Detection" section: "Identify the DAO from the Tally URL slug (e.g., `/gov/ens/` → ENS, `/gov/uniswap/` →
  Uniswap)"
- Keep all critical principles (manual derivation, mismatch = finding, assertion baseline)

- [ ] **Step 3: Rewrite `src/skills/draft-review/SKILL.md`**

Same generalization as live-review. Key changes:

- Parameterize branch naming: `{dao}/ep-{topic-name}` instead of `ens/ep-topic-name`
- Parameterize test class inheritance
- Parameterize commit messages and PR templates

- [ ] **Step 4: Rewrite `src/skills/pre-draft-review/SKILL.md`**

Same generalization. Key changes:

- Parameterize directory creation path
- Parameterize contract naming convention
- Parameterize import paths

- [ ] **Step 5: Rewrite `src/skills/review-reference/SKILL.md`**

Replace the single ENS reference table with a structure that says:

- "Look up the DAO in `src/dao-registry.json` for addresses and config"
- "Each DAO may have a Constants.sol with shared addresses"
- Keep the helpers section but note which helpers are DAO-specific
- Keep troubleshooting (it's universal)

- [ ] **Step 6: Verify all skills are valid markdown with correct frontmatter**

```bash
head -5 src/skills/live-review/SKILL.md
head -5 src/skills/draft-review/SKILL.md
head -5 src/skills/pre-draft-review/SKILL.md
head -5 src/skills/review-reference/SKILL.md
```

- [ ] **Step 7: Commit**

```bash
git add src/skills/
git commit -m "refactor: generalize skills from ENS-specific to DAO-generic"
```

---

### Task 5: Create Universal Proposal Review Entry Point Skill

**Files:**

- Create: `src/skills/proposal-review/SKILL.md`

- [ ] **Step 1: Write the universal entry point skill**

This skill is the single entry point for all proposal reviews. It:

1. Accepts a Tally URL (or proposal description)
2. Detects the DAO from the URL slug
3. Determines the phase (pre-draft/draft/live) from URL pattern
4. Loads the DAO config from `src/dao-registry.json`
5. Routes to the correct sub-skill (live-review, draft-review, pre-draft-review)
6. After review completes, generates a structured report

````markdown
---
name: proposal-review
description:
  Use when reviewing any DAO governance proposal. Accepts a Tally URL or proposal description, detects the DAO and
  phase, and runs the full autonomous review workflow ending with a structured security report.
---

# Proposal Review — Universal Entry Point

Autonomous end-to-end review of DAO governance proposals. Input: a Tally URL or proposal context. Output: a complete
security review with structured findings.

## Step 1: Detect DAO and Phase

**From Tally URL:**

- `/gov/{slug}/proposal/{id}` → Live proposal. Look up `slug` in `src/dao-registry.json` → `daos[key].tallySlug`
- `/gov/{slug}/draft/{id}` → Draft proposal. Same lookup.
- No URL → Pre-draft. Ask the user which DAO.

**From dao-registry.json, load:**

- `basePath`, `baseTestContract`, `proposalsPath`, `contractNaming`, `helpers`, `interfacesPath`

## Step 2: Route to Sub-Skill

| Phase     | Skill              | Trigger                   |
| --------- | ------------------ | ------------------------- |
| Live      | `live-review`      | URL contains `/proposal/` |
| Draft     | `draft-review`     | URL contains `/draft/`    |
| Pre-draft | `pre-draft-review` | No Tally URL              |

Invoke the sub-skill. It handles: branch creation, data fetch, test scaffold, calldata construction, test execution.

## Step 3: Run Tests

```bash
forge test --match-path "{proposalsPath}/{proposal-dir}/*" -vv
```
````

If tests fail, diagnose using the troubleshooting section in `review-reference`.

## Step 4: Generate Security Report

After successful test execution, produce a report following `src/skills/report-template.md`.

The report must include:

1. **Proposal Summary** — What the proposal does (1-3 sentences)
2. **Calldata Verification** — PASS/FAIL for each executable call
3. **Assertion Results** — What was checked before and after execution
4. **Findings** — Any mismatches, concerns, or anomalies (CRITICAL/IMPORTANT/INFO)
5. **Recommendation** — APPROVE / REJECT / NEEDS_REVIEW
6. **Reproduction** — Exact commands to reproduce locally

## Step 5: Commit, Push, PR

Follow the commit conventions from the sub-skill. Open PR targeting `main`.

## Step 6: Forum Post

Generate the forum post text from the sub-skill's template.

````

- [ ] **Step 2: Commit**

```bash
git add src/skills/proposal-review/
git commit -m "feat: add universal proposal-review entry point skill"
````

---

### Task 6: Create Structured Report Template

**Files:**

- Create: `src/skills/report-template.md`

- [ ] **Step 1: Write the report template**

````markdown
# Security Report Template

Use this template after completing a proposal review. Fill in all sections.

---

## Proposal: {DAO} EP {number} — {title}

**DAO:** {DAO name} **Phase:** {Pre-draft | Draft | Live} **Tally URL:** {url or N/A} **Reviewer:** Claude Code
(autonomous) **Date:** {YYYY-MM-DD}

---

### Summary

{1-3 sentences describing what the proposal does}

### Calldata Verification

| #   | Target      | Selector     | Status           | Notes                 |
| --- | ----------- | ------------ | ---------------- | --------------------- |
| 0   | `{address}` | `{function}` | MATCH / MISMATCH | {details if mismatch} |
| 1   | ...         | ...          | ...              | ...                   |

**Overall:** {N}/{N} calls match — PASS / FAIL

### Pre-Execution Assertions (`_beforeProposal`)

- {assertion 1}: PASS
- {assertion 2}: PASS

### Post-Execution Assertions (`_afterExecution`)

- {assertion 1}: PASS
- {assertion 2}: PASS

### Findings

#### CRITICAL

{None, or list of critical findings}

#### IMPORTANT

{None, or list of important findings}

#### INFO

{None, or list of informational findings}

### Recommendation

**{APPROVE / REJECT / NEEDS_REVIEW}**

{1-2 sentences justifying the recommendation}

### Reproduction

```bash
git clone https://github.com/blockful/dao-proposals.git
cd dao-proposals
git checkout {commit_hash}
forge test --match-path "{test_path}" -vv
```
````

### Forum Post (copy-paste ready)

```markdown
## {Phase} proposal calldata security verification

{Forum post text following the sub-skill's template}
```

````

- [ ] **Step 2: Commit**

```bash
git add src/skills/report-template.md
git commit -m "docs: add structured security report template"
````

---

### Task 7: Update foundry.toml fs_permissions for Skills

**Files:**

- Modify: `foundry.toml`

The skills directory moved from `src/ens/skills` to `src/skills`. The foundry.toml fs_permissions already allows read
access to `./src`, so `src/skills` is covered. But we should also ensure `src/dao-registry.json` is readable by
Foundry's `vm.readFile()`.

- [ ] **Step 1: Verify fs_permissions in foundry.toml**

Read the current `fs_permissions` setting. If it says `{ access = "read", path = "./src" }`, the new paths are already
covered.

- [ ] **Step 2: Commit if changes needed**

Only commit if foundry.toml was modified.

---

## Phase B: Bulletproof ENS

### Task 8: Create ENS Constants.sol

**Files:**

- Create: `src/ens/Constants.sol`

- [ ] **Step 1: Identify all duplicated addresses across ENS proposals**

Search for recurring addresses in `src/ens/proposals/`:

- USDC: `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`
- USDT: `0xdAC17F958D2ee523a2206206994597C13D831ec7`
- WETH: `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2`
- ENS Endowment Safe: `0x4F2083f5fBede34C2714aFfb3105539775f7FE64`
- Zodiac Roles: `0x703806E61847984346d2D7DDd853049627e50A40`
- karpatkey: `0xb423e0f6E7430fa29500c5cC9bd83D28c8BD8978`
- MultiSend: `0x40A2aCCbd92BCA938b02010E17A5b8929b49130D`
- Meta-Gov Multisig: `0x91c32893216dE3eA0a55ABb9851f581d4503d39b`
- Ecosystem Multisig: `0x2686A8919Df194aA7673244549E68D42C1685d03`
- Public Goods Multisig: `0xcD42b4c4D102cc22864e3A1341Bb0529c17fD87d`
- fireeyesdao.eth: `0x5BFCB4BE4d7B43437d5A0c57E908c048a4418390`
- ENS Root: `0xaB528d626EC275E3faD363fF1393A41F581c5897`
- ENS Registry: `0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e`

- [ ] **Step 2: Write Constants.sol**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

/// @title ENS Constants
/// @notice Shared address constants for ENS governance proposal tests.
///         Use these instead of hardcoding addresses in individual proposals.
library ENSConstants {
    // ─── Governance ─────────────────────────────────────────────────────
    address internal constant ENS_TOKEN = 0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72;
    address internal constant GOVERNOR = 0x323A76393544d5ecca80cd6ef2A560C6a395b7E3;
    address internal constant TIMELOCK = 0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7;

    // ─── ENS Infrastructure ─────────────────────────────────────────────
    address internal constant ENS_ROOT = 0xaB528d626EC275E3faD363fF1393A41F581c5897;
    address internal constant ENS_REGISTRY = 0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e;

    // ─── Endowment & Zodiac ────────────────────────────────────────────
    address internal constant ENDOWMENT_SAFE = 0x4F2083f5fBede34C2714aFfb3105539775f7FE64;
    address internal constant ZODIAC_ROLES = 0x703806E61847984346d2D7DDd853049627e50A40;
    address internal constant KARPATKEY = 0xb423e0f6E7430fa29500c5cC9bd83D28c8BD8978;
    address internal constant MULTI_SEND = 0x40A2aCCbd92BCA938b02010E17A5b8929b49130D;

    // ─── Multisigs ──────────────────────────────────────────────────────
    address internal constant META_GOV_MULTISIG = 0x91c32893216dE3eA0a55ABb9851f581d4503d39b;
    address internal constant ECOSYSTEM_MULTISIG = 0x2686A8919Df194aA7673244549E68D42C1685d03;
    address internal constant PUBLIC_GOODS_MULTISIG = 0xcD42b4c4D102cc22864e3A1341Bb0529c17fD87d;

    // ─── Tokens ─────────────────────────────────────────────────────────
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant GHO = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;

    // ─── Token Decimals ─────────────────────────────────────────────────
    uint8 internal constant USDC_DECIMALS = 6;
    uint8 internal constant USDT_DECIMALS = 6;
    uint8 internal constant WETH_DECIMALS = 18;
    uint8 internal constant ENS_DECIMALS = 18;

    // ─── Default Actors ─────────────────────────────────────────────────
    address internal constant FIREEYESDAO = 0x5BFCB4BE4d7B43437d5A0c57E908c048a4418390;
}
```

- [ ] **Step 3: Verify it compiles**

Run: `forge build --skip script` Expected: Successful compilation

- [ ] **Step 4: Commit**

```bash
git add src/ens/Constants.sol
git commit -m "feat(ens): add shared Constants.sol with centralized addresses"
```

---

### Task 9: Create MultiSendHelper

**Files:**

- Create: `src/ens/helpers/MultiSendHelper.sol`

- [ ] **Step 1: Examine existing MultiSend patterns in ep-6-38**

Read `src/ens/proposals/ep-6-38/calldataCheck.t.sol` to understand how MultiSend is built inline.

- [ ] **Step 2: Write MultiSendHelper.sol**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { IMultiSend } from "@ens/interfaces/IMultiSend.sol";
import { SafeHelper } from "@ens/helpers/SafeHelper.sol";

/// @title MultiSendHelper
/// @notice Helpers for building MultiSend transactions executed through the Endowment Safe.
/// @dev MultiSend packs multiple transactions into a single delegatecall.
///      Format per tx: uint8 operation | address to | uint256 value | uint256 dataLength | bytes data
abstract contract MultiSendHelper is SafeHelper {
    IMultiSend internal constant multiSend = IMultiSend(0x40A2aCCbd92BCA938b02010E17A5b8929b49130D);

    /// @notice Pack a Call transaction for MultiSend (operation=0, value=0)
    function _packCall(address to, bytes memory data) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(0), to, uint256(0), uint256(data.length), data);
    }

    /// @notice Pack a DelegateCall transaction for MultiSend (operation=1, value=0)
    function _packDelegateCall(address to, bytes memory data) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(1), to, uint256(0), uint256(data.length), data);
    }

    /// @notice Pack a Call transaction with ETH value for MultiSend
    function _packCallWithValue(address to, uint256 value, bytes memory data) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(0), to, value, uint256(data.length), data);
    }

    /// @notice Build full Safe execTransaction calldata for a MultiSend batch
    /// @param packedTransactions Concatenated result of _packCall/_packDelegateCall calls
    /// @param safe The Safe to execute through
    /// @param owner The Safe owner providing pre-approved signature (typically the timelock)
    /// @return target The Safe address
    /// @return calldata_ The encoded execTransaction calldata
    function _buildSafeMultiSendCalldata(
        bytes memory packedTransactions,
        address safe,
        address owner
    ) internal pure returns (address target, bytes memory calldata_) {
        bytes memory multiSendData = abi.encodeWithSelector(
            IMultiSend.multiSend.selector,
            packedTransactions
        );
        return _buildSafeExecDelegateCalldata(safe, address(multiSend), multiSendData, owner);
    }
}
```

- [ ] **Step 3: Verify it compiles**

Run: `forge build --skip script` Expected: Successful compilation

- [ ] **Step 4: Commit**

```bash
git add src/ens/helpers/MultiSendHelper.sol
git commit -m "feat(ens): add MultiSendHelper for reusable Safe+MultiSend calldata"
```

---

### Task 10: Enforce dirPath() and Assertion Hooks in ENS Base Class

**Files:**

- Modify: `src/ens/ens.t.sol`

- [ ] **Step 1: Read current ens.t.sol**

Review the `test_proposal()` function to understand where to add enforcement.

- [ ] **Step 2: Add dirPath enforcement for live proposals**

After `_isProposalSubmitted()` check, add:

```solidity
// Enforce dirPath for live proposals — calldata comparison must not be silently skipped
if (_isProposalSubmitted()) {
    string memory _dirPath = dirPath();
    require(
        bytes(_dirPath).length > 0,
        "Live proposals must set dirPath() for calldata comparison"
    );
}
```

- [ ] **Step 3: Verify compilation**

Run: `forge build --skip script` Expected: Successful compilation

- [ ] **Step 4: Run ENS tests to check for regressions**

Run: `forge test --match-path "src/ens/proposals/ep-6-38/*" -vv` Expected: Tests pass (ep-6-38 has dirPath set)

- [ ] **Step 5: Fix any proposals that fail the new enforcement**

If any live proposals (where `_isProposalSubmitted() == true`) are missing `dirPath()`, add it. Based on exploration,
these proposals need fixing: ep-5-16, ep-5-22, ep-5-23, ep-5-25, ep-5-26, ep-5-27, ep-5-28, ep-5-29, ep-6-1, ep-6-2,
ep-6-7, ep-6-9, ep-6-11.

For each, add:

```solidity
function dirPath() public pure override returns (string memory) {
    return "src/ens/proposals/ep-X-Y";
}
```

- [ ] **Step 6: Run all ENS tests to verify**

Run: `forge test --match-path "src/ens/**" -vv` Expected: All tests pass

- [ ] **Step 7: Commit**

```bash
git add src/ens/ens.t.sol src/ens/proposals/
git commit -m "feat(ens): enforce dirPath() for live proposals in base class"
```

---

### Task 11: Adopt Constants.sol in Existing Proposals

**Files:**

- Modify: Multiple proposals that hardcode addresses already in Constants.sol

- [ ] **Step 1: Identify proposals that use hardcoded USDC, USDT, or token addresses**

Search for `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` (USDC) in proposals:

```bash
grep -r "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" src/ens/proposals/ -l
```

- [ ] **Step 2: Update proposals to import and use ENSConstants**

For each proposal found, add:

```solidity
import { ENSConstants } from "@ens/Constants.sol";
```

And replace the hardcoded address with `ENSConstants.USDC`, `ENSConstants.USDT`, etc.

**Important:** Only update the address references. Do NOT change any logic, assertions, or calldata construction. This
is a pure deduplication refactor.

- [ ] **Step 3: Verify all tests still pass**

Run: `forge test --match-path "src/ens/**" -vv` Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add src/ens/proposals/
git commit -m "refactor(ens): adopt Constants.sol across proposals"
```

---

### Task 12: Standardize Uniswap Pragma and Naming

**Files:**

- Modify: `src/uniswap/uniswap.t.sol`
- Modify: `src/uniswap/proposals/93 - UNIfication/activeProposal.t.sol`

- [ ] **Step 1: Update Uniswap pragma to match ENS standard**

Change `pragma solidity ^0.8.13;` to `pragma solidity >=0.8.25 <0.9.0;` in:

- `src/uniswap/uniswap.t.sol`
- All files under `src/uniswap/`

- [ ] **Step 2: Rename Uniswap proposal file**

```bash
mv "src/uniswap/proposals/93 - UNIfication/activeProposal.t.sol" "src/uniswap/proposals/93 - UNIfication/calldataCheck.t.sol"
```

- [ ] **Step 3: Verify compilation**

Run: `forge build --skip script` Expected: Successful compilation

- [ ] **Step 4: Commit**

```bash
git add src/uniswap/
git commit -m "refactor(uniswap): standardize pragma and rename to calldataCheck.t.sol"
```

---

## Phase A: DAO Factory

### Task 13: Create BaseGovernance Abstract Contract

**Files:**

- Create: `src/base/BaseGovernance.sol`

- [ ] **Step 1: Design the abstract base**

Extract the shared lifecycle that ALL DAOs follow:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";

/// @title BaseGovernance
/// @notice Abstract base for all DAO governance proposal tests.
///         Provides the shared lifecycle: setUp → test_proposal → assertions.
///         Governance-specific logic (propose, vote, queue, execute) is delegated
///         to adapter methods that each DAO implements.
abstract contract BaseGovernance is Test {
    // ─── Proposal State ─────────────────────────────────────────────────
    address public proposer;
    address[] public voters;

    // ─── Lifecycle ──────────────────────────────────────────────────────

    function setUp() public virtual {
        _selectFork();
        proposer = _proposer();
        voters = _voters();
        _labelContracts();
    }

    /// @notice Main test entry point — runs the full governance lifecycle
    function test_proposal() public {
        _validateQuorum();
        _validateProposer();
        _prepareProposal();

        _beforeProposal();

        if (!_isProposalSubmitted()) {
            _submitProposal();
        }

        _advanceToVoting();
        _castVotes();
        _advancePastVoting();
        _queueProposal();
        _advancePastTimelock();
        _executeProposal();

        _afterExecution();
        _compareCalldata();
    }

    // ─── Abstract: Must be implemented by each DAO ──────────────────────

    function _selectFork() public virtual;
    function _proposer() public view virtual returns (address);
    function _voters() public view virtual returns (address[] memory);
    function _labelContracts() internal virtual;

    function _validateQuorum() internal virtual;
    function _validateProposer() internal virtual;
    function _prepareProposal() internal virtual;
    function _submitProposal() internal virtual;
    function _advanceToVoting() internal virtual;
    function _castVotes() internal virtual;
    function _advancePastVoting() internal virtual;
    function _queueProposal() internal virtual;
    function _advancePastTimelock() internal virtual;
    function _executeProposal() internal virtual;
    function _compareCalldata() internal virtual;

    function _beforeProposal() public virtual;
    function _afterExecution() public virtual;
    function _isProposalSubmitted() public view virtual returns (bool);

    function dirPath() public virtual returns (string memory) {
        return "";
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `forge build --skip script`

- [ ] **Step 3: Commit**

```bash
git add src/base/BaseGovernance.sol
git commit -m "feat: add BaseGovernance abstract contract for multi-DAO support"
```

---

### Task 14: Create CalldataComparison Library

**Files:**

- Create: `src/base/CalldataComparison.sol`

- [ ] **Step 1: Extract the JSON parsing and comparison logic**

Both ENS and Uniswap have near-identical `callDataComparison()`, `parseJsonTargets()`, `parseJsonValues()`,
`parseJsonCalldatas()` methods. Extract these into a shared contract.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";
import { console2 } from "@forge-std/src/console2.sol";

/// @title CalldataComparison
/// @notice Shared logic for comparing generated calldata against proposalCalldata.json.
///         Inherit this in any DAO base class that supports JSON calldata verification.
abstract contract CalldataComparison is Test {
    /// @notice Compare generated calldata against JSON file (no signatures field)
    function _compareLiveCalldata(
        string memory jsonContent,
        address[] memory generatedTargets,
        uint256[] memory generatedValues,
        bytes[] memory generatedCalldatas
    ) internal {
        address[] memory jsonTargets = _parseJsonTargets(jsonContent);
        string[] memory jsonValues = _parseJsonValues(jsonContent);
        bytes[] memory jsonCalldatas = _parseJsonCalldatas(jsonContent);

        console2.log("JSON parsed successfully with", jsonTargets.length, "operations");

        assertEq(jsonTargets.length, generatedTargets.length, "Number of executable calls mismatch");

        for (uint256 i = 0; i < jsonTargets.length; i++) {
            assertEq(
                jsonTargets[i],
                generatedTargets[i],
                string(abi.encodePacked("Target mismatch at index ", vm.toString(i)))
            );
            assertEq(
                vm.parseUint(jsonValues[i]),
                generatedValues[i],
                string(abi.encodePacked("Value mismatch at index ", vm.toString(i)))
            );
            assertEq(
                jsonCalldatas[i],
                generatedCalldatas[i],
                string(abi.encodePacked("Calldata mismatch at index ", vm.toString(i)))
            );
        }
    }

    // ─── JSON Parsing (handles both array and single-element) ───────────

    function _decodeTargetsArray(string memory j) public pure returns (address[] memory) {
        return abi.decode(vm.parseJson(j, ".executableCalls[*].target"), (address[]));
    }

    function _decodeTargetSingle(string memory j) public pure returns (address) {
        return abi.decode(vm.parseJson(j, ".executableCalls[*].target"), (address));
    }

    function _parseJsonTargets(string memory j) internal returns (address[] memory result) {
        (bool ok, bytes memory ret) = address(this).call(
            abi.encodeWithSelector(this._decodeTargetsArray.selector, j)
        );
        if (ok) return abi.decode(ret, (address[]));

        (, ret) = address(this).call(abi.encodeWithSelector(this._decodeTargetSingle.selector, j));
        result = new address[](1);
        result[0] = abi.decode(ret, (address));
    }

    function _decodeValuesArray(string memory j) public pure returns (string[] memory) {
        return abi.decode(vm.parseJson(j, ".executableCalls[*].value"), (string[]));
    }

    function _decodeValueSingle(string memory j) public pure returns (string memory) {
        return abi.decode(vm.parseJson(j, ".executableCalls[*].value"), (string));
    }

    function _parseJsonValues(string memory j) internal returns (string[] memory result) {
        (bool ok, bytes memory ret) = address(this).call(
            abi.encodeWithSelector(this._decodeValuesArray.selector, j)
        );
        if (ok) return abi.decode(ret, (string[]));

        (, ret) = address(this).call(abi.encodeWithSelector(this._decodeValueSingle.selector, j));
        result = new string[](1);
        result[0] = abi.decode(ret, (string));
    }

    function _decodeCalldatasArray(string memory j) public pure returns (bytes[] memory) {
        return abi.decode(vm.parseJson(j, ".executableCalls[*].calldata"), (bytes[]));
    }

    function _decodeCalldataSingle(string memory j) public pure returns (bytes memory) {
        return abi.decode(vm.parseJson(j, ".executableCalls[*].calldata"), (bytes));
    }

    function _parseJsonCalldatas(string memory j) internal returns (bytes[] memory result) {
        (bool ok, bytes memory ret) = address(this).call(
            abi.encodeWithSelector(this._decodeCalldatasArray.selector, j)
        );
        if (ok) return abi.decode(ret, (bytes[]));

        (, ret) = address(this).call(abi.encodeWithSelector(this._decodeCalldataSingle.selector, j));
        result = new bytes[](1);
        result[0] = abi.decode(ret, (bytes));
    }

    function _getDescriptionFromMarkdown(string memory _dirPath) internal returns (string memory) {
        return vm.readFile(string.concat(_dirPath, "/proposalDescription.md"));
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `forge build --skip script`

- [ ] **Step 3: Commit**

```bash
git add src/base/CalldataComparison.sol
git commit -m "feat: extract CalldataComparison into shared base contract"
```

---

### Task 15: Create GovernorTimelockAdapter

**Files:**

- Create: `src/base/adapters/GovernorTimelockAdapter.sol`

- [ ] **Step 1: Write the adapter**

This adapter implements the BaseGovernance lifecycle methods for OZ Governor + Timelock DAOs (ENS, Uniswap). It contains
the shared propose → vote → queue → execute logic.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { BaseGovernance } from "@contracts/base/BaseGovernance.sol";
import { CalldataComparison } from "@contracts/base/CalldataComparison.sol";

/// @title GovernorTimelockAdapter
/// @notice Adapter for DAOs using OpenZeppelin Governor + Timelock (ENS, Uniswap).
///         Implements the shared governance lifecycle from BaseGovernance.
abstract contract GovernorTimelockAdapter is BaseGovernance, CalldataComparison {
    // ─── Proposal State ─────────────────────────────────────────────────
    uint256 public proposalId;
    address[] public targets;
    uint256[] public values;
    string[] public signatures;
    bytes[] public calldatas;
    string public description;
    bytes32 public descriptionHash;

    // ─── Abstract: DAO-specific contracts ────────────────────────────────
    // Each DAO (ENS, Uniswap) provides these in its own base class

    function _governorAddress() internal view virtual returns (address);
    function _timelockAddress() internal view virtual returns (address);
    function _tokenAddress() internal view virtual returns (address);

    function _generateCallData()
        public
        virtual
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory, string memory);

    // ─── Lifecycle implementation ───────────────────────────────────────
    // These are filled by the DAO-specific base class that knows the
    // exact Governor/Timelock interface (ENS uses different methods than Uniswap)
}
```

**Note:** The exact implementation of each lifecycle method differs between ENS and Uniswap Governor interfaces (e.g.,
`castVote` parameters, `queue` signature, vote counting). The adapter provides the structure; each DAO fills in the
specifics. This is intentional — forcing a single adapter to handle both would require complex conditional logic that's
harder to audit.

- [ ] **Step 2: Verify it compiles**

Run: `forge build --skip script`

- [ ] **Step 3: Commit**

```bash
git add src/base/adapters/GovernorTimelockAdapter.sol
git commit -m "feat: add GovernorTimelockAdapter for OZ Governor+Timelock DAOs"
```

---

### Task 16: Refactor ENS Base Class to Use Shared Infrastructure

**Files:**

- Modify: `src/ens/ens.t.sol`

- [ ] **Step 1: Update ENS_Governance to inherit CalldataComparison**

Replace the duplicated JSON parsing methods in `ens.t.sol` with an import of `CalldataComparison`. Keep `ENSHelper`
(namehash, labelhash) as ENS-specific.

The ENS_Governance should:

1. Import `CalldataComparison` from `@contracts/base/CalldataComparison.sol`
2. Inherit from `Test, CalldataComparison, ENSHelper` (instead of `Test, IDAO, ENSHelper`)
3. Remove the duplicated `parseJsonTargets`, `parseJsonValues`, `parseJsonCalldatas`, `decodeTargetsArray`, etc.
4. Update `callDataComparison()` to call `_compareLiveCalldata()`
5. Keep `getDescriptionFromMarkdown()` as a thin wrapper around `_getDescriptionFromMarkdown(dirPath())`

**Critical:** Do NOT change the `test_proposal()` lifecycle or any virtual method signatures. Existing proposals must
continue to compile and pass without modification.

- [ ] **Step 2: Verify all ENS tests pass**

Run: `forge test --match-path "src/ens/**" -vv` Expected: All tests pass unchanged

- [ ] **Step 3: Commit**

```bash
git add src/ens/ens.t.sol
git commit -m "refactor(ens): inherit CalldataComparison, remove duplicated JSON parsing"
```

---

### Task 17: Refactor Uniswap Base Class to Use Shared Infrastructure

**Files:**

- Modify: `src/uniswap/uniswap.t.sol`

- [ ] **Step 1: Update UNI_Governance to inherit CalldataComparison**

Same approach as ENS. Remove duplicated JSON parsing methods, import from CalldataComparison.

**Critical:** Keep the Uniswap-specific governance logic (different `castVote`, `queue(proposalId)` vs
`queue(targets, values, calldatas, descriptionHash)`).

- [ ] **Step 2: Verify Uniswap tests pass**

Run: `forge test --match-path "src/uniswap/**" -vv` Expected: Tests pass

- [ ] **Step 3: Commit**

```bash
git add src/uniswap/uniswap.t.sol
git commit -m "refactor(uniswap): inherit CalldataComparison, remove duplicated JSON parsing"
```

---

### Task 18: Create DAO Scaffold Skill

**Files:**

- Create: `src/skills/dao-scaffold/SKILL.md`

- [ ] **Step 1: Write the scaffold skill**

````markdown
---
name: dao-scaffold
description:
  Use when adding a new DAO to the repository. Scaffolds all required files — base test class, interfaces directory,
  proposals directory, constants, and registry entry.
---

# DAO Scaffold

Scaffolds the complete directory structure and boilerplate for adding a new DAO to the repository.

## Prerequisites

- Know the DAO's governance type (OZ Governor+Timelock, Azorius, or custom)
- Have the governance contract addresses (governor, timelock/treasury, token)
- Know the chain (mainnet, arbitrum, etc.)
- Have at least one voter address with sufficient voting power
- Have a proposer address with enough tokens to meet proposal threshold

## Step 1: Create Directory Structure

```bash
mkdir -p src/{dao-name}/interfaces
mkdir -p src/{dao-name}/helpers
mkdir -p src/{dao-name}/proposals
```
````

## Step 2: Add Remapping

Add to `remappings.txt`:

```
@{dao-name}/=src/{dao-name}/
```

## Step 3: Create Base Test Class

For **Governor+Timelock DAOs**, use `src/ens/ens.t.sol` as the template. For **Azorius DAOs**, use
`src/shutter/shutter.t.sol` as the template.

The base class MUST implement:

- `setUp()` with contract initialization and labeling
- `test_proposal()` with full governance lifecycle
- `_selectFork()`, `_proposer()`, `_voters()` — virtual with defaults
- `_beforeProposal()`, `_afterExecution()` — abstract
- `_generateCallData()` or `_prepareTransactions()` — abstract
- `_isProposalSubmitted()` — abstract
- `dirPath()` — virtual, default empty
- `callDataComparison()` — using CalldataComparison base (for Governor+Timelock DAOs)
- `getDescriptionFromMarkdown()` — using CalldataComparison base

## Step 4: Create Governance Interfaces

At minimum, create interface files for:

- The governance token (`IToken.sol`)
- The governor contract (`IGovernor.sol`)
- The timelock or treasury (`ITimelock.sol` or `ITreasury.sol`)

Extract interfaces from the actual deployed contracts using `cast interface`.

## Step 5: Add to DAO Registry

Add an entry to `src/dao-registry.json` with all required fields.

## Step 6: Create First Proposal Template

Create `src/{dao-name}/proposals/template/calldataCheck.t.sol` with a minimal working example.

## Step 7: Verify

```bash
forge build --skip script
```

## Step 8: Commit

```bash
git add src/{dao-name}/ remappings.txt src/dao-registry.json
git commit -m "feat({dao-name}): scaffold DAO governance test infrastructure"
```

````

- [ ] **Step 2: Commit**

```bash
git add src/skills/dao-scaffold/
git commit -m "feat: add dao-scaffold skill for bootstrapping new DAOs"
````

---

### Task 19: Write Process Documentation for Adding New DAOs

**Files:**

- Create: `docs/ADDING_A_NEW_DAO.md`

- [ ] **Step 1: Write comprehensive process documentation**

```markdown
# Adding a New DAO to the Repository

This guide walks through adding a new DAO to the governance calldata verification system. By the end, you'll have a
working test infrastructure that can verify any proposal for this DAO.

## Quick Start (AI Agent)

If you're an AI agent, use the `dao-scaffold` skill:
```

/dao-scaffold

````

It will interactively guide you through the process.

## Manual Process

### 1. Gather Information

Before starting, collect:

| Info | Example (ENS) | Where to Find |
|------|---------------|---------------|
| DAO name | ENS | Tally governance page |
| Governance type | Governor+Timelock | Check contracts on Etherscan |
| Governor address | `0x323A76...` | Tally or Etherscan |
| Timelock/Treasury address | `0xFe89cc...` | Governor contract's `timelock()` method |
| Token address | `0xC18360...` | Governor contract's `token()` method |
| Chain | mainnet | Tally |
| Tally slug | `ens` | URL: `tally.xyz/gov/{slug}` |
| Proposer address | `0x5BFCB4...` | Any delegate with enough tokens |
| Voter addresses (10+) | See ens.t.sol | Top delegates on Tally |

### 2. Create Directory Structure

```bash
mkdir -p src/{dao-name}/interfaces
mkdir -p src/{dao-name}/helpers
mkdir -p src/{dao-name}/proposals
````

### 3. Add Remapping

In `remappings.txt`, add:

```
@{dao-name}/=src/{dao-name}/
```

### 4. Extract Interfaces

Use `cast interface` to generate Solidity interfaces from deployed contracts:

```bash
cast interface {GOVERNOR_ADDRESS} --chain mainnet > src/{dao-name}/interfaces/IGovernor.sol
cast interface {TIMELOCK_ADDRESS} --chain mainnet > src/{dao-name}/interfaces/ITimelock.sol
cast interface {TOKEN_ADDRESS} --chain mainnet > src/{dao-name}/interfaces/IToken.sol
```

Clean up: keep only the functions you need, add proper SPDX headers and pragma.

### 5. Write Base Test Class

Copy the closest existing base class:

- For OZ Governor+Timelock: copy `src/ens/ens.t.sol`
- For Azorius: copy `src/shutter/shutter.t.sol`

Adapt:

- Replace contract addresses
- Replace token interface methods (e.g., `getVotes` vs `getCurrentVotes` vs `delegate`)
- Replace governance parameters (voting delay, voting period, quorum)
- Replace voter/proposer defaults
- Import from `@contracts/base/CalldataComparison.sol` for JSON comparison

### 6. Add to DAO Registry

Add an entry to `src/dao-registry.json`. All fields are required.

### 7. Write First Proposal Test

Use an existing live proposal to validate the infrastructure:

1. Find a recently executed proposal on Tally
2. Fetch its data: `node src/utils/fetchLiveProposal.js {URL} src/{dao-name}/proposals/{id}`
3. Write a `calldataCheck.t.sol` that reconstructs the calldata
4. Run: `forge test --match-path "src/{dao-name}/proposals/{id}/*" -vv`

If the test passes, the infrastructure is working.

### 8. Verify

```bash
# Build
forge build --skip script

# Run tests
forge test --match-path "src/{dao-name}/**" -vv
```

### 9. Commit and PR

```bash
git checkout -b feat/{dao-name}-scaffold
git add src/{dao-name}/ remappings.txt src/dao-registry.json
git commit -m "feat({dao-name}): scaffold DAO governance test infrastructure"
git push origin feat/{dao-name}-scaffold
```

## Governance Type Reference

| Type                    | Governor                                                                     | Timelock                            | Example      |
| ----------------------- | ---------------------------------------------------------------------------- | ----------------------------------- | ------------ |
| OZ Governor + Timelock  | `IGovernor.propose(targets, values, calldatas, description)`                 | `ITimelock.hashOperationBatch(...)` | ENS, Uniswap |
| Azorius                 | `IAzorius.submitProposal(strategy, data, transactions, metadata)`            | N/A (Safe-based)                    | Shutter      |
| Compound Governor Alpha | `GovernorAlpha.propose(targets, values, signatures, calldatas, description)` | `Timelock.queueTransaction(...)`    | (future)     |

## Checklist

- [ ] Directory structure created
- [ ] Remapping added
- [ ] Interfaces extracted and cleaned
- [ ] Base test class written and compiles
- [ ] DAO registry entry added
- [ ] First proposal test passes
- [ ] PR opened and merged

````

- [ ] **Step 2: Commit**

```bash
git add docs/ADDING_A_NEW_DAO.md
git commit -m "docs: add comprehensive guide for adding new DAOs"
````

---

### Task 20: Update TODO.md to Reflect Completed Items

**Files:**

- Modify: `src/ens/TODO.md`

- [ ] **Step 1: Mark completed items and add new ones**

Update TODO.md to reflect what this overhaul completed and what remains.

- [ ] **Step 2: Commit**

```bash
git add src/ens/TODO.md
git commit -m "docs(ens): update TODO.md with overhaul progress"
```

---

### Task 21: Final Integration Test

**Files:** None (verification only)

- [ ] **Step 1: Build entire project**

Run: `forge build --skip script` Expected: Successful compilation, no errors

- [ ] **Step 2: Run all ENS tests**

Run: `forge test --match-path "src/ens/**" -vv` Expected: All pass

- [ ] **Step 3: Run Uniswap tests**

Run: `forge test --match-path "src/uniswap/**" -vv` Expected: All pass

- [ ] **Step 4: Verify skills are in correct locations**

```bash
ls src/skills/*/SKILL.md
```

Expected: proposal-review, live-review, draft-review, pre-draft-review, review-reference, dao-scaffold

- [ ] **Step 5: Verify CLAUDE.md references are correct**

Read CLAUDE.md and check that all file paths it mentions actually exist.

- [ ] **Step 6: Verify dao-registry.json is consistent**

Check that every `basePath`, `baseTestFile`, `proposalsPath`, and `interfacesPath` in the registry points to real
directories.
