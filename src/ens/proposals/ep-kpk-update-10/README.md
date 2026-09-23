# Endowment permissions to kpk: Update #10

**Latest recheck:** [full security review, 2026-09-23](review-2026-09-23.md), pinned to Ethereum block 26,037,425;
ownership re-checked unchanged at block 26,038,524. A second adversarial pass (see
[adversarial-review.md](adversarial-review.md)) confirmed the conclusion and added a fail-closed gate. The
recommendation remains **NEEDS_REVIEW**.

## Proposal summary

[Forum post 4](https://discuss.ens.domains/t/draft-endowment-permissions-to-kpk-update-10/22323/4) replaces the
Endowment Safe's current Roles Modifier with a preconfigured replacement containing the existing MANAGER permissions
plus Update #10. The Foundation schedules execution through the EndowmentTimelock, whose delay is nine days. The
permission payload from round 1 is retained as the independently derived delta; it is no longer the executable proposal.

**Recommendation: NEEDS_REVIEW. Do not schedule the switch while the replacement is owned by kpk's test Safe.** The
tests simulate ownership transfer in the successful-switch scenario. Green tests do not mean that this external
precondition has been satisfied or that an actual scheduled transaction has been reviewed. That is what the fail-closed
gate (`failClosedGate.t.sol`, see Reproduction) certifies; at the recheck block it fails on the owner, as it should.

## Calldata verification

Published source:
[`ENS_Switch_ZRM.json`, commit `8f4fb0c34d8d1cc51d874930eb067c53d31b7f84`](https://github.com/karpatkey/client-configs/blob/8f4fb0c34d8d1cc51d874930eb067c53d31b7f84/clients/ens-dao/mainnet/payloads/ENS_Switch_ZRM.json),
also checked against the current upstream file. Both entries target the Endowment Safe,
`0x4F2083f5fBede34C2714aFfb3105539775f7FE64`, with value zero. Operation Call is the independently derived MultiSend
encoding; the Builder JSON does not state an operation.

| Call                             | Selector     | Arguments                                                                       | Result |
| -------------------------------- | ------------ | ------------------------------------------------------------------------------- | ------ |
| `disableModule(address,address)` | `0xe009cfde` | predecessor `address(1)`; old Main `0x703806E61847984346d2D7DDd853049627e50A40` | PASS   |
| `enableModule(address)`          | `0x610b5925` | new Main `0xa23BEBFD3628D6Dd7B0638c147db11d9B6FaBD59`                           | PASS   |

The manual interface-based derivation equals the published **274-byte MultiSend body**. The old Main is at the head of
the Safe's module list, so its predecessor is the sentinel. Reversing the calls with that predecessor fails atomically
under the reviewed wrapper.

[`referenceExecution.json`](referenceExecution.json) records the **unscheduled reference** used in the simulation: Safe
`execTransaction` to MultiSendCallOnly 1.3.0, DelegateCall, all gas/refund fields zero, and the EndowmentTimelock's
preapproved signature. It includes the target, value, predecessor, salt, delay, full schedule/execute calldata and
reference operation ID. Solidity independently derives and compares these fields.

- Safe calldata: **868 bytes**, keccak256 `0x24a2088d4064ae77c68c6077caad94f4376809f3a401c451dc7a7525ab501105`.
- Reference operation ID: `0x350becbe0c44ac653c437c8d378b01c0ab30b69a23486da9c9f1d063525878f3`.
- The reference salt is `keccak256("ENS_Switch_ZRM")`, predecessor zero, delay 777,600 seconds. These are review
  assumptions, not a claim about a Foundation-submitted operation.

The Foundation's eventual `CallScheduled` transaction must be checked against its complete operation tuple. A different
wrapper can change the outcome: the boundary test demonstrates nonzero `safeTxGas` allowing a failed Safe action to
consume its nonce and mark the timelock operation done without switching modules. An operation ID alone does not prove
the scheduled bytes match this review.

## Assertion results

The historical simulation forks block **25,984,900**. The latest current-state recheck is pinned separately to block
**26,037,425**, hash `0xfb29dae51cd328ec64208e4135cee8bbbb702d8e8d58aa6b3d58b11da297ce31` (2026-09-23 03:13:47 UTC). The
fork is selected with `REVIEW_BLOCK`; omitting it always runs the historical regression, not a live monitor.

| Area             | Before execution                                                                          | After execution / adversarial check                                                                                                                                                                                                                                                           |
| ---------------- | ----------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Safe control     | EndowmentTimelock sole owner, threshold 1; modules old Main and Allowance; nonce captured | Modules new Main and Allowance; old Main disabled; nonce increases exactly once; old Main execution rejected                                                                                                                                                                                  |
| Timing and veto  | Foundation proposer, open executor, nine-day delay; active Security Council veto          | Early execution rejected, including one second before readiness; replay and unmet predecessor rejected; veto cancels execution                                                                                                                                                                |
| Modifier wiring  | New Main/Sub clone implementation, owner/avatar/target, members, default role, adapters   | Main gates pod and Sub; Sub cannot bypass MANAGER by forwarding a forbidden call                                                                                                                                                                                                              |
| Policy storage   | Old Main independently reconstructed and Update #10 applied                               | 161 historical targets and 360 historical function keys compared: 151 active targets, 332 configured functions, 28 revoked functions zero on both                                                                                                                                             |
| Conditions       | Decode actual packed buffers from storage                                                 | 316 byte-identical permission entries; 15 safe Or reorderings; one root trailing Static Pass difference; no policy mismatch                                                                                                                                                                   |
| Permissions      | Probe permissions absent on old Main                                                      | Positive and negative vault, approval, Horizon, Pendle, syrup and distributor checks; all ten missing round-1 negative cases restored                                                                                                                                                         |
| Batching         | Old Main unwraps MultiSend 1.3.0                                                          | New Main unwraps both 1.4.1 entrypoints and rejects 1.3.0; forbidden items, inner delegatecalls, nested batches, inner/outer value and malformed encodings are rejected with the same Roles error on old and new Main; Sub-originated batches, value and delegatecall stay bounded by MANAGER |
| ETH sink         | Old Main sends ETH only to the DAO Timelock                                               | New Main sends any amount of ETH, empty calldata, only to the DAO Timelock (EP 6.39); other recipients and value on non-Send functions rejected                                                                                                                                               |
| Signature path   | Appended EIP-1271 module signatures accepted from enabled members                         | A signer that reverts with the magic value is accepted by old Main (v2.1.0) and rejected by new Main (v2.1.1); pod and Sub cannot be impersonated; replay blocked                                                                                                                             |
| Closure          | Ownership transfer simulated                                                              | No MANAGER path (pod or Sub; call, delegatecall or MultiSend) reaches an `onlyOwner` function of new Main, Sub or old Main, or the Safe's owners, threshold, modules or guard                                                                                                                 |
| Owner compromise | Actual new Main owner remains test Safe                                                   | Untransferred owner widens `sUSDS.transfer`; pod transfers the Safe's entire observed balance to another recipient                                                                                                                                                                            |

Positive permission probes intentionally allow the downstream protocol call to fail (for example, insufficient balance
or an invalid reward proof). They prove authorization by Roles, not economic execution of every protocol action. The
actual Safe switch, veto, ownership exploit and failure-boundary tests assert observable state changes or exact reverts.

The event replay and storage comparison are complementary. The event census finds keys outside the committed fixture; a
standalone fixed-key storage test cannot exclude a newly introduced key, so the fixture's contents are pinned by hash in
the test. Re-run the full replay and the gate before scheduling and execution. The replay fails closed on unknown or
reorged events, duplicate log positions, foreign-address logs, unsupported allowance histories, unproven normalization
cases, and any difference in new-Main members, modules, roles, default roles, unwrappers, avatar, target or owner. Or
alternatives are only normalized when every child has an identical operator/type shape and only pure operators are
involved. Only a trailing Static Pass directly under the root Calldata Matches is pruned; Dynamic, Array and nested
Tuple counterexamples are retained as regressions.

**Carried over, not new.** MANAGER keeps the two EP 6.23 Safe self-configuration permissions: switching the Endowment
Safe's fallback handler to the pinned ExtensibleFallbackHandler `0x2f55e8b20D0B9FEFA187AA7d00B6Cbe563605bF5` (one way)
and registering ComposableCoW `0xfdaFc9d1902f4e0b84f65F49f244b32b31013b74` as the CoW-domain verifier. Neither has been
used. The Allowance module keeps one delegate, `0x91c32893216dE3eA0a55ABb9851f581d4503d39b`, with 30 ETH per 36,000
minutes; it cannot reach either Roles module. The Security Council veto on the EndowmentTimelock expires on 2028-08-07.

**Baseline provenance.** The old Main's final policy before Update #10 (137 targets, 301 functions) traces to 14
transactions: kpk's test-Safe configuration before the May 2024 hand-off, which EP 5.12 adopted by reference (45 targets
and 84 functions, none with DelegateCall), and eight executed proposals (EP 5.12, 5.14, 6.8, 6.23, 6.27, 6.38, 6.39,
6.41). This review carries that policy over; it does not re-assess the economics of those venues.

## Mastercopy verification

The old Main is an EIP-1167 clone of `0x9646fDAD06d3e24444381f44362a3B0eB343D337`. The new Main and Sub
(`0x48dC0d88766a59E119e3f2585BC1dC5436Ee6ce0`) use `0xF2964CE6161ce0e75964Fe7927cE114cb0B283D5`, the v2.1.1 replacement
in
[upstream mastercopies.json](https://github.com/gnosisguild/zodiac-modifier-roles/blob/218a5164d739c107b132034436978e78cdd90c95/packages/evm/mastercopies.json).

The verified-source changes are:

1. EIP-1271 signature verification requires the `staticcall` to succeed.
2. `_arraySome` visits payload elements and resets allowance consumption between alternatives.
3. `_bitmask` uses the encoded length of dynamic bytes instead of padded payload length.

Fresh recompilation of both Etherscan-verified source bundles used solc 0.8.21, optimizer 100 runs, Shanghai, and their
deployed Integrity/Packer link addresses. The executable runtimes match after removing the 53-byte CBOR metadata
trailer: 24,356 bytes (v2.1.1) and 24,348 bytes (v2.1.0). Full metadata-inclusive bytecode does **not** match. The
linked libraries also match after removing CBOR and normalizing the leading 20-byte library self-address. See
[adversarial-review.md](adversarial-review.md) for hashes and provenance.

`_or` and `EqualTo` did not change; the prior report misidentified those two hunks. Neither ArraySome nor Bitmask nor
allowance operators occurs in the reviewed MANAGER policies. The pod's fallback handler is zero at the recheck block,
consistent with the stated interim mitigation. The EIP-1271 change is verified by source and deployed-code comparison
and by a runtime regression (`eip1271Path.t.sol`, pinned to block 26,037,425): a signer whose `isValidSignature` reverts
with data beginning with the magic value is accepted by the old Main and rejected by the new Main with `NotAuthorized`;
a magic-returning positive control shows the appended-signature path is live on both, and replay is blocked. Naming the
pod or the Sub as signer is rejected on both versions, with the pod's zero fallback handler and with the standard
CompatibilityFallbackHandler.

## Findings

1. **CRITICAL: ownership transfer is still missing.** At block 26,038,524, `owner()` of the new Main is
   `0xC01318baB7ee1f5ba734172bF7718b5DC6Ec90E1`, a 1-of-9 test Safe. Once enabled, that owner can rewrite policy without
   the Foundation timelock or veto. The historical exploit moves about 2.94 million sUSDS; the current proof uses the
   observed balance without assuming a fixed amount.
   - Only the current owner can fix this. `transferOwnership` is OpenZeppelin v5 `onlyOwner`, one step; the same call
     from the Endowment Safe, the EndowmentTimelock or the Foundation Safe reverts with `OwnableUnauthorizedAccount`, so
     the Foundation batch cannot include it. The test Safe can also call `renounceOwnership()`, which would leave a Main
     whose policy nobody can amend, recoverable only by another nine-day switch.
   - The executor role is open: once scheduled, anyone can execute the switch after nine days, whoever then owns the
     Main. The deadline is therefore **before scheduling**, not before execution.
   - Required sequence: kpk calls `transferOwnership(0x4F2083f5fBede34C2714aFfb3105539775f7FE64)` from the test Safe as
     a standalone transaction with no other Modifier changes, as it did for the current Modifier on 2 May 2024
     ([tx](https://etherscan.io/tx/0x78c69c7ad0c5f430d97ec5c3bac5cb649d831a756b3d4c5b09b45152427ae8f4)) before the
     Endowment enabled it. The Foundation confirms `owner()` and a passing gate and replay at the transfer block before
     it schedules; the Security Council repeats both before the operation becomes ready and cancels if either fails (its
     veto wrapper holds `PROPOSER_ROLE`, which gates `cancel` in TimelockController 4.3.2).
2. **IMPORTANT: the final scheduled wrapper remains unreviewed.** The published file contains only the two Safe module
   calls. Publish the scheduling transaction and complete operation tuple so the wrapper, operation ID and veto window
   can be verified. The event already exposes the ID and calldata; a forum notice helps reviewers locate it. The forum's
   reference to an executable DAO vote should be updated to the Foundation path.
3. **IMPORTANT: Sub ownership permits delegation beyond Harvest.** The kpk pod owns the Sub and can grant third parties
   any subset of MANAGER, or transfer the Sub, without a new ENS transaction. The Main limits delegated authority to
   MANAGER; it does not permanently restrict the Sub to three distributors. The pod also remains a direct Main member,
   so not every transaction goes through the Sub. Confirm the intended delegation policy and the controller of the
   published Harvest member, `0x14C2d2D64C4860ACF7CF39068eb467D7556197de`.
4. **INFO: Harvest remains unconfigured.** The Sub has no enabled members at the recheck block. The test simulates a
   configuration and verifies the Main's ceiling; it does not certify a future live Harvest policy. Verify its actual
   role key, members, permissions and adapters after configuration.

## Reproduction and files

Install Foundry, Node/npm and Python dependencies, then run from the repository root:

```bash
git clone https://github.com/blockful/dao-proposals.git
cd dao-proposals
git checkout 72df520ab6e4b15d5fe554107db79ca12e1538be
npm ci
export MAINNET_RPC_URL="<archive-mainnet-rpc>"
forge test --match-path "src/ens/proposals/ep-kpk-update-10/*" -vv
REVIEW_BLOCK=26037425 forge test --match-path "src/ens/proposals/ep-kpk-update-10/*" -vv
```

**Fail-closed gate.** Run this at the ownership-transfer block, at the `CallScheduled` block, and again before the
operation becomes ready. Every test must pass; `test_finding…` is skipped once the Endowment Safe owns the new Main.
Without `REVIEW_GATE_BLOCK` the gate only runs a pinned regression at block 26,037,425 and certifies nothing:

```bash
REVIEW_BLOCK=<block> REVIEW_GATE_BLOCK=<block> forge test --match-path "src/ens/proposals/ep-kpk-update-10/*" -vv
```

The gate requires the new Main's owner, avatar and target to be the Endowment Safe; its members, default roles and
unwrappers to be exactly the reviewed ones; the Endowment Safe's owner, threshold, guard, fallback handler and modules
to be unchanged; **no** event on the new Main or Sub after the configuration block other than the ownership transfer;
and every `CallScheduled` on the EndowmentTimelock to carry exactly the reference Safe calldata (keccak `0x24a2088d…`),
zero value, zero predecessor and a delay of at least nine days. A Harvest configuration on the Sub, or the pod switching
the Safe's fallback handler under EP 6.23, also fails the gate by design and must be reviewed. On a local fork, an
honest standalone transfer passes the gate; a transfer bundled with a second pod role and a rogue `sUSDS.transfer`
unwrapper leaves every other test green and fails only the gate.

For the independent event census and its regression suite (requires uv):

```bash
uv run src/ens/proposals/ep-kpk-update-10/rolesReplay.py --block 26037425 --no-write
uv run --python 3.13 --with pytest --with eth-abi --with eth-utils --with "eth-hash[pycryptodome]" python -m pytest src/ens/proposals/ep-kpk-update-10/test_roles_replay.py -q
```

`rolesReplay.py` uses inline dependency metadata. Its default online end block is resolved once for both histories.
`--block` pins the snapshot and `--no-write` preserves the committed historical fixtures. Saved `--logs` inputs must
carry matching addresses and `toBlock` metadata. Exit codes: 0 = policy, wiring and owner as reviewed; 1 = any policy or
wiring difference; 3 = policy and wiring match but the owner is not the Endowment Safe (the result at block 26,037,425).
After regenerating `roleStateKeys.json`, run Prettier and update the fixture hashes in `calldataCheck.t.sol` in the same
commit.

Reproduce at commit `72df520ab6e4b15d5fe554107db79ca12e1538be`; the branch moves. The two round-1 suites and the
explicitly historical ownership-precondition regression keep their original fork blocks even when `REVIEW_BLOCK` is
supplied. RPC values are supplied locally and must not be committed.

| File                                                                        | Purpose                                                                  |
| --------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| `calldataCheck.t.sol`                                                       | Switch, policy equivalence, authorization and semantic regression tests  |
| `executionBoundary.t.sol`                                                   | Full reference bytes, delay/replay/dependency and Safe failure behavior  |
| `failClosedGate.t.sol`                                                      | Gate: certifies `REVIEW_GATE_BLOCK`; otherwise a pinned regression       |
| `eip1271Path.t.sol`                                                         | Appended EIP-1271 module-signature regression, old versus new Main       |
| `closureAfterTransfer.t.sol`                                                | After the transfer, no MANAGER path reaches Roles or Safe administration |
| `review-2026-09-23.md`                                                      | Fresh-pin security review                                                |
| `referenceExecution.json`                                                   | Explicit unscheduled reference operation                                 |
| `expectedSwitchMultiSend.txt`                                               | Published batch comparison fixture                                       |
| `rolesReplay.py`, `rolesSemantics.py`, `test_roles_replay.py`               | Event reconstruction, canonicalization guards and their regressions      |
| `roleStateKeys.json`, `rolesDiff.txt`                                       | Storage-key census fixture and replay output                             |
| `adversarial-review.md`                                                     | Both adversarial passes: dispositions, fixes and verification limits     |
| `forum-reply-round-2.md`                                                    | Concise reply draft                                                      |
| `update10Payload.t.sol`, `expectedMultiSend.txt`, `annotationAddition.json` | Historical 59-call delta and round-1 fixtures                            |
| `postFoundationSequence.t.sol`, `forum-post.md`                             | Historical execution-path test and original findings                     |
