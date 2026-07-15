# BarnBridge SMART Yield — the "proposals #14/#15 approval exposure" warning, explained

**What this is:** a plain-language, independently verified write-up of a public warning about two BarnBridge DAO
governance proposals that could put old user token approvals at risk. The warning was a thread posted on X on 2026‑07‑14
by [@onechesss](https://x.com/onechesss/status/2077180012482928858) ("1chess", self-described "Smart Contract Security
Researcher").

I did **not** take the thread at face value. I decoded the proposals' calldata directly on-chain, cross-checked the
mechanism against BarnBridge's actual source code, and then **queried a full Ethereum archive node** (reth) to confirm
the live contract state, the actual proposal actions, the bytecode, and the real token balances/allowances behind the
thread's dollar claims. Everything below is split into what is **verified**, what is **plausible but not proven**, and
what the thread asserts that **could not be confirmed**.

> **One-line takeaway.** The technical threat is real and checks out on-chain: two brand-new proposals on the
> long-dormant BarnBridge DAO hand control of old SMART Yield pools to fresh contracts the proposers deployed themselves
> — and **proposal #14 has already executed**, so the attacker's contract is _already_ the live controller of the USDC
> pool. A captured controller can force-pull tokens from any wallet that still has a live approval to that pool. **The
> safe, cheap, reversible response is to revoke your old BarnBridge token approvals** (via revoke.cash, typed yourself).
> But when I checked the node, the thread's headline **"~$4M"** turns out to measure _approval limits_ (mostly
> "unlimited"), not money actually sitting in those wallets — most named wallets currently hold **$0** of the token. So:
> the takeover is real and revoking is prudent, but the imminent-theft scale is overstated, and the author's
> identity/motive is unknown. Act on the defense, stay agnostic about the messenger, never touch links in the replies.

---

## 0. Live on-chain state (verified against a reth archive node, block ~25,535,332)

| Fact                                       | Node result                                                                                            |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------ |
| `lastProposalId`                           | **15** — exactly proposals #1…#15 exist ✅                                                             |
| `state(14)`                                | **8 = Executed** — #14 already ran (it was "in Grace" when the thread was posted) ✅                   |
| `state(15)`                                | **5 = Queued** — #15 has _not_ executed; its pools still have their legitimate controllers ✅          |
| #14 USDC pool `0xDAA037F9…`.`controller()` | **`0x66c6f3b4…`** — the #14 proposer's own contract. **The takeover of the USDC pool is live now.** ✅ |
| #15 USDT pool `0xbF564952…`.`controller()` | **`0x1050716f…`** (old/legit) — not yet the attacker's `0x851E47F3…`; confirms #15 is still pending ✅ |
| Proxy check (all target/pool contracts)    | EIP-1967 + legacy proxy slots all **zero**, real bytecode → **not upgradeable proxies** ✅             |
| Named "at-risk" wallet balances            | Most hold **$0** of the token; a few (e.g. one wallet ~43.5k USDT) hold real, matching amounts ✅      |

**What this changes:** for **#14 (USDC)** the takeover is done, but the wallets the thread named currently hold ~0 USDC,
so ~$0 is drainable from them right now. For **#15** (USDT/DAI/USDC/…) the danger is _pending_ execution, and at least
one named wallet genuinely holds funds with a live approval. Revoking remains the correct move for anyone actually
exposed.

---

## Confidence legend

| Tag               | Meaning                                                                                                                                                   |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ✅ **Verified**   | I confirmed it directly — against a full archive node (reth) and Etherscan (calldata + contract state), BarnBridge's published source, or public records. |
| 🟡 **Plausible**  | Strongly supported and internally consistent, but not proven end-to-end.                                                                                  |
| ⚠️ **Unverified** | The thread asserts it and I could not independently confirm it. Treat with caution.                                                                       |

---

## 1. The 90-second version

- BarnBridge was a real DeFi protocol. Its flagship product, **SMART Yield**, let people deposit stablecoins (USDC, DAI,
  USDT, GUSD, RAI) into pools to earn yield. ✅
- To deposit, you had to **"Approve"** a BarnBridge pool contract to pull your tokens. That approval is a standing
  permission that **stays live forever until you cancel it** — even years later, even though BarnBridge wound down after
  a 2023 SEC settlement. ✅
- The DAO's on-chain governance contract still exists and still works, even though the team is gone. ✅
- In July 2026, after **~3 years of silence**, two fresh proposals — **#14** and **#15** — appeared. I decoded both:
  each **hands control of old SMART Yield pools to a brand-new contract that the proposer deployed himself days
  earlier**. Per the node, **#14 has already executed** (the USDC pool's controller is now the attacker's contract);
  **#15 is still queued**. ✅
- BarnBridge's own source code confirms the danger: whoever controls a pool's **controller** can call a function that
  pulls the underlying token out of **any wallet that still has a live approval** — with no action from the victim. And
  there is even a permissionless path by which a fully-captured DAO could sweep those funds to an attacker's own
  address. ✅ / 🟡
- **But two of the thread's headline specifics don't hold up:** the contracts are **not** "upgradeable proxies" (node
  bytecode confirms they're immutable — the real lever is the controller swap), and the **"~$4M"** figure measures
  _approval limits_ (mostly "unlimited"), **not** money in the wallets — I checked the named wallets on the node and
  most currently hold **$0** of the token. ⚠️
- **Defense:** revoking the old approval removes the risk at its root — a spender with zero allowance can take nothing.
  Safe, reversible, worth doing regardless of who's right about the rest. ✅

---

## 2. Background: what a "token approval" is, and why an old one is dangerous

On Ethereum, a smart contract can't touch your tokens unless you first grant it an **allowance**. When you deposited
into SMART Yield, your wallet sent an `approve(...)` transaction that said, in effect:

> "BarnBridge pool contract, you may pull up to _X_ of my USDC whenever you call `transferFrom`."

That permission does not expire on its own. It survives withdrawal, survives you forgetting about the app, and survives
the whole project shutting down. It sits on-chain, live, until you explicitly set it back to zero. This is the **"stale
approval" problem**, and it's the entire basis of the warning.

⚠️ **One nuance that decides whether _you_ are actually exposed:** the risk only persists if your original approval was
for an **unlimited** amount (or more than you ended up spending). DeFi apps _commonly_ asked for unlimited approvals,
but whether BarnBridge specifically did — and whether yours was ever spent down — is something only **your own wallet's
approval list** can tell you. Don't assume; check (see §8).

## 3. Background: BarnBridge's real-world status ✅ / ⚠️

- BarnBridge is a genuine DeFi protocol; SMART Yield is real, built on Compound/Aave. ✅
- In **December 2023**, the U.S. SEC announced a settlement with BarnBridge DAO and its two founders totaling roughly
  **$1.7M** (~$1.457M disgorgement plus two $125K penalties). The project wound down and is dormant today. ✅
  ([SEC 2023‑258](https://www.sec.gov/newsroom/press-releases/2023-258))
- ⚠️ You'll sometimes read that the order literally "ordered them to cease operations and stop funding the contracts."
  The settlement and wind-down are real, but that exact wording of the obligation is _likely_, not confirmed — don't
  over-cite it.
- This matches the chain: the governance contract sat **idle for ~1,175 days** before #14/#15 suddenly appeared.
  Brand-new governance activity on a legally wound-down project is, by itself, a notable red flag. ✅

A dead project does **not** mean dead contracts. Governance is permissionless code; anyone with enough voting power can
still use it. A dormant, unwatched DAO is arguably an _easier_ takeover target, not a harder one.

---

## 4. What the two proposals actually do (I decoded the calldata myself) ✅

This is the core of the warning, and it is fully checkable. I read the `propose(...)` transactions on Etherscan and
decoded the parameters by hand, then re-read the actions **straight from the governance contract's storage** on the node
(`getActions(14)` / `getActions(15)`) — they match exactly. Both proposals passed unopposed on the proposers' own voting
power (`againstVotes = 0`; ~63.8k vBOND for #14, ~135.7k vBOND for #15).

**The governor is genuinely BarnBridge's** — Etherscan labels `0x4cAE362D7F227e3d306f70ce4878E245563F3069` as
**"BarnBridge: Governance"**, and it matches the `governance` address in BarnBridge's official frontend/DAO source. ✅

### Proposal #14 — one action

| Field                     | Value                                                                                       |
| ------------------------- | ------------------------------------------------------------------------------------------- |
| Proposer                  | `0xf908610E9174c7cd6e9dfD371e238be4511297A1`                                                |
| Propose tx                | `0x07ff84e937…b7009` (block 25472231, 2026‑07‑06)                                           |
| Target being changed      | `0x41Ab25709e0C3EDf027F6099963fE9AD3EBaB3A3` — a 5‑year‑old BarnBridge SMART Yield contract |
| Function called           | `yieldControllTo(address)` — literally "hand yield control to …"                            |
| Argument (new controller) | `0x66c6f3b4B4b458e6d764759Ecf122484ebEf7580`                                                |
| Title / description       | **"migrate proxy implementation"**                                                          |

The kicker: the new controller `0x66c6f3b4…` was **deployed 8 days earlier by the proposer himself** (`0xf908610E…`).
**This proposal has now executed** (`state(14) = Executed`), and the node confirms the USDC pool `0xDAA037F9…` now
reports `controller() = 0x66c6f3b4…` — i.e. the attacker's contract is already in control. ✅

### Proposal #15 — the same play, ten times

| Field                             | Value                                                                                    |
| --------------------------------- | ---------------------------------------------------------------------------------------- |
| Proposer                          | `0xa8ce49a57400445c6A4118ae3460ed4E46c815b8`                                             |
| Propose tx                        | `0x33f10a4210…df82b` (block 25494106, 2026‑07‑09)                                        |
| Actions                           | **10**, each calling `yieldControllTo(address)` on a different old BarnBridge controller |
| Argument (new controller, all 10) | `0x851E47F37e20712407990556376A7124de5c3D4a`                                             |
| Title / description               | **"migrate controller proxy"**                                                           |

Again: the new controller `0x851E47F3…` was **deployed 5 days earlier by the #15 proposer himself** (`0xa8ce49a5…`).
Unlike #14, **#15 is still Queued** (`state(15) = Queued`); the node shows its pools still point at their old
controllers, so this batch has **not** taken effect yet — there is still a window to revoke before it can execute. ✅

### The pattern (verified on-chain for both)

Each proposer ran the identical sequence:

1. **Deploy** their own controller contract.
2. **Propose** `yieldControllTo(myController)` on the old BarnBridge SMART Yield contracts.
3. **Cast a vote** for their own proposal.
4. **Queue** it.
5. **Start an abrogation proposal** on their own proposal (the "cancel" slot — see §5).

Note the function name: `yieldControllTo` means "hand control to." So the on-chain action is a **control / authority
transfer**, which is consistent with a _controller swap_ — **not** the "proxy upgrade" the thread describes (see §6).
This is a textbook **hostile governance takeover** of a dormant protocol.

---

## 5. The timing, and the "you can't cancel it" trick

BarnBridge governance has a fixed lifecycle: **WarmUp → Active (voting) → Accepted → Queued (timelock) → Grace
(execution window) → Expired**, and once a proposal is in **Grace**, **anyone** can call `execute()`. ✅ The thread's
framing — "#14 is in Grace, executable now; #15 is Queued, executable later" — uses these terms correctly.

**The abrogation trick (✅ real, with an important caveat).** BarnBridge has a built-in "undo": while a proposal is
queued, the community can open an **abrogation proposal** to cancel it. But the code allows **exactly one abrogation
slot per proposal** — a second `startAbrogationProposal` for the same proposal reverts, and there's no reset. The
attackers **filled that slot themselves** with a sham abrogation. I confirmed on-chain that both proposers sent a "Start
Abrogation" transaction on their own proposals. ✅

⚠️ **But "defenders can't stop it" is an overstatement.** Occupying the slot only blocks opening a _new_ abrogation.
Anyone can still cast **FOR** votes on the _existing_ one, and it passes on those votes alone. The real obstacle is the
bar: abrogation needs FOR votes ≈ **50% of all staked BOND** — an absolute majority that, in a captured, unwatched DAO
where the attacker may hold a lot of voting power, is very hard to reach in time. So the honest version is "defenders
face a steep, maybe unwinnable uphill vote," not "defenders are powerless."

The thread's framing ("#14 in Grace, executable now; #15 Queued, executable later") was **correct when posted** — but
state has since advanced: the node now shows **#14 = Executed** and **#15 = Queued**. On the countdown: the node
confirms this deployment uses **non-default** windows — each proposal's `createTime → eta` gap is exactly **7 days**
(not the 12 days the source defaults to), which is why the thread's timeline is shorter than a textbook BarnBridge
proposal. So the timing is genuine, not fabricated — just re-check the live `state()`/`eta` yourself before relying on
specific hours. ✅

---

## 6. How this could actually drain your tokens (the mechanism, corrected) ✅ / 🟡

The thread's alarm is directionally right but names the wrong mechanism. Here's the accurate chain, verified against
BarnBridge's published Solidity:

1. **What you approved:** when you used SMART Yield, your approval on the underlying token (USDC/DAI/…) was granted to
   the **provider "pool" contract** (e.g. `CompoundProvider`), **not** to the main SmartYield contract. That's where the
   live allowance sits. ✅
2. **The pull:** the provider's `_takeUnderlying(from, amount)` runs `transferFrom(from, pool, amount)` with an
   **arbitrary `from`**, and is callable by the pool's **controller**. ✅
3. **The lever:** the BarnBridge DAO can **swap a pool's controller** (`setController`, governance-gated). ✅ Proposals
   #14/#15's `yieldControllTo(...)` calls are exactly this kind of control transfer — to a contract the proposer owns.
   **For #14 this already happened:** the node shows the USDC pool's `controller()` is now the attacker's `0x66c6f3b4…`.
   ✅
4. **The result:** a malicious controller can call `_takeUnderlying(victim, allowance)` and force your still-approved
   tokens out of your wallet and into the pool — **with no action from you**. ✅
5. **Getting it to the attacker:** the provider's `transferFees()` is **permissionless** and sends the pool's underlying
   balance to a **governance-settable `feesOwner`**. So a _fully captured_ DAO could set `feesOwner` to an attacker
   address and then anyone calls `transferFees()` to sweep the funds out. 🟡 (The path exists in the code; that #14/#15
   wire up this exact end-to-end sequence is not something I decoded — I only confirmed the control-transfer step.)

⚠️ **Correction to the thread's wording:** it says the proposals "migrate controllers to **upgradeable proxies** pointed
at new logic." That's inaccurate — BarnBridge's provider/controller/SmartYield contracts are **plain, immutable,
non-proxy** contracts. There is no arbitrary logic swap; the real lever is **replacing the controller**. The thread got
the _what_ (control handover → drain of live approvals) closer to right than the _how_ (it isn't a proxy upgrade).

🟡 **What is proven vs. not.** The _takeover_ is now proven live: #14 executed and the attacker's contract is the USDC
pool's controller. What is **not** proven is (a) the final exfiltration step that lands funds in an attacker's own
wallet (the `transferFees → feesOwner` path exists in code but I didn't confirm #14/#15 wire it up), and (b) that there
is a large pile to take **right now** — see the next point.

⚠️ **The scale is smaller than "$4M" today.** I read the named "at-risk" wallets on the node. Several carry
**unlimited** approvals to the pools (so the mechanism genuinely applies to them), but their **current token balance is
0**, so the amount drainable from them right now is **$0**. A few wallets do hold real funds (e.g. one holds ~43.5k USDT
with a live approval to a #15 pool). The USDC pool `0xDAA037F9…` itself also holds ~0 USDC now. So "~$4M live approval
exposure" reflects **approval ceilings**, not money currently at risk — real drainable value today is far smaller and
concentrated in a handful of wallets.

**None of this changes the defense:** if your allowance is **zero**, `_takeUnderlying` reverts and there is nothing to
pull — no matter who controls the contract. Revoking is still the right move for anyone who holds funds in an
approved-and-exposed wallet. ✅

---

## 7. Is the threat real? Is the _messenger_ trustworthy? (two different questions)

**The threat is technically real.** The on-chain actions are verified (governor identity, the two proposals, the
self-deployed controllers, the self-abrogation, the 3‑year dormancy), and BarnBridge's source confirms a captured
controller can drain live approvals. This part does not depend on trusting the poster. ✅

**The messenger is unverified — stay agnostic.** Separately from the on-chain facts:

- ⚠️ The author's identity, credentials, and motive are unknown. "Shared with emergency responders" is unfalsifiable. A
  thread naming a legitimate tool (revoke.cash) alongside a fear-inducing countdown is _also_ a known engagement-farming
  / phishing pattern — so do **not** conclude the thread is either clearly credible _or_ clearly benign.
- ⚠️ **Replies are restricted**, which conveniently blocks peer correction — and the reply section of any such thread is
  a magnet for scam "support" accounts posting fake revoke links and "recovery" offers.
- ⚠️ The headline **"~$4M"** is **overstated as an imminent-theft figure** — I checked the named wallets on the node and
  most hold **$0** of the relevant token today; the number looks like a sum of _approval ceilings_ (mostly "unlimited"),
  not balances at risk. Some per-wallet claims are stale or mislabeled (one wallet the thread tagged "~85,660 USDC"
  actually holds USDT and has no approval to the listed pools); a few are accurate (one wallet's ~43,559 USDT matches).
  Treat the specific numbers as unreliable and check your **own** approvals instead.

**Bottom line:** believe the _structural_ warning (it's verified), discount the _specific numbers_, and don't extend
trust to the _author_. The good news is you don't need to resolve any of that — the defensive action is safe and cheap
either way.

---

## 8. What to do (safe, and only if it applies to you)

If you ever used BarnBridge SMART Yield with an Ethereum wallet:

1. **Go to revoke.cash by typing the address yourself.** You can paste your **public** wallet address to just _look_ at
   your approvals without connecting anything.
2. **Trust the tool's view of _your own_ approvals — not the thread's address list.** revoke.cash shows the allowances
   your wallet actually granted; that's the ground truth. Cross-check any address on
   [etherscan.io](https://etherscan.io) before acting.
3. **Revoke** any live approval to a BarnBridge pool/provider (set the allowance to zero). It's a normal transaction you
   sign from your own wallet; it costs a little gas and is fully reversible.

**Never:**

- ❌ Click "revoke" / "support" / "recovery" links in the replies. Navigate yourself.
- ❌ Sign a `transfer` or `permit` prompt that someone sends or DMs you.
- ❌ Send funds anywhere to "secure" or "recover" them. No legitimate recovery ever requires that.

This project (and I) cannot enter wallet credentials or sign transactions for you — those steps must be done by the
wallet owner directly.

---

## 9. How to verify / replicate this yourself

This is exactly what this repository is for — reconstructing and verifying governance calldata. To reproduce:

**A. Read the proposal on Etherscan (no code needed).**

1. Open the governor `etherscan.io/address/0x4cAE362D7F227e3d306f70ce4878E245563F3069` → **Transactions**.
2. Find the two `Propose` txs from July 2026 and open one → **Input Data**.
3. The function is
   `propose(address[] targets, uint256[] values, string[] signatures, bytes[] calldatas, string description, string title)`.
   Decode it (Etherscan's "Decode Input Data", or by hand) → you'll see the `yieldControllTo(address)` calls and the
   "migrate …" titles from §4.
4. Open each **target** and each **argument** address. Confirm the targets are old BarnBridge SMART Yield contracts and
   the arguments were **freshly deployed by the proposer** (Etherscan → "Contract Creator" + age). That is the smoking
   gun: control is being handed to attacker-owned contracts.

**B. Reconstruct the calldata from first principles (the repo's method).**

- Derive the expected `propose` calldata from the interface: the
  `propose(address[],uint256[],string[],bytes[],string,string)` selector, the `yieldControllTo(address)` signature
  string, and the named target/argument addresses.
- Compare it to the on-chain input data. A match confirms _what_ the proposal does; the **finding** is that the "new
  controller" argument is attacker-owned → hostile takeover.

**C. (Optional) Prove the drain with a mainnet-fork test.**

- Fork mainnet at a block where #14 is in Grace, call `execute()`, then, from a wallet holding a live approval to the
  affected provider, drive the new controller's `_takeUnderlying(victim, amount)` and (if wired) the `transferFees()`
  sweep. If the pull succeeds, the drain is proven; if it reverts, the feared step isn't reachable. This is the honest
  way to close the 🟡 gaps in §6 — I described it rather than fabricate a result. (I can scaffold this Foundry test on
  request.)

**D. Query a node directly (what actually settled the facts above).** With any mainnet RPC (`export ETH_RPC_URL=…`):

```bash
GOV=0x4cAE362D7F227e3d306f70ce4878E245563F3069
cast call $GOV "lastProposalId()(uint256)"                 # -> 15
cast call $GOV "state(uint256)(uint8)" 14                  # -> 8 (Executed)
cast call $GOV "state(uint256)(uint8)" 15                  # -> 5 (Queued)
cast call $GOV "getActions(uint256)(address[],uint256[],string[],bytes[])" 14   # yieldControllTo -> 0x66c6f3b4…

# Did the takeover actually land? Ask the pool who its controller is now:
cast call 0xDAA037F99d168b552c0c61B7Fb64cF7819D78310 "controller()(address)"    # -> 0x66c6f3b4… (attacker)

# Proxy or immutable? EIP-1967 impl slot (zero = not a proxy):
cast storage 0xDAA037F99d168b552c0c61B7Fb64cF7819D78310 \
  0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc   # -> 0x0…0

# Real exposure of a listed wallet = min(allowance, balance), not the approval ceiling:
USDC=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
cast call $USDC "allowance(address,address)(uint256)" <wallet> 0xDAA037F99d168b552c0c61B7Fb64cF7819D78310
cast call $USDC "balanceOf(address)(uint256)" <wallet>
```

---

## 10. Appendix — addresses & transactions

**Verified on-chain (primary source, decoded during this review):**

| Role                                                 | Address                                                                                                              |
| ---------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| BarnBridge Governance (governor)                     | `0x4cAE362D7F227e3d306f70ce4878E245563F3069`                                                                         |
| #14 proposer                                         | `0xf908610E9174c7cd6e9dfD371e238be4511297A1`                                                                         |
| #14 target (old SMART Yield contract)                | `0x41Ab25709e0C3EDf027F6099963fE9AD3EBaB3A3`                                                                         |
| #14 new controller (proposer-deployed, 8 days prior) | `0x66c6f3b4B4b458e6d764759Ecf122484ebEf7580`                                                                         |
| #14 USDC pool (users' approvals sit here)            | `0xDAA037F99d168b552c0c61B7Fb64cF7819D78310` — `controller()` **now = attacker** `0x66c6f3b4…`; holds ~0 USDC itself |
| #15 proposer                                         | `0xa8ce49a57400445c6A4118ae3460ed4E46c815b8`                                                                         |
| #15 new controller (proposer-deployed, 5 days prior) | `0x851E47F37e20712407990556376A7124de5c3D4a`                                                                         |

**#15 targets (10 old BarnBridge controllers, each migrated to `0x851E47F3…`):**
`0x26984a19e3c6fc8d3e8ff124cd72d71f6b603ff3`, `0x39a84fcf5c22f227f2108a9d214090ee4c334893`,
`0x1050716f239e13a803b7d1ba55b187303b14374a`, `0xaa963524e65c671ef7a5485adf9e342c401a46ff`,
`0xbd4dd68e8a91076d9d3a4d6fef49231bd6eb6ed2`, `0x2ff662a35e7f66adc10469ddba3cd45a62854718`,
`0x0e87dc8aad3494252e641aad0745c009d08b8cc8`, `0xa7dad944581638ad570ce50e3e66e8cdea4f78ba`,
`0x4594bab27825d662064d20eb8eb75195c5d98c8b`, `0xcee88909be73d07d557ef2648ab60f7c8c90ac9f`.

**Underlying token contracts used by the protocol** (these are the ERC-20s; your approval is granted _to the pools
below_, not to these):

| Token | Contract                                                                                 |
| ----- | ---------------------------------------------------------------------------------------- |
| USDC  | [`0xA0b8…eB48`](https://etherscan.io/address/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48) |
| DAI   | [`0x6B17…1d0F`](https://etherscan.io/address/0x6B175474E89094C44Da98b954EedeAC495271d0F) |
| USDT  | [`0xdAC1…1ec7`](https://etherscan.io/address/0xdAC17F958D2ee523a2206206994597C13D831ec7) |
| GUSD  | [`0x056F…d5Cd`](https://etherscan.io/address/0x056Fd409E1d7A124BD7017459dFEa2F387b6d5Cd) |
| RAI   | [`0x03ab…4919`](https://etherscan.io/address/0x03ab458634910AaD20eF5f1C8ee96F1D6ac54919) |

**The pool/provider contracts your approvals sit on (the "spenders" to check/revoke).** All 11 are node-verified as real
provider pools (each returns a valid `uToken()`); each row shows its underlying token and current control state. ⚠️
Still, trust revoke.cash's view of _your own_ approvals over any list.

| Token | Pool (spender) — Etherscan                                                                | Prop | Control now                        |
| ----- | ----------------------------------------------------------------------------------------- | ---- | ---------------------------------- |
| USDC  | [`0xDAA0…78310`](https://etherscan.io/address/0xDAA037F99d168b552c0c61B7Fb64cF7819D78310) | #14  | **attacker-controlled (executed)** |
| USDC  | [`0x9923…61C9`](https://etherscan.io/address/0x99230f93135f3650ab5706b7B6D4B30b4EE961C9)  | #15  | legit (pending)                    |
| USDC  | [`0xA4f8…baDb`](https://etherscan.io/address/0xA4f8310CD972b1fc3CA9F130b235A91bc882baDb)  | #15  | legit (pending)                    |
| DAI   | [`0x372d…d4C7D`](https://etherscan.io/address/0x372d02e58a8Fcf42114232F614D57f31401d4C7D) | #15  | legit (pending)                    |
| DAI   | [`0xe6c1…1bd37`](https://etherscan.io/address/0xe6c1A8E7a879d7feBB8144276a62f9a6b381bd37) | #15  | legit (pending)                    |
| DAI   | [`0x3792…6cf76`](https://etherscan.io/address/0x37923EB0F4a9097B2774eAB9D928AFaD6196cf76) | #15  | legit (pending)                    |
| USDT  | [`0xbF56…CA5d8`](https://etherscan.io/address/0xbF5649526aa1DC1dAA82ED29dDc65149278CA5d8) | #15  | legit (pending)                    |
| USDT  | [`0x6ac0…B94d`](https://etherscan.io/address/0x6ac048eE380cBf0Cb22c30401e710c28d91EB94d)  | #15  | legit (pending)                    |
| USDT  | [`0x7B1E…475Be`](https://etherscan.io/address/0x7B1E1A841afE589F1b5337a2Eec41A18a58475Be) | #15  | legit (pending)                    |
| GUSD  | [`0x5cFc…fc094`](https://etherscan.io/address/0x5cFcFb6171db72a26b84bc50EdD2d80b0F3fc094) | #15  | legit (pending)                    |
| RAI   | [`0x02Cb…F3354`](https://etherscan.io/address/0x02Cbe7FeAa8B969aCC43ab368B6ed45Cb63F3354) | #15  | legit (pending)                    |

**Sources:** a full Ethereum archive node (**reth v1.9.3**, chain id 1, queried at block ~25,535,332) for live contract
state, `getActions`, bytecode/proxy-slot checks, and real balances/allowances; BarnBridge Governance & provider
contracts on Etherscan (with `propose` calldata decoded by hand); BarnBridge DAO / SmartYieldBonds source
(`Governance.sol`, `Parameters.sol`, `CompoundProvider.sol`); SEC press release
[2023‑258](https://www.sec.gov/newsroom/press-releases/2023-258); the original thread
([@onechesss](https://x.com/onechesss/status/2077180012482928858)).

---

### Confidence summary

| Claim                                                                              | Status                                                                     |
| ---------------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| Governor is BarnBridge Governance                                                  | ✅ Verified                                                                |
| Proposals #14/#15 exist; hand control to proposer-deployed contracts               | ✅ Verified (`getActions` read from contract storage)                      |
| **#14 already executed; USDC pool controller is now the attacker's contract**      | ✅ Verified (node `state(14)=Executed`, `controller()`)                    |
| #15 still queued; its pools not yet migrated                                       | ✅ Verified (node `state(15)=Queued`)                                      |
| Both proposers self-voted, queued, and self-started abrogation                     | ✅ Verified                                                                |
| Governance dormant ~3 years, then revived July 2026                                | ✅ Verified                                                                |
| A captured controller can force-pull live approvals (`_takeUnderlying`)            | ✅ Verified (source; #14 takeover now live)                                |
| A fully-captured DAO could sweep funds to an attacker (`transferFees`→`feesOwner`) | 🟡 Path exists; #14/#15 wiring not decoded                                 |
| "Upgradeable proxies pointed at new logic"                                         | ❌ False — node bytecode shows immutable, non-proxy code                   |
| "~$4M" imminent exposure / per-wallet amounts                                      | ⚠️ Overstated — measures approval ceilings; most named wallets hold $0 now |
| Exact countdown / timing                                                           | ✅ Genuine (non-default 7-day windows), but re-check live                  |
| Author identity / motive / "emergency responders"                                  | ⚠️ Unverified — stay agnostic                                              |
| Revoking approvals neutralizes the risk                                            | ✅ Verified                                                                |

_Prepared as an independent review. Nothing here is financial advice. The only recommended action — revoking a stale
token approval — is a standard, non-custodial safety step you perform yourself._
