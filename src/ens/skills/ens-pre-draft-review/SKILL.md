---
name: ens-pre-draft-review
description: Use when an ENS DAO proposal is being discussed or designed but has no Tally draft yet, when the user wants to test a proposal idea, deploy custom contracts, or build calldata before it goes to Tally
---

# ENS Pre-Draft Proposal Review

Review a proposal that is being **discussed or designed** -- no Tally draft exists yet.

**REQUIRED REFERENCE:** Use `ens-review-reference` for key addresses, helpers, and troubleshooting.

## Workflow

### 1. Create branch and directory

```bash
git checkout -b ens/ep-topic-name
mkdir -p src/ens/proposals/ep-topic-name
```

Use a descriptive name (e.g., `ens/ep-registrar-manager-endowment`).

### 2. (Optional) Add custom contracts

If the proposal deploys new contracts:
```
src/ens/proposals/ep-topic-name/
  contracts/
    MyContract.sol
    MyContract.t.sol    # Unit tests for the contract
  calldataCheck.t.sol   # Proposal governance test
```

### 3. Write test file

Create `calldataCheck.t.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { ENS_Governance } from "@ens/ens.t.sol";
// Import helpers based on proposal type (see ens-review-reference)
// Import shared interfaces from @ens/interfaces/

contract Proposal_ENS_EP_Topic_Name_Test is ENS_Governance {

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: RECENT_BLOCK, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0x5BFCB4BE4d7B43437d5A0c57E908c048a4418390; // fireeyesdao.eth (default)
    }

    function _beforeProposal() public override {
        // Assert pre-execution state
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

        // Build transactions manually from interfaces -- NO hex blobs
        targets[0] = TARGET_ADDRESS;
        calldatas[0] = abi.encodeWithSelector(...);

        description = "Pre-draft: proposal description TBD";
        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        // Assert expected state changes
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return false;
    }

    function dirPath() public pure override returns (string memory) {
        return ""; // No JSON/md files yet -- skip calldata comparison
    }
}
```

**Key points:**
- `_isProposalSubmitted()` returns `false` -- test submits via `governor.propose()`
- `dirPath()` returns `""` -- no `proposalCalldata.json` exists, calldata comparison skipped
- `description` is a placeholder
- Use `setUp()` override with `super.setUp()` to deploy custom contracts
- All selectors derived from interfaces (`.selector`), never hardcoded hex

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

When the proposal is created on Tally, use the `ens-draft-review` skill. Changes needed:

| Field | Pre-draft | Draft |
|-------|-----------|-------|
| `description` | Hardcoded placeholder | `getDescriptionFromMarkdown()` |
| `dirPath()` | `""` | `"src/ens/proposals/ep-topic-name"` |
| `_proposer()` | Default | From Tally draft |
| New files | None | `proposalCalldata.json`, `proposalDescription.md` (fetched) |
