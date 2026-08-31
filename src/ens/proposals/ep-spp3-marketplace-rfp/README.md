# SPP3 Marketplace RFP award (pre-draft)

Pre-draft payload for the SPP3 Marketplace RFP award to Nomentum Labs (Grails), per the committee recommendation:
https://discuss.ens.domains/t/spp3-marketplace-rfp-recommendation/22371

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

- `calldataCheck.t.sol` — pre-draft governance test: derives the three transfers, runs the full lifecycle
  (propose → vote → queue → execute), asserts the pod gains exactly \$500k and the timelock pays exactly \$500k, and
  pins the recipient by resolving `stream.mg.wg.ens.eth` on-fork and requiring the timelock to be a pod owner.
- `masterRaiseVariant.t.sol` — the alternative executable shape from the forum's Next Steps (90k + 100k transfers plus
  a master-stream raise for the \$310k); see Open items below.
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

## Open items

**The \$310k tranche's shape is not settled.** The forum's Next Steps says: "On execution, the \$90,000 up-front amount
and the \$100,000 performance reserve move to the Stream Management Pod, and **the master stream is raised to fund the
\$310,000 stream**" — and marks the on-chain payload as "pending specification". A master-stream raise is an EP
6.49-style `setFlowrate` from the timelock and cannot be done pod-side (MetaGov holds no flowOperator permission on the
timelock's flows), so the two readings produce different DAO executables:

- `calldataCheck.t.sol` — lump reading: three USDC transfers (90k / 100k / 310k) to the pod.
- `masterRaiseVariant.t.sol` — Next Steps reading: two USDC transfers (90k / 100k) plus a master-stream raise, modeled
  as spreading \$310k from execution (~Sep 10) to term end (the raise period is itself unspecified). Under this
  reading the Anticapture JSON's third action becomes a `custom` `setFlowrate` action, `podStreamSetup`'s stream-open
  batch loses its wrap steps (the pod accrues USDCx continuously instead of holding idle USDC), and the committee's
  draft may add a wrap + autowrap-allowance refresh like EP 6.49 did (live allowance ~4.55M USDC covers the current
  rate through term end, but drains ~\$310k faster once raised).

Confirm the shape with the committee/MetaGov before the draft goes live; both variants stay tested until then. When
the draft lands, verify it against the matching variant — a shape difference (including a single 500k transfer, or a
different transfer order) is a mismatch to investigate, not to paper over.

Other open items:

- Nomentum Labs's payout address is published only after KYC; the pod-side tests use a placeholder EOA.
- The \$25k wind-down escrow is "funded from the award when the stream opens" but neither its destination nor which
  tranche it reduces is specified. The happy-path test bakes in the "no carve-out" answer (Nomentum ends with the full
  \$500k), which cannot be right if the escrow reduces a tranche — confirm with MetaGov before the stream-open batch.
- Term end is modeled as 2027-08-01 (co-terminating with the SPP3 cohort's one-year term); the stream rate is
  `310_000e18 / (termEnd - streamOpen)`, so pin both dates before the batch is signed. The installment anchor is also
  unconfirmed (modeled Oct/Nov/Dec 1; a September start is plausible with the forum's ~Sep 10 execution).
- Confirm whether the Anticapture import form replaces or appends actions on re-import, and that the final on-chain
  title/description exactly match the submitted draft (the proposal id commits to the description hash).

When the draft goes up, transition per `ens-draft-review`: fetch `proposalCalldata.json` / `proposalDescription.md`,
set `dirPath()`, switch the description to `getDescriptionFromMarkdown()`, and set the real proposer.

## Run

```
forge test --match-contract Proposal_ENS_EP_SPP3_Marketplace_RFP_Test -vv
```
