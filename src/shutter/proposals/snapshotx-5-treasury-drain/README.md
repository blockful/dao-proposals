# Shutter Snapshot X proposal #5: "Snapshot X execution re-test" (MALICIOUS)

**Verdict: do not pass. The Security Council should cancel it.**

| | |
|---|---|
| Space | `0x594EB60b35C4E91A06a5df988e0504f7463cB769` (Shutter DAO 0x36, Snapshot X) |
| Proposer | `0x61F31C7B10ab421dD45aaC97813286A5Ed8aA880` |
| Execution | `0x5716…E7bB` AvatarExecutionStrategy → treasury Safe `0x36bD…32c4` |
| Voting | blocks 26,095,502 → 26,117,102 (≈ Oct 1 → Oct 4, 2026) |

## Claimed vs. actual

- **Description:** the treasury sends 1 SHU to the sub-DAO `0xBF1a…BF7B`. The Snapshot UI shows no execution metadata.
- **On-chain payload:** one `DELEGATECALL` from the Safe to the unverified contract `0x77B1…9fD0`, calling `transfer()`
  (`0x8a4068dd`).

Running as the Safe, the drainer:

1. Sends 1 SHU to the sub-DAO **only if `block.number <= 26,116,766`**. The earliest execution block is 26,117,102, so
   this decoy never runs.
2. Unwraps WETH and sells all USDC for ETH through the Uniswap V2 router.
3. Redeems all sUSDS and sends the USDS to `0xef79…Fbc0`.
4. Sells all SHU (path SHU→USDC→WETH) with 30% slippage tolerance.
5. Sends all ETH to `0xef79…Fbc0`.

The fork simulation leaves the Safe with 0 SHU, 0 USDC, 0 WETH, 0 sUSDS and 0 ETH. The attacker receives about 554k
USDS and about 60 ETH.

## Proposer origin

Within about 150 blocks the proposer:

1. Was funded with 6.04 ETH from an Aeroswap CEX hot wallet (`0xfb19…f4e1`).
2. Swapped 5.7 ETH for 10.36M SHU on the Uniswap V2 pool.
3. Self-delegated.
4. Proposed.

The proposal threshold is 10M SHU; quorum is 30M SHU.

The drainer was deployed 228 blocks earlier by `0x0f8a…f55d`, an EOA with a history of address-poisoning and
spoofed-token transfers.

## Tests

`forge test --match-path 'src/shutter/proposals/snapshotx-5-treasury-drain/*' -vv`

- `test_onchainProposalMatchesDrainerPayload`: rebuilds the payload hash and shows that it does not match the description.
- `test_proposerBoughtJustAboveThreshold`
- `test_execution_drainsTreasury`
- `test_councilVeto_blocksDrain` / `test_councilVeto_worksNow`: `Space.cancel(5)` from the Council Safe
  `0x3ea7…c0C0` (5-of-8) stops the drain.
