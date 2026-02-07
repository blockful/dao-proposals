# UNIfication

*This vote covers the [UNIfication proposal](https://gov.uniswap.org/t/unification-proposal/25881) and includes the final copy of the services agreement, indemnification agreements for the independent negotiation committee, final spec, and an updated list of v3 pools that has been refreshed to reflect the latest available data. We recommend reading the full details before voting.*

## Proposal Spec

If this proposal passes, it will execute eight function calls:

```
/// Burn 100m UNI
UNI.transfer(0xdead, 100_000_000 ether);

/// Set the owner of the v3 factory on mainnet to the configured fee controller to enable v3 protocol fees
V3_FACTORY.setOwner(address(v3FeeController));

/// Change the FeeToSetter parameter on the v2 factory on mainnet to the Governance Timelock
IOldV2FeeToSetter(V2_FACTORY.feeToSetter()).setFeeToSetter(TIMELOCK);

/// Change the FeeTo parameter on the v2 factory on mainnet to enable v2 protocol fees
V2_FACTORY.setFeeTo(address(tokenJar));

/// Approve two years of vesting into the UNIVester smart contract  
/// UNI stays in treasury until vested and unvested UNI can be cancelled by setting approve back to 0
UNI.approve(address(uniVesting), 40_000_000 ether);

/// Execute the services agreement with Uniswap Labs on behalf of DUNI
AgreementAnchor.attest(address(0xC707467e7fb43Fe7Cc55264F892Dd2D7f8Fc27C8));

/// Execute the indemnification agreement with Hart Lambur on behalf of DUNI
AgreementAnchor.attest(address(0x33A56942Fe57f3697FE0fF52aB16cb0ba9b8eadd));

/// Execute the indemnification agreement with DAO Jones LLC on behalf of DUNI  
AgreementAnchor.attest(address(0xF9F85a17cC6De9150Cd139f64b127976a1dE91D1));
```

## Proposal

*Hayden Adams, Ken Ng, Devin Walsh*

Today, Uniswap Labs and the Uniswap Foundation are excited to make a joint governance proposal that turns on protocol fees and aligns incentives across the Uniswap ecosystem, positioning the Uniswap protocol to win as the default decentralized exchange for tokenized value.

The protocol has processed \~$4 trillion in volume, made possible by thousands of developers, millions of liquidity providers, and hundreds of millions of swapping wallets.

But the last several years have also come with obstacles: we’ve fought legal battles and navigated a hostile regulatory environment under Gensler’s SEC. This climate has changed in the US, and milestones like Uniswap governance adopting [DUNI](https://gov.uniswap.org/t/governance-proposal-establish-uniswap-governance-as-duni-a-wyoming-duna/25770), the [DUNA](https://a16zcrypto.com/posts/article/duna-for-daos/), have prepared the Uniswap community for its next steps.

This proposal comes as DeFi reaches an inflection point. Decentralized trading protocols are [rivaling](https://www.theblock.co/data/decentralized-finance/dex-non-custodial/dex-to-cex-spot-trade-volume) centralized platforms in performance and scale, tokens are going mainstream, and institutions are building on Uniswap and other DeFi protocols.

This proposal establishes a long-term model for how the Uniswap ecosystem would operate, where protocol usage drives UNI burn and Uniswap Labs focuses on protocol development and growth. We propose to:

1. Turn on Uniswap protocol fees and use these fees to burn UNI  
2. Send Unichain sequencer fees to this same UNI burn mechanism  
3. Build Protocol Fee Discount Auctions (PFDA) to increase LP returns and allow the protocol to internalize MEV  
4. Launch aggregator hooks, turning Uniswap v4 into an onchain aggregator that collects fees on external liquidity  
5. Burn 100 million UNI from the treasury representing the approximate amount of UNI that would have been burned if fees were on from the beginning  
6. Focus Labs on driving protocol development and growth, including turning off our interface, wallet, and API fees and contractually committing to only pursue initiatives that align with DUNI interests  
7. Move ecosystem teams from the Foundation to Labs, with a shared goal of protocol success, with growth and development funded from the treasury  
8. Migrate governance-owned Unisocks liquidity from Uniswap v1 on mainnet to v4 on Unichain and burn the LP position, locking in the supply curve forever

### Protocol Fees

The Uniswap protocol includes a fee switch that can only be turned on by a UNI governance vote. We propose that governance flip the fee switch and introduce a programmatic mechanism that burns UNI.

#### Protocol Fee Rollout

To minimize impact, we propose fees roll out over time, starting with v2 pools and a set of v3 pools that make up 80-95% of LP fees on Ethereum mainnet. From there, fees can be turned on for L2s, other L1s, v4, UniswapX, PFDA, and aggregator hooks.

Uniswap v2 fee levels are hardcoded and governance must enable or disable fees across all v2 pools at once. With fees off, LP fees are 0.3%. Once activated, LP fees are 0.25% and protocol fees are 0.05%.

Uniswap v3 has fixed swap fee tiers on mainnet, with protocol fees that are adjustable by governance and set at the individual pool level. Protocol fees for 0.01% and 0.05% pools would initially be set to 1/4th of LP fees. For 0.30% and 1% pools, protocol fees would be set to 1/6th of LP fees.

Labs will assist the community in monitoring the impact of fees and may make recommendations to adjust. To improve efficiency, we propose governance votes on fee parameters skip the RFC process and move straight to Snapshot followed by an onchain vote.

***Update 12/18:***

The list of Uniswap v3 pools included in the proposal has been refreshed to reflect the latest available data. The full updated list can be found [here](https://github.com/Uniswap/protocol-fees/blob/main/merkle-generator/data/merkle-tree.json).

#### Unichain Sequencer Fees

Unichain launched just 9 months ago, and is already processing \~$100 billion in annualized DEX volume and \~$7.5 million annualized sequencer fees.

This proposal directs all Unichain sequencer fees, after L1 data costs and the 15% to Optimism, into the burn mechanism.

#### Fee Mechanism for MEV Internalization

The Protocol Fee Discount Auction (PFDA) is designed to improve LP performance and add a new source of protocol fees by internalizing MEV that would otherwise go to searchers or validators.

This mechanism auctions off the right to swap without paying the protocol fee for a single address for a short window of time, with the winning bid going to the UNI burn. Through this process, MEV that would typically go to validators instead burns UNI. For a detailed breakdown of this mechanism, read the [whitepaper](https://drive.google.com/file/d/1qhZFLTGOOHBx9OZW00dt5DzqEY0C3lhr/view?usp=sharing).

Early analysis shows these discount auctions could increase LP returns by about $0.06-$0.26 for every $10k traded, a significant improvement given that LP returns typically range between \-$1.00 and $1.00 for this amount of volume.

#### Aggregator Hooks

Uniswap v4 introduced hooks, turning the protocol into a developer platform with infinite possibilities for innovation. Labs is excited to be one of the many teams unlocking new functionality using hooks, starting with aggregation.

These hooks source liquidity from other onchain protocols and add a programmatic UNI burn on top, turning Uniswap v4 itself into an aggregator that anyone can integrate.

Labs will integrate aggregator hooks into its frontend and API, providing users access to more sources of onchain liquidity in a way that benefits the Uniswap ecosystem.

#### Retroactive Burn

Many community members wish the fee switch had been turned on earlier as UNI holders have missed out on years of fees on \~$4 trillion in Uniswap protocol volume. Alas, we cannot turn back the clock…  ***or can we***?

We propose a retroactive burn of 100 million UNI from the treasury. This is an estimate of what might have been burned if the protocol fee switch had been active at token launch.

#### Technical Implementation

Each fee source requires an adapter contract, that sends fees into an immutable onchain contract called [TokenJar](http://docs.uniswap.org/contracts/protocol-fee/technical-reference/TokenJar) where they accumulate. Fees can only be withdrawn from TokenJar if UNI is burned in another smart contract called [Firepit](http://docs.uniswap.org/contracts/protocol-fee/technical-reference/FirePit).

TokenJar and Firepit are already implemented, along with adapters for v2, v3, and Unichain. PFDA, v4, aggregator hooks, and bridge adapters for fees on L2s and other L1s are in progress and will be introduced through future governance proposals.

Detailed documentation on protocol fees and UNI burn can be found [here](https://docs.uniswap.org/contracts/protocol-fee/overview).

### UNIfication and Growth Budget

Labs led development of every version of the Uniswap protocol, grew the initial community, popularized AMMs and DeFi, and launched products used by tens of millions. Foundation expanded this ecosystem through grants, governance support, and community growth.

We propose unifying these efforts by transitioning Foundation teams to Labs, as Labs shifts its focus to helping make Uniswap protocol the default exchange for all tokenized value, funded through a growth budget from the treasury.

#### Uniswap Foundation Activities Move to Uniswap Labs

With the approval of this proposal, Labs will take on operational functions historically managed by the Foundation, including ecosystem support and funding, governance support, and developer relations.

Hayden Adams and Callil Capuozzo will join the existing Foundation board of Devin Walsh, Hart Lambur, and Ken Ng, bringing the board to five members. Most Foundation employees will move to Labs, except for a small team focused on grants and incentives. This team will deploy the Foundation’s remaining budget [consistent with its mission](https://www.uniswapfoundation.org/blog/unification), after which future grants will come from the growth budget under Labs.

#### Labs Focuses on Uniswap Protocol Growth and Development

This proposal aligns Labs’ incentives with the Uniswap ecosystem. If approved, Labs will shift its focus from monetizing its interfaces to protocol growth and development. Labs’ fees on the interface, wallet, and API will be set to zero.

These products already drive significant organic volume for the protocol. Removing fees makes them even more competitive and brings in more high quality volume and integrations, leading to better outcomes for LPs and the entire Uniswap ecosystem.

Monetization of Labs interfaces will continue to evolve over time and any fees on volume originating from these products will benefit the Uniswap ecosystem.

Labs will focus on both sides of the protocol’s flywheel – supply of liquidity and demand for volume. Below are just a few of the roadmap items ahead:

* **Improve LP outcomes and protocol liquidity.** Deploy the Protocol Fee Discount Auction and LVR-reducing hooks to capture more value for LPs and the protocol. Strengthen protocol leadership on strategic pairs, including dynamic fee hooks and stable-stable hooks. Add more sources of liquidity to the Uniswap protocol through aggregator hooks.  
* **Drive Uniswap protocol integrations and onboard new ecosystem players.** Accelerate adoption through strategic partnerships, grants, and incentives that bring new participants onchain. Provide SDKs, documentation, and even a dedicated engineering team to help partners build on the protocol.  
* **Accelerate developer adoption of the protocol with Uniswap API.** Pivot the API from a profit-generating product to a zero margin distribution method, expanding the protocol to more platforms and products, including those that previously competed with Labs products. Launch self-serve developer portal for key provisioning and allow integrators to add and rebalance liquidity directly through the API.  
* **Drive protocol usage with Labs’ interfaces.** Use the interface and wallet to drive more volume to the protocol by making it free, investing heavily in LP UX, and adding new features like dollar-cost-averaging, improved crosschain swaps, gas abstraction, and more.  
* **Empower hook builders.** Provide engineering support, routing, support in Labs’ interfaces, grants and more.  
* **Establish Unichain as a leading liquidity hub.** Optimize Unichain for low-cost, high-performance AMM trading which attracts LPs, asset issuers, and other protocols. Make Uniswap protocol on Unichain the lowest cost place to trade in Labs’ interface and API by sponsoring gas.  
* **Bring more assets to Uniswap.** Deploy Uniswap protocol wherever new assets live. Build and invest in liquidity bootstrapping tools and token launchers, RWA partnerships and bridging of non-EVM assets to Unichain.

Labs will also accelerate growth through builder programs, grants, incentives, partnerships, M&amp;A, venture, onboarding institutions, and exploring moonshot efforts to unlock new value for the Uniswap ecosystem. We will provide regular updates to the community, including budget reports, frequent product and growth updates, and real-time dashboards giving visibility into our impact.

#### The Growth Budget

We propose governance create an annual growth budget of 20M UNI, distributed quarterly using a [vesting contract](https://github.com/Uniswap/protocol-fees/blob/main/src/UNIVesting.sol) starting January 1, 2026, to fund protocol growth and development.

The growth budget would be governed by a services agreement between Labs and [DUNI](https://gov.uniswap.org/t/governance-proposal-establish-uniswap-governance-as-duni-a-wyoming-duna/25770). This would include an explicit commitment from Labs to maintain alignment between its activities and DUNI, ensuring Labs does not pursue strategies that conflict with token holder interests.

The Foundation will coordinate this process in its role as [Ministerial Agent](https://gov.uniswap.org/t/governance-proposal-establish-uniswap-governance-as-duni-a-wyoming-duna/25770#p-57430-ministerial-agent-agreement-overview-9) to DUNI. If the Snapshot vote passes, an independent committee composed of [Ben Jones](https://x.com/ben_chain?lang=en) and [Hart Lambur](https://x.com/hal2001?lang=en) will be appointed by the Foundation to lead negotiations based on this [draft](https://drive.google.com/file/d/1yXv2fm1XMr1eOsSMzG4DloGzvkFEYc1-/view?usp=sharing) letter of intent, with [Cooley LLP](https://www.cooley.com/) serving as the committee’s external counsel. The final negotiated agreement will be included in this governance proposal as part of the full onchain vote, and executed on its passing.

***Update 12/18:*** 

***Final services agreement between DUNI and Uniswap Labs***  

The [final services agreement](https://drive.google.com/file/d/1FxtK846m9CKQ9UqEnBt7uHRRMu9eTifs/view?usp=drive_link) reflects negotiations between the Uniswap Foundation’s [independent committee](https://gov.uniswap.org/t/unification-proposal/25881#p-57882-the-growth-budget-13), acting as Ministerial Agent to DUNI, and Uniswap Labs following the temperature check, and does include deviations from the previously posted Letter of Intent. 

Hash: 0xb7a5a04f613e49ce4a8c2fb142a37c6781bda05c62d46a782f36bb6e97068d3b

***Indemnification agreements for the independent negotiation committee***  

These agreements indemnify the members of the independent negotiation committee ([Hart Lambur](https://drive.google.com/file/d/1kgq66KcAGD5mZzZrW28S8n-XuQS0PH8f/view?usp=drive_link) and [Ben Jones](https://drive.google.com/file/d/18Mp0Honnb3nxGCx0k_aU4wBVncAwDA4F/view?usp=drive_link)), or their respective service providers, as applicable, for the services they provided in negotiating the SPA.

Hashes: 
0x96861f436ef11b12dc8df810ab733ea8c7ea16cad6fd476942075ec28d5cf18a (Hart Lambur), 0x576613b871f61f21e14a7caf5970cb9e472e82f993e10e13e2d995703471f011 (Ben Jones)

### Lock the Socks

Unisocks have a long history, ranging between [fun](https://x.com/EthereumFilm/status/1824171012696707244), [fashion](https://x.com/CL207/status/1550155749736689664), [flex](https://x.com/jaysonhobby/status/1382389435329744896), [weird](https://x.com/PleasrDAO/status/1636758148378918917), [weirder](https://x.com/cherdougie/status/1638703664016572419), [even weirder](https://x.com/Snowden/status/1592203313323593731), and gross (we’re not linking this one). They were [launched](https://x.com/Uniswap/status/1126506339075641344) by Labs in May 2019 as the first tokenized socks to trade on Uniswap protocol, or anywhere probably.

When Labs launched UNI in September 2020, it [transferred](https://etherscan.io/tx/0xa1c6a16481fe12f2003faa6f5797af8d6ab06512d10bd5010edf63d385c7e449) ownership of the original Uniswap v1 SOCKS/ETH liquidity position to Uniswap governance, where it has sat dormant ever since. We propose that governance move this position from Uniswap v1 on mainnet to Uniswap v4 on Unichain and transfer the LP position to a burn address, locking it forever.

This would ensure that this liquidity can never be withdrawn in the future, permanently locking in the original price curve and realizing the Unisocks vision. Also, the pink socks belong on the pink chain and “Uniswap v4” rhymes with “wore” – which is what you do with socks.

Due to technical complexity, this migration would be executed through a separate onchain vote.

### Thank you

Uniswap protocol wouldn’t be here without the LPs, swappers, builders, and community members who’ve helped the protocol become the largest decentralized exchange in the world. This proposal builds on that foundation, and sets the ecosystem up for the next phase of growth.

Thank you to everyone who has been part of the journey so far. We’re just getting started!

**Resources:**

* [Fee documentation](https://github.com/uniswap/protocol-fees)  
* [Fee contracts](https://github.com/Uniswap/protocol-fees/tree/main/src)  
* [Protocol Fee Discount Auction whitepaper](https://drive.google.com/file/d/1qhZFLTGOOHBx9OZW00dt5DzqEY0C3lhr/view?usp=sharing)  
* [Draft letter of intent](https://drive.google.com/file/d/1yXv2fm1XMr1eOsSMzG4DloGzvkFEYc1-/view?usp=sharing)
* [Final services agreement](https://drive.google.com/file/d/1FxtK846m9CKQ9UqEnBt7uHRRMu9eTifs/view?usp=sharing)
* [Indemnification agreement for Hart Lambur](https://drive.google.com/file/d/1kgq66KcAGD5mZzZrW28S8n-XuQS0PH8f/view?usp=drive_link)
* [Indemnification agreement for Ben Jones](https://drive.google.com/file/d/18Mp0Honnb3nxGCx0k_aU4wBVncAwDA4F/view?usp=drive_link)
