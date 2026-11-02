## Draft proposal calldata security review

Blockful reviewed this upgrade against the contracts ENS Labs deployed on 20 October. They match the source (DNSSECImpl `0x668ad4467129d49ECbe6274d95197797C0E262AA` and DNSRegistrar `0x8284c9D6e7882Fe1DE49C79062a4c797F0988B3D` = `f0151aa`, OffchainDNSResolver `0xEbBcBFBE4A8F3357e7d1d444406C28cFa34f1261` = `f0151aa` + #580). The oracle is owned by the DAO timelock and anchors KSK-2017 and KSK-2024, and the wiring matches the description.

The original draft has no actions and lists the contracts as `0x<TBD>`. The proposal should make these three calls on Root (`0xaB528d626EC275E3faD363fF1393A41F581c5897`), which we derived independently and executed on a mainnet fork:

1. `setController(0x8284c9D6e7882Fe1DE49C79062a4c797F0988B3D, true)`
2. `setController(0xB32cB5677a7C971689228EC835800432B339bA2B, false)`
3. `setController(0x58774Bb8acD458A640aF0B88238369A167546ef2, false)`, which revokes the 2021 registrar, still a controller

After execution, TLDs migrate, and `proveAndClaim` and gasless resolution work through the new contracts with live proofs.

Points to address:

1. **DNSSEC is down now.** The gap @estmcmxci flagged has happened: the KSK-2017 root signature expired on 22 October, the gateway serves the KSK-2024 one, and the current oracle rejects its proofs. Imports through the app have failed since 11 October. Execution takes at least ~8.4 days from submission, plus TLD migration.
2. **The deployed DNSRegistrar rejects valid proofs when signatures differ in age.** After a claim with a newer signature, proofs with an older valid signature over the same records revert `StaleProof` for every name below. On 28 October Quad9 served the `.xyz` DS signed at 16:00 while the root served 19:00. Open PR #583 fixes this. If it is deployed before this goes on-chain, call 1 should point at it.
3. **Gasless DNS through the Universal Resolver stays broken after the vote.** Since the ENSv2 activation, lookups reach DNS TLDs through `DNSTLDResolver` `0xaB48304A2520CE420E636AaCD48A8bb3e7e485Ee`, which has the old oracle as an immutable. It needs redeploying on the new oracle, and the 1,275 DNS TLDs in the v2 root need moving again. Please share the plan and timing.
4. **Other off-chain work.** The ENS app and ensjs need `dnsprovejs` >= 1.0.1 and the new addresses. `.hiphop` is held by a third party and can't be migrated by `enableNode`. `dnssec.ens.eth` and `dnsregistrar.ens.eth` still point at the old contracts.

The simulation and tests can be found [here](https://github.com/blockful/dao-proposals/blob/a624dc522b1720ea9603fbf78c14b6c0a38b25d6/src/ens/proposals/ep-dnssec-ksk-rollover/calldataCheck.t.sol).

To verify locally:

1. Clone: `git clone https://github.com/blockful/dao-proposals.git`
2. Checkout: `git checkout a624dc5`
3. Run: `forge test --match-path "src/ens/proposals/ep-dnssec-ksk-rollover/*" -vv`
