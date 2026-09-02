# Fake World Assets

![](https://i.imgur.com/iYD3j6m.png)

## ⚡️ TLDR

Quick summary:

- Send 24 treasury Nouns into [fwa.fun](https://fwa.fun), the onchain gacha machine
- Each backed with ~1.28 ETH so a winner nets exactly the same whether they keep the Noun or take the ETH
- No discounts, no giveaways. Anyone who keeps a Noun turned down its exact cash value to do so
- Every listing earns an equal share of every draw fee in the protocol, paid to the treasury
- In expectation, a listing earns back its own backing in fees before it is ever drawn (math below)
- Nouns and ETH move through a reusable manager contract whose every exit is hardcoded to the treasury

*Throughout this proposal, "the treasury" means the Nouns DAO treasury, the timelock at [nouns.eth](https://etherscan.io/address/0xb1a32FC9F9D8b2cf86C068Cae13108809547ef71). Full details below...*

---

## 🙋 Background

I'm gami, Nouner since the early days (Nouns 13 and 189) and founder of [Gnars](https://gnars.com), which got started with 69 ETH from [Prop 51](https://nouns.wtf/vote/51) in April 2022 and has been proliferating Nouns ever since. You've seen my proposals before. They tend to bring voters out of the woodwork. Bring them.

In July 2026 I forked FWA onto Robinhood Chain as [StockRip](https://stockrip.com): 74,000+ draws, 1,700+ ETH of volume, 900+ players ([live stats](https://stockrip.com/secretdash)). So I know this machine from both sides of the glass, because I run one. I've also fed FWA a Noun of my own: [Noun 1382](https://nouns.wtf/noun/1382), backed with my own ETH, priced too low, gone in three hours, lol. That mistake is where this proposal's pricing rule comes from.

## 🎰 Why

The treasury holds 613 Nouns and gains one every day. Since the reserve went to 2.8 ETH in April, 101 of the 102 auctions through mid-August ended with zero bids: 26 Nouns burned, 75 swept into the treasury, one single winner. The treasury's ~4,000 ETH is mostly staked and earning. Its 604 Nouns earn nothing.

FWA is doing ~310 draws and ~25 ETH in draw fees a day across 6,400+ active listings as of 2026-08-22, down from a ~2,900-draw peak as post-emissions volume settles (measured onchain, methodology at the bottom). Nouns is already whitelisted as collection #17. The machine is running either way. This proposal puts 24 of our idle Nouns inside it, earning, and in front of people.

## ⚖️ The true decision

Each Noun is listed with backing set to floor ÷ 0.9 (~1.28 ETH at time of writing, set precisely at listing time). FWA pays a winner 90% of backing if they hand the NFT back, so at this level the choice is perfectly balanced. Draw one and you choose:

- **Keep the Noun.** You just turned down ETH worth exactly what the Noun fetches at floor. You want this.
- **Take the ETH.** Same value, none of the hassle of selling. The Noun goes straight back to the treasury.

Flippers press the ETH button. Believers keep the Noun. And while they wait to be chosen, all 24 earn draw fees for the treasury.

## 📊 The numbers

Everything here is measured from FWA's contracts onchain (latest: a full 24-hour sample ending 2026-08-22). Volume has kept settling since emissions ended, so the timeline numbers move with it; the key result in bullet three does not. Verify it, please.

- ~310 draws/day at an average price of ~0.08 ETH. 98% of every draw fee splits equally across active listings, which works out to **~0.0038 ETH per listing per day** at current volume, or ~0.09 ETH/day across our 24 (a week ago this was 4x, at the emissions peak 10x: these scale with volume)
- Draw odds scale with 1/backing. At 1.28 ETH backing, each Noun's expected time in the pool is **~11 months** at current volume (it was ~75 days a week ago; the timeline moves inversely with volume, in either direction), roughly one draw event across our 24 every couple of weeks
- The part worth checking twice: the draw fee is the pool's harmonic mean × 1.025, and draw odds are 1/backing. Those cancel, so **a listing's expected fee income before it is ever drawn ≈ its own backing**, independent of volume and of what everyone else lists
- Per-Noun branches, in expectation:
  - *Winner keeps the Noun:* ~1.28 ETH earned in fees + backing returned (minus 1% protocol cut). Treasury up ~1.3 ETH, one new Nouner who chose a Noun over cash
  - *Winner takes the ETH:* ~1.28 ETH earned in fees, 1.28 ETH of backing paid out. Roughly ETH-neutral, Noun back in the treasury
- Expectation is not a guarantee. A Noun drawn on day 2 earns less than its backing (ask me about Noun 1382). A Noun that sits earns more. That variance is why this is sized at 30 ETH and not 300
- Not modeled, pure upside: $FWA depositor rewards (30% of the protocol's fee-funded buybacks accrue to depositors)
- For calibration: across all of FWA in the sample window, winners kept the NFT in ~1.3% of settlements, because most listings are cheap NFTs backed above their value. Ours are the opposite. Keeps will still be the minority, and that's fine: a keep is a new Nouner who wanted in, a buyback is a round trip that paid us fees

## 🖼 The 24

Hand-picked from the treasury and shaped like a pyramid: the oldest Noun we have at the top, three from the early days, six from the middle years, fourteen from the no-bid era that were minted straight into the treasury. All 24 heads are different, all 24 accessories are different, and Noun 1980 is the only Noun in the entire treasury wearing the Gnars accessory.

![](https://raw.githubusercontent.com/0xigami/fwa-middleware/main/docs/img/11.png)

**11**

![](https://raw.githubusercontent.com/0xigami/fwa-middleware/main/docs/img/26.png) ![](https://raw.githubusercontent.com/0xigami/fwa-middleware/main/docs/img/82.png) ![](https://raw.githubusercontent.com/0xigami/fwa-middleware/main/docs/img/89.png)

**26 · 82 · 89**

![](https://raw.githubusercontent.com/0xigami/fwa-middleware/main/docs/img/279.png) ![](https://raw.githubusercontent.com/0xigami/fwa-middleware/main/docs/img/408.png) ![](https://raw.githubusercontent.com/0xigami/fwa-middleware/main/docs/img/548.png) ![](https://raw.githubusercontent.com/0xigami/fwa-middleware/main/docs/img/559.png) ![](https://raw.githubusercontent.com/0xigami/fwa-middleware/main/docs/img/801.png) ![](https://raw.githubusercontent.com/0xigami/fwa-middleware/main/docs/img/861.png)

**279 · 408 · 548 · 559 · 801 · 861**

![](https://raw.githubusercontent.com/0xigami/fwa-middleware/main/docs/img/1914.png) ![](https://raw.githubusercontent.com/0xigami/fwa-middleware/main/docs/img/1917.png) ![](https://raw.githubusercontent.com/0xigami/fwa-middleware/main/docs/img/1929.png) ![](https://raw.githubusercontent.com/0xigami/fwa-middleware/main/docs/img/1933.png) ![](https://raw.githubusercontent.com/0xigami/fwa-middleware/main/docs/img/1942.png) ![](https://raw.githubusercontent.com/0xigami/fwa-middleware/main/docs/img/1950.png) ![](https://raw.githubusercontent.com/0xigami/fwa-middleware/main/docs/img/1954.png)

**1914 · 1917 · 1929 · 1933 · 1942 · 1950 · 1954**

![](https://raw.githubusercontent.com/0xigami/fwa-middleware/main/docs/img/1957.png) ![](https://raw.githubusercontent.com/0xigami/fwa-middleware/main/docs/img/1958.png) ![](https://raw.githubusercontent.com/0xigami/fwa-middleware/main/docs/img/1969.png) ![](https://raw.githubusercontent.com/0xigami/fwa-middleware/main/docs/img/1980.png) ![](https://raw.githubusercontent.com/0xigami/fwa-middleware/main/docs/img/1983.png) ![](https://raw.githubusercontent.com/0xigami/fwa-middleware/main/docs/img/1988.png) ![](https://raw.githubusercontent.com/0xigami/fwa-middleware/main/docs/img/1989.png)

**1957 · 1958 · 1969 · 1980 · 1983 · 1988 · 1989**

## 🔧 The middleware

The treasury can't act inside FWA's 24h settlement windows, so a small manager contract sits in between. It's the only new code in this proposal and it's deliberately boring:

- Every exit path is hardcoded to the treasury: withdrawn Nouns, returned Nouns, reclaimed backing and earned fees can go nowhere else. The operator manages listings but cannot redirect a single wei
- I'm the operator at launch. The treasury can replace the operator at any time by proposal, and the role can be opened up further later (even permissionless keeper functions) if that's where we want to take it
- It's reusable. If this experiment earns its keep, a future proposal can load more Nouns into the same audited contract without deploying anything new
- Governance stays safe: 24 Nouns in escrow shift quorum by roughly 2 votes, quorum snapshots at proposal creation so no live vote is affected, and the impact only shrinks as Nouns supply grows
- Already deployed and [verified on Etherscan](https://etherscan.io/address/0x89ec417Fa93F02926bF9c28316dA4E7d0F28089b#code): `0x89ec417Fa93F02926bF9c28316dA4E7d0F28089b`. What you audit is what executes

Attached transactions send the 24 Nouns and ~30 ETH from the treasury to the manager. I then list each one at floor ÷ the live buyback rate (90% today), priced at listing time; the contract enforces a 1 ETH minimum backing on me, and every listing tx is public and checkable against the formula.

## 🔎 Check my work

Don't trust the claims above, verify them. Everything is public in [the repo](https://github.com/0xigami/fwa-middleware):

- **[27 mainnet-fork tests](https://github.com/0xigami/fwa-middleware/blob/main/contracts/test/NounsListingManager.t.sol)**, including one that replays these exact four proposal actions with all 24 Noun ids against forked mainnet state. Anyone with an RPC can run them
- **[Security audit](https://github.com/0xigami/fwa-middleware/blob/main/audit-report.md)**: a 222-item checklist walk on top of two earlier review rounds and external review by dev friends. Zero critical, high or medium findings. The one confirmed finding from the adversarial round was fixed before deployment (`pull()` skips ids a concurrent proposal may have moved, so nothing can brick execution)
- **[A live mainnet dry-run](https://github.com/0xigami/fwa-middleware/blob/main/docs/DRYRUN.md)** of the same bytecode, done with my own ETH and NFT against the real FWA before this proposal went up. Load, list, earn a real fee from a real third-party draw, claim, withdraw, return, sweep: every transaction linked, every wei accounted for, every exit landing at the hardcoded treasury address
- **[The four transactions themselves](https://github.com/0xigami/fwa-middleware/blob/main/docs/TRANSACTIONS.md)**, pre-encoded with a pre-flight checklist, so what you vote on is byte-for-byte what runs

One Noun, every day, forever. But somebody has to want one. Let's find out who.

⌐◨-◨

---

*Methodology: draw counts and fees from `AcquisitionRequested` events, outcomes from `NFTKept` / `DepositorBidAccepted` events on FWA core `0xB276F62DB0ce8CA2Ca5bc522695bE604521eAc1c`; listing count, total weight and fee parameters read from the same contract; treasury and auction figures from the Nouns token, auction house and treasury. Ask = 30 ETH ≈ 24 × the ~1.28 ETH backing. Backing is priced at listing time; if the floor drifts up before listing, the tail of the pyramid lists as the first backing refunds cycle home, and every unlisted wei is sweepable only to the treasury.*
