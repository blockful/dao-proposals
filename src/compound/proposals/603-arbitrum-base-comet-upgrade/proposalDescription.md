# Complete Arbitrum and Base Comet Upgrade

## Summary

This is a follow-up to [Proposal 596](https://www.tally.xyz/gov/compound/proposal/596), which upgraded Comets on Arbitrum and Base to v1.2.1. That upgrade was split per network into a sub-proposal that bumped the Comet Factory's version to 1.2.1 and a sub-proposal that redeploys each Comet from that same factory.

The execution automation ran these out of order, so the redeploy step for four Comets ran before the factory's version was bumped, deploying the prior version instead:

- Arbitrum cUSDTv3 ('0xd98Be00b5D27fc98112BdE293e487f8D4cA57d07')
- Arbitrum cWETHv3 ('0x6f7D514bbD4aFf3BcD1140B7344b32f063dEe486')
- Base cAEROv3 ('0x784efeB622244d2348d4F2522f8860B96fbEcE89')
- Base cWETHv3 ('0x46e6b214b524310239732D51387075E0e70970bf')

These four are now on an earlier Service Patch release rather than v1.2.1. That patch predates v1.2.1 and does not include the auditor-identified fix for under-paying suppliers when a market has no borrowers, but since all those markets are live there is no impact on current functionality or funds. All other Comets from Proposal 596 upgraded correctly and are unaffected.

The Comet Factory is already at v1.2.1, so this proposal just re-runs 'deployAndUpgradeTo' for the four Comets to finish the upgrade.

## Proposal Actions

The first action sends a cross-chain message to Arbitrum calling 'deployAndUpgradeTo' for cUSDTv3 and cWETHv3.

The second action sends a cross-chain message to Base calling 'deployAndUpgradeTo' for cAEROv3 and cWETHv3.
