# Completion of pumpBTC Deprecation on cWBTCv3

## Proposal summary

WOOF! proposes to complete the deprecation of pumpBTC as collateral on cWBTCv3. pumpBTC's supply cap was already reduced to 0 and its price feed already points to a constant price feed of 1 wei ([Compound Governance Proposal 605](https://www.tally.xyz/gov/compound/proposal/605)). This proposal finishes the process by zeroing out pumpBTC's borrow collateral factor, liquidate collateral factor, and liquidation factor, fully de-listing it as collateral.

These configuration changes are bundled with an update of the cWBTCv3 Comet to the recent service patch version, and both are applied together in a single deployAndUpgradeTo call.

Detailed information can be found on the corresponding [proposal pull request](https://github.com/Compound-Foundation/comet/pull/24).

## Proposal Actions

The proposal actions fully deprecates pumpBTC as collateral on cWBTCv3 by zeroing out its borrow collateral factor, liquidate collateral factor, and liquidation factor, and then deploying and upgrading the WBTC Comet to apply these changes.
