# ENS Draft Calldata Review Guide

Use this guide when a proposal exists as a **Tally draft** (URL contains `/draft/`). This covers fetching the draft data, writing or updating the test, and verifying calldata.

## Critical Objective (Read First)

- The goal is to detect calldata mistakes before a live submission. A false positive is unacceptable.
- Build `_generateCallData()` from manual derivation of proposal intent, not by copying from `proposalCalldata.json`.
- Do not copy raw calldata blobs from JSON/on-chain/legacy files into the test.
- Derive as much as possible with semantics (`namehash`, `labelhash`, selectors, typed args, contract interfaces).
- `callDataComparison()` is a validation step, not a source of truth.
- If manually derived calldata differs from `proposalCalldata.json`, treat it as a security finding and stop approval. Do not publish approval text.

## 1. Create Branch (if new)

```bash
git checkout -b ens/ep-topic-name
```

If continuing from a pre-draft, use the existing branch.

## 2. Fetch Draft Proposal Data

```bash
node src/utils/fetchTallyDraft.js <DRAFT_URL_OR_ID> <OUTPUT_DIR>
```

Examples:
```bash
node src/utils/fetchTallyDraft.js https://www.tally.xyz/gov/ens/draft/2786603872288769996 src/ens/proposals/ep-topic-name
node src/utils/fetchTallyDraft.js 2786603872288769996 src/ens/proposals/ep-topic-name
```

This creates:
- `proposalCalldata.json` — executable calls from the draft
- `proposalDescription.md` — proposal description

## 3. Write or Update Test File

Create `calldataCheck.t.sol` (or update the existing one from the pre-draft phase).

### Inherited State from `ENS_Governance`

The base contract (`src/ens/ens.t.sol`) provides these variables — do NOT redeclare them:

| Variable | Type | Address | Notes |
|----------|------|---------|-------|
| `ensToken` | `IENSToken` | `0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72` | ENS governance token |
| `governor` | `IGovernor` | `0x323A76393544d5ecca80cd6ef2A560C6a395b7E3` | ENS Governor contract |
| `timelock` | `ITimelock` | `0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7` | ENS Timelock (= wallet.ensdao.eth) |
| `proposer` | `address` | Set by `_proposer()` | Proposal submitter |
| `voters` | `address[]` | Set by `_voters()` | Default voter set with quorum |
| `targets`, `values`, `signatures`, `calldatas`, `description` | — | — | Proposal parameters |

**Important**: Use `address(timelock)` instead of hardcoding the timelock/wallet address.

### Template

```solidity
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { ENS_Governance } from "@ens/ens.t.sol";
// Import relevant interfaces

contract Proposal_ENS_EP_Topic_Name_Test is ENS_Governance {

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: RECENT_BLOCK, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return PROPOSER_ADDRESS; // From Tally draft
    }

    function _beforeProposal() public override {
        // Capture state before execution
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
        // Assert expected state changes
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

| Field | Pre-draft | Draft |
|-------|-----------|-------|
| `description` | Hardcoded placeholder | `getDescriptionFromMarkdown()` |
| `dirPath()` | `""` | `"src/ens/proposals/ep-topic-name"` |
| `_proposer()` | Default | From Tally draft |

### What the test does

1. Simulates the full governance lifecycle (propose → vote → queue → execute)
2. Runs `_beforeProposal()` and `_afterExecution()` assertions
3. Runs `callDataComparison()` — compares manually generated calldata against `proposalCalldata.json`

If step 3 fails, this is a finding, not a flaky test. Pause approval and investigate the mismatch.

## 4. Run Test

```bash
forge test --match-contract Proposal_ENS_EP_Topic_Name_Test -vvv
```

## 5. Commit and PR

```bash
git add src/ens/proposals/ep-topic-name/
git commit -m "test(ens): draft proposal topic-name"
git push origin ens/ep-topic-name
```

## 6. Post to Forum

```markdown
## Draft proposal calldata security review

The calldata draft executes successfully and achieves the expected outcome of the proposal. All simulations and tests are available [here](https://github.com/blockful/dao-proposals/blob/COMMIT_HASH/src/ens/proposals/ep-topic-name/calldataCheck.t.sol).

To verify locally:
1. Clone: `git clone https://github.com/blockful/dao-proposals.git`
2. Checkout: `git checkout SHORT_HASH`
3. Run: `forge test --match-path "src/ens/proposals/ep-topic-name/*" -vv`
```

## 7. Transitioning to Live

When the proposal is submitted on-chain, follow the [Calldata Review Guide](./CALLDATA_REVIEW_GUIDE.md) to update the same `calldataCheck.t.sol`:

1. Rename directory to `ep-X-Y` if it now has a number
2. Fetch live data: `node src/utils/fetchLiveProposal.js <TALLY_URL> src/ens/proposals/ep-X-Y`
3. Update `_isProposalSubmitted()` to return `true`
4. Update `_selectFork()` with the proposal creation block from `proposalCalldata.json`
5. Update `_proposer()` with the on-chain proposer
6. Update `dirPath()` if the directory was renamed
7. Fix the description if needed (see troubleshooting in the live guide)

## Available Helpers

| Helper | Import | Use Case |
|--------|--------|----------|
| `SafeHelper` | `@ens/helpers/SafeHelper.sol` | Build `execTransaction` calldata. Provides `endowmentSafe`, `_buildSafeExecCalldata()`, `_buildSafeExecDelegateCalldata()` |
| `ZodiacRolesHelper` | `@ens/helpers/ZodiacRolesHelper.sol` | Test Zodiac Roles permissions. Provides `roles`, `karpatkey`, `MANAGER_ROLE`, `_safeExecuteTransaction()`, `_expectConditionViolation()` |

## Troubleshooting

### Calldata mismatch

1. Check decimal places (USDC: 6, ETH/ENS: 18)
2. Verify address checksums
3. Ensure parameter order matches function signature
4. Draft may have been updated on Tally — refetch with the same command

### Stack Too Deep

```bash
# Skip specific file causing issues
forge test --match-contract Proposal_ENS_EP_Topic_Name_Test --skip FileName -vvv
```
