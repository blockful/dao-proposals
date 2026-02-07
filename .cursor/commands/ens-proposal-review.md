New ENS proposal to review. Ask for:
- Proposal URL on Tally (to determine if it's live or draft)
- Proposal number or name (e.g., EP-6.17)

Then:
1. Check if URL contains "/draft/" → Use DRAFT_CALLDATA_REVIEW_GUIDE.md
2. Otherwise → Use CALLDATA_REVIEW_GUIDE.md for live proposals

Key differences:
- Draft: _isProposalSubmitted() returns false, use ep-title-of-proposal naming
- Live: _isProposalSubmitted() returns true, use ep-X-Y naming

Important: ENS_Governance (src/ens/ens.t.sol) already provides these inherited variables — do NOT redeclare them:
- `timelock` (ITimelock) = wallet.ensdao.eth = 0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7
- `governor` (IGovernor) = 0x323A76393544d5ecca80cd6ef2A560C6a395b7E3
- `ensToken` (IENSToken) = 0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72
- `proposer`, `voters`, `targets`, `values`, `signatures`, `calldatas`, `description`
Use `address(timelock)` instead of hardcoding the timelock/wallet address.

Available helpers (src/ens/helpers/):
- SafeHelper: for proposals calling Safe.execTransaction (endowment transfers, delegatecalls). Inherit and use `_buildSafeExecCalldata()` or `_buildSafeExecDelegateCalldata()`. Provides `endowmentSafe` constant.
- ZodiacRolesHelper: for proposals updating Zodiac Roles permissions (karpatkey). Inherit and use `_safeExecuteTransaction()` for dry-run testing and `_expectConditionViolation()` for asserting role restrictions. Provides `roles`, `karpatkey`, `MANAGER_ROLE` constants.