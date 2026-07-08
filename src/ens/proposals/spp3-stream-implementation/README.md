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

The proposal executes in July, and from that moment the master stream is on the new $3.09M rate. The provider streams
don't switch until the pod runs its batch, so through that overlap the pod keeps paying the old SPP2 cohort the full
$4.5M while only taking in $3.09M, about -$1.41M/yr ($3,869/day). The executable covers this by sending a $250k margin
to the pod up front, which carries it about 65 days past execution.

This matters more than it sounds. The switch date is not enforced on-chain, and during SPP2's own transition last year
the pod streams were liquidated by Superfluid sentinels and the pod-side restart did not happen until mid-September, six
weeks after the Aug 1 target. If SPP3 slips the same way and the margin runs out first, the pod goes critical and every
stream it runs gets liquidated, eth.limo and Blockful included. So the margin is sized for a mid-September slip, not the
Aug 1 target, and `test_transitionOverlap_margin` models exactly that (execution Jul 19, switch Sep 12) with the pod
staying funded. The stronger move is to pre-sign the pod batch so the switch cannot slip past the margin at all.

The switch itself is atomic: one pod batch turns the old streams off and the new ones on together.

## Still to confirm

- Master receiver is the existing pod. If SPP3 spins up a new committee multisig, swap `STREAM_POD`.
- Master rate covers cohort plus the two-year streams ($3.09M). Cohort-only would be $1.69M.
- Margin covers about 65 days from execution. Confirm the real switch date; if it could slip past late September, raise
  the margin (about $27k per extra week) or pre-sign the pod batch.
- Goldsky's address could not be verified on-chain (see above). Treat this as a hard blocker: confirm it through the SPP
  award-notice channel or a signed message from Goldsky before any draft goes live.

## Run

Needs an archive `MAINNET_RPC_URL`. `evm_version` is cancun (set in foundry.toml) since the 2026 Superfluid contracts
use transient storage.

```
forge test --match-path "src/ens/proposals/spp3-stream-implementation/*" -vv
```
