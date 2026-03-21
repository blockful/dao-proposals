# DAO Proposals — Governance Calldata Verification

## What This Repo Does

This repository independently verifies the calldata of DAO governance proposals. For each proposal, we reconstruct the expected calldata from first principles (interfaces, addresses, parameters) and compare it against the on-chain or draft calldata. If they match, the proposal does what it claims. If not, it's a security finding.

This system tests proposals that control millions/billions of dollars in DAO treasuries. Correctness is paramount. A false positive (approving bad calldata) is the worst possible outcome.

## Supported DAOs

See `src/dao-registry.json` for the full list. Currently:
- **ENS** — OZ Governor + Timelock (`src/ens/`)
- **Uniswap** — OZ Governor + Timelock (`src/uniswap/`)
- **Shutter** — Azorius + LinearERC20Voting (`src/shutter/`)

## Repo Structure

```
src/
  dao-registry.json          # DAO config manifest
  skills/                    # Claude Code skills (review workflows)
    proposal-review/         # Universal entry point
    live-review/             # Live proposal workflow
    draft-review/            # Draft proposal workflow
    pre-draft-review/        # Pre-draft workflow
    review-reference/        # Shared reference data
    dao-scaffold/            # Scaffold a new DAO
  base/                      # Shared governance abstractions
  ens/                       # ENS-specific proposals, helpers, interfaces
  uniswap/                   # Uniswap-specific proposals
  shutter/                   # Shutter-specific proposals
  utils/                     # Fetch scripts, shared interfaces
```

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
```
