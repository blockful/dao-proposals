# SPP3 stream implementation (pre-draft)

Calldata for the SPP3 stream transition, built ahead of the on-chain executable and checked against live mainnet state
(fork block 25,480,000). Same setup as SPP2 (EP 6.13): the timelock streams USDCx to the Stream Management Pod
(`0xB162...31D1`, `stream.mg.wg.ens.eth`), and the pod streams to each provider.

Two parts:

- `calldataCheck.t.sol`: the DAO executable. Wraps a month of funding plus a margin, sends the margin to the pod, sets
  the master stream to $3.09M/yr, and refreshes the autowrap allowance. This is what the proposer submits.
- `podStreamSetup.t.sol`: the pod's Safe transaction that switches the individual streams from the SPP2 cohort to SPP3.
  Run by the pod signers, not the governor.

## Numbers

SPP3 cohort, $1.69M/yr:

| Provider   | Address                                    | Amount                    |
| ---------- | ------------------------------------------ | ------------------------- |
| Namespace  | 0x168CAfEcFBE97dF85968Ea039CC11D10a9A44567 | $500k (was $400k in SPP2) |
| Goldsky    | 0x79d46b9a85F0CC040aE66186aDCa8e318b064485 | $450k (new)               |
| Unruggable | 0x64Ca550F78d6Cc711B247319CC71A04A166707Ab | $400k (unchanged)         |
| Fluidkey   | 0xdcC34c0da55cEF7AeD38Bb749AD97DAC12A9936C | $340k (new)               |

The master stream is $3.09M/yr: the cohort ($1.69M) plus eth.limo and Blockful ($700k each), whose SPP2 two-year streams
run into next year. The pod switch turns off the SPP2 providers that were not renewed (NameHash $1.1M, EFP $500k, ZK
Email $400k, JustaName $300k) in the same batch that starts the new ones.

Rates: the master uses budget / 31,556,926 (the SPP2 convention); per-provider streams use budget / 31,536,000, which
matches the rates the pod runs today to the wei.

## Timing and margin

The switch is atomic: everything flips in one pod batch. The thing to watch is the gap between the master change
(executable) and the pod batch, since they run on different paths. If the master drops to $3.09M before the pod
switches, the pod keeps paying the old $4.5M on $3.09M of income and its small live buffer runs out within a day. So the
executable sends a ~$60k margin (about a week of outflow) to the pod up front. `test_atomicSwitch_withMargin` runs the
worst case (master down Aug 1, pod switch Aug 4) and the pod stays funded the whole way.

## Still to confirm

- Master receiver is the existing pod. If SPP3 spins up a new committee multisig, swap `STREAM_POD`.
- Master rate covers cohort plus the two-year streams ($3.09M). Cohort-only would be $1.69M.
- Goldsky's address is a plain EOA with no ENS name or label, unlike the other three. Worth confirming.
- Margin size and the funding amounts follow SPP2 ratios; the real stream spreadsheet sets the finals.

## Run

Needs an archive `MAINNET_RPC_URL`. `evm_version` is cancun (set in foundry.toml) since the 2026 Superfluid contracts
use transient storage.

```
forge test --match-path "src/ens/proposals/spp3-stream-implementation/*" -vv
```
