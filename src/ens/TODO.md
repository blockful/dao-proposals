# ENS Folder — Improvement Backlog

## High Priority

- [ ] **Shared `Constants.sol`** — Create `src/ens/Constants.sol` with centralized address definitions (USDC, ENS_TOKEN, GOVERNOR, TIMELOCK, ENDOWMENT_SAFE, ENS_ROOT, ZODIAC_ROLES, recurring actors like fireeyesdao.eth, karpatkey, etc.). Currently duplicated across 8+ proposals.

- [ ] **Enforce `dirPath()` for live proposals** — ep-5-16, ep-5-23, and ep-6-1 are live on-chain but missing `dirPath()`, which silently skips calldata comparison. Add a `require()` in `ens.t.sol` that enforces non-empty `dirPath()` when `_isProposalSubmitted()` returns true.

- [ ] **Fix pragma in skill code examples** — All 3 skill SKILL.md files (ens-draft-review, ens-live-review, ens-pre-draft-review) still show `^0.8.25` in code snippets instead of `>=0.8.25 <0.9.0`.

## Medium Priority

- [ ] **`_buildSafeMultiSendCalldata()` helper** — 7 proposals inline MultiSend + Safe integration. Extract this into `SafeHelper.sol` as a reusable method.

- [ ] **Decimal handling in guides** — Neither the draft nor live guide mentions USDC=6 decimals vs ETH/ENS=18. Add to troubleshooting sections in DRAFT_CALLDATA_REVIEW_GUIDE.md and CALLDATA_REVIEW_GUIDE.md.

- [ ] **Standardize IERC20 import path** — Some proposals import from `@contracts/utils/interfaces/IERC20.sol`, others from `@forge-std/src/interfaces/IERC20.sol`. Pick one and use consistently.

## Low Priority

- [ ] **Proposal template file** — Create `src/ens/ProposalTemplate.sol` with a test scaffold and TODO placeholders in `_beforeProposal()` / `_afterExecution()` hooks to guide reviewers.

- [ ] **Expand ens-review-reference skill** — Add a decimal place reference table and concrete examples of correct vs. incorrect calldata derivation.

- [ ] **Modernize remaining hex blob tests** — ep-6-8 and ep-6-23 still use raw hex calldata (deeply nested Zodiac Roles operations). Revisit when tooling improves or if proposals need re-review.
