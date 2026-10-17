## Draft proposal calldata security review

**The draft has no actions attached.** Publishing it as it stands would create a proposal with no calls. The two `setController` calls need to be added as actions once the new DNSRegistrar is deployed.

The calldata written in the description is correct: both calls match our independent derivation. We built DNSSECImpl, OffchainDNSResolver and DNSRegistrar from `f0151aa`, deployed them on a mainnet fork, and replayed live DNSSEC proofs. After execution, TLDs migrate, `proveAndClaim` works with KSK-2024 chains, and gasless resolution works through the new resolver. We found no critical or high issue in the PR #572 code.

Points to address:

1. **No actions attached** (above).
2. **Timeline.** Imports through the ENS app have been broken since 11 October, as the draft says. Gasless resolution is not broken yet: the gateway still serves the root DNSKEY RRset signed by KSK-2017 on 2026-10-01, which the current oracle accepts until **2026-10-22 00:00 UTC** at the latest. Execution takes at least ~8.4 days from submission, so expect a resolution outage of several days.
3. **Off-chain prerequisites that the draft does not mention.** Executing the proposal alone does not restore DNSSEC:
   - the gateway needs redeploying with the KSK-2024 anchor (its public repo pins `dnsprovejs` 0.4.1), ideally before execution. Otherwise resolution stays down, and once anyone claims with the current root signature, gateway-built proofs fail the new `StaleProof` check;
   - the ENS app and ensjs need `dnsprovejs` >= 1.0.1, and ensjs's oracle address must be updated, or imports stay broken;
   - `.hiphop` is held by a third party with the old resolver and cannot be migrated by `enableNode`; its owner has to switch it;
   - `dnssec.ens.eth` and `dnsregistrar.ens.eth` still point at the old contracts.
4. **Also deauthorise the 2021 DNSRegistrar.** `0x58774Bb8acD458A640aF0B88238369A167546ef2` is still a Root controller and can be used to take unowned TLDs. It holds none today, so revoking it breaks nothing. We suggest adding `setController(0x58774Bb8acD458A640aF0B88238369A167546ef2, false)`.
5. **Minor.** After 22 October the KSK-2017 anchor will never validate anything again: IANA revokes KSK-2017 on 2027-01-11 and removes it on 2027-03-22. Consider deploying with KSK-2024 only, or plan the `setAnchors` call. Also, the previous-registrars list resolves to exactly two addresses, not `[..., ...]`.

We will re-run the review against the real addresses once the contracts are deployed and the actions are attached, including a bytecode comparison with `f0151aa`.

The simulation and tests can be found [here](https://github.com/blockful/dao-proposals/blob/2b6370ee125f2c3f07159f627b330bdee4be7ebd/src/ens/proposals/ep-dnssec-ksk-rollover/calldataCheck.t.sol).

To verify locally:

1. Clone: `git clone https://github.com/blockful/dao-proposals.git`
2. Checkout: `git checkout 2b6370e`
3. Run: `forge test --match-path "src/ens/proposals/ep-dnssec-ksk-rollover/*" -vv`
