# [Executable] Upgrade DNSSEC oracle and registrar for the 2026 root KSK rollover

# \[Executable] Upgrade DNSSEC oracle and registrar for the 2026 root KSK rollover

| **Status**            | Draft                                                                                                                      |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| **Discussion Thread** | [Forum](https://discuss.ens.domains/t/executable-upgrade-dnssec-oracle-and-registrar-fro-the-2026-root-ksk-rollover/22497) |
| **Votes**             | TBD                                                                                                                        |

## Abstract

The DNS root zone rolled its key-signing key on 11 October 2026. ENS's DNSSEC oracle was deployed with a fixed set of root trust anchors that doesn't include the new key, so it can no longer verify DNSSEC proofs. That breaks both ways DNS names are used in ENS: importing a name onchain, and gasless DNSSEC resolution.

This proposal switches ENS over to a new DNSSEC oracle, DNS registrar and offchain DNS resolver. The new oracle trusts the new root key, and its anchors can be updated by the DAO in future instead of requiring a redeployment. The new contracts also fix several lower-severity vulnerabilities in the DNSSEC code, described below. Finally, the proposal authorises a small registrar on ENSv2 that points each DNS TLD at a resolver using the new oracle.

Existing DNS names in ENS are unaffected, and no user action is needed.

## Motivation

### The root key rollover

DNSSEC proofs in ENS start from the root zone. The oracle holds a set of root DS records ('trust anchors'), and every proof begins with the root DNSKEY RRset, which has to be signed by a key matching one of those anchors.

On 11 October 2026 at 14:00 UTC the root zone began signing its DNSKEY RRset with KSK-2024 (key tag 38696) alone. The current oracle, `0x0fc3152971714E5ed7723FAFa650F86A4BaF30C5`, was deployed in January 2024 with anchors for KSK-2010 (19036) and KSK-2017 (20326), and has no function to change them. The last root signature made with KSK-2017 expired on 22 October, so there is no longer any valid proof the current oracle will accept.

`DNSRegistrar` and `OffchainDNSResolver` both take the oracle's address as an immutable constructor argument, so they have to be replaced along with it.

### Security fixes

The new contracts fix the following issues. As far as we can tell, none of the first three can be exploited without a compromised DNSSEC key or an unusual DNS configuration.

1. **Stale ancestor records could be replayed.** The current registrar records only the RRSIG inception time of the final `_ens.<name>` TXT RRset in a claim. Nothing stopped a proof from reusing older RRsets further up the chain (a DS or DNSKEY set from before a key change, say) for as long as their signatures remained valid. The new registrar stores, for every `(name, type)` in a proof, the latest inception seen and a 28-byte hash of the record data. An RRset that isn't newer than the stored one is accepted only if its data is identical; otherwise the claim reverts with `StaleProof`. For names imported under the current registrar, the TXT inception falls back to the value it recorded.
2. **Revoked keys were accepted.** RFC 5011 section 2.4.3 requires that a DNSKEY with the REVOKE bit set be treated as invalid for everything except validating its own revocation. The current oracle ignores the flag. The new oracle rejects any signature made by a key with REVOKE set.
3. **The claim record's class and type weren't checked.** `DNSClaimChecker` read the owner address from the final RRset without requiring it to be a TXT record of class IN. It now requires both.
4. **`OffchainDNSResolver` trusted the resolver named in a DNS record too far.** A name's `ENS1` TXT record names a resolver contract, which `OffchainDNSResolver` then calls. Interface detection now goes through `ERC165Checker`, and the `addr()` lookup used to turn a name in the TXT record into a resolver address is guarded, so a revert from either call, including an `OffchainLookup`, is no longer passed on to the client.

Fixes 1 to 3 were made in [ens-contracts#572](https://github.com/ensdomains/ens-contracts/pull/572), fix 4 in [ens-contracts#580](https://github.com/ensdomains/ens-contracts/pull/580), and the record-hash comparison in fix 1 was added after audit in [ens-contracts#583](https://github.com/ensdomains/ens-contracts/pull/583).

### Other changes

* `DNSSECImpl` adds an owner-only `setAnchors(bytes)`, which emits `AnchorsUpdated`. The DAO can handle the next root key rollover with a single call.
* `DNSSECImpl` adds `verifyRRSetAt` and `verifyRRSetNow`, which return every signed set in the chain. The existing `verifyRRSet` functions keep their ABI. An empty proof now reverts with `InvalidRRSet`.
* `DNSRegistrar` adds `getInception(name, type)` and emits `InceptionUpdated` whenever a stored inception changes. `inceptions(node)` is kept for compatibility.

## Specification

### Deployed contracts

All of these are verified on Etherscan.

| Contract                        | Address                                      | Constructor arguments                                                                                                                                                                                                                                                                                                                       |
| ------------------------------- | -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `DNSSECImpl`                    | `0x668ad4467129d49ECbe6274d95197797C0E262AA` | anchors: root DS records for KSK-2017 (20326) and KSK-2024 (38696)                                                                                                                                                                                                                                                                          |
| `OffchainDNSResolver`           | `0xA4A2d86B30896fe5c4f2A7F2Ee0BDE3dbff26924` | registry `0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e`, oracle `0x668ad4467129d49ECbe6274d95197797C0E262AA`, gateway `https://dnssec-oracle.ens.domains/`                                                                                                                                                                                    |
| `DNSRegistrar`                  | `0x084462610A20eFbDB686b30fe587ecA0E234D2EF` | previous registrars \[`0xB32cB5677a7C971689228EC835800432B339bA2B`, `0x58774Bb8acD458A640aF0B88238369A167546ef2`], resolver `0xA4A2d86B30896fe5c4f2A7F2Ee0BDE3dbff26924`, oracle `0x668ad4467129d49ECbe6274d95197797C0E262AA`, suffixes `0x823BDa9cA8c47d072376eCD595530c8fb2fAa3ED`, registry `0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e` |
| `TemporaryDNSRegistrar` (ENSv2) | `0x9d6D535f08be25A9A2FdA1a1C21217D27d81cC61` | owner `0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7`, root registry `0x2553c09bE6447BeFfdB86FA622ad41fB8f77A91e`, token owner `0x5B716D6587d241166bC8914858640F8684F3A2F3`, suffixes `0x823BDa9cA8c47d072376eCD595530c8fb2fAa3ED`, default resolver `0x6695327EE70F41151d2cBADC3ABBb6e4a58e739c`                                              |

Notes:

* `DNSSECImpl` was deployed on 20 October and its ownership has already been transferred to the DAO timelock, `0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7`. Its algorithms are RSASHA1 (5 and 7) at `0x58E0383E21f25DaB957F6664240445A514E9f5e8`, RSASHA256 (8) at `0xaee0E2c4d5AB2fc164C8b0Cc8D3118C1c752C95E` and P256SHA256 (13) at `0xB091C4F6FAc16eDDA5Ee1E0f4738f80011905878`; its digests are SHA1 (1) at `0x9c9fcEa62bD0A723b62A2F1e98dE0Ee3df813619` and SHA256 (2) at `0xCFe6edBD47a032585834A6921D1d05CB70FcC36d`.
* `DNSRegistrar` and `OffchainDNSResolver` were deployed on 13 November from the post-audit code, in [ens-contracts#585](https://github.com/ensdomains/ens-contracts/pull/585) (`b6234f4`). Of the previous registrars, `0xB32cB567…` is the current one and `0x58774Bb8…` is the 2021 one.
* `TemporaryDNSRegistrar` is from [contracts-v2#486](https://github.com/ensdomains/contracts-v2/pull/486). Its default resolver is ENSv2's `DNSTLDResolver`, which was deployed on 28 October against the new oracle.

### The ENSv2 registrar

ENSv2 reserved the DNS TLDs in its root registry at launch. `TemporaryDNSRegistrar` exposes one permissionless operation, `syncTLD(label)` (and `syncTLDs` for batches). For a label on the public suffix list, it either registers the TLD to the DAO's token safe with `DNSTLDResolver` as its resolver, or, if the TLD is already registered, updates its resolver to the current default. It reverts with `TLDNotPublic` for anything else. The token owner and suffix list are immutable; only the DAO can change the default resolver.

It needs two things from the DAO. The first is the `REGISTRAR` and `REGISTER_RESERVED` roles on the root registry (bitmap `0x11`), so that it can register reserved TLDs. The second is operator approval over the tokens held by the DAO token safe, so that it can update the resolver of TLDs the safe already holds. The safe's only owner is the timelock, so the timelock calls `execTransaction` directly with a pre-validated signature.

This registrar only manages TLDs. It will be replaced when DNS imports are enabled on ENSv2.

### Transactions

| # | Target                                                    | Function                                                                                                             | Description                                                                                |
| - | --------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| 1 | Root `0xaB528d626EC275E3faD363fF1393A41F581c5897`         | `setController(0xB32cB5677a7C971689228EC835800432B339bA2B, false)`                                                   | Deauthorise the current DNSRegistrar                                                       |
| 2 | Root `0xaB528d626EC275E3faD363fF1393A41F581c5897`         | `setController(0x084462610A20eFbDB686b30fe587ecA0E234D2EF, true)`                                                    | Authorise the new DNSRegistrar                                                             |
| 3 | RootRegistry `0x2553c09bE6447BeFfdB86FA622ad41fB8f77A91e` | `grantRootRoles(0x11, 0x9d6D535f08be25A9A2FdA1a1C21217D27d81cC61)`                                                   | Grant TemporaryDNSRegistrar `REGISTRAR` and `REGISTER_RESERVED` on the ENSv2 root registry |
| 4 | DAOTokenSafe `0x5B716D6587d241166bC8914858640F8684F3A2F3` | `execTransaction(...)` calling `setApprovalForAll(0x9d6D535f08be25A9A2FdA1a1C21217D27d81cC61, true)` on RootRegistry | Approve TemporaryDNSRegistrar as operator for TLD tokens held by the safe                  |

### Calldata

```
1. 0xe0dba60f000000000000000000000000b32cb5677a7c971689228ec835800432b339ba2b0000000000000000000000000000000000000000000000000000000000000000

2. 0xe0dba60f000000000000000000000000084462610a20efbdb686b30fe587eca0e234d2ef0000000000000000000000000000000000000000000000000000000000000001

3. 0x072d5d7700000000000000000000000000000000000000000000000000000000000000110000000000000000000000009d6d535f08be25a9a2fda1a1c21217d27d81cc61

4. 0x6a7612020000000000000000000000002553c09be6447beffdb86fa622ad41fb8f77a91e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001c00000000000000000000000000000000000000000000000000000000000000044a22cb4650000000000000000000000009d6d535f08be25a9a2fda1a1c21217d27d81cc610000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000041000000000000000000000000Fe89cc7aBB2C4183683ab71653C4cdc9B02D44b700000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000
```

### After execution

Two permissionless follow-up steps move the TLDs across. ENS Labs will run both for every TLD on the public suffix list as soon as the proposal executes.

* On ENSv1, calling `enableNode(tld)` on the new `DNSRegistrar` takes over a TLD owned by any previous registrar and sets its resolver to the new `OffchainDNSResolver`. Until a TLD has been moved, imports and gasless resolution under it continue to fail.
* On ENSv2, calling `syncTLDs(labels)` on `TemporaryDNSRegistrar` registers each TLD to the DAO token safe with `DNSTLDResolver` as its resolver.

Names that have already been imported onchain keep their owner, resolver and records throughout.

The current registrar, oracle and offchain resolver are left in place but unused. The 2021 registrar is not touched by this proposal.

## Verifying this proposal

* The root zone is signed by KSK-2024 alone: `dig @a.root-servers.net . DNSKEY +dnssec +multi` shows one RRSIG over the DNSKEY RRset, with key tag 38696.
* The KSK-2024 DS record in the new oracle's `anchors()` matches IANA's published trust anchors at [https://data.iana.org/root-anchors/root-anchors.xml](https://data.iana.org/root-anchors/root-anchors.xml) (digest `683D2D0ACB8C9B712A1948B27F741219298D0A450D612C483AF444A4C0FB2B16`).
* `DNSSECImpl.owner()` returns the timelock, and `algorithms()` and `digests()` return the addresses listed above.
* `DNSRegistrar.oracle()` and `DNSRegistrar.resolver()` return the new oracle and resolver, and `wasRegistrar(0xB32cB5677a7C971689228EC835800432B339bA2B)` returns true.
* `OffchainDNSResolver.oracle()` returns the new oracle.
* `TemporaryDNSRegistrar.owner()` returns the timelock, `TOKEN_OWNER()` returns the DAO token safe, and `defaultResolver()` returns `0x6695327EE70F41151d2cBADC3ABBb6e4a58e739c`, whose `DNSSEC_ORACLE()` is the new oracle.
* The fork tests in [contracts-v2#504](https://github.com/ensdomains/contracts-v2/pull/504) (`test/fork/DNSRegistrarV1.test.ts` and `test/fork/TemporaryDNSRegistrar.test.ts`) execute these four calls as the timelock against mainnet state, then call `enableNode` and `syncTLD` and resolve known DNS names through the result.
