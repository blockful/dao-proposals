## Draft proposal calldata security review

**The draft has no actions attached.** Publishing it as it stands would create a proposal with no calls. The two `setController` calls need to be added as actions, and the description should name the deployed contracts (it still says `0x<TBD>`).

The calldata written in the description is correct: both calls match our independent derivation. The contracts ENS Labs deployed on 20 October match the reviewed source byte for byte (DNSSECImpl `0x668ad4467129d49ECbe6274d95197797C0E262AA` and DNSRegistrar `0x8284c9D6e7882Fe1DE49C79062a4c797F0988B3D` = `f0151aa`, OffchainDNSResolver `0xEbBcBFBE4A8F3357e7d1d444406C28cFa34f1261` = `f0151aa` + #580), the oracle is owned by the DAO timelock and anchors KSK-2017 and KSK-2024, and the wiring matches the draft. On a mainnet fork with live proofs, the proposal executes and TLDs migrate, `proveAndClaim` works and gasless resolution works through the new resolver.

Points to address:

1. **No actions attached** (above).
2. **DNSSEC is down now.** Imports through the app have failed since 11 October, and gasless resolution since the gateway switched to the KSK-2024 root signature (by 22 October). The current oracle rejects the gateway's proofs. Execution takes at least ~8.4 days from submission, plus TLD migration.
3. **The deployed DNSRegistrar rejects valid proofs when signatures differ in age.** It stores the newest inception for every link of a proof (root DNSKEY, every TLD's DS and DNSKEY), so after any claim with a newer signature, proofs carrying an older but still valid signature over the same records revert `StaleProof` for every name below. This happens constantly (on 28 October Quad9 served the `.xyz` DS signed at 16:00 while the root served 19:00). Open PR #583 fixes it. Given the outage, we suggest authorising `0x8284…` now and committing to a follow-up that swaps in the #583 build (deployed from `staging`, so its previous registrars include `0x8284…`); or using the #583 build directly if it is deployed before this goes on-chain.
4. **This does not restore gasless DNS names for apps using the Universal Resolver.** Since the ENSv2 activation, lookups go through ENSv2, whose `DNSTLDResolver` (`0xaB48…85Ee`) is bound to the old oracle as an immutable. A `DNSTLDResolver` on the new oracle, and another move of the 1,275 DNS TLDs in the v2 root, are needed. Please include the plan and timing.
5. **Other prerequisites:** the ENS app and ensjs need `dnsprovejs` >= 1.0.1 and the new oracle and registrar addresses; `.hiphop` (third-party owned, old resolver) cannot be migrated by `enableNode`; `dnssec.ens.eth` and `dnsregistrar.ens.eth` still point at the old contracts.
6. **Also deauthorise the 2021 DNSRegistrar.** `0x58774Bb8acD458A640aF0B88238369A167546ef2` is still a Root controller and can be used to take unowned TLDs. It holds none, so revoking it breaks nothing.
7. **Minor:** the KSK-2017 anchor will never validate anything again (IANA revokes it on 11 January 2027); drop it with `setAnchors` when convenient.

We will re-run the review once the actions are attached.

The simulation and tests can be found [here](https://github.com/blockful/dao-proposals/blob/a866eed01209f7bdce202faf10f127ad5fd6d9cd/src/ens/proposals/ep-dnssec-ksk-rollover/calldataCheck.t.sol).

To verify locally:

1. Clone: `git clone https://github.com/blockful/dao-proposals.git`
2. Checkout: `git checkout a866eed`
3. Run: `forge test --match-path "src/ens/proposals/ep-dnssec-ksk-rollover/*" -vv`
