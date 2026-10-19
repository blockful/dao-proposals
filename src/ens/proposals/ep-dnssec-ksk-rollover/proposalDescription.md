# \[EP X.Y] \[Executable] Upgrade DNSSEC oracle and registrar for the 2026 root KSK rollover

## Abstract

On 11 October 2026 at 14:00 UTC, the DNS root zone switched to signing its DNSKEY RRset exclusively with the new root key-signing key, KSK-2024 (key tag 38696). The DNSSEC oracle ENS currently uses (`0x0fc3152971714E5ed7723FAFa650F86A4BaF30C5`) was deployed in January 2024 with trust anchors for KSK-2010 (19036) and KSK-2017 (20326) only, and has no way to update them. As a result it can no longer verify a proof built from the current root DNSKEY RRset. That breaks both ways DNS names are used in ENS: importing or updating a name onchain via `proveAndClaim`, and gasless DNSSEC resolution, since `OffchainDNSResolver` verifies the gateway's proof against the oracle on every lookup.

This proposal replaces the oracle, the DNS registrar and the offchain DNS resolver with new versions from [ensdomains/ens-contracts#572](https://github.com/ensdomains/ens-contracts/pull/572). The new oracle trusts KSK-2017 and KSK-2024, and its anchors can be updated by the DAO in future, so the next root rollover will be a single `setAnchors` call rather than a redeployment. The same release also fixes three lower-severity issues in the oracle and registrar, described below.

The only DAO action required is to authorise the new registrar as a controller of the root, and deauthorise the current one. Existing DNS names in ENS are unaffected, and no user action is needed.

## Background

DNSSEC proofs in ENS start from the root zone. The oracle holds a set of root DS records ('trust anchors'), and every proof begins with the root DNSKEY RRset, which must be signed by a key matching one of those anchors. The root zone's KSK is rolled infrequently; the last rollover was in 2018, from KSK-2010 to KSK-2017. KSK-2024 was first published in the root zone on 11 January 2025, and became the sole key signing the root DNSKEY RRset on 11 October 2026.

The current `DNSSECImpl` sets its anchors in the constructor and has no setter, so adding KSK-2024 requires a new deployment. Because `DNSRegistrar` and `OffchainDNSResolver` both take the oracle address as an immutable constructor argument, they need to be redeployed alongside it.

## Changes

All changes are in [PR #572](https://github.com/ensdomains/ens-contracts/pull/572), merged to `staging` as commit [`f0151aa`](https://github.com/ensdomains/ens-contracts/commit/f0151aaf8a53b5b8f725a584fc194997c8226fbd).

### Root key rollover

* **Anchors updated.** The new oracle is deployed with DS records for KSK-2017 (20326) and KSK-2024 (38696). The obsolete KSK-2010 (19036) anchor, retired in 2018, is dropped.
* **Anchors are now mutable.** `DNSSECImpl` gains an owner-only `setAnchors(bytes)` and emits `AnchorsUpdated` on construction and on every change. The contract is owned by the DAO, so future rollovers (including the eventual removal of KSK-2017) can be handled by a single executable call.

### Security fixes

None of these were considered exploitable in practice without either a compromised DNSSEC key or an unusual DNS configuration, which is why they have been bundled with this upgrade rather than handled as an emergency. They are all fixed in PR #572.

1. **Stale ancestor records could be replayed.** `DNSRegistrar` only recorded the RRSIG inception time of the final `_ens.<name>` TXT record in a claim, and rejected claims whose TXT record was older than the last one seen. The DS and DNSKEY RRsets earlier in the chain were not checked, so any validly-signed, unexpired version of them was accepted. If a zone (or its parent, such as a TLD) rolled a key because it had been compromised, an attacker holding the old key could keep building valid claims - and taking over names - from the superseded DNSKEY/DS records until their signatures expired, by signing a fresh TXT record with the compromised key. The new registrar stores the latest inception seen for every `(name, type)` in the chain, and reverts with `StaleProof(name, type, last, inception)` if any RRset in a proof is older than one already submitted. To preserve existing protection, the TXT inception for `_ens.<name>` falls back to the previous registrar's `inceptions(node)` when no value has been stored yet.
2. **Revoked keys were still accepted.** RFC 5011 §2.4.3 says a DNSKEY with the REVOKE flag set must be treated as permanently invalid for everything except validating its own revocation. The oracle ignored the flag, so a revoked key published in a zone's DNSKEY RRset could still be used to verify signatures. The new oracle rejects any key with the REVOKE bit set. This is more relevant than usual right now, as KSK-2017 is expected to be revoked in the root zone following the rollover, as KSK-2010 was after the 2018 rollover.
3. **Claim record type and class were not checked.** `DNSClaimChecker` searched the final RRset for a record owned by `_ens.<name>` containing an `a=0x...` string, but did not require it to be a TXT record of class IN. A non-TXT record at `_ens.<name>` whose rdata happened to parse as an owner string would have been accepted as a claim. The checker now requires `CLASS_INET` and `DNSTYPE_TXT`.

Separately, the RSA signature forgery issue disclosed in [GHSA-c6rr-7pmc-73wc](https://github.com/ensdomains/ens-contracts/security/advisories/GHSA-c6rr-7pmc-73wc) (missing PKCS#1 v1.5 padding validation) was fixed earlier this year by pointing the existing oracle at patched algorithm contracts. The new oracle uses those same patched contracts from the outset.

### Other changes

* `DNSSEC` gains `verifyRRSetAt(input, time)` and `verifyRRSetNow(input)`, which return every verified RRset in the chain (`RRUtils.SignedSet[]`) rather than just the last one. Both existing `verifyRRSet` overloads are retained with their original signatures and return values.
* `DNSSECImpl` uses OpenZeppelin's `Ownable` in place of the bespoke `Owned` contract. Note that this changes the ownership-transfer function from `setOwner` to `transferOwnership`.
* `DNSRegistrar` accepts an array of all previous registrars, and treats a TLD owned by any of them as eligible for migration (`wasRegistrar`). Previously only the immediately preceding registrar was recognised.
* `verifyRRSetAt` and `verifyRRSetNow` revert with `InvalidRRSet` on an empty proof, and the registrar rejects empty proofs up front with `NoOwnerRecordFound`. Previously an empty proof made the oracle return its own anchors as if they were a verified RRset; the registrar then failed to find an owner record in them, so this was not exploitable. The legacy `verifyRRSet` keeps its old behaviour for compatibility.
* `DNSRegistrar` adds `getInception(name, type)` and emits `InceptionUpdated` whenever a stored inception changes. `inceptions(node)` is kept as a backwards-compatible getter.

## Deployed contracts

ENS Labs will deploy these from commit `f0151aa` and source-verify them on Etherscan before the proposal goes to a vote, and will transfer ownership of the new `DNSSECImpl` to the DAO timelock (`0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7`).

| Contract              | Address   | Constructor arguments                                                                                                                                                                                                                                                                                  |
| --------------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `DNSSECImpl`          | `0x<TBD>` | anchors: DS 20326/8/2, DS 38696/8/2                                                                                                                                                                                                                                                                    |
| `OffchainDNSResolver` | `0x<TBD>` | registry `0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e`, oracle `0x<new DNSSECImpl>`, gateway `https://dnssec-oracle.ens.domains/`                                                                                                                                                                       |
| `DNSRegistrar`        | `0x<TBD>` | previous registrars `[0xB32cB5677a7C971689228EC835800432B339bA2B, 0x58774bb8acd458a640af0b88238369a167546ef2, ...]`, resolver `0x<new OffchainDNSResolver>`, oracle `0x<new DNSSECImpl>`, suffixes `0x823BDa9cA8c47d072376eCD595530c8fb2fAa3ED`, registry `0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e` |

The new oracle is configured with the existing algorithm and digest contracts:

| ID       | Algorithm / digest | Address                                      |
| -------- | ------------------ | -------------------------------------------- |
| 5, 7     | RSASHA1            | `0x58e0383e21f25dab957f6664240445a514e9f5e8` |
| 8        | RSASHA256          | `0xaee0e2c4d5ab2fc164c8b0cc8d3118c1c752c95e` |
| 13       | P256SHA256         | `0xb091c4f6fac16edda5ee1e0f4738f80011905878` |
| digest 1 | SHA1               | `0x9c9fcEa62bD0A723b62A2F1e98dE0Ee3df813619` |
| digest 2 | SHA256             | `0xCFe6edBD47a032585834A6921D1d05CB70FcC36d` |

The public suffix list contract is unchanged.

## Specification

The DAO calls `setController` on the root contract (`root.ens.eth`, `0xaB528d626EC275E3faD363fF1393A41F581c5897`) twice: once to authorise the new `DNSRegistrar`, and once to deauthorise the current one. Authorising the new registrar lets it take ownership of DNS TLDs from the old one via the permissionless `enableNode` call. Deauthorising the old registrar stops it from enabling any further TLDs against an oracle that can no longer verify proofs.

## Transactions

| Address                                      | Value | Function                      | Argument     | Value                                        |
| -------------------------------------------- | ----- | ----------------------------- | ------------ | -------------------------------------------- |
| `0xaB528d626EC275E3faD363fF1393A41F581c5897` | 0 ETH | `setController(address,bool)` | `controller` | `0x<new DNSRegistrar>`                       |
|                                              |       |                               | `enabled`    | `true`                                       |
| `0xaB528d626EC275E3faD363fF1393A41F581c5897` | 0 ETH | `setController(address,bool)` | `controller` | `0xB32cB5677a7C971689228EC835800432B339bA2B` |
|                                              |       |                               | `enabled`    | `false`                                      |

Calldata:

```
0xe0dba60f000000000000000000000000<new DNSRegistrar, 20 bytes>0000000000000000000000000000000000000000000000000000000000000001
0xe0dba60f000000000000000000000000b32cb5677a7c971689228ec835800432b339ba2b0000000000000000000000000000000000000000000000000000000000000000
```

## After execution

ENS Labs will run the `20_set_tlds` deploy script, which calls `enableNode` on the new registrar for every DNS TLD currently held by a previous registrar, in batches of 25 via Multicall3. Each call transfers the TLD to the new registrar and sets its resolver to the new `OffchainDNSResolver`. This is permissionless, so anyone can migrate a TLD that has been missed. Until a TLD has been migrated, gasless resolution and imports for names under it will continue to fail as they do today.

DNS names that have already been imported into ENS are owned by their users in the registry and are not touched by the migration. Applications and libraries that call the oracle directly (rather than through ENS) should switch to the new `DNSSECImpl` address.

## Verifying this proposal

* The root DNSKEY RRset is signed by key tag 38696: `dig +dnssec . DNSKEY @a.root-servers.net`.
* The KSK-2024 DS record in the new oracle's anchors matches IANA's published trust anchors: [https://data.iana.org/root-anchors/root-anchors.xml](https://data.iana.org/root-anchors/root-anchors.xml)
* `DNSSECImpl.owner()` returns the DAO timelock, and `algorithms(id)` / `digests(id)` match the tables above.
* `DNSRegistrar.oracle()` and `DNSRegistrar.resolver()` return the new oracle and resolver, and `wasRegistrar(0xB32cB5677a7C971689228EC835800432B339bA2B)` returns `true`.
* `OffchainDNSResolver.oracle()` returns the new oracle.
* A mainnet-fork test (`TEST_REMOTE=1`, `test/dnsregistrar/TestDNSRegistrar.remote.ts`) migrates names imported under the current registrar and confirms their stored inceptions carry over.