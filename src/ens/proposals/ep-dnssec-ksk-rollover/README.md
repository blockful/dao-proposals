# Upgrade DNSSEC oracle and registrar for the 2026 root KSK rollover

[Nick's draft](https://ens.gov.blockful.io/proposals/new?draftId=a9adfa71-3cde-44f5-950b-ff97602bdeef) has no actions
and lists the new contracts as `0x<TBD>`. `anticaptureImport.json` is the version to import, with the actions and the
deployed addresses. It isn't imported yet. `proposalCalldata.json` and `proposalDescription.md` are generated from it,
in the format `fetchDraft.js` writes; re-fetch them once the draft exists.

The proposal makes three calls on Root (`0xaB528d626EC275E3faD363fF1393A41F581c5897`):

| #   | Call                                 | Effect                       |
| --- | ------------------------------------ | ---------------------------- |
| 1   | `setController(0x8284…8B3D, true)`   | authorises the new registrar |
| 2   | `setController(0xB32c…bA2B, false)`  | revokes the January 2024 one |
| 3   | `setController(0x58774…6ef2, false)` | revokes the 2021 one         |

ENS Labs deployed the contracts on 2026-10-20. Their runtime code matches ens-contracts builds
(`upstream/verify-deployed.py`):

| Contract              | Address                                      | Source           |
| --------------------- | -------------------------------------------- | ---------------- |
| `DNSSECImpl`          | `0x668ad4467129d49ECbe6274d95197797C0E262AA` | `f0151aa`        |
| `DNSRegistrar`        | `0x8284c9D6e7882Fe1DE49C79062a4c797F0988B3D` | `f0151aa`        |
| `OffchainDNSResolver` | `0xEbBcBFBE4A8F3357e7d1d444406C28cFa34f1261` | `f0151aa` + #580 |

## Findings

1. **DNSSEC is down now.** Imports through the ENS app have failed since 11 October. Gasless resolution failed once the
   gateway moved to the KSK-2024 root signature (the KSK-2017 one it replayed expired on 22 October). The current oracle
   rejects the gateway's proofs. Execution takes at least 8 days 9 hours from `propose`, then each TLD has to migrate.
2. **The deployed registrar rejects valid proofs when signatures differ in age.** It stores the newest inception for
   each link of a proof, so after a claim with a newer signature, an older valid signature over the same records reverts
   `StaleProof` for every name below it. On 2026-10-28 Quad9 served the `xyz` DS signed at 16:00 while the root served
   19:00. This affects availability; no case was found where it accepts a proof it shouldn't. ens-contracts #583 (open)
   fixes it. We tested #583 at `61595d0`; its head is now `587e2df`, which changes the record hash and isn't reviewed.
   If #583 is deployed first, call 1 should point at it, deployed from `staging`.
3. **Gasless DNS through the Universal Resolver stays broken after the vote.** Since the ENSv2 activation, lookups reach
   DNS TLDs through `DNSTLDResolver` `0xaB48…85Ee`, which has the old oracle `0x0fc3…` as an immutable. ENS Labs has to
   deploy one on `0x668a…` and move the 1,275 TLDs in the v2 root again.
4. **Other off-chain work.** The ENS app and ensjs need `dnsprovejs` >= 1.0.1 and the new oracle and registrar
   addresses. `.hiphop` is held by a third party and can't be migrated by `enableNode`, so its owner has to switch the
   resolver. `dnssec.ens.eth` and `dnsregistrar.ens.eth` still point at the old contracts.
5. **Minor.** The KSK-2017 anchor won't validate anything again (IANA revokes it on 2027-01-11, removes it on
   2027-03-22). It can be dropped with `setAnchors`.

Consistent with the description: Root is owned by the timelock; the new oracle is owned by the timelock and anchors
exactly KSK-2017 and KSK-2024 (digests match IANA); its algorithm and digest contracts match the table; the registrar
and resolver are wired to it, to the current suffix list and to the same gateway. The previous registrars are exactly
`0xB32c…` and `0x58774…`. The 2021 registrar held no TLD in the Oct 18 sweep; repeat that sweep at the live review.

## Test

Forks block 26,295,292 and runs on Osaka, because the P256SHA256 contract needs the P256VERIFY precompile.

- Compares the three derived calls with `proposalCalldata.json` and the description's Transactions table.
- Before: the current oracle rejects the gateway's proof and the new one verifies it, and the 2021 registrar can take an
  unowned TLD with an empty proof.
- After: Root rejects both old registrars and the empty-proof claim reverts, `.domains` and `.xyz` migrate, `.hiphop`
  can't, and only the DAO can call `setAnchors`. `proveAndClaim` and gasless resolution work through the new contracts
  and fail through the old ones, an older root signature reverts `StaleProof`, and the Universal Resolver still reaches
  the old oracle.

```bash
forge test --match-path "src/ens/proposals/ep-dnssec-ksk-rollover/*" -vv
```

`upstream/build.sh` rebuilds the artifacts from ens-contracts `06fd01e`. `fixtures/fetch_proofs.py` snapshots DNSSEC
proofs: `fixtures/proofs.json` matches the fork block, and `fixtures/proofs-2026-10-17.json` covers the KSK-2017 cutoff.

## Before the live vote

1. Re-fetch the imported draft with `fetchDraft.js`.
2. If call 1 points at a #583 build, rebuild the artifacts at that commit, update the address, and check its previous
   registrars include `0x8284…`.
3. Re-check findings 2 to 4 against ENS Labs' plan.
