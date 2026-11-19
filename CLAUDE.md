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
src/
  dao-registry.json              # DAO config manifest
  base/                          # Shared governance abstractions
  ens/                           # ENS proposals, helpers, interfaces, Constants.sol
  uniswap/                       # Uniswap proposals
  shutter/                       # Shutter proposals
  utils/                         # Shared interfaces (IDAO.sol)
```

## How to Review a Proposal

Use `/proposal-review <URL>` from the private `blockful-skills` repo. Install it with
`npx skills@1.5.10 add blockful/blockful-skills@proposal-review -a claude-code -a codex -g -y`.

Every review runs through `src/utils/review.js` and ends the same way: a plain test, a one-line PR description, a squash
merge and a forum comment ready to paste. `review.js finish` produces the PR text and the forum comment, so use them as
printed.

## Golden Rules

1. **Manual derivation only.** Build `_generateCallData()` from the proposal specification and Solidity interfaces.
   Never copy from `proposalCalldata.json`.
2. **No hex blobs.** Every selector must come from `Interface.method.selector`. Every address from a named constant or
   variable.
3. **Meaningful assertions.** Both `_beforeProposal()` and `_afterExecution()` must contain substantive state checks.
   Empty hooks are never acceptable.
4. **Mismatch = finding.** If manually derived calldata differs from `proposalCalldata.json`, stop. Do not approve.
   Report the mismatch.
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

# Start a review: fetch the proposal, check it against the chain, write the test skeleton
node src/utils/review.js start <PROPOSAL_URL_OR_ID>

# Check a finished test
node src/utils/review.js check <PROPOSAL_DIR>

# Commit, open the PR, wait for CI, merge and print the forum comment
node src/utils/review.js finish <PROPOSAL_DIR> --summary "what moves where" --wait

# Test the review script
node --test src/utils/review.test.js
```
