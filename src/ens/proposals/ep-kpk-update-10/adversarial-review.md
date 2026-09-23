# Update #10 adversarial review

## Scope and recommendation

This is the continuation of the module-swap review at `e9b07261643aebe2b401ea4e5389d653ecf8a690`. It covers the official
discussion, all published switch calls, the Safe/timelock wrapper, complete Main policy histories, the Update #10 delta,
packed condition buffers, authorization, Sub delegation, implementation provenance, and the report's claims.

**NEEDS_REVIEW remains the proposal recommendation.** The new Main is still owned by the 1-of-9 test Safe at block
26,034,037, at the fresh pin 26,037,425 ([review-2026-09-23.md](review-2026-09-23.md)) and at block 26,038,524.
Ownership transfer, the actual scheduled operation and future Harvest configuration are external state that this review
cannot declare completed. The [security report](README.md) lists the actions needed before approval.

## Recovered swarm and continuation

The original workflow started 164 agents. Only 11 attackers returned substantive structured reports, containing 48
entries, including no-finding observations. The other 153 jobs failed at the session limit: 144 refuters, four
deliverable auditors, three attackers, a critic and a synthesis agent. **Zero original refuters delivered a verdict.
Failure to run is not confirmation of a finding.**

This continuation recovered the raw evidence, consolidated 25 topics, freshly fetched primary sources and chain state,
reproduced the actionable defects, and added permanent regressions. It does not claim the original 144-refuter procedure
completed. The new completeness critic identified one further missing security-path check: appended EIP-1271 module
signatures, which direct-member prank tests do not exercise. It is now covered by `eip1271Path.t.sol` (second pass,
below). Final review verdicts are recorded in [review-2026-09-23.md](review-2026-09-23.md) at commit
`72df520ab6e4b15d5fe554107db79ca12e1538be`.

## Finding disposition

| Topic                                            | Disposition and evidence                                                                                                                                                                                                                                                                                                                   |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| R1: full scheduled wrapper absent                | Confirmed. Published source has two inner Safe calls only. `referenceExecution.json` and five `executionBoundary.t.sol` tests pin the reviewed wrapper and demonstrate why its gas fields matter. Actual scheduled tuple still requires review.                                                                                            |
| R2: generic trailing-Pass pruning                | Confirmed and fixed in Python and Solidity. Fork regressions show Dynamic bounds, Array arity and Tuple offset divergences. Pruning is now limited to root Calldata Static Pass leaves.                                                                                                                                                    |
| R3: 28 revoked keys omitted                      | Confirmed and fixed. Historical function census is 360; all 28 revoked entries are checked zero on both Mains. Reactivation is detected. A fresh replay remains necessary to discover future new keys.                                                                                                                                     |
| R4: unsafe logical reordering                    | Confirmed guard gap and fixed. Only pure Or subtrees with equal decoder type trees may be sorted; And/Nor remain ordered. The broader claim that both heterogeneous Or orders can be configured was refuted: Integrity rejects one ordering. A local buffer mutation isolates the decoder difference without claiming both are deployable. |
| R5: wrong mastercopy diff description            | Confirmed and corrected: `_arraySome` and `_bitmask`, not `_or` and EqualTo. Fresh source comparison and compilation support the correction.                                                                                                                                                                                               |
| R6–R7: Harvest ceiling and standing delegation   | Confirmed disclosure gap. The pod owns the Sub and can delegate any MANAGER-bounded subset or transfer the Sub. Three-distributor scope is a proposed configuration, not a permanent architectural cap. Pod remains a direct Main member.                                                                                                  |
| R8: signature safeguard narrative                | Zero pod fallback handler independently verified. The signature patch is identified separately from MANAGER policy; no universal historical no-loss claim is adopted. The EIP-1271 change is source- and bytecode-verified; the appended-contract-signature path has a runtime regression (eip1271Path.t.sol).                             |
| R9: module-head drift                            | Relevant precondition. Recheck head before execution; wrong predecessor fails atomically only under the reviewed Safe failure-propagation settings.                                                                                                                                                                                        |
| R10: ten missing negatives                       | Restored: seven vault redeem owner pins, foreign Pendle YT, syrupUSDT bad spender and syrupUSDC forbidden transfer.                                                                                                                                                                                                                        |
| R11: positive probes versus protocol success     | Clarified. Roles permission acceptance can be proved even when the inner venue call fails; those probes do not prove balances, liquidity or reward proofs.                                                                                                                                                                                 |
| R12: simulated ownership and stale balance floor | Clarified historical versus selected-block tests; exploit uses the observed positive sUSDS balance. The arbitrary one-million-token minimum was removed without weakening the exact drain assertion.                                                                                                                                       |
| R13: synthetic DAO error check                   | Strengthened: exact GS026 is checked on the actual switch wrapper.                                                                                                                                                                                                                                                                         |
| R14: counts described inconsistently             | Clarified: 151 active/161 historical targets; 332 configured/360 historical function keys. Solidity applies 50 policy calls; Python applies those plus three old-Sub wiring calls, skipping six other calls out of the historical 59.                                                                                                      |
| R15: v2.1.1 provenance                           | Upstream versioned `mastercopies.json` at `218a5164d739c107b132034436978e78cdd90c95` establishes the label/address. “Only kpk's label” is refuted; README alone was an incomplete citation.                                                                                                                                                |
| R16: bytecode match overstated                   | Corrected. Executable bytes match after 53-byte CBOR removal; full metadata-inclusive runtime does not. Linked library self-address normalization is also disclosed.                                                                                                                                                                       |
| R17: stale forum/delta annotations               | Forum's old payload URL is explicitly struck through, so it is not an active competing payload. DAO-vote wording is still stale. Historical round-1 comments are not used as the current specification.                                                                                                                                    |
| R18: operation notice versus veto ability        | Corrected: CallScheduled exposes ID/calldata without a forum notice. Publishing the scheduling transaction improves discoverability and enables complete-byte review.                                                                                                                                                                      |
| R19: Foundation controls veto configuration      | Existing control-stack context, not a new effect of the two-call switch. Tests assert the current veto remains active through the simulated window.                                                                                                                                                                                        |
| R20: unsupported replay behavior                 | Unknown topics/actions and allowance histories fail closed. Delta parser rejects unsupported execution modes, values, truncation and unknown old-Main methods. Wiring and owner are part of the exit code (1 on any difference, 3 while the owner is not the Endowment Safe).                                                              |
| R21: old annotation not reposted                 | Historical annotation is not part of the two-call switch and does not grant permissions. No annotation-equivalence claim is made.                                                                                                                                                                                                          |
| R22: approval delta mapping                      | Existing tests preserve spender lists while adding WETH→ETH-yield, USDS→Pendle, and USDC→four vaults. Syrup pairs remain isolated; no global cross-product expansion is asserted.                                                                                                                                                          |
| R23: HARVEST/HARVESTER naming                    | Live role key remains unconfigured; verify the eventual key and members instead of assuming the prose label.                                                                                                                                                                                                                               |
| R24: stale current-state claims                  | Fresh block pin confirms ownership/module/policy state. Pod changed from 2-of-7 to 2-of-6, with threshold and zero fallback handler unchanged; no Main/Sub configuration drift.                                                                                                                                                            |
| R25: Transaction Builder checksum                | Empty checksum does not alter the decoded calls. No browser import test is claimed in this continuation. The complete published ABI/input entries and bytes were independently checked.                                                                                                                                                    |

## Source and bytecode provenance

Continuation snapshot (superseded by the 26,037,425 recheck in review-2026-09-23.md): Ethereum block **26,034,037**,
hash `0x9879ebe29da19e645f50115471695a7d237b2410f2f1513183c5a94b21748898`, **2026-09-22 15:51:11 UTC**. Historical fork:
25,984,900. Complete event histories contain 617 old-Main and 495 new-Main events; neither has configuration events
after the historical fork. The Sub has eight setup events and no role/member configuration.

- [Official topic and complete four-post stream](https://discuss.ens.domains/t/22323.json).
- [Switch source at full commit](https://github.com/karpatkey/client-configs/blob/8f4fb0c34d8d1cc51d874930eb067c53d31b7f84/clients/ens-dao/mainnet/payloads/ENS_Switch_ZRM.json):
  1,449 bytes, SHA-256 `e621b47f0a2582adbac2e73eeac013d8149bc81625bd4b5d785b5edf2538168a`; current upstream content
  identical.
- [Upstream versioned mastercopy registry](https://github.com/gnosisguild/zodiac-modifier-roles/blob/218a5164d739c107b132034436978e78cdd90c95/packages/evm/mastercopies.json).
- [Verified new Roles source](https://etherscan.io/address/0xF2964CE6161ce0e75964Fe7927cE114cb0B283D5#code) and
  [verified old source](https://etherscan.io/address/0x9646fDAD06d3e24444381f44362a3B0eB343D337#code).
- [Corrected ArraySome hunk](https://github.com/gnosisguild/zodiac-modifier-roles/blob/218a5164d739c107b132034436978e78cdd90c95/packages/evm/contracts/PermissionChecker.sol#L427)
  and
  [Bitmask hunk](https://github.com/gnosisguild/zodiac-modifier-roles/blob/218a5164d739c107b132034436978e78cdd90c95/packages/evm/contracts/PermissionChecker.sol#L593).
- [Pod fallback-handler removal transaction](https://etherscan.io/tx/0x10c073b3d0beaded14aa4d3ef57d524818f9f9a9e657b9c760f0b3d58eabea28)
  and
  [pod owner removal during this review](https://etherscan.io/tx/0x5bf8c6ee060c1ca35bd347041eda477bd27610ba9c85b92669bc723746b738e4).

Fresh verified-source compilation: **solc 0.8.21+commit.d9974bed**, optimizer enabled/100 runs, Shanghai, no via-IR,
IPFS metadata. Both Roles versions link Integrity `0x6a6Af4b16458Bc39817e4019fB02BD3b26d41049`; old/new Packer addresses
are `0x61c5b1be435391fdd7bc6703f3740c0d11728a8c` / `0x869718c939652084bc491fbc5ce0d3c1d5b309f0`.

| Runtime     | Full deployed bytes | Full deployed keccak256                                              | Equal executable bytes after normalization |
| ----------- | ------------------: | -------------------------------------------------------------------- | -----------------------------------------: |
| Roles 2.1.1 |              24,409 | `0x471d8b3b419f1eb955230c0326c8812176df49bf3c7b414a563fda5a3c6c10b6` |                                     24,356 |
| Roles 2.1.0 |              24,401 | `0x87911cbc6aa0496e6bcb07dab2462b9c76daea130dede6dcc57d0adf307fa7ec` |                                     24,348 |
| Integrity   |               5,637 | `0xee8ec55ea4ac609a3fc768eccf3f0479631454fe0a802e4a4b8132102d10d495` |                                      5,584 |
| New Packer  |               2,138 | `0xc28f5fb0c8857669286d01e3df89f310d5ddfbf98205ad46d2f7d28767a76c82` |                                      2,085 |
| Old Packer  |               2,138 | `0xd22ba4e0e51926cd6562bcb9709899789662a165e2ef7669e9a16602313f087d` |                                      2,085 |

Normalization removes the 51-byte CBOR metadata payload and its two-byte length suffix (53 bytes total). Libraries
additionally normalize the leading PUSH20 self-address that deployment replaces. Old/new Packer executable code then
matches each other. All three clone byte sequences are exactly 45-byte EIP-1167 proxies pointing at the expected
mastercopy.

## Regression evidence and limits

The original nine committed Foundry tests passed before changes. Five new semantic regressions failed against the old
comparator for the expected equality defects, then passed after hardening. Python regressions likewise distinguished the
original unsafe behavior from the hardened implementation, including CLI nonzero exit on target mismatches. The final
test commands are in [README.md](README.md); reproduce at commit `72df520ab6e4b15d5fe554107db79ca12e1538be`.

No production state was changed. Ownership handover, a real scheduled transaction, future Harvest permissions,
protocol-level economics, and universal historical exploitability are not certified. This review verifies authorization
and execution at explicit state snapshots. It is not an investment-risk assessment of the permitted venues.

## Second pass (HEAD 93aec85)

A second adversarial pass ran 39 agents against the hardened HEAD, all of which completed: five attackers (Solidity
hardening with mutation testing, Python tooling with crafted logs and mutants, documented claims, the EIP-1271 signature
path, and five carried items), two refuters for every important finding, a completeness critic and four gap attackers.
It returned 39 findings: 8 confirmed, 6 contested, 25 informational, none refuted and none that changes the
recommendation. Every re-derived byte, hash, count, bytecode match and policy-equivalence result held.

| Topic                                         | Disposition and evidence                                                                                                                                                                                                                                                                |
| --------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| S1: no fail-closed exit criterion             | Confirmed. With the test Safe bundling a second pod role (Target clearance on sUSDS) and a rogue `sUSDS.transfer` unwrapper into its ownership transfer, every behavioural test stayed green and the replay exited 0. Fixed: `failClosedGate.t.sol` and replay wiring/owner exit codes. |
| S2: replay exit code ignored wiring and owner | Confirmed. Fixed with an expected-wiring check (exit 1) and an owner check (exit 3); five rogue-wiring and one owner regression added.                                                                                                                                                  |
| S3: structural fixture not pinned             | Confirmed: emptying `.targets` stayed green and a revoked-key substitution hid a reactivated function. Fixed: counts and content hashes of all five fixture arrays are asserted.                                                                                                        |
| S4: who can fix ownership                     | Confirmed. Only the test Safe can call `transferOwnership`; it can also renounce; the open executor runs the switch whoever owns the Main. The required sequence and the May 2024 precedent are now stated.                                                                             |
| S5: EIP-1271 runtime regression               | Closed: `eip1271Path.t.sol` (6 tests) shows revert-with-magic accepted on v2.1.0 and rejected on v2.1.1, a live positive control, real members rejected, and replay blocked.                                                                                                            |
| S6: batch and forwarding controls             | Added `test_batchNegativeControls…`: old and new Main reject the same malformed or forbidden batches with the same error; Sub-originated batches stay bounded by MANAGER. Four of seven policy or adapter mutants had previously passed every test.                                     |
| S7: closure after the transfer                | Added `closureAfterTransfer.t.sol` (15 tests, 3 fuzzed, 2 negative controls): no MANAGER path reaches Roles or Safe administration; the EP 6.23 fallback-handler switch is the only Safe self-configuration.                                                                            |
| S8: Or-reorder guard                          | Two Integrity-valid Or trees with equal decoder types but different operators authorise differently (revert order). Guard tightened to identical operator/type shape in Solidity and Python; the 15 real reorderings are unaffected.                                                    |
| S9: weak isolated tests                       | Execution-option controls added; GS013 pinned as the Safe-level reason; the revoked-reactivation test now runs the real comparison after a passing control; `test_precondition…` renamed `test_historical…`.                                                                            |
| S10: Python input hygiene                     | Replay rejects reorged, duplicate and foreign-address logs and mismatched AssignRoles arrays; JSON output is deterministic; dependency resolution is pinned; caches and downloads are ignored.                                                                                          |
| S11: documents                                | Unpinned links and the 20/20 fresh-pin count corrected; forum reply no longer says the Foundation path was verified; ETH sink, EP 6.23, veto expiry, Allowance module and baseline provenance disclosed.                                                                                |

Validation after applying the fixes: all 44 Foundry tests pass at blocks 25,984,900, 26,037,425 and 26,038,600, with the
gate in its pinned regression mode (the CI test job counts skipped tests as failures, so the gate never skips);
certifying the head with `REVIEW_GATE_BLOCK` fails on the owner; 48 Python regressions pass; on real data the replay
reports 316/15/1/0 with no wiring mismatch and exits 3.
