# Zeroing Supply Rates on Deprecated Comets

## Proposal summary

Woof proposes to zero out supply rates on deprecated Comets: cUSDCv3 and cWETHv3 on Linea, cUSDev3 on Mantle, cWETHv3 and cWRONv3 on Ronin, and cUSDCv3 on Scroll. This proposal takes the governance steps recommended and necessary to update Compound III markets on each network. Simulations have confirmed the market’s readiness, as much as possible, using the [Comet scenario suite](https://github.com/compound-finance/comet/tree/main/scenario). The new parameters are based on the [recommendations from Gauntlet](https://www.comp.xyz/t/accelerating-deprecation-zeroing-supply-rates-on-deprecated-comets/7997/1).

Further detailed information can be found on the corresponding [proposal pull request](https://github.com/Compound-Foundation/comet/pull/12) and [forum discussion](https://www.comp.xyz/t/accelerating-deprecation-zeroing-supply-rates-on-deprecated-comets/7997).

## Specification

The following parameters apply identically to all six Comets:

| Parameter                      | Proposed |
| ------------------------------- | -------- |
| Annual Supply Rate Base         | 0%       |
| Annual Supply Rate Slope Low    | 0%       |
| Supply Kink                     | 90%      |
| Annual Supply Rate Slope High   | 0%       |

## Proposal Actions

The first action sends a message to the Linea network to zero out supply rates and upgrade the USDC and WETH Comets.

The second action sends a message to the Mantle network to zero out supply rates and upgrade the USDe Comet.

The third action approves the L1CCIPRouter to transfer GHO from the Timelock to pay for the proposal execution fee on Ronin.

The fourth action sends a CCIP message to the Ronin network to zero out supply rates and upgrade the WETH and WRON Comets.

The fifth action sends a message to the Scroll network to zero out supply rates and upgrade the USDC Comet.
