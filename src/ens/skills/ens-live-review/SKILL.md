---
name: ens-live-review
description: Use when an ENS DAO proposal is live on-chain (submitted to the ENS Governor), when the user shares a Tally proposal URL (contains /proposal/), or when transitioning a draft review to a live review
---

# ENS Live Calldata Review

Review a proposal that is **live on-chain** (submitted to the ENS Governor).

**REQUIRED REFERENCE:** Use `ens-review-reference` for key addresses, helpers, and troubleshooting.

## Workflow

### 1. Create branch (if new)

```bash
git checkout -b ens/ep-X-Y
```

If continuing from a draft, rename the directory first:
```bash
mv src/ens/proposals/ep-topic-name src/ens/proposals/ep-X-Y
```

### 2. Fetch live proposal data

```bash
node src/utils/fetchLiveProposal.js <TALLY_URL_OR_ONCHAIN_ID> <OUTPUT_DIR>
```

Example:
```bash
node src/utils/fetchLiveProposal.js https://www.tally.xyz/gov/ens/proposal/10731397... src/ens/proposals/ep-6-32
```

This overwrites:
- `proposalCalldata.json` -- executable calls with `blockNumber`
- `proposalDescription.md` -- proposal description

**Important**: The description from Tally may differ from on-chain (trailing whitespace, encoding). If test fails with "Governor: unknown proposal id", see troubleshooting in `ens-review-reference`.

### 3. Update test file

Update the existing `calldataCheck.t.sol`:

```solidity
contract Proposal_ENS_EP_X_Y_Test is ENS_Governance {

    function _selectFork() public override {
        // Use blockNumber from proposalCalldata.json
        vm.createSelectFork({ blockNumber: BLOCK_NUMBER, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return PROPOSER_ADDRESS; // On-chain proposer from Tally
    }

    // _beforeProposal, _generateCallData, _afterExecution stay the same

    function _isProposalSubmitted() public pure override returns (bool) {
        return true; // Live proposal
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-X-Y";
    }
}
```

### What changes from draft to live

| Field | Draft | Live |
|-------|-------|------|
| `_isProposalSubmitted()` | `false` | `true` |
| `_selectFork()` | Latest block | `blockNumber` from `proposalCalldata.json` |
| `_proposer()` | Draft proposer | On-chain proposer |
| `dirPath()` | May need update | `"src/ens/proposals/ep-X-Y"` |
| Contract name | `_Draft_Test` | `_Test` |

### What the test does

1. Computes `proposalId` from generated calldata + description hash
2. Verifies the proposal exists on-chain (hash mismatch = "Governor: unknown proposal id")
3. Simulates voting, queuing, and execution
4. Runs `_beforeProposal()` and `_afterExecution()` assertions
5. Runs `callDataComparison()` -- compares manually generated calldata against live `proposalCalldata.json`

**If step 5 fails, do not approve. Report the mismatch as a finding.**

### 4. Run test

```bash
forge test --match-path "src/ens/proposals/ep-X-Y/*" -vv
```

### 5. Commit, push, and open PR

```bash
git add src/ens/proposals/ep-X-Y/
git commit -m "test(ens): EP X.Y -- update to live proposal"
git push origin ens/ep-X-Y
```

Open PR targeting `main`. Merge after review.

### 6. Post to forum

```markdown
## Live proposal calldata security verification

This proposal is finally [live](https://anticapture.com/ens/governance/proposal/ONCHAIN_ID)!

Calldata executed the expected outcome. The simulation and tests of the **live** proposal can be found [here](https://github.com/blockful/dao-proposals/blob/COMMIT_HASH/src/ens/proposals/ep-X-Y/calldataCheck.t.sol).

To verify locally:
1. Clone: `git clone https://github.com/blockful/dao-proposals.git`
2. Checkout: `git checkout SHORT_HASH`
3. Run: `forge test --match-path "src/ens/proposals/ep-X-Y/*" -vv`
```

Replace:
- `ONCHAIN_ID` -- on-chain proposal ID (from `proposalCalldata.json`)
- `COMMIT_HASH` -- full merge commit hash
- `SHORT_HASH` -- first 7 characters
- `ep-X-Y` -- the proposal number
