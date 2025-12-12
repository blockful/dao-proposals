# [EP #] [Executable] Endowment permissions to karpatkey - Update #7
## Abstract

This proposal introduces a routine update to the permissions for the Endowment Manager. These updates continue to evolve diversification to lending markets. This update also removes a permission no longer needed.

## Motivation

The permissions in this update focus on in increasing the availability of lending markets, specifically Morpho Vaults curated by kpk and others on Fluid Protocol.

## Specification

This proposal adds and removes the following contracts and functions:

### ✅ Additions

#### 1. Tokens

|Token|Functions Allowed|Token Address (Mainnet)|

| --- | --- | --- |

|Circle: EURC|`approve`|0x1aBaEA1f7C830bD89Acc67eC4af516284b1bC33c|

|GHO|`approve`|0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f|

#### 2. Morpho Lending Markets

|Market|Functions Allowed|Vault Contract Address (Mainnet)|

| --- | --- | --- |

|[kpk USDC Prime](https://app.morpho.org/ethereum/vault/0x4Ef53d2cAa51C447fdFEEedee8F07FD1962C9ee6/kpk-usdc)|`deposit` `withdraw` `redeem`|0xe108fbc04852B5df72f9E44d7C29F47e7A993aDd|

|[kpk USDC (v2)](https://app.morpho.org/ethereum/vault/0x4Ef53d2cAa51C447fdFEEedee8F07FD1962C9ee6/kpk-usdc)|`deposit` `withdraw` `redeem`|0x4Ef53d2cAa51C447fdFEEedee8F07FD1962C9ee6|

|[kpk ETH Prime](https://app.morpho.org/ethereum/vault/0xd564F765F9aD3E7d2d6cA782100795a885e8e7C8/kpk-eth-prime)|`deposit` `withdraw` `redeem`|0xd564F765F9aD3E7d2d6cA782100795a885e8e7C8|

|[kpk ETH (v2)](https://app.morpho.org/ethereum/vault/0xBb50A5341368751024ddf33385BA8cf61fE65FF9/kpk-eth)|`deposit` `withdraw` `redeem`|0xBb50A5341368751024ddf33385BA8cf61fE65FF9|

|[kpk EURC Yield](https://app.morpho.org/ethereum/vault/0x0c6aec603d48eBf1cECc7b247a2c3DA08b398DC1/kpk-eurc-yield)|`deposit` `withdraw` `redeem`|0x0c6aec603d48eBf1cECc7b247a2c3DA08b398DC1|

|[kpk EURC (v2)](https://app.morpho.org/ethereum/vault/0xa877D5bb0274dcCbA8556154A30E1Ca4021a275f/kpk-eurc)|`deposit` `withdraw` `redeem`|0xa877D5bb0274dcCbA8556154A30E1Ca4021a275f|

#### 3. Fluid Protocol Lending Markets

|Market|Functions Allowed|Vault Contract Address (Mainnet)|

| --- | --- | --- |

|Fluid protocol USDC|`deposit` `withdraw` `redeem`|0x9Fb7b4477576Fe5B32be4C1843aFB1e55F251B33|

|Fluid protocol USDT|`deposit` `withdraw` `redeem`|0x5C20B550819128074FD538Edf79791733ccEdd18|

|Fluid protocol GHO|`deposit` `withdraw` `redeem`|0x6A29A46E21C730DcA1d8b23d637c101cec605C5B|

#### 4. Other

|Name|Functions Allowed|Contract Address (Mainnet)|

| --- | --- | --- |

|Fluid Merkl Distributor|`claim`|0x7060FE0Dd3E31be01EFAc6B28C8D38018fD163B0|

### ❌ Removals

#### Other

|Name|Functions Removed|Contract Address (Mainnet)|

| --- | --- | --- |

|Universal Rewards Distributor|`claim`|0x330eefa8a787552DC5cAd3C3cA644844B1E61Ddb|

## Reviewing Zodiac Roles Modifier Permissions Policy

To review, the following resources are below:

* **Payload:** [https://github.com/karpatkey/client-configs/blob/main/clients/ens-dao/mainnet/payloads/ensPermissionsUpdate7.json](https://github.com/karpatkey/client-configs/blob/main/clients/ens-dao/mainnet/payloads/ensPermissionsUpdate7.json)

* **Zodiac Diff Visualisation Tool:** [https://roles.gnosisguild.org/eth:0x703806E61847984346d2D7DDd853049627e50A40/roles/MANAGER/diff/NCKRMzEwQHav0XGhlSQXPisyWHkCUihyD6KAhZBVSY?annotations=false](https://roles.gnosisguild.org/eth:0x703806E61847984346d2D7DDd853049627e50A40/roles/MANAGER/diff/NCKRMzEwQHav0XGhlSQXPisyWHkCUihyD6KAhZBVSY?annotations=false)

The Zodiac Diff Visualization Tool is a helpful way to see the additions (green), removed (red), and updated (blue) permissions.

## Considerations

The assets in these lending markets are considered to conform to the risk tolerance specified in the [Investment Policy Statement (IPS)](https://copper-added-anglerfish-892.mypinata.cloud/ipfs/bafybeiajihjdrplt75h36upclptjmkqziboekuf7e25fgfuyk2m54sonfi).

Morpho vaults curated by kpk collect no additional fees.

## Next Steps

The proposal will be introduced in the next meta-governance call. Pending review from Blockful and no revisions following the discussion in during the meta-gov call, this proposal will progress to an on-chain executable vote.