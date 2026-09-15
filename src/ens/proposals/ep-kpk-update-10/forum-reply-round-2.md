# Calldata security verification: PUR #10, revised execution

Blockful has completed an independent review of the revised execution: the switch batch `ENS_Switch_ZRM.json` and the redeployed Roles Modifier it enables (`karpatkey/client-configs`, commit `8f4fb0c34d`).

## Verification result

**The switch batch.** We derived the two Safe calls, `disableModule(SENTINEL, 0x703806E6…)` and `enableModule(0xa23BEBFD…)`, from the Safe interface and compared the derivation against the published batch byte for byte. The two are identical. `prevModule = SENTINEL` is correct: the current Modifier heads the Endowment Safe's module list. Executed on a mainnet fork through the path now in force (the ENS Foundation Safe schedules it on the EndowmentTimelock, nine days elapse, anyone executes), the Safe ends with exactly two modules, the new Modifier and the untouched Allowance module. The old Modifier is disabled and can no longer execute; the Security Council veto cancels the scheduled operation; the DAO Timelock cannot execute the batch.

**The new Modifier.** `0xa23BEBFD…` and the Sub `0x48dC0d88…` are EIP-1167 clones of the canonical Roles v2.1.1 mastercopy (`0xF2964CE6…`), whose verified source we recompiled to the on-chain bytecode. The mastercopy differs from the v2.1.0 the current Modifier runs on in three places: the EIP-1271 signature check now requires the call to succeed, Or alternatives no longer share allowance consumption, and dynamic `EqualTo` values are compared over their encoded length.

**The policy.** We did not rely on the diff page. We reconstructed the MANAGER policy of both Modifiers from their complete on-chain event histories (617 events on the current one since block 19,736,050; 495 on the new one), applied the Update #10 payload we verified in round 1 to the reconstructed current policy, and diffed the result against the new Modifier: 151 targets and 332 function permissions on each side, no permission present on one side only, every target clearance equal. 316 condition trees are byte-identical; 15 differ only in the order of Or alternatives, which the checker evaluates as a set; one, `USDC.transfer`, differs only by a trailing unconstrained parameter that the checker never inspects. Members are the kpk pod and the Sub, there are no allowances and no other roles, and the registered unwrappers are MultiSend and MultiSendCallOnly 1.4.1. The same comparison is repeated inside the test directly against storage: after replaying the Update #10 calls onto the current Modifier in the fork, every target slot and every condition tree, decoded from the packed buffers the Modifiers evaluate, is equal between the two. Every Update #10 permission verified in round 1 was then re-asserted on the new Modifier after the switch, together with the pre-existing approval lists and the `USDC.transfer` pin to the DAO Timelock.

We confirm the claim in the post: the new Modifier is the live MANAGER policy plus the Update #10 additions and nothing else.

The simulation and tests can be found [here](https://github.com/blockful/dao-proposals/blob/19c4ed985f579e5ee40328bbb85bb5cbc28f7d58/src/ens/proposals/ep-kpk-update-10/calldataCheck.t.sol); the event replay and its output are in the same directory.

## Findings

**1. The new Modifier is still owned by kpk's test Safe. Ownership must move to the Endowment Safe before the switch is scheduled.** `owner()` of `0xa23BEBFD…` is `0xC01318baB7ee1f5ba734172bF7718b5DC6Ec90E1`, a 1-of-9 Safe (the avatar of kpk's `test` instance in `client-configs`). The current Modifier is owned by the Endowment Safe, so its policy can only change through whoever controls the Safe: today the Foundation, through the nine-day timelock and the Security Council veto. If the switch executes as published, any one signer of the test Safe can rewrite the Endowment's policy with no delay and no veto; our simulation widens `sUSDS.transfer` and moves the Safe's 2.9M sUSDS in the following block. kpk's PR #252 lists the transfer as handled separately, but neither the post nor the batch includes it. _Request: transfer ownership of `0xa23BEBFD…` to the Endowment Safe (`0x4F2083f5…`) before the batch is scheduled, and let us know so we re-run the verification against the final state. Our test treats the transfer as a precondition and simulates it._

**2. The execution path is the Foundation, not a DAO vote.** The thread still says the proposal progresses to an on-chain executable vote; the batch as published is executed by the Foundation Safe through the EndowmentTimelock. We take the post as settling that this update is a Foundation decision. So that the Security Council's veto window is usable in practice, we ask that the timelock operation id be published in this thread when the batch is scheduled.

**3. The Harvest role is not yet configured.** The Sub has no roles and no members at the time of review; kpk configures it after the switch, as described in post 3. Our simulation of that configuration confirms the Sub cannot redirect payouts or reach anything beyond the three distributors.

## Reproduction

1. Clone: `git clone https://github.com/blockful/dao-proposals.git`
2. Checkout: `git checkout 19c4ed985f579e5ee40328bbb85bb5cbc28f7d58`
3. Run: `forge test --match-path "src/ens/proposals/ep-kpk-update-10/*" -vv`

We will re-run the verification once ownership of the new Modifier has been transferred.
