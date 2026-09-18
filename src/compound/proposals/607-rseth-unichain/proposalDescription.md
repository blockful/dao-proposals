# Deprecate rsETH from cWETHv3 on Unichain

## Proposal summary

Woof proposes to deprecate rsETH from cWETHv3 on Unichain network, due to its Kelp oracle deprecation.

In order to achieve this, rsETH's price feed will be updated to a new one, which will return the smallest acceptable price - 0.00000001 (1e-8); the borrow collateral factor, liquidation factor and liquidate collateral factor will be set to 0; the supply cap will be set to 0 to prevent further deposits.

This proposal takes the governance steps recommended and necessary to update a Compound III WETH market on Unichain. Simulations have confirmed the market's readiness, as much as possible, using the [Comet scenario suite](https://github.com/compound-finance/comet/tree/main/scenario).

Further detailed information can be found on the corresponding [proposal pull request](https://github.com/Compound-Foundation/comet/pull/22).

[Forum](https://www.comp.xyz/t/rseth-oracle-updates-on-unichain-and-linea/8074)

## Proposal Actions

The first proposal action updates rsETH config to a deprecated state and deploys and upgrades Comet to a new version. This sends the encoded 'updateAsset' and 'deployAndUpgradeTo' calls across the bridge to the governance receiver on Unichain.