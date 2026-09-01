# Stop Legacy On-Chain COMP Reward Accrual; Merkl Migration and Season 1 Update
## Summary

This proposal seeks governance approval for one on-chain action: stop the remaining legacy on-chain COMP reward accrual by setting reward speeds to zero in the affected Comet markets.

It also provides implementation updates on the [<u>Merkl rewards</u>](https://app.compound.xyz/rewards) migration. These migration activities are proceeding under the existing TMC and Risk Manager mandates. Reward funding held in the relevant multisigs is being directed through Merkl, including the method by which accrued and future incentive rewards are delivered.

The Merkl migration does not change the applicable legacy methodology used to calculate previously accrued rewards. It changes how the resulting allocations are distributed and claimed. Season 1 applies the same distribution architecture to future incentives. The on-chain action in this proposal only sets the remaining legacy reward speeds to zero, stopping further technical accrual in the affected Comet markets.

## Background

Since the launch of Compound V2 and V3, COMP rewards have been distributed through protocol-owned reward contracts. Users continuously accrued rewards and could claim them at any time through the Compound interface or directly from the corresponding reward contracts. This mechanism has served since launch, but it has structural limitations:

* Reward logic is embedded in the protocol contracts. Any change to incentives, including rates, markets, or duration, requires a new protocol release, with the engineering and audit work that entails.
* Distribution is continuous by design. There is no native way to run a fixed-term or market-scoped campaign.
* Accrual and funding are independent. The contracts keep accruing rewards whether or not the rewards contract holds COMP, so the accrual a user sees on-chain can diverge from what is actually claimable.
* The claim functions permit any third party to trigger delivery of another account's accrued COMP. This mechanism has been deliberately abused to force COMP into contract addresses with no ability to transfer it out, rendering those rewards inaccessible and exposing further accrued COMP to the same attack.

This is an active security issue, not merely a design limitation. As described in this [<u>post</u>](https://www.comp.xyz/t/pausing-comet-rewards-top-ups/7879), the legacy permissionless claim mechanism has been used maliciously to force COMP into addresses that cannot recover it. Continued operation exposes further accrued COMP to the same misuse. Acting to protect the protocol and prevent further loss falls within the existing protocol-steward mandate.

The Risk Manager's existing mandate covers incentive programs intended to support Comet growth and healthy market behavior. Together with the TMC's responsibility for reward funding held in the relevant multisigs, this includes confirming campaign parameters and directing how funded rewards are delivered. The Merkl migration and Season 1 are being implemented under those mandates.

To address these limitations, the Merkl rewards migration changes the distribution implementation to Merkl, an independent rewards distribution platform used by multiple DeFi protocols. Merkl specializes in distributing on-chain incentives while allowing protocols to maintain transparent and verifiable reward calculations.

The migration changes only the distribution layer. The applicable legacy reward calculations remain unchanged.

## Proposal Overview

This proposal seeks approval for one on-chain action and separately provides implementation updates on the Merkl rewards migration and Season 1.

The action submitted for approval is to set the remaining legacy Comet reward speeds to zero, ending further technical accrual in the affected markets. The Merkl migration update below describes the treatment of previously accrued rewards included in the snapshot ranges for migrated networks.

Season 1 is the first fixed 90-day incentive campaign distributed through Merkl. It is funded from the relevant multisigs and is proceeding under the existing TMC and Risk Manager mandates. Season 1 and all future Merkl-distributed COMP incentive programmes are governed by the Incentive Programme Terms set out below.

This approach separates reward distribution from protocol contracts while allowing the TMC and Risk Manager to confirm and publish future campaign parameters without modifying protocol reward contracts.

## Merkl Rewards Migration Update

Previously accrued rewards included in the snapshot ranges for migrated networks are being moved to Merkl without changing the applicable legacy calculation methodology.

The implementation process consists of reading the relevant on-chain data, aggregating each user's previously accrued rewards using open-source scripts, publishing the resulting allocations, and making those allocations claimable through Merkl. The full snapshot amount is funded by directing COMP from the relevant multisigs to the Merkl distributor.

Users are not required to migrate their positions or perform any protocol interaction. Existing lending and borrowing positions remain completely unaffected.

## Seasonal Incentive Model

Season 1 is being launched as the first Merkl-distributed COMP incentive campaign.

A Season is a fixed 90-day incentive campaign during which users earn rewards through lending and borrowing activity on supported Compound markets.

## Season 1 Parameters

Details of Season 1 will be posted on the website.

* Distribution terms: 
  * Mainnet
    * USDC
      * Lending: 55 COMP/daily
      * Borrowing: 55 COMP/daily
    * USDT
      * Lending: 30 COMP/daily
      * Borrowing: 30 COMP/daily
    * WETH
      * Lending: 10 COMP/daily
      * Borrowing: 20 COMP/daiy

In total 200 COMP/daily

* Maximum COMP allocation: 18,000

Unlike the previous system, rewards cannot be claimed during the Season itself.

Instead, rewards accumulate throughout the campaign. After the Season concludes:

1. A snapshot of accrued rewards is generated.
2. The allocation dataset is published publicly.
3. A dedicated Merkl campaign is created.
4. Users can claim their rewards during the campaign's claim window.

Before each future Season begins, the Compound Governance Working Group (CGWG), TMC and Risk Manager will confirm and publish relevant parameters and terms applying to the relevant Season. This allows the CGWG, TMC and Risk Manager to adjust incentive programs without modifying protocol reward contracts, while ensuring that each Season's parameters are published before it begins.

## Reward Claiming

Previously accrued rewards become claimable through dedicated Merkl campaigns. Future Season rewards become claimable only after the corresponding Season has ended and the reward snapshot has been published.

To claim rewards, users simply connect the wallet that participated in Compound to the official Merkl application and claim any available COMP rewards.

No migration transaction, staking process, or protocol interaction is required. From the snapshot block forward, the Merkl distribution is the DAO's record of reward entitlement.

## Claim Windows

To avoid rewards remaining unclaimed indefinitely, Merkl campaigns include finite claim windows.

Under the Incentive Programme Terms below:

* Previously accrued V2 rewards may be claimed for 60 days after their snapshot.
* Previously accrued V3 rewards may be claimed for 180 days after their snapshot.
* Season rewards may be claimed for 30 days after the Season concludes.

Once a campaign's claim window expires, rewards can no longer be claimed under the current governance rules. COMP that remains unclaimed when a window closes is returned by the TMC, as distributor admin, to the Treasury Timelock.

## If This Proposal Fails

If this proposal fails, the remaining Ethereum USDC, USDT and WETH Comet reward speeds will stay non-zero and the on-chain contracts will continue recording technical accrual. The relevant multisigs will not be reloaded to fund those additional balances, so legacy distribution will remain effectively off despite the continuing accounting entries. The Merkl migration and Season 1 will continue under the existing TMC and Risk Manager implementation.

Existing funded COMP balances in the legacy rewards contracts will remain available for on-chain claims while sufficient balances remain. Any additional balances recorded after the Merkl cutover will not be funded through those contracts.

## Supported Networks

Previously accrued rewards continue to be available for all chains where Compound previously distributed COMP incentives.

The migration covers:

* Ethereum
* Arbitrum
* Optimism
* Base
* Polygon
* Unichain

Mantle and Linea are excluded from this migration and continue using their existing on-chain reward contracts. Rewards on those chains remain claimable through the legacy mechanism and are not subject to the Merkl claim deadlines.

## Snapshot Blocks

Allocations are calculated deterministically and can be independently verified.

For the legacy rewards system, each campaign is calculated over an inclusive block range, meaning both the start and end blocks are included in the reward calculation. These ranges correspond to the governance proposals that either initiated or terminated rewards on each network.

The corresponding block snapshots will be posted on the [forum](https://www.comp.xyz/t/stop-legacy-on-chain-comp-reward-accrual-merkl-migration-and-season-1-update/8043) once the Merkl campaigns are created.

## Merkl Rewards Migration FAQ

*All placeholders will be filled in once the details are ready on the* [*forum*](https://www.comp.xyz/t/stop-legacy-on-chain-comp-reward-accrual-merkl-migration-and-season-1-update/8043)*.*

### Q1

* Question: Why was claiming moved to Merkl?
* Answer: Claiming moved so incentive campaigns can run without changing protocol contracts. Under the old system, every rewards program was tied to a protocol release and carried its own distribution infrastructure. Merkl changes only how rewards are distributed and claimed; Compound's reward calculations remain unchanged. The TMC and Risk Manager confirm the parameters for each Season and publish them before it begins.

### Q2

* Question: Is rewards distribution still active?
* Answer: Yes. Season 1 is active as the first Merkl-distributed incentive campaign. Its parameters were confirmed by the TMC and Risk Manager under their existing mandates and published at [<u>forum</u>](https://www.comp.xyz/t/stop-legacy-on-chain-comp-reward-accrual-merkl-migration-and-season-1-update/8043). Rewards accrued before the Merkl cutover remain available and can be claimed separately. The Snapshot Blocks section records where the legacy distribution period ended and Season 1 began.

### Q3

* Question: How can I verify the accrued rewards calculation is accurate?
* Answer: To calculate your claimable amount for Merkl, an off-chain script reads the on-chain data and applies no additional logic beyond aggregating it. You can verify your own number two ways: (1) check the calculation script's source code (see on the [<u>forum</u>](https://www.comp.xyz/t/stop-legacy-on-chain-comp-reward-accrual-merkl-migration-and-season-1-update/8043)), which is open and published on GitHub, or (2) independently read your \`baseTrackingAccrued\` value directly from the \[CometRewards contract]\(https://github.com/compound-foundation/comet/blob/main/contracts/CometRewards.sol#L207) on a block explorer and compare it to what Merkl shows. This method applies to V3. For V2, the calculation reads the Comptroller contract's reward state; the V2 script linked under "Do rewards expire?" shows the exact method. 

##

### Q4

* Question: What's the official Merkl link, and what happens once I leave the Compound app?
* Answer: The only official Merkl app URL is app\[.]merkl\[.]xyz]. Once you leave the Compound app for Merkl, you're interacting with an independent, third-party platform; Compound Foundation and Compound DAO aren't responsible for actions taken there.

### Q5

* Question: What chains are supported for rewards?
* Answer: All chains where Compound DAO has historically distributed rewards: \*\*V2\*\* — \[Ethereum]\({{V2\_ETHEREUM\_MERKL\_LINK}}). \*\*V3\*\* — \[Ethereum]\({{V3\_ETHEREUM\_MERKL\_LINK}}), \[Arbitrum]\({{V3\_ARBITRUM\_MERKL\_LINK}}), \[Optimism]\({{V3\_OPTIMISM\_MERKL\_LINK}}), \[Unichain]\({{V3\_UNICHAIN\_MERKL\_LINK}}), \[Polygon]\({{V3\_POLYGON\_LINK}}), \[Base]\({{V3\_BASE\_MERKL\_LINK}}). See all the links on the [<u>forum</u>](https://www.comp.xyz/t/stop-legacy-on-chain-comp-reward-accrual-merkl-migration-and-season-1-update/8043). Mantle and Linea rewards are claimed on-chain, not through Merkl; see "Have all V3 chains migrated to the new Merkl distribution system?" below. 

### Q6

* Question: Are V2 rewards available only on Ethereum?
* Answer: Yes. Compound V2 rewards are only on Ethereum.

### Q7

* Question: Can I still see my rewards in the old on-chain system after claiming via Merkl?
* Answer: Yes. Even after claiming COMP via Merkl, you can still view your historical reward balance in the old on-chain system (except on Mantle and Linea, where that system is still the active claim method). No new rewards are distributed through the old system on any other chain; Merkl has fully replaced it there. The balance the old contracts display after migration is historical only. The Merkl distribution is the DAO's record of reward entitlement, and amounts claimed through Merkl are not payable again from the old contracts 

### Q8

* Question: Have all V3 chains migrated to the new Merkl distribution system?
* Answer: No. Ethereum, Arbitrum, Optimism, Unichain, Polygon, and Base have migrated to Merkl. \*\*Mantle and Linea have not\*\* — claim there directly through the original on-chain reward contracts:
* Mantle: 0xCd83CbBFCE149d141A5171C3D6a0F0fCCeE225Ab
* Linea: 0x2c7118c4C88B9841FCF839074c26Ae8f035f2921

### Q9

* Question: What is a "Season," how are its rewards distributed, when can I claim them, and do they expire?
* Answer: A Season is a fixed-term incentive campaign during which users accrue COMP rewards through lending and borrowing activity. Season 1 runs for 90 days. It distributes 200 COMP per day, up to 18,000 per Season 1, across USDC, USDT and WETH V3 markets on Mainnet. Rewards cannot be claimed during the Season. After it ends, the allocation snapshot is published on [forum](https://www.comp.xyz/t/stop-legacy-on-chain-comp-reward-accrual-merkl-migration-and-season-1-update/8043) and a dedicated Merkl claim campaign opens for \[30] days. Before each subsequent Season begins, the TMC and Risk Manager will confirm its parameters and publish them in advance.

### Q10

* Question: What block ranges were rewards calculated over? 
* Answer: For the legacy rewards distribution mechanism, rewards were calculated from the snapshot block at which the first rewards campaign for a given market began (or from the market deployment block if rewards started immediately) through the block at which the last rewards campaign ended. Both the start and end blocks are included in the calculation (i.e., the block range is inclusive on both ends).

## Incentive Programme Terms

These terms govern Season 1 and all future COMP incentive programmes distributed through Merkl.

1. COMP accrues only in the markets, at the rates and for the period published before a Season begins. Participation in one Season creates no entitlement to rewards in any future Season.
2. The programme is administered by the Compound Governance Working Group (CGWG), Treasury Management Committee (TMC) and the Risk Manager. The TMC multisig holds the Merkl distributor admin role, and its signers are publicly disclosed.
3. Claims are made through the Merkl distributor. Merkl is a third-party platform, and claims are also subject to Merkl's terms.
4. Each campaign's published claim window applies: 60 days for previously accrued V2 rewards, 180 days for previously accrued V3 rewards and the period published for each Season. Unclaimed COMP is returned by the TMC to the Treasury Timelock when the window closes.
5. For migrated networks, the published Merkl distribution is the DAO's definitive record of reward entitlement for the period it covers. Mantle and Linea remain on their existing on-chain reward contracts and are outside that record.
6. Allocations are calculated from on-chain data using published open-source scripts. If a published allocation differs from a legacy contract display, the published allocation governs for the relevant campaign.
7. Reward speeds recorded in Comet contracts after a snapshot do not establish that additional COMP is owed. No COMP is appropriated to legacy reward contracts; funding them would require a new DAO appropriation.
8. Recipients are responsible for any tax arising from COMP they receive.
9. The TMC, Risk Manager and CGWG may set, change or end a Season by a joint forum update within their existing mandates. These terms may be amended only by a joint forum update from the TMC, Risk Manager and CGWG.
