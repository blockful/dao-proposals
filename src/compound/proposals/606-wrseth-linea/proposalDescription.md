# Update wrsETH Price Feed in cWETHv3 on Linea

## Proposal summary

Woof proposes to update wrsETH's price feed on cWETHv3 on the Linea network from the deprecated Kelp oracle to a new Chainlink price feed.

In order to achieve this, wrsETH's price feed will be updated to a new price feed contract with underlying Chainlink ([oracle](https://lineascan.build/address/0xEEDF0B095B5dfe75F3881Cb26c19DA209A27463a)).

This proposal takes the governance steps recommended and necessary to update a Compound III WETH market on Linea. Simulations have confirmed the market's readiness, as much as possible, using the [Comet scenario suite](https://github.com/compound-finance/comet/tree/main/scenario).

Further detailed information can be found on the corresponding [proposal pull request](https://github.com/Compound-Foundation/comet/pull/23).

[Forum](https://www.comp.xyz/t/rseth-oracle-updates-on-unichain-and-linea/8074)

## Proposal Actions

The first proposal action updates wrsETH's price feed and deploys and upgrades Comet to a new version. This sends the encoded 'updateAssetPriceFeed' and 'deployAndUpgradeTo' calls across the bridge to the governance receiver on Linea.