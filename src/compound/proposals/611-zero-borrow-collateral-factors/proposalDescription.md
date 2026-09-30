# Set Borrow Collateral Factors to 0 on Deprecated Linea and Mantle Comets
## Simple Summary

Gauntlet recommends setting the borrow collateral factor (BCF) to 0 for every collateral asset on the deprecated Linea cUSDCv3, Linea cWETHv3, and Mantle cUSDEv3 Comets. This stops all new borrowing on these markets. Existing positions keep working: users can still repay debt and be liquidated.

## Motivation

These Comets were deprecated in an earlier proposal. That proposal set collateral supply caps to 0, cut borrow collateral factors by 50%, and updated interest rate parameters. Setting the remaining borrow collateral factors to 0 is the next step in winding down these markets. It removes all remaining borrowing capacity so outstanding exposure can only go down over time.

## Specification

Only `borrowCollateralFactor` changes. Liquidate collateral factors, liquidation factors, supply caps, and interest rate parameters are unchanged.

### Linea cUSDCv3

| Asset  | Current BCF | Proposed BCF |
| ------ | ----------- | ------------ |
| WETH   | 42%         | 0%           |
| wstETH | 41%         | 0%           |
| WBTC   | 40%         | 0%           |

### Linea cWETHv3

| Asset  | Current BCF | Proposed BCF |
| ------ | ----------- | ------------ |
| ezETH  | 90%         | 0%           |
| wstETH | 45%         | 0%           |
| WBTC   | 40%         | 0%           |
| weETH  | 45%         | 0%           |

Linea cWETHv3 wrsETH already has a borrow collateral factor of 0% and is not included.

### Mantle cUSDEv3

| Asset | Current BCF | Proposed BCF |
| ----- | ----------- | ------------ |
| mETH  | 40%         | 0%           |
| WETH  | 41%         | 0%           |
| FBTC  | 39%         | 0%           |

## Proposal Actions

The proposal sends two cross-chain messages from Ethereum mainnet:

1. **Linea** (via the Linea bridge): calls `Configurator.updateAssetBorrowCollateralFactor(comet, asset, 0)` for the 7 Linea assets listed above, then `CometProxyAdmin.deployAndUpgradeTo(configurator, comet)` for Linea cUSDCv3 and Linea cWETHv3.
2. **Mantle** (via the Mantle bridge): calls `Configurator.updateAssetBorrowCollateralFactor(comet, asset, 0)` for the 3 Mantle assets listed above, then `CometProxyAdmin.deployAndUpgradeTo(configurator, comet)` for Mantle cUSDEv3.

## User Impact

* No new borrows can be opened on these Comets.
* Existing borrowers cannot increase their debt or withdraw collateral until they have fully repaid their debt.
* Repayments and liquidations work as before, because liquidate collateral factors and liquidation factors are unchanged.

For the full analysis and risk considerations, see the forum post: [Set Borrow Collateral Factors to 0 on Deprecated Comets (Linea, Ronin, Mantle, Scroll, Unichain)](https://www.comp.xyz/t/set-borrow-collateral-factors-to-0-on-deprecated-comets-linea-ronin-mantle-scroll-unichain/8097)