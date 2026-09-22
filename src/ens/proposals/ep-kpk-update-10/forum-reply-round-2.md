# Calldata security verification: PUR #10, revised execution

We reviewed the switch batch (`ENS_Switch_ZRM.json`, `karpatkey/client-configs` @ `8f4fb0c34d`) and the new Roles Modifier it enables.

## Result

- **Batch.** `disableModule(SENTINEL, 0x703806E6…)` + `enableModule(0xa23BEBFD…)`, derived independently, is byte-identical to the published batch.
- **Policy.** The new Modifier is the current MANAGER policy plus the Update #10 additions, nothing else. We reconstructed both policies from their full on-chain event histories and diffed them (151 targets and 332 functions each, no allowances, no other roles, members: kpk pod and Sub), then repeated the comparison inside the test directly against storage. Every permission verified in round 1 passes on the new Modifier after the switch.
- **Code.** `0xa23BEBFD…` and the Sub `0x48dC0d88…` are clones of the canonical Roles v2.1.1 mastercopy; its verified source recompiles to the on-chain bytecode.
- **Execution.** Scheduled by the Foundation Safe on the EndowmentTimelock, the swap executes after nine days; the Security Council veto cancels it; the DAO Timelock cannot execute it.

Tests: [calldataCheck.t.sol](https://github.com/blockful/dao-proposals/blob/19c4ed985f579e5ee40328bbb85bb5cbc28f7d58/src/ens/proposals/ep-kpk-update-10/calldataCheck.t.sol) (the event replay is in the same directory).

## Findings

**1. Blocking: the new Modifier is owned by kpk's test Safe (`0xC01318ba…`, 1-of-9), not by the Endowment Safe.** After the switch, any single signer of that Safe could rewrite the Endowment's policy with no delay and no veto; our simulation moves the Safe's 2.9M sUSDS in one block. Please transfer ownership of `0xa23BEBFD…` to the Endowment Safe (`0x4F2083f5…`) before the batch is scheduled and let us know. We will re-run the verification against the final state.

**2. This is a Foundation execution, not a DAO vote.** Please publish the timelock operation id when the batch is scheduled, so the Security Council's veto window is usable.

**3. The Harvest role is not yet configured on the Sub.** Once kpk configures it, our simulation shows it cannot exceed the MANAGER policy.

## Reproduction

```
git clone https://github.com/blockful/dao-proposals.git
git checkout 19c4ed985f579e5ee40328bbb85bb5cbc28f7d58
forge test --match-path "src/ens/proposals/ep-kpk-update-10/*" -vv
```
