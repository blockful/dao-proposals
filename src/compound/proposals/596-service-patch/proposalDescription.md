# Update All L2 Comets to the service patch version

## Proposal summary

WOOF! proposes upgrading next Comet markets:

- Arbitrum: USDC, USDC.e, USDT and WETH
- Base: USDC, USDbC, USDS, AERO and WETH
- Optimism: USDC, USDT and WETH
- Polygon: USDC and USDT
- Mantle: USDe
- Unichain: USDC and WETH

To a new service patch version introducing several improvements and security enhancements:

- Extended Pause Controls: collateral interactions can now be paused independently per collateral asset.
- Price Feed Patch (Post-USDM incident response): skips price feed calls for assets with zero collateral factor, preventing unnecessary reverts.
- Collateral Deactivation Mechanism: introduces a Guardian-controlled emergency mechanism to deactivate unsafe collateral assets, with reactivation requiring a governance proposal.
- Utilization Peaking Protection: caps utilization at 200%, preventing additional borrowing when post-borrow utilization exceeds this threshold, while preserving lender withdrawals.
- Borrow Index Fix (Empty Market): prevents borrow interest accrual in markets without active borrowers.
- Supply Index Fix (Empty Market): ensures supply index only accrues when lenders are present.
- Lender Illiquidity Fix in Zero-Borrow Markets: prevents reserve depletion in markets with no borrowers by capping supply rate to zero when utilization is zero and reserves are exhausted.
- Accrue Interest on Collateral Actions (Post-USDM incident response): collateral actions (supply, withdraw, transfer) now trigger interest accrual for affected accounts.
- Technical Improvements: includes removal of redundant arguments in supplyInternal() and optimized price caching in absorbInternal(), improving gas efficiency without affecting protocol behavior.

This proposal takes the governance steps recommended and necessary to update Compound III markets. Simulations have confirmed the market’s readiness, as much as possible, using the [Comet scenario suite](https://github.com/compound-finance/comet/tree/main/scenario).

Detailed information can be found on the corresponding [proposal pull request](https://github.com/compound-finance/comet/pull/1132).

### Bytecode Repository

This update is done with the use of the bytecode repository, which provides trustless and deterministic deployments.

Further details on the deployment can be found in the [Bytecode Repository git](https://github.com/woof-software/bytecode-repository) and [forum discussion](https://www.comp.xyz/t/rfc-bytecode-repository-and-deployment-pipeline-modernization/6965).

### Audit

Both service patch Comet update and Bytecode Repository have been audited by Certora and full reports can be found here:

- [Certora Comet Service Patch Audit](https://www.certora.com/reports/comet-service-patch)
- [Certora Bytecode Repository Audit](https://www.certora.com/reports/compound-bytecoderepository)

## Proposal Actions

The first action sets the factory to the newly deployed factory, extension delegate to the newly deployed contract and deploys and upgrades Arbitrum USDC and USDC.e Comets to a new version.

The second action sets the factory to the newly deployed factory, extension delegate to the newly deployed contract and deploys and upgrades Arbitrum USDT and WETH Comets to a new version.

The third action sets the factory to the newly deployed factory, extension delegate to the newly deployed contract and deploys and upgrades Base USDC, USDbC and USDS Comets to a new version.

The fourth action sets the factory to the newly deployed factory, extension delegate to the newly deployed contract and deploys and upgrades Base AERO and WETH Comets to a new version.

The fifth action sets the factory to the newly deployed factory, extension delegate to the newly deployed contract and deploys and upgrades Optimism USDC, USDT and WETH Comets to a new version.

The sixth action sets the factory to the newly deployed factory, extension delegate to the newly deployed contract and deploys and upgrades Polygon USDC and USDT Comets to a new version.

The seventh action sets the factory to the newly deployed factory, extension delegate to the newly deployed contract and deploys and upgrades Mantle USDe Comet to a new version.

The eighth action sets the factory to the newly deployed factory, extension delegate to the newly deployed contract and deploys and upgrades Unichain USDC and WETH Comets to a new version.
