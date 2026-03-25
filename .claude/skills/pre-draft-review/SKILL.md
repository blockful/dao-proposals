---
name: pre-draft-review
description: Review a DAO proposal that is being discussed or designed but has no Tally draft yet. Use when testing a proposal idea, deploying custom contracts, or building calldata before it goes to Tally.
---

# Pre-Draft Proposal Review

Review a proposal that is being **discussed or designed** — no Tally draft exists yet.

**Before proceeding, read the full guide:** `src/ens/PRE_DRAFT_GUIDE.md`

The guide is the source of truth for the review process, assertion baseline, and inherited state.

## Critical Objective

- Catch bugs in proposal calldata early. A false positive is the worst outcome.
- Build calldata manually from proposal intent and contract interfaces.
- Derive parameters from first principles. Do not copy raw calldata blobs.
- If any parameter cannot be confidently derived, flag it as a finding.

## Workflow

### 1. Create branch and directory

```bash
git checkout -b ens/ep-topic-name
mkdir -p src/ens/proposals/ep-topic-name
```

### 2. (Optional) Add custom contracts

If the proposal deploys new contracts:
```
src/ens/proposals/ep-topic-name/
  contracts/
    MyContract.sol
    MyContract.t.sol       # Unit tests for the contract
  calldataCheck.t.sol      # Proposal governance test
```

### 3. Write test file

Create `calldataCheck.t.sol` per the template in `src/ens/PRE_DRAFT_GUIDE.md`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { ENS_Governance } from "@ens/ens.t.sol";
// Import relevant interfaces from @ens/interfaces/

contract Proposal_ENS_EP_Topic_Name_Test is ENS_Governance {

    function setUp() public override {
        super.setUp();
        // Deploy custom contracts here if needed
    }

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: RECENT_BLOCK, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0x5BFCB4BE4d7B43437d5A0c57E908c048a4418390; // fireeyesdao.eth (default)
    }

    function _beforeProposal() public override {
        // Capture state before execution — see assertion baseline in guide
    }

    function _generateCallData()
        public override
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory, string memory)
    {
        uint256 numTransactions = N;
        targets = new address[](numTransactions);
        values = new uint256[](numTransactions);
        calldatas = new bytes[](numTransactions);
        signatures = new string[](numTransactions);

        // Build transactions manually from interfaces — NO hex blobs
        targets[0] = TARGET_ADDRESS;
        calldatas[0] = abi.encodeWithSelector(IContract.method.selector, args);
        values[0] = 0;
        signatures[0] = "";

        description = "Pre-draft: proposal description TBD";
        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        // Assert expected state changes — see assertion baseline in guide
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return false;
    }

    function dirPath() public pure override returns (string memory) {
        return ""; // No JSON/md files yet — skip calldata comparison
    }
}
```

**Key points:**
- `_isProposalSubmitted()` returns `false` — test submits via `governor.propose()`
- `dirPath()` returns `""` — no JSON exists, calldata comparison is skipped
- `description` is a placeholder — replaced when draft goes to Tally
- Override `setUp()` with `super.setUp()` to deploy custom contracts

### 4. Run test

```bash
forge test --match-contract Proposal_ENS_EP_Topic_Name_Test -vvv
```

### 5. Commit

```bash
git add src/ens/proposals/ep-topic-name/
git commit -m "chore(ens): add pre-draft calldata review for EP topic-name"
git push origin ens/ep-topic-name
```

## Transitioning to Draft

When the proposal is created on Tally, use `/draft-review`. See `src/ens/PRE_DRAFT_GUIDE.md` section 8 for what changes:

| Field | Pre-draft | Draft |
|-------|-----------|-------|
| `description` | Hardcoded placeholder | `getDescriptionFromMarkdown()` |
| `dirPath()` | `""` | `"src/ens/proposals/ep-topic-name"` |
| `_proposer()` | Default | From Tally draft |
| New files | None | `proposalCalldata.json`, `proposalDescription.md` |

## For Shutter/Azorius DAOs

Shutter uses a different governance architecture (Azorius + LinearERC20Voting). The template above does NOT work for Shutter. For Shutter proposals:

1. Inherit `Shutter_Governance` from `src/shutter/shutter.t.sol`
2. Override `_prepareTransactions()` (returns `IAzorius.Transaction[]`) instead of `_generateCallData()`
3. Override `_metadata()` instead of using `description`

See `src/shutter/shutter.t.sol` and existing Shutter proposals for examples.

## Assertion Baseline

See `src/ens/PRE_DRAFT_GUIDE.md` — "Minimum Assertion Baseline" section.
