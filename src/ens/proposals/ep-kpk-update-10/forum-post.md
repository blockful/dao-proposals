# Pre-draft calldata security verification: Endowment permissions to kpk, Update #10

Blockful has completed an independent review of the executable payload referenced in this proposal
(`karpatkey/client-configs`, branch `ens-dao-manager-harvest-rwa-yield`, commit `3e447f8d`).

## Verification result

We reconstructed all 54 transactions of the payload and compared our reconstruction against the published payload byte
for byte. The two are identical. The transactions described in the specification were derived from the specification and
from the public contract interfaces. The remaining content, namely the module deployment addressed in finding 1, the
retained entries of the extended token approval lists, and the annotation text, is not described in the specification;
for those items our reconstruction was transcribed from the published payload and verified against the current on-chain
configuration. The byte comparison validates the encoding and internal consistency of the payload; it does not by itself
establish that the undescribed items were authorized by the specification, which is the subject of the findings below.
The permissions granted are correctly restricted: deposits, withdrawals, and redemptions can only be directed to the
Endowment Safe, token approvals are limited to the named protocol contracts, and the swap functions on the Pendle Router
cannot be used to route funds through external contracts. We also confirm, both by simulation and by inspection of the
configuration repository, that no existing permission is removed.

The simulation and tests can be found
[here](https://github.com/blockful/dao-proposals/blob/f47b3171112ea7d01a53f8bb29b4162b4783f4d4/src/ens/proposals/ep-kpk-update-10/calldataCheck.t.sol).

## Findings and questions for kpk

Our review identified four discrepancies between the proposal text and the payload. We ask kpk to address them before
this proposal proceeds to a vote.

**1. The payload deploys a new permissions module that the proposal text does not mention.** Transactions 0 through 7
deploy a second Roles instance, connect it to the existing one with the full Endowment Manager permission set as its
default, and transfer its ownership to kpk. Under this arrangement, kpk may grant third parties access to the Endowment
Manager permissions without a DAO vote. Any such access remains limited to what the Manager role already allows, but the
authority to delegate it moves from the DAO to kpk. _Question: please disclose this deployment in the proposal text,
explain its intended use, and confirm who will hold roles on it._

**2. Two items of the specification are not present in the payload.** Item 5 (adding syrupUSDC and syrupUSDT to the swap
token lists) and item 6 (the Harvest role for reward claims) do not appear in any of the 54 transactions. We note that a
Harvest role definition exists in the configuration repository but is not applied by the payload. _Question: will the
payload be amended to include these items, or will the Harvest role be configured by kpk on the new module described in
finding 1, outside of the DAO vote?_

**3. The reward claim permissions presented as new already exist.** The three distributors listed under item 6 are
already callable under the current Endowment Manager permissions, with payouts already restricted to the Endowment Safe.
We verified this against the current state of mainnet. _Question: please confirm what item 6 is intended to change,
given that these permissions are already in force._

**4. The specification lists an address that does not correspond to a deployed contract.** The table entry for
Steakhouse High Yield USDC gives `0xbeeff7aE5E00Aae3Db302e4B0d8C883810a58100`, which holds no code on mainnet. The
payload instead uses `0xbeeff2C5bF38f90e3482a8b19F12E5a6D2FCa757`, which is the deployed vault of that name. The payload
is correct; the table is not. _Question: please correct the address in the proposal text._

We further note, for completeness, that the payload extends the approval lists of WETH, USDC, and USDS to the newly
added vaults, which the specification tables do not mention, and that the on-chain annotations posted by the payload
cover only the six Morpho vaults.

## Reproduction

To verify locally:

1. Clone: `git clone https://github.com/blockful/dao-proposals.git`
2. Checkout: `git checkout f47b317`
3. Run: `forge test --match-path "src/ens/proposals/ep-kpk-update-10/*" -vv`

We will re-run this verification once the payload is finalized and the Tally draft is published.
