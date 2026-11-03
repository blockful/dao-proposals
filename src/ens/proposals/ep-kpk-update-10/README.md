# Endowment permissions to kpk — Update #10 (pre-draft)

Forum post: https://discuss.ens.domains/t/draft-endowment-permissions-to-kpk-update-10/22323

There is no Tally draft yet, so there is no `proposalCalldata.json`. The executable artefact published with the forum
post is a Safe Transaction Builder batch:

```
karpatkey/client-configs @ ens-dao-manager-harvest-rwa-yield
clients/ens-dao/mainnet/payloads/ensPermissionsUpdate10.json
```

reviewed at commit `3e447f8d21` ("ENS PUR 10: deploy Sub-Roles Modifier from Roles v2.1.1 mastercopy", 2026-07-29).

## Files

| File                      | Purpose                                                                        |
| ------------------------- | ------------------------------------------------------------------------------ |
| `calldataCheck.t.sol`     | Manually derives the 54-transaction MultiSend body and asserts the permissions |
| `expectedMultiSend.txt`   | The published payload re-encoded verbatim — the diff target, not a source      |
| `annotationAddition.json` | Annotation content posted by TX 53, extracted from the payload                 |

`expectedMultiSend.txt` was produced by ABI-encoding each transaction in the payload JSON and packing it in MultiSend
format. It plays the same role `proposalCalldata.json` plays for a live proposal: `_assertDerivedPayloadMatches()`
proves the hand-derived calldata equals it. Nothing in `_generateCallData()` is copied from it.

## Running

```bash
forge test --match-contract Proposal_ENS_KPK_Update_10_Test -vv
```

## Status

Derived calldata matches the published payload. The payload implements items 1–4 of the forum specification. Items 5
(syrupUSDC / syrupUSDT on the CoW token lists) and 6 (Harvest role reward claims) are **not** present in it, and the
payload additionally deploys a sub-Roles Modifier owned by karpatkey, which the forum post does not describe.

Working assumption (pending kpk confirmation): the sub-Roles Modifier exists to host the Harvest role of item 6,
configured by karpatkey after execution with the definition published in their configuration repository (single operator
`0x14C2d2D64C4860ACF7CF39068eb467D7556197de`). `_assertAssumedHarvestArchitecture()` simulates that configuration and
proves the two-layer chain: payouts remain pinned to the Endowment Safe by the existing MANAGER conditions even if the
sub-role is configured without restrictions, and the operator can reach nothing beyond the three distributors. See
`forum-post.md` for the findings and the questions put to kpk.

`_assertForumItemsNotImplemented()` encodes the current gap: those assertions are expected to start failing once the
payload is completed, at which point this test must be updated.
