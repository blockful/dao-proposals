# Endowment permissions to kpk — Update #10

Forum thread: https://discuss.ens.domains/t/draft-endowment-permissions-to-kpk-update-10/22323

The review has two rounds because kpk changed how the update executes halfway through.

| Round | Executable artefact                                                      | Test                    | Status                       |
| ----- | ------------------------------------------------------------------------ | ----------------------- | ---------------------------- |
| 1     | `ensPermissionsUpdate10.json`, 59 Roles admin calls on the live Modifier | `update10Payload.t.sol` | superseded, retained (delta) |
| 2     | `ENS_Switch_ZRM.json`, swap the Modifier for a pre-configured v2.1.1     | `calldataCheck.t.sol`   | current                      |

## Round 2 — revised execution (forum post 4, 2026-09-14)

Instead of editing the Endowment's Zodiac Roles Modifier, the update now replaces it. kpk deployed and configured a new
Modifier on Roles v2.1.1 and asks the Endowment Safe to swap modules:

```
TX 0   EndowmentSafe.disableModule(SENTINEL, 0x703806E61847984346d2D7DDd853049627e50A40)   old Main, v2.1.0
TX 1   EndowmentSafe.enableModule(0xa23BEBFD3628D6Dd7B0638c147db11d9B6FaBD59)              new Main, v2.1.1
```

Artefacts, all in `karpatkey/client-configs` at commit `8f4fb0c34d` (PR #252):

- `clients/ens-dao/mainnet/payloads/ENS_Switch_ZRM.json` — the batch, re-encoded here as `expectedSwitchMultiSend.txt`
- `clients/ens-dao/mainnet/payloads/ens-main-zrm-compare-eth.html` — kpk's own diff page (not relied upon)

On-chain objects (block 25,941,653, tx `0x9b5b71d1…e3d60`, plus five configuration transactions up to block 25,941,858):

| Object      | Address                                      | Notes                                                                  |
| ----------- | -------------------------------------------- | ---------------------------------------------------------------------- |
| new Main    | `0xa23BEBFD3628D6Dd7B0638c147db11d9B6FaBD59` | EIP-1167 clone of Roles v2.1.1; avatar/target = Endowment Safe         |
| Sub         | `0x48dC0d88766a59E119e3f2585BC1dC5436Ee6ce0` | clone of v2.1.1; owner = kpk pod; target = new Main; member of MANAGER |
| mastercopy  | `0xF2964CE6161ce0e75964Fe7927cE114cb0B283D5` | canonical v2.1.1 (Zodiac README); bytecode reproduced from source      |
| owner (now) | `0xC01318baB7ee1f5ba734172bF7718b5DC6Ec90E1` | kpk's "test" instance Safe, 1-of-9 — see finding 1                     |

The Endowment Safe's sole owner is the EndowmentTimelock (`0x0bcC3dA6…`, 9-day delay) since "Empowering the ENS
Foundation" executed at block 25,729,925, so the batch is executed by the ENS Foundation Safe scheduling it there. It is
not executable as an ENS DAO proposal.

### Files

| File                           | Purpose                                                                                     |
| ------------------------------ | ------------------------------------------------------------------------------------------- |
| `calldataCheck.t.sol`          | Round-2 review: derives the switch batch, executes it through the Foundation path, verifies |
| `expectedSwitchMultiSend.txt`  | `ENS_Switch_ZRM.json` re-encoded as a MultiSend body — the diff target, not a source        |
| `rolesReplay.py`               | Reconstructs both Modifiers' MANAGER policy from their event histories and diffs them       |
| `rolesDiff.txt`                | Output of `rolesReplay.py` at block 25,984,988                                              |
| `roleStateKeys.json`           | Every target and (target, selector) either Modifier ever configured; consumed by the test   |
| `update10Payload.t.sol`        | Round-1 review of the 59-call payload, pinned to block 25,647,900 — the Update #10 delta    |
| `expectedMultiSend.txt`        | Round-1 diff target (the regenerated payload, byte-identical to the manual derivation)      |
| `annotationAddition.json`      | Round-1: annotation content posted by the payload's last transaction                        |
| `postFoundationSequence.t.sol` | Round-1 local simulation of the payload under Foundation ownership (block 25,676,000)       |
| `forum-post.md`                | Round-1 findings as posted (thread post 2)                                                  |
| `forum-reply-round-2.md`       | Round-2 findings, reply to thread post 4                                                    |

### Running

```bash
forge test --match-path "src/ens/proposals/ep-kpk-update-10/*" -vv
```

`rolesReplay.py` needs `eth-abi` and `eth-utils` and an archive RPC in `ETH_RPC_URL`; it refetches both event histories
and regenerates `rolesDiff.txt` and `roleStateKeys.json`.

### What the round-2 test proves

1. **Calldata.** The switch batch derived from the two Safe calls above is byte-identical to `ENS_Switch_ZRM.json`
   (`prevModule = SENTINEL` is correct: the old Main heads the Safe's module list).
2. **Execution path.** Scheduled by the Foundation Safe on the EndowmentTimelock, executable by anyone after nine days,
   cancellable by the Security Council veto wrapper. The DAO Timelock cannot execute it (`GS026`).
3. **Effect.** Modules become `[new Main, Allowance module]`; the old Main is disabled and can no longer execute
   (`GS104`), while remaining a dormant contract owned by the Safe. One Safe nonce is consumed.
4. **Policy equivalence, structurally.** `test_structuralEquivalence…` replays the round-1 Update #10 admin calls onto
   the old Main in the fork and compares the two Modifiers slot by slot over all 161 targets and 332 (target, selector)
   keys either Modifier ever configured: target clearance equal everywhere; condition trees, decoded from the packed
   buffers the Modifiers evaluate, canonically equal everywhere. 316 headers are byte-identical, 15 differ only in the
   order of Or alternatives (unordered by `PermissionChecker._or`) and one, `USDC.transfer`, only by a trailing
   unconstrained parameter (inert: `Decoder.inspect` derives the payload layout from the condition tree). Negative
   controls show the comparison tolerates reordering and detects a one-spender change or a wildcard. Members are the pod
   and the Sub; no allowances; no other roles; unwrappers are MultiSend and MultiSendCallOnly 1.4.1.
5. **Policy equivalence, behaviourally.** Every Update #10 permission verified in round 1 is re-asserted on the new Main
   after the switch (vaults, approvals, Horizon, Pendle, syrup pairs, distributor claims), together with the
   pre-existing approval lists and `USDC.transfer` pinned to the DAO Timelock. The Sub, once kpk configures the Harvest
   role on it, cannot redirect payouts or reach anything beyond the three distributors.
6. **MultiSend routing.** After the switch, batches must go through MultiSend 1.4.1; the 1.3.0 contracts are no longer
   unwrappers (and vice versa before).

The v2.1.1 mastercopy differs from v2.1.0 in three places (sources verified on Etherscan, runtime bytecode reproduced
with solc 0.8.21 / 100 runs): `SignatureChecker` now requires the EIP-1271 `staticcall` to succeed; `_or` iterates the
payload's children and resets consumptions per alternative; dynamic `EqualTo` values are plucked using the encoded
length instead of the payload size.

### Findings

1. **Blocking precondition — the new Main is owned by kpk's test Safe, not by the Endowment Safe.** `owner()` is
   `0xC01318…`, a 1-of-9 Safe. kpk's PR #252 lists the ownership transfer as "handled separately"; the forum post does
   not mention it. Until it is transferred, any single signer of that Safe can rewrite the Endowment's policy after the
   switch with no delay and no veto (`test_finding_…` moves the Safe's 2.9M sUSDS in one block). `test_switch` simulates
   the transfer as a precondition; `test_precondition_…` fails once the on-chain owner changes and must then be updated
   together with a re-run.
2. **Not a DAO vote.** The batch is executed by the Foundation through the EndowmentTimelock. The proposal thread still
   describes an on-chain executable vote; the veto window is only usable if the timelock operation id is published when
   scheduled.
3. **Harvest role still unconfigured.** The Sub has no roles or members; kpk configures it after the switch. The
   simulated configuration cannot exceed the MANAGER policy.

## Round 1 — the permission payload (forum posts 1–3)

`update10Payload.t.sol` manually derives the 59-transaction payload from the forum specification and proves it equals
kpk's regenerated payload (`expectedMultiSend.txt`), then asserts every permission it adds. Round-1 findings
(`forum-post.md`): the undisclosed sub-Roles instance, item 5 missing (later added as isolated syrup pairs), and a wrong
Steakhouse address in the spec; all answered by kpk in post 3. The payload is no longer executed as such, but the test
remains the reference derivation of the Update #10 delta that round 2 depends on.
