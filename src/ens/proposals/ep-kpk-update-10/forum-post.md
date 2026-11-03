# Pre-draft calldata security verification: Endowment permissions to kpk, Update #10

Blockful has completed an independent review of the executable payload referenced in this proposal (`karpatkey/client-configs`, branch `ens-dao-manager-harvest-rwa-yield`, commit `3e447f8d`).

## Verification result

We reconstructed all 54 transactions of the payload and compared the reconstruction against the published payload byte for byte. The two are identical. Transactions described in the specification were derived from the specification and the public contract interfaces; content the specification does not describe (the module deployment in finding 1, the retained approval list entries, and the annotation text) was transcribed from the payload and checked against the current on-chain configuration. All new permissions are correctly restricted: deposits, withdrawals, and reward payouts can only be directed to the Endowment Safe, approvals are limited to the named protocol contracts, and the Pendle Router cannot be used to route funds through external contracts. No existing permission is removed.

The simulation and tests can be found [here](https://github.com/blockful/dao-proposals/blob/337e3000c1be578a06c343bb04ab642de8a70f9a/src/ens/proposals/ep-kpk-update-10/calldataCheck.t.sol).

## Findings and questions for kpk

**1. Item 6 is implemented through a new module that the proposal text should describe.** Transactions 0 through 7 deploy a second Roles instance, place the Endowment Manager permission set behind it, and transfer its ownership to kpk; we understand it will host the Harvest role, configured by kpk after execution. The claims listed under item 6 are already permitted today, with payouts restricted to the Endowment Safe, so the practical effect of item 6 is a dedicated claim operator. Our simulation confirms that payouts cannot be redirected even if the module is misconfigured. Ownership of the module, however, allows kpk to grant third parties access to the Endowment Manager permission set without a DAO vote. _Question: please describe the module in the proposal text, confirm that its use is limited to the Harvest role, and identify its intended members._

**2. Item 5 is not implemented.** Adding syrupUSDC and syrupUSDT to the swap token lists does not appear in any of the 54 transactions. _Question: will the payload be amended to include it?_

**3. The specification lists an address that does not correspond to a deployed contract.** The table entry for Steakhouse High Yield USDC gives `0xbeeff7aE5E00Aae3Db302e4B0d8C883810a58100`, which holds no code on mainnet. The payload correctly uses `0xbeeff2C5bF38f90e3482a8b19F12E5a6D2FCa757`. _Question: please correct the address in the proposal text._

We further note that the payload extends the approval lists of WETH, USDC, and USDS to the newly added vaults, which the specification tables do not mention.

## Reproduction

1. Clone: `git clone https://github.com/blockful/dao-proposals.git`
2. Checkout: `git checkout 337e300`
3. Run: `forge test --match-path "src/ens/proposals/ep-kpk-update-10/*" -vv`

We will re-run this verification once the payload is finalized and the Tally draft is published.
