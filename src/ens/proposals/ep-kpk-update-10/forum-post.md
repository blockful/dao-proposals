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
[here](https://github.com/blockful/dao-proposals/blob/337e3000c1be578a06c343bb04ab642de8a70f9a/src/ens/proposals/ep-kpk-update-10/calldataCheck.t.sol).

## Findings and questions for kpk

Our review identified four discrepancies between the proposal text and the payload. We ask kpk to address them before
this proposal proceeds to a vote.

**1. The payload deploys a new permissions module that the proposal text does not mention.** Transactions 0 through 7
deploy a second Roles instance, connect it to the existing one with the full Endowment Manager permission set as its
default, and transfer its ownership to kpk. Our working understanding, based on the Harvest role definition present in
the configuration repository, is that this module is intended to host the Harvest role of item 6, configured by kpk
after execution and outside of the DAO vote, with a single claim operator as its member. We have verified by simulation
that this arrangement functions as intended and that it cannot redirect payouts: claims executed through the module
reach only the Endowment Safe, because the existing Endowment Manager permissions independently restrict the recipient,
and this holds even if the module itself were configured without restrictions. The governance consequence remains: as
owner of the module, kpk may grant third parties access to the Endowment Manager permission set without a DAO vote.
_Question: please confirm this understanding in the proposal text, disclose the module and its intended membership, and
state whether the module will be used for any purpose other than the Harvest role._

**2. Two items of the specification are not present in the payload.** Item 5 (adding syrupUSDC and syrupUSDT to the swap
token lists) does not appear in any of the 54 transactions. Item 6 (the Harvest role) is likewise absent from the
payload itself; under the understanding stated in finding 1, it will be configured on the new module after execution.
_Question: will the payload be amended to include item 5, and will the Harvest role applied to the module match the
definition published in the configuration repository, including its membership?_

**3. The reward claim permissions presented as new already exist.** The three distributors listed under item 6 are
already callable under the current Endowment Manager permissions, with payouts already restricted to the Endowment Safe.
We verified this against the current state of mainnet. Under the understanding stated in finding 1, the contribution of
item 6 is therefore not a new claim permission but a dedicated operator able to claim without holding the wider manager
permissions. _Question: please confirm that this is the intended effect of item 6, and identify the operator._

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
2. Checkout: `git checkout 337e300`
3. Run: `forge test --match-path "src/ens/proposals/ep-kpk-update-10/*" -vv`

We will re-run this verification once the payload is finalized and the Tally draft is published.
