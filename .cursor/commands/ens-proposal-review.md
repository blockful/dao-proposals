New ENS proposal to review. Ask for:
- Proposal URL on Tally (or "no URL yet" for pre-draft)
- Proposal number or name (e.g., EP-6.17, or descriptive name like "registrar-manager")

Then route to the correct guide based on the phase:

1. No URL / idea / pre-draft → Read and follow `src/ens/PRE_DRAFT_GUIDE.md`
2. URL contains "/draft/" → Read and follow `src/ens/DRAFT_CALLDATA_REVIEW_GUIDE.md`
3. URL is a live proposal → Read and follow `src/ens/CALLDATA_REVIEW_GUIDE.md`

Lifecycle: proposals evolve through phases in the SAME `calldataCheck.t.sol` file:
- Pre-draft: `_isProposalSubmitted = false`, `dirPath = ""`
- Draft: `_isProposalSubmitted = false`, `dirPath = "src/ens/proposals/ep-..."`, fetches JSON/md from Tally
- Live: `_isProposalSubmitted = true`, `dirPath = "src/ens/proposals/ep-X-Y"`, updates JSON/md with on-chain data

When transitioning between phases, UPDATE the existing test file — don't create a new one.
If the directory needs renaming (e.g., `ep-topic-name` → `ep-X-Y`), rename it and update `dirPath()`.

Important: ENS_Governance (src/ens/ens.t.sol) already provides these inherited variables — do NOT redeclare them:
- `timelock` (ITimelock) = wallet.ensdao.eth = 0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7
- `governor` (IGovernor) = 0x323A76393544d5ecca80cd6ef2A560C6a395b7E3
- `ensToken` (IENSToken) = 0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72
- `proposer`, `voters`, `targets`, `values`, `signatures`, `calldatas`, `description`
Use `address(timelock)` instead of hardcoding the timelock/wallet address.

Forum posts: When generating forum post text, always output as raw markdown inside a fenced code block so the user can copy-paste directly.

Available helpers (src/ens/helpers/):
- SafeHelper: for proposals calling Safe.execTransaction (endowment transfers, delegatecalls). Inherit and use `_buildSafeExecCalldata()` or `_buildSafeExecDelegateCalldata()`. Provides `endowmentSafe` constant.
- ZodiacRolesHelper: for proposals updating Zodiac Roles permissions (karpatkey). Inherit and use `_safeExecuteTransaction()` for dry-run testing and `_expectConditionViolation()` for asserting role restrictions. Provides `roles`, `karpatkey`, `MANAGER_ROLE` constants.

## Mandatory completion steps (do not stop early)
After implementing the review and passing tests, continue automatically in this order:
1. Create or switch to a branch named `ens/<proposal-slug>` (reuse current proposal branch if already on it)
2. Commit only proposal-related files for this review
3. Push the branch to `origin`
4. Open a PR against `main`
5. Return the PR URL
6. Return forum post text in a fenced markdown block using the exact template below

Do not ask for confirmation between these steps unless blocked by auth, permissions, or a hard tool error.

## Forum post template (exact)
Use this exact output structure (replace placeholders):

```markdown
## Draft proposal calldata security review

The calldata draft executes successfully and achieves the expected outcome of the proposal. All simulations and tests are available [here](https://github.com/blockful/dao-proposals/blob/SHORT_HASH/src/ens/proposals/PROPOSAL_DIR/calldataCheck.t.sol).

To verify locally:
1. Clone: `git clone https://github.com/blockful/dao-proposals.git`
2. Checkout: `git checkout SHORT_HASH`
3. Run: `forge test --match-path "src/ens/proposals/PROPOSAL_DIR/*" -vv`
```
