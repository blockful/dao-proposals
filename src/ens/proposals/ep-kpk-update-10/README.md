# Endowment permissions to kpk: Update #10

## Proposal summary

[Forum post 4](https://discuss.ens.domains/t/draft-endowment-permissions-to-kpk-update-10/22323/4) replaces the
Endowment Safe's current Roles Modifier with a preconfigured replacement containing the existing MANAGER permissions
plus Update #10. The Foundation schedules execution through the EndowmentTimelock, whose delay is nine days. The
permission payload from round 1 is retained as the independently derived delta; it is no longer the executable proposal.

**Recommendation: NEEDS_REVIEW. Do not schedule the switch while the replacement is owned by kpk's test Safe.** The
tests simulate ownership transfer in the successful-switch scenario. Green tests do not mean that this external
precondition has been satisfied or that an actual scheduled transaction has been reviewed.

## Calldata verification

Published source:
[`ENS_Switch_ZRM.json`, commit `8f4fb0c34d8d1cc51d874930eb067c53d31b7f84`](https://github.com/karpatkey/client-configs/blob/8f4fb0c34d8d1cc51d874930eb067c53d31b7f84/clients/ens-dao/mainnet/payloads/ENS_Switch_ZRM.json),
also checked against the current upstream file. Both entries target the Endowment Safe,
`0x4F2083f5fBede34C2714aFfb3105539775f7FE64`, with operation Call and value zero.

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

The historical simulation forks block **25,984,900**. A current-state recheck is pinned separately to block
**26,034,037**, hash `0x9879ebe29da19e645f50115471695a7d237b2410f2f1513183c5a94b21748898` (2026-09-22 15:51:11 UTC). The
fork is selected with `REVIEW_BLOCK`; omitting it always runs the historical regression, not a live monitor.

| Area             | Before execution                                                                          | After execution / adversarial check                                                                                                               |
| ---------------- | ----------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| Safe control     | EndowmentTimelock sole owner, threshold 1; modules old Main and Allowance; nonce captured | Modules new Main and Allowance; old Main disabled; nonce increases exactly once; old Main execution rejected                                      |
| Timing and veto  | Foundation proposer, open executor, nine-day delay; active Security Council veto          | Early execution rejected, including one second before readiness; replay and unmet predecessor rejected; veto cancels execution                    |
| Modifier wiring  | New Main/Sub clone implementation, owner/avatar/target, members, default role, adapters   | Main gates pod and Sub; Sub cannot bypass MANAGER by forwarding a forbidden call                                                                  |
| Policy storage   | Old Main independently reconstructed and Update #10 applied                               | 161 historical targets and 360 historical function keys compared: 151 active targets, 332 configured functions, 28 revoked functions zero on both |
| Conditions       | Decode actual packed buffers from storage                                                 | 316 byte-identical permission entries; 15 safe Or reorderings; one root trailing Static Pass difference; no policy mismatch                       |
| Permissions      | Probe permissions absent on old Main                                                      | Positive and negative vault, approval, Horizon, Pendle, syrup and distributor checks; all ten missing round-1 negative cases restored             |
| Batching         | Old Main unwraps MultiSend 1.3.0                                                          | New Main unwraps both 1.4.1 entrypoints and rejects 1.3.0                                                                                         |
| Owner compromise | Actual new Main owner remains test Safe                                                   | Untransferred owner widens `sUSDS.transfer`; pod transfers the Safe's entire observed balance to another recipient                                |

Positive permission probes intentionally allow the downstream protocol call to fail (for example, insufficient balance
or an invalid reward proof). They prove authorization by Roles, not economic execution of every protocol action. The
actual Safe switch, veto, ownership exploit and failure-boundary tests assert observable state changes or exact reverts.

The event replay and storage comparison are complementary. The event census finds keys outside the committed fixture; a
standalone fixed-key storage test cannot exclude a newly introduced key. Re-run the full replay and compare its output
before scheduling and execution. The replay rejects unknown events, unsupported allowance histories, target mismatches
and unproven normalization cases. Or alternatives are only normalized with matching decoder type trees and supported
pure operators. Only a trailing Static Pass directly under the root Calldata Matches is pruned; Dynamic, Array and
nested Tuple counterexamples are retained as regressions.

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
consistent with the stated interim mitigation. That observed configuration is not a claim that MANAGER restrictions
alone universally prevent the signature vulnerability. The EIP-1271 change is verified by source and deployed-code
comparison; this review does not include a runtime regression for the appended-contract-signature path.

## Findings

1. **CRITICAL: ownership transfer is still missing.** At the recheck block, `owner()` of the new Main is
   `0xC01318baB7ee1f5ba734172bF7718b5DC6Ec90E1`, a 1-of-9 test Safe. Once enabled, that owner can rewrite policy without
   the Foundation timelock or veto. Transfer ownership to the Endowment Safe before scheduling, then repeat state and
   policy verification. The historical exploit moves about 2.94 million sUSDS; the current proof uses the observed
   balance without assuming a fixed amount.
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
git checkout ens/kpk-update-10-zrm-switch
npm ci
export MAINNET_RPC_URL="<archive-mainnet-rpc>"
forge test --match-path "src/ens/proposals/ep-kpk-update-10/*" -vv
REVIEW_BLOCK=26034037 forge test --match-path "src/ens/proposals/ep-kpk-update-10/*" -vv
```

For the independent event census and its regression suite (requires uv):

```bash
uv run src/ens/proposals/ep-kpk-update-10/rolesReplay.py --block 26034037 --no-write
uv run --python 3.13 --with pytest --with eth-abi --with eth-utils --with "eth-hash[pycryptodome]" python -m pytest src/ens/proposals/ep-kpk-update-10/test_roles_replay.py -q
```

`rolesReplay.py` uses inline dependency metadata. Its default online end block is resolved once for both histories.
`--block` pins the snapshot and `--no-write` preserves the committed historical fixtures. Saved `--logs` inputs must
carry matching addresses and `toBlock` metadata.

Use the commit linked by the review handoff for immutable reproduction. The two round-1 suites and the explicitly
historical ownership-precondition regression keep their original fork blocks even when `REVIEW_BLOCK` is supplied. RPC
values are supplied locally and must not be committed.

| File                                                                        | Purpose                                                                 |
| --------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| `calldataCheck.t.sol`                                                       | Switch, policy equivalence, authorization and semantic regression tests |
| `executionBoundary.t.sol`                                                   | Full reference bytes, delay/replay/dependency and Safe failure behavior |
| `referenceExecution.json`                                                   | Explicit unscheduled reference operation                                |
| `expectedSwitchMultiSend.txt`                                               | Published batch comparison fixture                                      |
| `rolesReplay.py`, `roleStateKeys.json`, `rolesDiff.txt`                     | Event reconstruction and storage-key census                             |
| `adversarial-review.md`                                                     | Recovered swarm status, confirmed fixes and verification limits         |
| `forum-reply-round-2.md`                                                    | Concise reply draft                                                     |
| `update10Payload.t.sol`, `expectedMultiSend.txt`, `annotationAddition.json` | Historical 59-call delta and round-1 fixtures                           |
| `postFoundationSequence.t.sol`, `forum-post.md`                             | Historical execution-path test and original findings                    |
