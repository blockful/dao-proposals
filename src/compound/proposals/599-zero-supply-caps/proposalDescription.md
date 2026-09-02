# Set Zero Supply Caps for Low-Demand LST/LRT Collateral on Ethereum

## Summary

Gauntlet recommends setting the supply caps to `0` for three low-demand LST/LRT collateral listings across the Ethereum WETH and wstETH Comets.

## Proposed Changes

| Comet           | Collateral | Current Supply Cap | Proposed Supply Cap |
| --------------- | ---------- | -----------------: | ------------------: |
| Ethereum WETH   | pufETH     |                105 |                   0 |
| Ethereum WETH   | ezETH      |                500 |                   0 |
| Ethereum wstETH | tETH       |                 44 |                   0 |

Setting a supply cap to `0` prevents users from depositing additional units of the affected collateral into the corresponding Comet.

This proposal does not:

* Force liquidations.
* Change collateral or liquidation factors.
* Prevent withdrawals or repayments.
* Affect existing collateral balances.

Existing positions will continue to operate normally, and users will retain the ability to repay debt and withdraw collateral.

## Proposal Actions

1. Set the pufETH supply cap on the Ethereum WETH Comet to `0`.
2. Set the ezETH supply cap on the Ethereum WETH Comet to `0`.
3. Deploy and upgrade the Ethereum WETH Comet to apply the updated configuration.
4. Set the tETH supply cap on the Ethereum wstETH Comet to `0`.
5. Deploy and upgrade the Ethereum wstETH Comet to apply the updated configuration.

## Additional Information

For the complete motivation, methodology, risk considerations, and supporting data, see the [Compound V3 ETH Comets: Zero Supply Caps for Low-Demand LST/LRT Collateral forum post](https://www.comp.xyz/t/compound-v3-eth-comets-zero-supply-caps-for-low-demand-lst-lrt-collateral/8029).
