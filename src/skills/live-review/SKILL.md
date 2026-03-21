---
name: live-review
description: Use when a DAO proposal is live on-chain (submitted to the Governor), when the user shares a Tally proposal URL (contains /proposal/), or when transitioning a draft review to a live review
---

# Live Calldata Review

Review a proposal that is **live on-chain** (submitted to the DAO's Governor).

**REQUIRED REFERENCE:** Use `review-reference` for key addresses, helpers, and troubleshooting.

## DAO Detection

1. Extract the Tally slug from the URL (e.g., `tally.xyz/gov/{slug}/proposal/...`).
2. Look up the slug in `src/dao-registry.json` under `daos[slug].tallySlug`.
3. Use the matched entry to resolve all parameterized values below:
   - `{dao}` -- the registry key (e.g., `ens`, `uniswap`)
   - `{name}` -- human-readable DAO name (e.g., `ENS`, `Uniswap`)
   - `{basePath}` -- e.g., `src/ens`
   - `{proposalsPath}` -- e.g., `src/ens/proposals`
   - `{baseTestContract}` -- e.g., `ENS_Governance`
   - `{baseTestFile}` -- e.g., `src/ens/ens.t.sol`
   - `{chain}` -- e.g., `mainnet`
   - `{proposalPrefix}` -- e.g., `ep`

If no Tally URL is provided, ask the user which DAO this review is for.

## Workflow

### 1. Create branch (if new)

```bash
git checkout -b {dao}/{proposalPrefix}-X-Y
```

If continuing from a draft, rename the directory first:
```bash
mv {proposalsPath}/{proposalPrefix}-topic-name {proposalsPath}/{proposalPrefix}-X-Y
```

### 2. Fetch live proposal data

```bash
node src/utils/fetchLiveProposal.js <TALLY_URL_OR_ONCHAIN_ID> <OUTPUT_DIR>
```

Example:
```bash
node src/utils/fetchLiveProposal.js https://www.tally.xyz/gov/{dao}/proposal/10731397... {proposalsPath}/{proposalPrefix}-X-Y
```

This overwrites:
- `proposalCalldata.json` -- executable calls with `blockNumber`
- `proposalDescription.md` -- proposal description

**Important**: The description from Tally may differ from on-chain (trailing whitespace, encoding). If test fails with "Governor: unknown proposal id", see troubleshooting in `review-reference`.

### 3. Update test file

Update the existing `calldataCheck.t.sol`:

```solidity
contract Proposal_{NAME}_{PREFIX}_X_Y_Test is {baseTestContract} {

    function _selectFork() public override {
        // Use blockNumber from proposalCalldata.json
        vm.createSelectFork({ blockNumber: BLOCK_NUMBER, urlOrAlias: "{chain}" });
    }

    function _proposer() public pure override returns (address) {
        return PROPOSER_ADDRESS; // On-chain proposer from Tally
    }

    // _beforeProposal, _generateCallData, _afterExecution stay the same

    function _isProposalSubmitted() public pure override returns (bool) {
        return true; // Live proposal
    }

    function dirPath() public pure override returns (string memory) {
        return "{proposalsPath}/{proposalPrefix}-X-Y";
    }
}
```

### What changes from draft to live

| Field | Draft | Live |
|-------|-------|------|
| `_isProposalSubmitted()` | `false` | `true` |
| `_selectFork()` | Latest block | `blockNumber` from `proposalCalldata.json` |
| `_proposer()` | Draft proposer | On-chain proposer |
| `dirPath()` | May need update | `"{proposalsPath}/{proposalPrefix}-X-Y"` |
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
forge test --match-path "{proposalsPath}/{proposalPrefix}-X-Y/*" -vv
```

### 5. Commit, push, and open PR

```bash
git add {proposalsPath}/{proposalPrefix}-X-Y/
git commit -m "test({dao}): {PREFIX} X.Y -- update to live proposal"
git push origin {dao}/{proposalPrefix}-X-Y
```

Open PR targeting `main`. Merge after review.

### 6. Post to forum

```markdown
## Live proposal calldata security verification

This proposal is finally [live](https://anticapture.com/{dao}/governance/proposal/ONCHAIN_ID)!

Calldata executed the expected outcome. The simulation and tests of the **live** proposal can be found [here](https://github.com/blockful/dao-proposals/blob/COMMIT_HASH/{proposalsPath}/{proposalPrefix}-X-Y/calldataCheck.t.sol).

To verify locally:
1. Clone: `git clone https://github.com/blockful/dao-proposals.git`
2. Checkout: `git checkout SHORT_HASH`
3. Run: `forge test --match-path "{proposalsPath}/{proposalPrefix}-X-Y/*" -vv`
```

Replace:
- `ONCHAIN_ID` -- on-chain proposal ID (from `proposalCalldata.json`)
- `COMMIT_HASH` -- full merge commit hash
- `SHORT_HASH` -- first 7 characters
- `{proposalPrefix}-X-Y` -- the proposal number
