## Live proposal calldata security verification

This proposal is [live](https://app.anticapture.com/ens/governance/proposal/19667497139373951686084433718987773325019389190188449031876262520356769920394).

Calldata executed the expected outcome. The simulation and tests of the **live** proposal can be found [here](https://github.com/blockful/dao-proposals/blob/c9204aefd0d7396b5c9c2df56066401aab34d145/src/ens/proposals/ep-spp3-marketplace-rfp/calldataCheck.t.sol).

To verify locally:

1. Clone: `git clone https://github.com/blockful/dao-proposals.git`
2. Checkout: `git checkout c9204ae`
3. Run: `forge test --match-path "src/ens/proposals/ep-spp3-marketplace-rfp/*" -vv`
