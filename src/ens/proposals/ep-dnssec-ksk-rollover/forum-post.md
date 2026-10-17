## Draft proposal calldata security review

**The draft has no actions attached.** Its Actions section is empty, so publishing it as it stands would create a proposal with no executable calls. The two `setController` calls from the Transactions section need to be added as actions, with the new DNSRegistrar address once it is deployed.

We reviewed the calldata against the Transactions table and the Calldata block in the description instead. Both calls match our independently derived calldata: the second byte for byte, the first apart from the `<new DNSRegistrar>` placeholder.

Since the new contracts are not deployed yet, we compiled DNSSECImpl, OffchainDNSResolver and DNSRegistrar from `f0151aa` and deployed them on a mainnet fork in their place, wired as the "Deployed contracts" table describes. With them, the proposal executes and:

- the new registrar takes over `.domains` and `.xyz` through the permissionless `enableNode`, and points them at the new resolver; imported names (e.g. `ens.domains`) are untouched, and stored inceptions carry over from the current registrar
- `proveAndClaim` with a chain from the current, KSK-2024-signed root DNSKEY RRset works on the new registrar and fails on the current one
- gasless resolution (`taytems.xyz`) works through the new OffchainDNSResolver and fails through the current one
- the current registrar can no longer assign TLDs through Root

Points to address before publishing:

1. **No actions attached** (above).
2. **Timeline.** The current oracle still verifies the gateway's proofs today, because the gateway still serves the root DNSKEY RRset with the KSK-2017 signature made on 2026-10-01. That signature expires at **2026-10-22 00:00 UTC**, so proofs built on it fail by then at the latest (sooner if the gateway switches to the KSK-2024-signed RRset), and stay broken until this proposal executes, which takes at least ~8.4 days from submission (voting period plus the 2-day timelock). The abstract says resolution and imports already broke on 11 October; it would help to correct that and set expectations for the gap.
3. **The 2021 DNSRegistrar is still a Root controller.** `0x58774Bb8acD458A640aF0B88238369A167546ef2`, the registrar before `0xB32c…`, was never deauthorised. The reasoning for removing `0xB32c…` applies to it as well, and its claim path can be used by anyone to take ownership of unowned TLDs through Root. We suggest adding a third call, `setController(0x58774Bb8acD458A640aF0B88238369A167546ef2, false)`. Nothing depends on it holding the role.
4. **Minor:** the previous-registrars list in the "Deployed contracts" table ends in `...`, but the deploy script resolves it to exactly `[0xB32cB5677a7C971689228EC835800432B339bA2B, 0x58774Bb8acD458A640aF0B88238369A167546ef2]`.

Once the contracts are deployed and the actions are attached, we will re-run the review against the real addresses, including comparing the deployed bytecode against `f0151aa` and checking ownership, anchors and constructor arguments.

The simulation and tests can be found [here](https://github.com/blockful/dao-proposals/blob/8c76e3e8f7f460d22bed71a87eba726172f7bb83/src/ens/proposals/ep-dnssec-ksk-rollover/calldataCheck.t.sol).

To verify locally:

1. Clone: `git clone https://github.com/blockful/dao-proposals.git`
2. Checkout: `git checkout 8c76e3e`
3. Run: `forge test --match-path "src/ens/proposals/ep-dnssec-ksk-rollover/*" -vv`
