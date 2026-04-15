## Update: Ready for on-chain submission

The RegistrarManager contract has been
[audited by Cyfrin](https://github.com/blockful/dao-proposals/blob/565bfbf/src/ens/proposals/ep-registrar-manager-endowment/audits/2026-03-23-cyfrin-registrar-manager-v2.0.pdf)
and deployed at
[`0x62627681D92e36b9aeE1D9A6BF181373ccd42552`](https://etherscan.io/address/0x62627681D92e36b9aeE1D9A6BF181373ccd42552).

The calldata has been verified, succeeds in simulation, and matches the expected intent. We encourage delegates and
contributors to review the calldata as well.

**Tally draft:** https://www.tally.xyz/gov/ens/draft/2822069893434705582

**Calldata review:**
[calldataCheck.t.sol](https://github.com/blockful/dao-proposals/blob/565bfbf/src/ens/proposals/ep-registrar-manager-endowment/calldataCheck.t.sol)

The draft is ready for a delegate to submit on-chain.

To verify locally:

1. `git clone https://github.com/blockful/dao-proposals.git`
2. `git checkout 565bfbf`
3. `forge test --match-path "src/ens/proposals/ep-registrar-manager-endowment/*" -vv`
