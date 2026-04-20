# [EP 6.8] [Executable] Endowment permissions to karpatkey - Update #5

# Abstract

This proposal aims to introduce new permissions for deploying Endowment funds, with a continued focus on diversification
and alignment with the evolving market landscape and liquidity.

# Motivation

The proposal seeks to request new permissions from the ENS DAO to karpatkey, such that the permissions are aligned with
evolving market conditions and protocol updates.

The proposed new permissions focus on strategies involving:

- **Protocol update**: MakerDAO migration to Sky Protocol
- Continuous diversification of **Ethereum LST providers**: Origin Protocol
- Continuous diversification to **Stablecoin offerings**: USDT, Real-World Assets (Mountain Protocol)
  - **Why USDT?** While USDC is a reliable and widely-used stablecoin, adding USDT enhances the diversification of
    counterparty and operational risks within the endowment. By holding both, the endowment mitigates potential risks
    associated with reliance on a single issuer, and USDT’s higher liquidity and wider acceptance in different market
    conditions can enhance resilience during periods of stress.
  - **Why Real-World Assets (RWAs)?** Stablecoins, although designed to maintain a 1:1 peg with fiat, carry counterparty
    and systemic risks that could be difficult to foresee. RWAs bypass these risks by directly linking the endowment to
    established, traditional off-chain assets. Tokenised T-Bills (or equivalent) provide a reliable venue to mitigate
    potential risks associated with stablecoin black swan events. For the selection of tokenised T-Bills, due diligence
    on products available in the market was conducted with the following non-exhausitve criteria: AUM/TVL, underlying
    assets, liquidity, legal design, and fees; this was assessed in conjunction with suitability for the Endowment (e.g.
    secondary liquidity). At present, on-chain yields exceed traditional risk-free rates, making immediate RWA
    allocation unlikely. However, we will continue to monitor both markets for future opportunities.

# Specification

## New permissions implemented in this payload

1. Sky USDS
   - Upgrade DAI into USDS
   - Deposit and Withdraw USDS in Spark (Sky Savings Rate)
   - Deposit USDS in [SKY Farm](https://app.spark.fi/farms/1/0x0650CAF159C5A49f711e8169D4336ECB9b950275) & claim rewards
   - Deposit USDS into Aave v3 & claim rewards
2. Origin oETH
   - Mint oETH in vault
   - Redeem WETH via ARM and vault
   - Curve: whitelist oETH/ETH pool for swap, liquidity provision, staking, claim rewards, unstake, and withdraw
   - Convex: whitelist staking of oETH/ETH LP token, claim rewards, unstake, and withdraw
3. USDT
   - Deposit USDT on Aave v3
   - Deposit USDT on Compound v3
   - Curve: whitelist DAI/USDC/USDT pool for swap, liquidity provision, staking, claim rewards, unstake, and withdraw
4. RWA
   - Mountain Protocol: USDM
   - Whitelist Curve sDAI/USDM pool for swap, liquidity provision, staking, claim rewards, unstake, and withdraw
5. Token Arrays for Swapping:
   - Add the following tokens for Token IN Allowlist in Cow, Uniswap v3, Balancer: \[USDS, sUSDS, oETH, USDT, USDM]
   - Add the following tokens for Token OUT Allowlist in Cow, Uniswap v3, Balancer: \[USDS, sUSDS, oETH, USDT, USDM]

## Implications on the ENS Investment Policy Statement

The ENS Investment Policy Statement shall reflect the above changes, i.e. The ENS Investment Policy Statement will be
updated to accommodate allowing US Treasury Bill wrappers as eligible holdings.

We also received feedback that the IPS requirement of holding at least 3 years of DAO operating expenses in stablecoin
was unclear as to whether this referred to the endowment or across the ENS DAO wallets. This has been clarified to
reflect the latter (at least 3 years of DAO operating expenses in stablecoins across ENS DAO wallets).

The
updated [Investment Policy Statement](https://copper-added-anglerfish-892.mypinata.cloud/ipfs/bafybeiajihjdrplt75h36upclptjmkqziboekuf7e25fgfuyk2m54sonfi) has
been pinned on IPFS.

# Zodiac Roles Modifier Permissions Policy

The payload to be executed upon the successful approval of this proposal can be
found [here](https://gist.github.com/JeronimoHoulin/02674b705ccc24ed1285b8d55f4ec790) (to be downloaded, unzipped, and
dropped
into [Safe’s transaction builder](https://app.safe.global/apps/open?safe=eth:0x4F2083f5fBede34C2714aFfb3105539775f7FE64&appUrl=https%3A%2F%2Fapps-portal.safe.global%2Ftx-builder)).

The UI visualization of added (green), removed (red), and updated (blue) permissions is
available [here](https://roles.gnosisguild.org/eth:0x703806E61847984346d2D7DDd853049627e50A40/roles/MANAGER/diff/O7n3WhgerkVBpURmrrpkw5sxzV1srQLr7AdUiISSXKw?annotations=false),
as well as the resulting Tenderly simulation
available [here](https://dashboard.tenderly.co/public/safe/safe-apps/simulator/0e5363fa-dc47-4a70-9c76-9dc5fd142bac).

The permissions in this proposal have been tested beforehand through
our [Test Safe](https://app.safe.global/transactions/history?safe=eth:0xC01318baB7ee1f5ba734172bF7718b5DC6Ec90E1)
