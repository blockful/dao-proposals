# Minimum Assertion Baseline

Every proposal test MUST include meaningful assertions in both `_beforeProposal()` and `_afterExecution()`. Passing
execution alone is not sufficient — assertions prove the proposal achieves its stated intent and does not silently
mis-configure state.

## `_beforeProposal()` — capture and verify pre-state

At minimum:

1. **Snapshot values that will change.** Store balances, owners, config values, or permissions into state variables so
   `_afterExecution()` can compare against them.
2. **Assert preconditions hold.** If the proposal assumes the timelock owns a contract, assert that. If it assumes a
   permission does NOT exist yet, assert that too. This catches stale fork blocks or incorrect assumptions.
3. **For permission proposals:** exercise permissions that will be revoked (they should succeed) and attempt permissions
   that will be added (they should revert). This creates a before/after proof.

## `_afterExecution()` — verify every claimed effect

At minimum, assert **one check per executable call** in the proposal. The categories below are not exhaustive but cover
the most common proposal types:

| Proposal type                                               | Required assertions                                                                                                                                               |
| ----------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Token transfer**                                          | Recipient balance increased by exact amount. Sender balance decreased by exact amount (or at least changed). Use `assertEq` on the delta, not just `assertNotEq`. |
| **Ownership / registry change**                             | New owner or registry value matches expected address. Old value no longer applies.                                                                                |
| **Permission grant (Zodiac Roles, access control)**         | The granted action succeeds when executed by the authorized actor. A similar action with wrong parameters reverts (negative test).                                |
| **Permission revocation**                                   | The revoked action reverts with the expected error selector.                                                                                                      |
| **Configuration change** (flow rates, parameters, upgrades) | New config value matches expected. Old value no longer returned.                                                                                                  |
| **Contract deployment / upgrade**                           | New contract address is non-zero. Key interface calls return expected values (e.g., `owner()`, `version()`).                                                      |
| **ENS name operations**                                     | `ensRegistry.owner(namehash(...))` or resolver returns expected value.                                                                                            |

## Anti-patterns to avoid

- **Empty hooks.** `_beforeProposal() {}` or `_afterExecution() {}` is never acceptable for a review to be published.
- **Only `assertNotEq`.** This proves something changed but not that it changed correctly. Always pair with an
  `assertEq` on the expected value.
- **No negative tests for permission changes.** If a proposal grants scoped permissions, test that out-of-scope
  parameters revert. If it revokes permissions, test that the revoked action fails.

These assertions carry forward from pre-draft through draft to live stages. Writing them early saves rework later.
