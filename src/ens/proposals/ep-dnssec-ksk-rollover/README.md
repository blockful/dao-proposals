# Upgrade DNSSEC oracle and registrar for the 2026 root KSK rollover (draft)

Draft review of "[Executable] Upgrade DNSSEC oracle and registrar for the 2026 root KSK rollover" by nick.eth:
https://ens.gov.blockful.io/proposals/new?draftId=a9adfa71-3cde-44f5-950b-ff97602bdeef (created 2026-10-16, not updated
since; re-checked 2026-10-28). `draft.json` is the API response as fetched; `proposalDescription.md` is its `body`.

**Status: not approvable as drafted.** The draft has no actions attached (`"actions": []`) and its description still
lists the new contracts as `0x<TBD>`. ENS Labs deployed them on 2026-10-20 and their code matches the reviewed source:

| Contract              | Address                                      | Runtime code matches                       |
| --------------------- | -------------------------------------------- | ------------------------------------------ |
| `DNSSECImpl`          | `0x668ad4467129d49ECbe6274d95197797C0E262AA` | ens-contracts `f0151aa` (= `06fd01e`)      |
| `DNSRegistrar`        | `0x8284c9D6e7882Fe1DE49C79062a4c797F0988B3D` | ens-contracts `f0151aa` (= `06fd01e`)      |
| `OffchainDNSResolver` | `0xEbBcBFBE4A8F3357e7d1d444406C28cFa34f1261` | ens-contracts `06fd01e` (`f0151aa` + #580) |

The DAO-side executable is two calls on Root (`0xaB528d626EC275E3faD363fF1393A41F581c5897`):

| #   | Call                                      | Effect                               |
| --- | ----------------------------------------- | ------------------------------------ |
| 1   | `setController(<new DNSRegistrar>, true)` | lets the new registrar take DNS TLDs |
| 2   | `setController(0xB32cB567…, false)`       | removes the January 2024 registrar   |

Because the actions are only written out in the description, that is the comparison target: the test derives both calls
from the Specification and checks them against the Transactions table and the Calldata block (call 2 byte for byte, call
1 with the deployed registrar in place of the placeholder).

## Findings

Reviewed in depth by independent reviewers (calldata and governance, the PR #572 and #583 code, DNSSEC timeline, Root
controllers, the ENSv2 redeploy, and a mutation audit of this test). Each claim below was re-checked against mainnet,
the upstream sources or the published packages before it went in.

1. **Blocker: no actions attached.** Publishing the draft as it is would create a proposal with no calls. The two calls
   need to be added as actions, and the description should name the deployed contracts.
2. **DNSSEC in ENS is down now, until execution.**
   - Imports through the ENS app have failed since the 11 October switch: the app (ensjs 4.3.0, `@ensdomains/dnsprovejs`
     0.5.1) builds proofs from Cloudflare DoH and only trusts KSK-2010 and KSK-2017.
   - Gasless resolution failed once the gateway switched to the KSK-2024 root signature (inception 2026-10-21; the
     KSK-2017 signature it had been replaying expired at 2026-10-22 00:00 UTC). The current oracle rejects the gateway's
     proofs (`NoMatchingProof(.)`, in the test).
   - Execution takes at least 8 days 9 hours from `propose` (45,818-block vote, 2-day timelock), then each TLD has to be
     migrated with `enableNode`.
3. **The deployed `DNSRegistrar` rejects valid proofs whenever signatures differ in age; ens-contracts #583 (open) fixes
   it.** The registrar stores the newest RRSIG inception for every link of every proof (the root DNSKEY, every TLD's DS
   and DNSKEY). After anyone claims with a newer signature, any proof that carries an older, still valid signature over
   the same records reverts `StaleProof`, for every name under that ancestor. This happens all the time: the root
   re-signs DS records several times a day, and on 2026-10-28 Quad9 served the `xyz` DS signed at 16:00 while the root,
   Google and Cloudflare served 19:00. The test shows it with the two valid root signatures (2026-10-11 and 2026-10-21).
   It affects availability only; no case was found where the registrar accepts a proof it should not. #583 stores a hash
   of each record set and accepts an older signature over identical records (checked with fork tests on a #583 build
   during this review). #583 has no reviews yet and its branch still carries the old deployment records, so it must be
   deployed from `staging` after merging, where the deploy script lists `[0x8284…, 0xB32c…, 0x58774…]` as previous
   registrars.
   - Recommendation: given the outage, authorise `0x8284…` now and say so in the draft, with a committed follow-up that
     swaps in the #583 build (it takes the TLDs over through `wasRegistrar`; tested lossless). If the #583 build is
     deployed before this goes on-chain, use it instead.
4. **This proposal does not restore gasless DNS names for apps that use the Universal Resolver.** Since the ENSv2
   activation executed, `0xeEeE…EeEe` → managed proxy `0xcFFd…022B` → UniversalResolverV2 `0x06Fd…Cfd5`, which resolves
   DNS TLDs through ENSv2's `DNSTLDResolver` `0xaB48…85Ee`. That contract's `DNSSEC_ORACLE` is the current oracle
   `0x0fc3…`, as an immutable (asserted in the test after execution). ENS Labs has to deploy a `DNSTLDResolver` bound to
   `0x668a…` and move the 1,275 DNS TLDs in the v2 root to it again (only the Labs deployer holds those v2 root roles).
5. **Other off-chain work the draft does not mention.**
   - The ENS app and ensjs must move to `dnsprovejs` >= 1.0.1 (first release with KSK-2024) and point at the new oracle
     and registrar (ensjs `ensLegacyDnssecImpl`, ens-app-v3 `DNS_REGISTRAR_ADDRESSES`), or imports stay broken.
   - `.hiphop` is held by a third party and uses the current resolver; `enableNode` cannot migrate it
     (`PreconditionNotMet`, in the test), so its owner has to switch the resolver.
   - `dnssec.ens.eth` and `dnsregistrar.ens.eth` still resolve to the current oracle and registrar.
6. **The 2021 DNSRegistrar (`0x58774Bb8acD458A640aF0B88238369A167546ef2`) stays a Root controller.** Its `claim` enables
   the parent name before it checks the proof, an empty proof for a name with no stored record does not revert, and its
   suffix list accepts any single label, so anyone can make it take any unowned TLD through Root (in the test). It holds
   no TLD today, so revoking it breaks nothing. Suggested third call:
   `setController(0x58774Bb8acD458A640aF0B88238369A167546ef2, false)`.
7. **Minor.** The KSK-2017 anchor will never validate anything again (IANA revokes KSK-2017 on 2027-01-11 and removes it
   on 2027-03-22; the oracle rejects revoked keys): drop it with `setAnchors` when convenient. The draft's previous
   registrars `[0xB32c…, 0x58774…, ...]` are exactly those two on the deployed registrar.

Checked and consistent with the draft: Root is owned by the timelock and `0xB32c…` is a controller; the current oracle's
anchors are exactly KSK-2010 and KSK-2017; the deployed oracle is owned by the timelock and anchors exactly KSK-2017 and
KSK-2024 (digests match IANA), with the algorithm and digest contracts in the draft's table; the deployed registrar and
resolver are wired to it, to the current suffix list and to the same gateway URL. The PR #572 and #580 code reviews
found no critical or high issue.

## What the test does

`calldataCheck.t.sol` forks block 26,295,292 (after the deployment) and runs on Osaka: the P256SHA256 algorithm contract
calls the P256VERIFY precompile at `0x100`, and under the repo's default `cancun` every P-256 signature fails.

- **Before:** checks the current stack and the deployed contracts against the draft. The current oracle rejects the
  gateway's current proof; the new oracle verifies it and the one with the older root signature. From the 2026-10-17
  snapshot, checks the current oracle accepted the KSK-2017 root link up to 2026-10-22 00:00 UTC and not after.
- **Description:** checks the derived calls against the Transactions table and Calldata block, and that the description
  does not name the deployed contracts yet.
- **Lifecycle:** propose, vote, queue and execute the two calls.
- **After:**
  - Root rejects the 2024 registrar, and the 2021 registrar can still take an unowned TLD (finding 6).
  - Only the DAO can call `setAnchors` on the new oracle.
  - Anyone can migrate `.domains` and `.xyz` to the new registrar and resolver; `.hiphop` cannot be migrated.
  - `ens.domains` keeps its owner, and stored inceptions carry over.
  - `proveAndClaim` of `ens.domains` succeeds on the new registrar and fails on the old one; then the chain with the
    older root signature is rejected as stale (finding 3).
  - Gasless resolution of `taytems.xyz` works through the new resolver and fails through the old one.
  - The Universal Resolver still reaches DNS TLDs through ENSv2's resolver on the old oracle (finding 4).

Mutating either call (wrong registrar in call 1 or call 2, `enabled = false`) or the deployed oracle address makes the
test fail.

`forum-post.md` is the review message for the draft thread.

```bash
forge test --match-path "src/ens/proposals/ep-dnssec-ksk-rollover/*" -vv
```

Supporting files:

- `upstream/build.sh` rebuilds `upstream/artifacts/*.json` from ens-contracts `06fd01e` (PR #572 + #580, what was
  deployed) with upstream's compiler settings (solc 0.8.26, 1,000,000 runs, paris). The output is byte-for-byte
  reproducible.
- `upstream/verify-deployed.py <RPC_URL>` compares the deployed runtime code with the artifacts, masking immutables and
  the metadata tail.
- `fixtures/fetch_proofs.py` snapshots proofs for `_ens.ens.domains` and `taytems.xyz` from the gateway, the KSK-2024
  variant from `a.root-servers.net` and, given an older snapshot, the variant with its older root signature.
  `fixtures/proofs.json` matches the fork block; `fixtures/proofs-2026-10-17.json` is the earlier snapshot. RRSIGs only
  hold around their fetch time, so a new snapshot means moving the fork block too.

## Before the live vote

1. Re-fetch the draft (`draft.json`, `proposalDescription.md`) and add `proposalCalldata.json` built from its actions,
   so `callDataComparison` runs.
2. If the registrar in the actions is a #583 build, rebuild the artifacts at that commit, update the address constant
   and `verify-deployed.py`, and check its previous registrars include `0x8284…`.
3. Re-check findings 4 to 6 against the final action list and ENS Labs' plan for ENSv2's DNS resolver.
