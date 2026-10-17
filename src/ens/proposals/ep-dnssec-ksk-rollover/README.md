# Upgrade DNSSEC oracle and registrar for the 2026 root KSK rollover (draft)

Draft review of "[Executable] Upgrade DNSSEC oracle and registrar for the 2026 root KSK rollover" by nick.eth:
https://ens.gov.blockful.io/proposals/new?draftId=a9adfa71-3cde-44f5-950b-ff97602bdeef (created 2026-10-16, not updated
since). `draft.json` is the API response as fetched; `proposalDescription.md` is its `body`.

**Status: not approvable yet.** The draft has no actions attached (`"actions": []`), and the three contracts it depends
on are still `0x<TBD>`. The actions are only written out in the description, so that is the comparison target: the
calldata is derived from the Specification, then checked against the description's Transactions table and Calldata
block. The new contracts are built from source and deployed on a fork in their place.

The DAO-side executable is two calls on Root (`0xaB528d626EC275E3faD363fF1393A41F581c5897`):

| #   | Call                                      | Effect                               |
| --- | ----------------------------------------- | ------------------------------------ |
| 1   | `setController(<new DNSRegistrar>, true)` | lets the new registrar take DNS TLDs |
| 2   | `setController(0xB32cB567…, false)`       | removes the January 2024 registrar   |

The test asserts both calls against the description: targets, values and function from the Transactions table, and
calldata from the Calldata block (call 2 byte for byte, call 1 with the stand-in address in place of the placeholder).

## Findings

Reviewed in depth by five independent reviewers (calldata and governance, the PR #572 code, DNSSEC timeline, Root
controllers, and a mutation audit of this test). Each claim below was re-checked against mainnet, the upstream sources
or the published packages before it went in.

1. **Blocker: no actions attached.** Publishing the draft as it is would create a proposal with no calls. The two calls
   need to be added as actions, with the new registrar's address once deployed. Re-review then (see below).
2. **Timeline: imports are already broken; gasless resolution breaks by 2026-10-22 00:00 UTC at the latest.**
   - Imports through the ENS app have failed since the 11 October switch, as the draft says: the app (ensjs 4.3.0,
     `@ensdomains/dnsprovejs` 0.5.1) builds proofs from Cloudflare DoH and only trusts KSK-2010 and KSK-2017, so it
     stops before any transaction.
   - Gasless resolution has not broken yet, contrary to the draft: the ENS gateway still replays the root DNSKEY RRset
     with the KSK-2017 signature made on 2026-10-01, which the current oracle accepts until it expires at 2026-10-22
     00:00 UTC (the test verifies a live gateway proof on the current oracle, then shows the root link failing one
     second after expiry). It stops sooner if the gateway changes what it serves.
   - Execution takes at least 8 days 9 hours from `propose` (45,818-block vote, 2-day timelock), so gasless resolution
     will be down for several days even if the proposal went up today.
3. **The proposal alone does not restore DNSSEC; off-chain work is a prerequisite and is not in the draft.**
   - The gateway must be redeployed with the KSK-2024 anchor (its public repo pins `dnsprovejs` 0.4.1; 1.0.1 is the
     first release with 38696), ideally before execution. Otherwise gasless resolution stays broken, and once anyone
     claims through the new registrar with the current root signature, every gateway-built proof that still carries the
     older root signature reverts `StaleProof` (shown in the test), for any name.
   - The ENS app and ensjs must move to `dnsprovejs` >= 1.0.1, and ensjs's `ensLegacyDnssecImpl` (`0x0fc3…`) must point
     at the new oracle, or imports stay broken after execution. The draft's "no user action is needed" holds for users,
     not for these clients.
   - `.hiphop` is held by a third party and uses the current resolver; `enableNode` cannot migrate it
     (`PreconditionNotMet`, in the test), so its owner has to switch the resolver. All other DNS TLDs (1,285) are held
     by the current registrar and will migrate.
   - `dnssec.ens.eth` and `dnsregistrar.ens.eth` still resolve to the current oracle and registrar.
4. **The 2021 DNSRegistrar (`0x58774Bb8acD458A640aF0B88238369A167546ef2`) stays a Root controller.** The draft's reason
   for removing the 2024 registrar applies to it as well, and it is easier to abuse: its `claim` enables the parent name
   before it checks the proof, an empty proof for a name with no stored record does not revert, and its suffix list
   accepts any single label. So anyone can make it take any unowned TLD through Root (shown on the fork; `eth_call` on
   mainnet succeeds too), including the 162 real IANA TLDs that ENS does not hold, and it can then clear names under a
   TLD it holds. It holds no TLD today, so revoking it breaks nothing; undoing a squat would need the DAO or the
   Security Council. Suggested third call: `setController(0x58774Bb8acD458A640aF0B88238369A167546ef2, false)`.
5. **Minor: the KSK-2017 anchor is inert after 2026-10-22.** IANA publishes KSK-2017 with the REVOKE bit on 2027-01-11
   and removes it on 2027-03-22; the new oracle rejects revoked keys, so DS 20326 will not validate anything again.
   Consider deploying with KSK-2024 only, or plan the `setAnchors` call that drops it.
6. **Minor: the draft's "previous registrars `[0xB32c…, 0x58774…, ...]`".** The deploy script walks
   `previousRegistrar()` and stops at the 2021 deployment, so the list is exactly those two. Check `wasRegistrar` on the
   deployed contract.

The PR #572 code review found no critical or high issue: revoked-key handling (including the root's 2027 KSK-2017
revocation), chain integrity, inception keying and the `enableNode` boundaries all held under fork tests. One
informational upstream note: `StaleProof`'s first-write comparison treats any inception after 2038-01-19 as stale (same
in the deployed registrar).

Checked and consistent with the draft: Root is owned by the timelock and `0xB32c…` is a controller; the current oracle's
anchors are exactly KSK-2010 and KSK-2017 (digests match IANA) with no KSK-2024; all 13 root servers serve the root
DNSKEY RRset signed only by key tag 38696; the KSK-2024 DS in upstream's fixture matches IANA; the algorithm and digest
table matches the current oracle; the suffix list and gateway URL are the current ones; PR #572 is merged into `staging`
as `f0151aa`.

## What the test does

`calldataCheck.t.sol` forks block 26,214,036 and runs on Osaka: the P256SHA256 algorithm contract calls the P256VERIFY
precompile at `0x100`, and under the repo's default `cancun` every P-256 signature fails.

- **Setup:** deploys `DNSSECImpl`, `OffchainDNSResolver` and `DNSRegistrar` from `upstream/artifacts`, wired as the
  draft's "Deployed contracts" table says, and hands the oracle to the timelock.
- **Before:** checks the current stack and the new contracts against the draft. The current oracle verifies the
  gateway's KSK-2017 chain but rejects the KSK-2024 one (`NoMatchingProof(.)`). The new oracle verifies both. Also
  checks the 2026-10-22 cutoff.
- **Description:** checks the derived calls against the Transactions table and Calldata block.
- **Lifecycle:** propose, vote, queue and execute the two calls.
- **After:**
  - Root rejects the 2024 registrar, and the 2021 registrar can still take an unowned TLD (finding 4).
  - Only the DAO can call `setAnchors` on the new oracle.
  - Anyone can migrate `.domains` and `.xyz` to the new registrar and resolver; `.hiphop` cannot be migrated.
  - `ens.domains` keeps its owner, and stored inceptions carry over.
  - `proveAndClaim` of `ens.domains` with a KSK-2024 chain succeeds on the new registrar and fails on the old one, and
    an older chain is then rejected as stale.
  - Gasless resolution of `taytems.xyz` works through the new resolver and fails through the old one.

Mutating either call (call 1 with `enabled = false`, or call 2 revoking the wrong registrar) makes the test fail; the
wrong-registrar mutant is caught by the description check before the proposal is submitted.

`forum-post.md` is the review message for the draft thread.

```bash
forge test --match-path "src/ens/proposals/ep-dnssec-ksk-rollover/*" -vv
```

Supporting files:

- `upstream/build.sh` rebuilds `upstream/artifacts/*.json` from ensdomains/ens-contracts `f0151aa` with upstream's
  compiler settings (solc 0.8.26, 1,000,000 runs, paris). Sources are unmodified, the output is byte-for-byte
  reproducible, and `deployedBytecode` plus `immutableReferences` are kept so the real deployments can be diffed later.
- `fixtures/fetch_proofs.py` snapshots the proofs for `_ens.ens.domains` and `taytems.xyz` from the gateway, and builds
  the KSK-2024 variant from `a.root-servers.net`. The RRSIGs only hold around the fork block, so regenerating them means
  moving the fork block too.

## When the contracts are deployed

1. Re-fetch the draft (`draft.json`, `proposalDescription.md`) and add `proposalCalldata.json` built from its actions,
   so `callDataComparison` runs.
2. Replace the fork deployment with the real addresses as named constants, and move the fork to a block after
   deployment.
3. Check the deployed runtime bytecode against `upstream/artifacts`, masking immutables and the metadata tail.
4. Check `owner()` is the timelock, plus the anchors, algorithms, digests and constructor arguments.
5. Re-check findings 3 and 4 against the final action list and the gateway's state.
