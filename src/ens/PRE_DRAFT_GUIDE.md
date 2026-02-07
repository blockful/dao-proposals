# ENS Pre-Draft Proposal Guide

Use this guide when a proposal is being **discussed or designed** but has no Tally draft yet. This covers deploying custom contracts, testing an idea, or building calldata before it goes to Tally.

## 1. Create Branch

```bash
git checkout -b ens/ep-topic-name
```

Use a descriptive name (e.g., `ens/ep-registrar-manager-endowment`, `ens/ep-enable-security-controllers`).

## 2. Create Proposal Directory

```bash
mkdir -p src/ens/proposals/ep-topic-name
```

No `proposalCalldata.json` or `proposalDescription.md` yet — those come later when the draft is created on Tally.

## 3. (Optional) Add Custom Contracts

If the proposal deploys new contracts, place them in a `contracts/` subdirectory:

```
src/ens/proposals/ep-topic-name/
  ├── contracts/
  │   ├── MyContract.sol
  │   └── MyContract.t.sol       # Unit tests for the contract
  └── calldataCheck.t.sol         # Proposal governance test
```

## 4. Write Test File

Create `calldataCheck.t.sol` extending `ENS_Governance`.

### Inherited State from `ENS_Governance`

The base contract (`src/ens/ens.t.sol`) provides these variables via `setUp()` — do NOT redeclare them:

| Variable | Type | Address | Notes |
|----------|------|---------|-------|
| `ensToken` | `IENSToken` | `0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72` | ENS governance token |
| `governor` | `IGovernor` | `0x323A76393544d5ecca80cd6ef2A560C6a395b7E3` | ENS Governor contract |
| `timelock` | `ITimelock` | `0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7` | ENS Timelock (= wallet.ensdao.eth) |
| `proposer` | `address` | Set by `_proposer()` | Proposal submitter |
| `voters` | `address[]` | Set by `_voters()` | Default voter set with quorum |
| `targets` | `address[]` | — | Proposal targets |
| `values` | `uint256[]` | — | Proposal values |
| `signatures` | `string[]` | — | Proposal signatures |
| `calldatas` | `bytes[]` | — | Proposal calldatas |
| `description` | `string` | — | Proposal description |

**Important**: `address(timelock)` is `wallet.ensdao.eth` (`0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7`).

### Template

```solidity
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { ENS_Governance } from "@ens/ens.t.sol";
// Import relevant interfaces / custom contracts

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

        // Build transactions...

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
        return ""; // No JSON/md files yet — skip calldata comparison
    }
}
```

### Key Points

- `_isProposalSubmitted()` returns `false` — the test will submit the proposal via `governor.propose()`
- `dirPath()` returns `""` — no `proposalCalldata.json` exists yet, so calldata comparison is skipped
- `description` is a placeholder — it will be replaced when the draft goes to Tally
- Use `setUp()` override with `super.setUp()` to deploy custom contracts

## 5. Run Test

```bash
forge test --match-contract Proposal_ENS_EP_Topic_Name_Test -vvv
```

## 6. Available Helpers

| Helper | Import | Use Case |
|--------|--------|----------|
| `SafeHelper` | `@ens/helpers/SafeHelper.sol` | Build `execTransaction` calldata with pre-approved signatures. Provides `endowmentSafe`, `_buildSafeExecCalldata()`, `_buildSafeExecDelegateCalldata()` |
| `ZodiacRolesHelper` | `@ens/helpers/ZodiacRolesHelper.sol` | Test Zodiac Roles permissions. Provides `roles`, `karpatkey`, `MANAGER_ROLE`, `_safeExecuteTransaction()`, `_expectConditionViolation()` |

## 7. Transitioning to Draft

When the proposal is created as a Tally draft, follow the [Draft Calldata Review Guide](./DRAFT_CALLDATA_REVIEW_GUIDE.md) to update the same `calldataCheck.t.sol`:

1. Fetch draft data: `node src/utils/fetchTallyDraft.js <DRAFT_URL> src/ens/proposals/ep-topic-name`
2. Update `description = getDescriptionFromMarkdown();` in `_generateCallData()`
3. Update `dirPath()` to return the proposal directory path
4. Verify calldata matches: the test will now run `callDataComparison()` against the JSON
