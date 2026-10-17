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

1. **Blocker: no actions attached.** Publishing the draft as it is would create a proposal with no calls. The two calls
   need to be added as actions, with the new registrar's address once deployed. Re-review then (see below).
2. **Timeline: DNSSEC in ENS stops working on 2026-10-22 00:00 UTC, before this can execute.** The draft says resolution
   and imports broke at the 11 October rollover. They have not yet: the gateway still serves the root DNSKEY RRset with
   the KSK-2017 signature made on 2026-10-01, which the current oracle accepts until it expires at 2026-10-22 00:00 UTC
   (the test verifies a live gateway proof on the current oracle, then shows the root link failing one second after
   expiry). A proposal takes at least ~8.4 days to execute (45,818-block vote, 2-day timelock), so gasless resolution
   and imports will be down for several days even if the proposal went up today. The description should say so, and the
   gap is worth planning for.
3. **The 2021 DNSRegistrar (`0x58774Bb8acD458A640aF0B88238369A167546ef2`) stays a Root controller.** The draft's reason
   for removing the 2024 registrar applies to it as well, and it is easier to abuse: its `claim` enables the parent name
   before it checks the proof, an empty proof for a name with no stored record does not revert, and its suffix list
   accepts any single label. So any account can call `claim("x.<label>", "")` and make it take any unowned TLD through
   Root (shown on the fork; `eth_call` on mainnet succeeds too). The DAO can undo it, and the new registrar can reclaim
   real public suffixes, but it is a free squat on the ENS root. Suggested third call:
   `setController(0x58774Bb8acD458A640aF0B88238369A167546ef2, false)`. Nothing depends on it holding the role.
4. **Note: mixed proof sources after the first claim.** Once anyone claims through the new registrar with the current
   root signature (inception 2026-10-11), a proof that still uses the gateway's older root signature reverts
   `StaleProof`. This is the new stale-ancestor check doing its job. It only matters until 2026-10-22, but clients and
   the gateway should serve the current RRset.
5. **Note: the draft's "previous registrars `[0xB32c…, 0x58774…, ...]`".** The deploy script walks `previousRegistrar()`
   and stops at the 2021 deployment, so the list is exactly those two. Check `wasRegistrar` on the deployed contract.

Checked and consistent with the draft: Root is owned by the timelock and `0xB32c…` is a controller; the current oracle's
anchors are exactly KSK-2010 and KSK-2017 (digests match IANA) with no KSK-2024; a, b and k root servers serve the root
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
  - Root rejects the 2024 registrar, and the 2021 registrar can still take an unowned TLD (finding 3).
  - Anyone can migrate `.domains` and `.xyz` to the new registrar and resolver.
  - `ens.domains` keeps its owner, and stored inceptions carry over.
  - `proveAndClaim` of `ens.domains` with a KSK-2024 chain succeeds on the new registrar and fails on the old one, and
    an older chain is then rejected as stale.
  - Gasless resolution of `taytems.xyz` works through the new resolver and fails through the old one.

Mutating either call (call 1 with `enabled = false`, or call 2 revoking the wrong registrar) makes the test fail; the
wrong-registrar mutant is caught by the description check before the proposal is submitted.

`forum-post.md` is the review message for the draft thread; fill in `COMMIT_HASH` and `SHORT_HASH` once committed.

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
5. Re-check finding 3 against the final action list.
