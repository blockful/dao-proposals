# Live Calldata Review

Use this workflow when a proposal is **live on-chain** (submitted to the ENS Governor). This covers fetching the
on-chain data, updating the test, and verifying the live calldata.

## 1. Create Branch (if new)

```bash
git checkout -b ens/ep-X-Y
```

If continuing from a draft, rename the directory first:

```bash
mv src/ens/proposals/ep-topic-name src/ens/proposals/ep-X-Y
```

## 2. Fetch Live Proposal Data

```bash
node ${CLAUDE_SKILL_DIR}/scripts/fetchLiveProposal.js <TALLY_URL_OR_ONCHAIN_ID> <OUTPUT_DIR>
```

Examples:

```bash
node ${CLAUDE_SKILL_DIR}/scripts/fetchLiveProposal.js https://www.tally.xyz/gov/ens/proposal/10731397... src/ens/proposals/ep-6-32
node ${CLAUDE_SKILL_DIR}/scripts/fetchLiveProposal.js 107313977323541760723614084561841045035159333942448750767795024713131429640046 src/ens/proposals/ep-6-32
```

This overwrites:

- `proposalCalldata.json` — executable calls with block info
- `proposalDescription.md` — proposal description

**Important**: The description from Tally may differ from the on-chain description (trailing whitespace, encoding). If
the test fails with "Governor: unknown proposal id", see [troubleshooting.md](troubleshooting.md).

## 3. Update Test File

Update the existing `calldataCheck.t.sol` with these changes:

### What changes from draft to live

| Field                    | Draft           | Live                                              |
| ------------------------ | --------------- | ------------------------------------------------- |
| `_isProposalSubmitted()` | `false`         | `true`                                            |
| `_selectFork()`          | Recent block    | Proposal creation block (from JSON `blockNumber`) |
| `_proposer()`            | Draft proposer  | On-chain proposer (from Tally)                    |
| `dirPath()`              | May need update | `"src/ens/proposals/ep-X-Y"`                      |
| Contract name            | `_Draft_Test`   | `_Test`                                           |

### Template

```solidity
contract Proposal_ENS_EP_X_Y_Test is ENS_Governance {

    function _selectFork() public override {
        // Use blockNumber from proposalCalldata.json
        vm.createSelectFork({ blockNumber: BLOCK_NUMBER, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return PROPOSER_ADDRESS; // On-chain proposer
    }

    // ... _beforeProposal, _generateCallData, _afterExecution stay the same ...

    function _isProposalSubmitted() public pure override returns (bool) {
        return true; // Live proposal
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-X-Y";
    }
}
```

### What the test does

1. Computes `proposalId` from the generated calldata + description hash
2. Verifies the proposal exists on-chain (if the hash doesn't match, you get "Governor: unknown proposal id")
3. Simulates voting, queuing, and execution
4. Runs `_beforeProposal()` and `_afterExecution()` assertions
5. Compares manually generated calldata against `proposalCalldata.json`

**If step 5 fails, do not approve the proposal calldata. Report the mismatch as a finding.**

## 4. Run Test

```bash
forge test --match-path "src/ens/proposals/ep-X-Y/*" -vv
```

## 5. Commit and PR

```bash
git add src/ens/proposals/ep-X-Y/
git commit -m "test(ens): EP X.Y — update to live proposal"
git push origin ens/ep-X-Y
```

Open PR targeting `main`. Merge after review.

## 6. Post to Forum

```markdown
## Live proposal calldata security verification

This proposal is finally [live](https://anticapture.com/ens/governance/proposal/ONCHAIN_ID)!

Calldata executed the expected outcome. The simulation and tests of the **live** proposal can be found
[here](https://github.com/blockful/dao-proposals/blob/COMMIT_HASH/src/ens/proposals/ep-X-Y/calldataCheck.t.sol).

To verify locally:

1. Clone: `git clone https://github.com/blockful/dao-proposals.git`
2. Checkout: `git checkout SHORT_HASH`
3. Run: `forge test --match-path "src/ens/proposals/ep-X-Y/*" -vv`
```

Replace:

- `ONCHAIN_ID` — the on-chain proposal ID (from `proposalCalldata.json`)
- `COMMIT_HASH` — full commit hash from the merged PR
- `SHORT_HASH` — first 7 characters
- `ep-X-Y` — the proposal number
