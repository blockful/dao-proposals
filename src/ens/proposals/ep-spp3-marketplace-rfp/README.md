# SPP3 Marketplace RFP award (live)

Live calldata review for the SPP3 Marketplace RFP award to Nomentum Labs (Grails), per the committee recommendation:
https://discuss.ens.domains/t/spp3-marketplace-rfp-recommendation/22371

Now live on-chain: proposal id `19667497139373951686084433718987773325019389190188449031876262520356769920394`,
proposed by coltron.eth at block 25,877,353 (2026-08-31). The live payload took the lump three-transfer shape (the
forum's Next Steps had sketched a master-stream raise for the \$310k; the submitted executable settled on the lump
transfer, so the pre-draft `masterRaiseVariant.t.sol` was removed). The three on-chain calls were verified
byte-for-byte against the `ProposalCreated` event, and `proposalDescription.md` is byte-identical to the event's
description string.

The DAO-side executable is three USDC transfers from the timelock to the MetaGov Stream Management Pod
(`stream.mg.wg.ens.eth`, `0xB162Bf7A7fD64eF32b787719335d06B2780e31D1` — the same pod that runs the SPP3 cohort streams
from EP 6.49), one per tranche so each shows up separately on-chain:

| # | Amount        | Purpose                                                                             |
| - | ------------- | ----------------------------------------------------------------------------------- |
| 1 | 90,000 USDC   | Upfront tranche; MetaGov releases \$30k/month over the first quarter (KYC + Award Notice) |
| 2 | 100,000 USDC  | Four \$25k performance gates, released only on verified results                      |
| 3 | 310,000 USDC  | Funds the stream MetaGov opens on ENSv2-readiness verification (~Q4 2026/December)   |

Total: \$500,000, the RFP maximum (\$400k base + \$100k performance-gated). All release mechanics are pod-side Safe
transactions by the MetaGov stewards; unreleased funds return to the treasury at term end.

Files:

- `calldataCheck.t.sol` — live governance test: derives the three transfers from first principles, reproduces the live
  proposal id from the derived calldata plus the on-chain description hash, compares against the fetched
  `proposalCalldata.json`, runs the full lifecycle (vote → queue → execute), asserts the pod gains exactly \$500k and
  the timelock pays exactly \$500k, and pins the recipient by resolving `stream.mg.wg.ens.eth` on-fork and requiring
  the timelock to be a pod owner.
- `proposalCalldata.json` / `proposalDescription.md` — fetched live data (creation block 25,877,353); the description
  is byte-identical to the `ProposalCreated` event's.
- `podReleaseFlow.t.sol` — pod-side simulation of how the multisigs execute the releases in production. The pod is a
  1-of-2 Safe owned by the timelock and the MetaGov main Safe (`main.mg.wg.ens.eth`, 2-of-N), so every release is the
  MetaGov Safe calling the pod's `execTransaction` with its own pre-approved signature — the nested-safe path. Two
  tests against live mainnet state (SPP3 cohort streams already switched): the happy path (three \$30k installments,
  wrap-and-open of the 310k stream in December, 2 + 2 gate releases, stream close at term end, Nomentum ends with
  \$190k USDC + ~\$310k streamed) and the miss path (gates unmet, \$100k returns to the timelock). Both assert the pod
  stays solvent at every monthly checkpoint and the cohort streams are untouched, and both log the exact Safe
  Transaction Builder bytes for each pod batch.
- `anticaptureImport.json` — Anticapture proposal-import payload (v1, 2026-08) with title, forum link, body (ENS
  executable-proposal template headings: Abstract / Specification / Transactions), and the three `erc20-transfer`
  actions.

## Open items (pod-side releases, not the DAO executable)

The forum's Next Steps had sketched a master-stream raise for the \$310k; the submitted executable settled on the lump
transfer, so the shape question is closed (the pre-draft's `masterRaiseVariant.t.sol` was removed at that point — see
git history). Remaining items all concern the pod-side release batches MetaGov signs later:

- Nomentum Labs's payout address is published only after KYC; the pod-side tests use a placeholder EOA.
- The \$25k wind-down escrow is "funded from the award when the stream opens" but neither its destination nor which
  tranche it reduces is specified. The happy-path test bakes in the "no carve-out" answer (Nomentum ends with the full
  \$500k), which cannot be right if the escrow reduces a tranche — confirm with MetaGov before the stream-open batch.
- Term end is modeled as 2027-08-01 (co-terminating with the SPP3 cohort's one-year term); the stream rate is
  `310_000e18 / (termEnd - streamOpen)`, so pin both dates before the batch is signed. The installment anchor is also
  unconfirmed (modeled Oct/Nov/Dec 1; a September start is plausible with the ~Sep 10 execution).

## Run

```
forge test --match-contract Proposal_ENS_EP_SPP3_Marketplace_RFP_Test -vv
```
