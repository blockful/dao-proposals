# ENS Folder — Improvement Backlog

## Completed (State-of-the-Art Overhaul)

- [x] **Shared `Constants.sol`** — Created `src/ens/Constants.sol` with ENSConstants library (governance, infrastructure, endowment, multisigs, tokens, decimals, default actors).
- [x] **Enforce `dirPath()` for live proposals** — Added `require()` in `ens.t.sol` + added `dirPath()` to all 14 live proposals that were missing it.
- [x] **Fix pragma in skill code examples** — Skills moved to `src/skills/` and generalized to DAO-generic. Pragma fixed to `>=0.8.25 <0.9.0`.
- [x] **`_buildSafeMultiSendCalldata()` helper** — Created `MultiSendHelper.sol` with `_packCall()`, `_packDelegateCall()`, `_packCallWithValue()`, and `_buildSafeMultiSendCalldata()`.
- [x] **BaseGovernance + CalldataComparison** — Shared abstractions in `src/base/` for multi-DAO support.
- [x] **DAO registry** — `src/dao-registry.json` with ENS, Uniswap, Shutter configs.
- [x] **CLAUDE.md** — AI agent orchestration instructions.
- [x] **Universal skills** — `proposal-review`, `dao-scaffold`, `report-template` + generalized existing skills.
- [x] **Process docs** — `docs/ADDING_A_NEW_DAO.md` with full guide.

## Remaining — Medium Priority

- [ ] **Adopt Constants.sol across proposals** — Proposals still hardcode addresses that exist in ENSConstants. Incrementally update as proposals are touched.

- [ ] **Decimal handling in guides** — Neither the draft nor live guide mentions USDC=6 decimals vs ETH/ENS=18. Add to troubleshooting sections.

- [ ] **Standardize IERC20 import path** — Some proposals import from `@contracts/utils/interfaces/IERC20.sol`, others from `@forge-std/src/interfaces/IERC20.sol`. Pick one.

- [x] **Refactor ENS base class to inherit CalldataComparison** — `ens.t.sol` now inherits `CalldataComparison`, removing ~130 lines of duplicated code. Also fixed double `_generateCallData()` call.

- [x] **Refactor Uniswap base class to inherit CalldataComparison** — `uniswap.t.sol` now inherits `CalldataComparison`, removing ~180 lines. Kept signature parsing locally (Uniswap-specific).

## Remaining — Low Priority

- [ ] **Modernize remaining hex blob tests** — ep-6-8 and ep-6-23 still use raw hex calldata (deeply nested Zodiac Roles operations). Revisit when tooling improves.

- [ ] **Expand review-reference skill** — Add a decimal place reference table and concrete examples of correct vs. incorrect calldata derivation.
