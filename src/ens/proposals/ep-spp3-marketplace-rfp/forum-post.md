## Live proposal calldata security verification

This proposal is now [live](https://anticapture.com/ens/governance/proposal/19667497139373951686084433718987773325019389190188449031876262520356769920394)!

Calldata executes the expected outcome: three USDC transfers from the DAO treasury to the MetaGov Stream Management Pod ([`stream.mg.wg.ens.eth`](https://etherscan.io/address/0xB162Bf7A7fD64eF32b787719335d06B2780e31D1)) — $90,000 for the upfront installments, $100,000 for the four performance gates, and $310,000 for the ENSv2-readiness stream, totaling the $500,000 award. The calldata was reconstructed from first principles and matches the on-chain proposal byte-for-byte, the recomputed proposal id equals the live id, the description is byte-identical to the `ProposalCreated` event, and the recipient is pinned by resolving `stream.mg.wg.ens.eth` on-fork. We also simulated the pod-side release flow end to end — the monthly installments, the stream opening on ENSv2-readiness verification, the gate releases, and the return of unreleased funds at term end — through the same nested-safe path MetaGov will use in production.

The simulation and tests of the **live** proposal can be found [here](https://github.com/blockful/dao-proposals/blob/e531e83123f79d188e991ab3870f858bf9d7d66d/src/ens/proposals/ep-spp3-marketplace-rfp/calldataCheck.t.sol).

To verify locally:

1. Clone: `git clone https://github.com/blockful/dao-proposals.git`
2. Checkout: `git checkout e531e83`
3. Run: `forge test --match-path "src/ens/proposals/ep-spp3-marketplace-rfp/*" -vv`
