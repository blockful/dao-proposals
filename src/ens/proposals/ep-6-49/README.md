# SPP3 stream implementation (EP 6.49)

Calldata review for EP 6.49, the SPP3 stream transition, now live on-chain (proposer coltron.eth, proposal id
`30153206...348879`). The nine on-chain transactions match this reconstruction byte-for-byte, and `calldataCheck.t.sol`
runs the full lifecycle against the live proposal (fork block 25,496,915). Same setup as SPP2 (EP 6.13): the timelock
streams USDCx to the Stream Management Pod (`0xB162...31D1`, `stream.mg.wg.ens.eth`), and the pod streams to each
provider and committee member.

Two parts:

- `calldataCheck.t.sol`: the DAO executable. Wraps a month of funding plus a margin, sends the margin to the pod, sets
  the master stream to \$3.21M/yr, refreshes the autowrap allowance, and pays the committee's 20% lump sum in USDC. This
  is what the proposer submits.
- `podStreamSetup.t.sol`: the pod's Safe transaction that switches the provider streams from the SPP2 cohort to SPP3 and
  opens the committee salary streams. Run by the pod signers, not the governor.

## Numbers

The pod streams \$3.21M/yr in total.

SPP3 cohort, \$1.69M/yr:

| Provider   | Address                                    | Amount                      |
| ---------- | ------------------------------------------ | --------------------------- |
| Namespace  | 0x168CAfEcFBE97dF85968Ea039CC11D10a9A44567 | \$500k (was \$400k in SPP2) |
| Goldsky    | 0x79d46b9a85F0CC040aE66186aDCa8e318b064485 | \$450k (new)                |
| Unruggable | 0x64Ca550F78d6Cc711B247319CC71A04A166707Ab | \$400k (unchanged)          |
| Fluidkey   | 0xdcC34c0da55cEF7AeD38Bb749AD97DAC12A9936C | \$340k (new)                |

Committee salary streams, \$120k/yr. This is the 80% streamed portion of the \$150k committee comp. The other 20%
(\$30k) is the upfront payment, which the executable pays as USDC straight to each member (coltron \$9k, the three
members \$7k each).

| Member          | Address                                    | Stream (80%)     |
| --------------- | ------------------------------------------ | ---------------- |
| coltron (chair) | 0x1D5460F896521aD685Ea4c3F2c679Ec0b6806359 | \$36k (of \$45k) |
| sovereignsignal | 0x2D7d6Ec6198ADFD5850D00BD601958F6E316b05E | \$28k (of \$35k) |
| austingriffith  | 0x34aA3F359A9D614239015126635CE7732c18fDF3 | \$28k            |
| abdullahumar    | 0xaA4a9282594a8ec02116fc97B634648CCc9fBe5f | \$28k            |

gregskril.eth is the fifth committee member and is not compensated, so gets no stream.

The remaining \$1.4M/yr is the two SPP2 streams still running into next year, eth.limo and Blockful (\$700k each). The
pod switch turns off the SPP2 providers that were not renewed (NameHash \$1.1M, EFP \$500k, ZK Email \$400k, JustaName
\$300k) in the same batch that starts the new providers.

Rates: the master uses budget / 31,556,926 (the SPP2 convention); the per-provider and committee streams use budget /
31,536,000, which matches the rates the pod runs today to the wei.

## Timing and margin

The proposal executes in July, and from that moment the master stream is on the new \$3.21M rate and the committee
streams begin. The provider streams don't switch until the pod runs its batch, so through that overlap the pod keeps
paying the old SPP2 cohort the full \$4.5M (plus the committee) while only taking in \$3.21M, about -\$1.41M/yr
(\$3,869/day). The executable covers this by sending a \$250k margin to the pod up front, which carries it about 65 days
past execution.

This matters more than it sounds. The switch date is not enforced on-chain, and during SPP2's own transition last year
the pod streams were liquidated by Superfluid sentinels and the pod-side restart did not happen until mid-September, six
weeks after the Aug 1 target. If SPP3 slips the same way and the margin runs out first, the pod goes critical and every
stream it runs gets liquidated, eth.limo and Blockful included. So the margin is sized for a mid-September slip, not the
Aug 1 target, and `test_transitionOverlap_margin` models exactly that (execution Jul 19, switch Sep 12) with the pod
staying funded. The stronger move is to pre-sign the pod batch so the switch cannot slip past the margin at all.

The provider switch itself is atomic: one pod batch turns the old streams off and the new ones on together. The
committee streams open earlier, at ratification.

## Still to confirm

- Master receiver is the existing pod. If SPP3 spins up a new committee multisig, swap `STREAM_POD`.
- Master rate covers the cohort, the two-year streams, and the committee streams (\$3.21M). Without the committee it is
  \$3.09M.
- Margin covers about 65 days from execution. Confirm the real switch date; if it could slip past late September, raise
  the margin (about \$27k per extra week) or pre-sign the pod batch.
- Goldsky's address could not be verified on-chain. Treat this as a hard blocker: confirm it through the SPP
  award-notice channel or a signed message from Goldsky before any draft goes live.
- Committee payout addresses are the members' resolved ENS addresses. Confirm these are the intended payout wallets
  (abdullahumar.eth resolves forward but has no reverse record set).
- The committee's 20% lump sum is paid as USDC direct from the treasury to each member. The forum frames committee pay
  as coming from the accountability body's multisig, so confirm the direct route is acceptable rather than routing it
  through the pod.

## Run

Needs an archive `MAINNET_RPC_URL`. `evm_version` is cancun (set in foundry.toml) since the 2026 Superfluid contracts
use transient storage.

```
forge test --match-path "src/ens/proposals/spp3-stream-implementation/*" -vv
```
