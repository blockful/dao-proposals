# Aligning Treasury Delays with the Governance Process
Summary
-------

Increase the Treasury Escrow withdrawal cooldown and the Treasury Timelock minimum delay from two days to ten days. Set the Escrow expiration to seventeen days from initiation, preserving a seven-day withdrawal window after the cooldown.

The purpose is to give COMP holders enough time to complete the governance process before treasury actions become executable.

## Rationale

Treasury activity has continued while governance concerns remain unresolved. On September 29, the TMC transferred $3 million in stablecoins to a separate Safe. That Safe subsequently deployed $2 million USDC into a single-sided Uniswap V3 COMP position, committing those funds to purchasing COMP as its price falls through the position’s range.

These movements, documented in the forum discussion, demonstrate why voluntary requests to suspend treasury activity are insufficient. Governance needs an enforceable period in which it can consider and execute a response.

This proposal extends the existing treasury controls and gives the Governor Timelock explicit authority to execute and cancel Treasury Timelock operations.

## Executable actions

The proposal executes five actions in this order:

1. Set the Treasury Escrow withdrawal expiration to `1468800` seconds (17 days from initiation).
2. Set the Treasury Escrow withdrawal cooldown to `864000` seconds (10 days).
3. Grant the Governor Timelock `EXECUTOR_ROLE` on the Treasury Timelock.
4. Grant the Governor Timelock `CANCELLER_ROLE` on the Treasury Timelock.
5. Schedule a Treasury Timelock self-call to `updateDelay(864000)`, using its existing `172800`-second minimum delay.

Expiration is increased before the cooldown to satisfy the Escrow’s configuration constraints.

The fifth action schedules the delay increase. It does not immediately change the Treasury Timelock’s minimum delay. A separate execution is required once the scheduled operation is ready. A follow-up governance proposal is prepared for that execution; an existing authorized executor can also complete it.

## Treasury custody instruction

Treasury assets administered by the TMC shall be held in the Treasury Escrow or in contracts owned by the Treasury Timelock.

The TMC Safe may hold treasury assets only in transit, for no longer than needed to complete a disbursement that has passed through the Escrow cooldown or the Treasury Timelock delay.

This custody requirement is a governance instruction and is not enforced by the executable calls.

## References

[Forum discussion and supporting evidence](https://www.comp.xyz/t/aligning-treasury-delays-with-the-governance-process/8098)

[Transaction payloads and simulation evidence](https://github.com/umersin61/compound-treasury-delay-proposal)

Scheduled operation ID: `0x953db1c078de556930197fab4266b633d0b7fd28477d9028de81a438e6c6214d`
