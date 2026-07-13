# Draft Calldata Review

Use this workflow when a proposal exists as an **Anticapture draft** (URL contains `draftId=`). This covers fetching the
draft data, writing or updating the test, and verifying calldata.

## 1. Create Branch (if new)

```bash
git checkout -b ens/ep-topic-name
```

If continuing from a pre-draft, use the existing branch.

## 2. Fetch Draft Proposal Data

```bash
node ${CLAUDE_SKILL_DIR}/scripts/fetchDraft.js <DRAFT_URL_OR_ID> <OUTPUT_DIR>
```

Examples:

```bash
node ${CLAUDE_SKILL_DIR}/scripts/fetchDraft.js "https://app.anticapture.com/ens/proposals/new?draftId=5daf1183-4216-47b0-8599-ccdaecf25538" src/ens/proposals/ep-topic-name
node ${CLAUDE_SKILL_DIR}/scripts/fetchDraft.js "https://ens.gov.blockful.io/proposals/new?draftId=5daf1183-4216-47b0-8599-ccdaecf25538" src/ens/proposals/ep-topic-name
node ${CLAUDE_SKILL_DIR}/scripts/fetchDraft.js 5daf1183-4216-47b0-8599-ccdaecf25538 src/ens/proposals/ep-topic-name
```

A raw UUID defaults the DAO to `ens`; pass the full URL for other DAOs. This creates:

- `proposalCalldata.json` — executable calls from the draft
- `proposalDescription.md` — proposal description (`# title` + body)

### Raw API (spot checks)

The script reads the Anticapture draft API (no auth needed):

```bash
curl -s "https://app.anticapture.com/api/gateful/<dao>/proposal/drafts/<draftId>"
```

Each entry in `.actions[]` is one transaction: `contractAddress` is the target, and the call comes as `functionName` +
`args` — not encoded calldata. The fetch script encodes it with `cast calldata`. Compare the result against your
manually derived `targets`/`calldatas` exactly as you would any `proposalCalldata.json`, and treat any mismatch as a
finding.

## 3. Write or Update Test File

Create `calldataCheck.t.sol` (or update the existing one from the pre-draft phase).

### Inherited State from `ENS_Governance`

The base contract (`src/ens/ens.t.sol`) provides these variables — do NOT redeclare them:

| Variable                                                      | Type        | Address                                      | Notes                              |
| ------------------------------------------------------------- | ----------- | -------------------------------------------- | ---------------------------------- |
| `ensToken`                                                    | `IENSToken` | `0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72` | ENS governance token               |
| `governor`                                                    | `IGovernor` | `0x323A76393544d5ecca80cd6ef2A560C6a395b7E3` | ENS Governor contract              |
| `timelock`                                                    | `ITimelock` | `0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7` | ENS Timelock (= wallet.ensdao.eth) |
| `proposer`                                                    | `address`   | Set by `_proposer()`                         | Proposal submitter                 |
| `voters`                                                      | `address[]` | Set by `_voters()`                           | Default voter set with quorum      |
| `targets`, `values`, `signatures`, `calldatas`, `description` | —           | —                                            | Proposal parameters                |

**Important**: Use `address(timelock)` instead of hardcoding the timelock/wallet address.

### Template

```solidity
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { ENS_Governance } from "@ens/ens.t.sol";
// Import relevant interfaces from @ens/interfaces/

contract Proposal_ENS_EP_Topic_Name_Draft_Test is ENS_Governance {

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: RECENT_BLOCK, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return PROPOSER_ADDRESS; // Draft author
    }

    function _beforeProposal() public override {
        // Capture state before execution — see assertion-baseline.md
    }

    function _generateCallData()
        public
        override
        returns (
            address[] memory,
            uint256[] memory,
            string[] memory,
            bytes[] memory,
            string memory
        )
    {
        uint256 numTransactions = N;

        targets = new address[](numTransactions);
        values = new uint256[](numTransactions);
        calldatas = new bytes[](numTransactions);
        signatures = new string[](numTransactions);

        // Reconstruct calldata manually from spec + interfaces.
        // Result must then match proposalCalldata.json.
        targets[0] = TARGET_ADDRESS;
        calldatas[0] = abi.encodeWithSelector(...);
        values[0] = 0;
        signatures[0] = "";

        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        // Assert expected state changes — see assertion-baseline.md
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return false; // Draft — not yet on-chain
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-topic-name";
    }
}
```

### What changes from pre-draft

| Field         | Pre-draft             | Draft                                                                                           |
| ------------- | --------------------- | ----------------------------------------------------------------------------------------------- |
| `description` | Hardcoded placeholder | `getDescriptionFromMarkdown()`                                                                  |
| `dirPath()`   | `""`                  | `"src/ens/proposals/ep-topic-name"` **(MANDATORY — comparison is silently skipped without it)** |
| `_proposer()` | Default               | From the draft author                                                                           |

> **WARNING**: If `dirPath()` returns `""` and `proposalCalldata.json` exists, the calldata comparison is silently
> skipped — the test will pass without verifying calldata. This is a false positive risk. Always set `dirPath()` for
> draft reviews.

### What the test does

1. Simulates the full governance lifecycle (propose -> vote -> queue -> execute)
2. Runs `_beforeProposal()` and `_afterExecution()` assertions
3. Compares manually generated calldata against `proposalCalldata.json`

**If step 3 fails, do not approve the proposal calldata. Report the mismatch as a finding.** This is a security check,
not a flaky test — treat any mismatch as critical until investigated.

## 4. Run Test

```bash
forge test --match-path "src/ens/proposals/ep-topic-name/*" -vv
```

## 5. Commit and PR

```bash
git add src/ens/proposals/ep-topic-name/
git commit -m "chore(ens): add draft calldata review for EP X.Y — topic-name"
git push origin ens/ep-topic-name
```

Open PR targeting `main`. Merge after review.

## 6. Post to Forum

```markdown
## Draft proposal calldata security review

The calldata draft executes successfully and achieves the expected outcome of the proposal. All simulations and tests
are available
[here](https://github.com/blockful/dao-proposals/blob/COMMIT_HASH/src/ens/proposals/ep-topic-name/calldataCheck.t.sol).

To verify locally:

1. Clone: `git clone https://github.com/blockful/dao-proposals.git`
2. Checkout: `git checkout SHORT_HASH`
3. Run: `forge test --match-path "src/ens/proposals/ep-topic-name/*" -vv`
```

## 7. Transitioning to Live

When the proposal is submitted on-chain, re-run `/proposal-review` with the live Tally URL. Changes needed:

1. Rename directory to `ep-X-Y` if it now has a number
2. Fetch live data with the live URL
3. Update `_isProposalSubmitted()` to return `true`
4. Update `_selectFork()` with the proposal creation block from `proposalCalldata.json`
5. Update `_proposer()` with the on-chain proposer
6. Update `dirPath()` if the directory was renamed
7. Fix the description if needed (see [troubleshooting.md](troubleshooting.md))
