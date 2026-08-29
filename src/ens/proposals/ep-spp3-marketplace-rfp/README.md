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
  (propose → vote → queue → execute), asserts the pod gains exactly \$500k and the timelock pays exactly \$500k.
- `anticaptureImport.json` — Anticapture proposal-import payload (v1, 2026-08) with title, forum link, body, and the
  three `erc20-transfer` actions.

When the draft goes up, transition per `ens-draft-review`: fetch `proposalCalldata.json` / `proposalDescription.md`,
set `dirPath()`, switch the description to `getDescriptionFromMarkdown()`, and set the real proposer.

## Run

```
forge test --match-contract Proposal_ENS_EP_SPP3_Marketplace_RFP_Test -vv
```
