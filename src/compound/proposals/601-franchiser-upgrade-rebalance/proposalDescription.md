# Franchiser Operational Upgrade and Rebalance

## Summary

This proposal upgrades Compound's treasury-delegation (Franchiser) system to a new pool-based architecture and, in the same step, carries out the first scheduled biannual delegate rebalancing under **Proposal 504 — [Compound Delegate Race (Cycle 2)](https://www.comp.xyz/t/compound-delegate-race-cycle-2/7302)**.

The total COMP delegated through the program does not change. Existing delegations migrate to the new pool with no interruption to voting power, and the pool reclaimed from under-participating delegates is redistributed to qualified active delegates. COMP remains in Governance-owned contracts throughout.

## Background

Proposal 504 established a standing six-monthly review of treasury-delegated voting power, with a uniform on-chain participation standard and a defined reallocation procedure. The first review window (Proposals 505–586) has closed and participation has been verified on-chain. The full review, application window, and waterfall are documented on the forum: [comp.xyz/t/7862](https://www.comp.xyz/t/7862).

## What this proposal does

1. **Upgrade.** Migrate the treasury-delegation program to the upgraded Franchiser pool: existing delegations move into a new Governance-funded pool, with the CGWG multisig set as Coordinator and a Guardian set for emergency oversight. Governance retains sole authority to fund, halt, or reclaim the pool in full.

2. **Rebalance.** As part of the migration, three delegations that fell below the participation standard are not renewed — releasing **81,178.58 COMP** — which is redistributed to the qualified applicants per the waterfall.

**Not renewed — 81,178.58 COMP reclaimed:**

| Delegatee | Address | COMP |
|---|---|---:|
| Michigan Blockchain | `0x13BD…8548` | 29,999.88 |
| Reservoir / AlphaGrowth | `0x4f89…fd3c` | 50,000.00 |
| Sharp | `0x72C5…7708` | 1,178.70 |

**Reallocated — 81,178.58 COMP:**

| Delegate | Address | COMP |
|---|---|---:|
| FranklinDAO | `0x0703…961b` | 8,262.46 |
| DAOplomats | `0xc554…7759` | 40,000.00 |
| blockful | `0x1F3D…0591` | 32,916.12 |

## The upgraded architecture

The upgrade replaces per-delegation Franchiser deployments with a single pool, split across three role-gated contracts:

- **FranchiserPoolFactory** — the Governance-only entry point. Governance creates, funds, and can halt a pool; halting recalls all delegates and returns the full COMP balance to the Timelock (the only path for COMP to leave the program).
- **FranchiserPool** — holds the program's idle COMP. A **Coordinator** (the CGWG multisig) can `delegate`, `recall`, and `reassign` voting power among delegates within Governance-set limits. A separate **Guardian** can emergency-`recall` a delegate or `freeze` the pool (10-day minimum), but can never move or delegate COMP.
- **Franchiser** — unchanged from V1: holds delegated COMP and grants voting power to a delegatee (who may name up to one sub-delegate).

Governance (the Timelock) sets each pool's parameters — delegate cap, Coordinator, Guardian, freeze period — and can change them or halt the program at any time by on-chain vote.

## Guarantees

- **Delegation only, never custody.** COMP stays in Governance-owned contracts at every step (Timelock → pool → Franchiser); no working group, Coordinator, or Guardian ever takes custody of the tokens.
- **Total set by governance.** This proposal does not change the program's total delegated COMP — it migrates and reallocates the existing pool. Any change to the total returns to an on-chain vote, and Governance can recall or reassign any delegation at any time.
