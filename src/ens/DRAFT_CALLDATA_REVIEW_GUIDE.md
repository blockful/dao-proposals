# ENS Draft Calldata Review Guide

This guide covers the process for reviewing calldata when ENS proposals are in the **Tally Draft** stage, before they are submitted on-chain.

## Overview

Draft proposals on Tally allow community review and feedback before formal submission. This guide helps reviewers verify the calldata will execute as intended.

## 1. Create Branch

```bash
git checkout -b ens/ep-X-Y-draft
```

## 2. Extract Draft Proposal ID

From the Tally draft URL (e.g., `https://www.tally.xyz/gov/ens/draft/2786603872288769996`), extract the draft ID: `2786603872288769996`

## 3. Fetch Draft Proposal Data

First, update the `PROPOSAL_ID` in `src/utils/fetchTallyDraft.js`:

```javascript
const PROPOSAL_ID = '2786603872288769996'; // Your draft ID
```

Then run:
```bash
node src/utils/fetchTallyDraft.js
```

Output files:
- `proposalCalldata.json` - Executable calls for the draft
- `proposalDescription.md` - Proposal description

Note: The script outputs `proposalCalldata.json` (not `draftCalldata.json`) to maintain consistency with the existing workflow.

## 4. Create Proposal Directory

```bash
mkdir -p src/ens/proposals/ep-X-Y-draft
cp proposalCalldata.json proposalDescription.md src/ens/proposals/ep-X-Y-draft/
```

## 5. Write Test File

Create `calldataCheck.t.sol` extending `ENS_Governance`.

### Inherited State from `ENS_Governance`

The base contract (`src/ens/ens.t.sol`) already provides these variables via `setUp()` — do NOT redeclare them:

| Variable | Type | Address | Notes |
|----------|------|---------|-------|
| `ensToken` | `IENSToken` | `0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72` | ENS governance token |
| `governor` | `IGovernor` | `0x323A76393544d5ecca80cd6ef2A560C6a395b7E3` | ENS Governor contract |
| `timelock` | `ITimelock` | `0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7` | ENS Timelock (= wallet.ensdao.eth) |
| `proposer` | `address` | Set by `_proposer()` | Proposal submitter |
| `voters` | `address[]` | Set by `_voters()` | Default voter set with quorum |
| `targets` | `address[]` | — | Proposal targets (use in `_generateCallData`) |
| `values` | `uint256[]` | — | Proposal values (use in `_generateCallData`) |
| `signatures` | `string[]` | — | Proposal signatures (use in `_generateCallData`) |
| `calldatas` | `bytes[]` | — | Proposal calldatas (use in `_generateCallData`) |
| `description` | `string` | — | Proposal description (use in `_generateCallData`) |

**Important**: `address(timelock)` is `wallet.ensdao.eth` (`0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7`). Use `address(timelock)` instead of redeclaring this address.

Template:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";
import { console2 } from "@forge-std/src/console2.sol";

import { ENS_Governance } from "@ens/ens.t.sol";
// Import relevant interfaces based on proposal type

contract Proposal_ENS_EP_X_Y_Draft_Test is ENS_Governance {
    // State variables for tracking changes
    
    function _selectFork() public override {
        // Use latest block or specific block for consistent testing
        vm.createSelectFork({ blockNumber: BLOCK_NUMBER, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        // Draft proposer address from Tally
        return PROPOSER_ADDRESS;
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
        // Reconstruct calldata from proposalCalldata.json
        uint256 numTransactions = N;

        targets = new address[](numTransactions);
        values = new uint256[](numTransactions);
        calldatas = new bytes[](numTransactions);
        signatures = new string[](numTransactions);

        // Transaction 1
        targets[0] = TARGET_ADDRESS;
        calldatas[0] = CALLDATA;
        values[0] = VALUE;
        signatures[0] = "";

        // Add more transactions as needed

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        // Assert expected state changes
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return false; // IMPORTANT: false for draft proposals
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-X-Y-draft";
    }
}
```

## 6. Key Differences from Live Proposals

| Aspect | Draft | Live |
|--------|-------|------|
| **Proposal ID** | Draft ID from Tally | On-chain proposal ID |
| **Block Number** | Use latest or recent block | Specific proposal block |
| **_isProposalSubmitted()** | Returns `false` | Returns `true` |
| **Directory Name** | `ep-X-Y-draft` | `ep-X-Y` |
| **Calldata File** | `proposalCalldata.json` | `proposalCalldata.json` |

## 7. Run Test

```bash
forge test --match-contract Proposal_ENS_EP_X_Y_Draft_Test -vvv
```

## 8. Community Review Process

### Create Review Post

Post in the ENS governance forum with:

```markdown
## Draft Proposal Calldata Review: [EP X.Y Title]

I've reviewed the draft proposal calldata for [EP X.Y](https://www.tally.xyz/gov/ens/draft/DRAFT_ID).

### Summary
[Brief description of what the proposal does]

### Calldata Verification
- ✅ Calldata correctly implements the intended actions
- ✅ All target addresses verified
- ✅ Parameter values match proposal description
- ✅ No unexpected side effects

### Test Results
The simulation passed successfully. You can verify by:
1. Clone: `git clone https://github.com/blockful-io/dao-proposals.git`
2. Checkout: `git checkout ens/ep-X-Y-draft`
3. Run: `forge test --match-path "src/ens/proposals/ep-X-Y-draft/*" -vv`

### Recommendations
[Any suggestions for improvement before submission]
```

## 9. Transitioning from Draft to Live

When the proposal is submitted on-chain:

1. **Create new branch** from main: `git checkout -b ens/ep-X-Y`

2. **Copy draft files** to new directory:
   ```bash
   cp -r src/ens/proposals/ep-X-Y-draft src/ens/proposals/ep-X-Y
   ```

3. **Fetch live proposal data**:
   ```bash
   node src/utils/fetchLiveProposal.js
   ```

4. **Update test file**:
   - Change `_isProposalSubmitted()` to return `true`
   - Update block number from `proposalCalldata.json`
   - Update proposer if different
   - Update `dirPath()` to remove `-draft`

5. **Run updated test** and create PR

## Example: Draft Proposal Review

Here's a real example based on EP-6.17 (transfer .locker TLD):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";
import { ENS_Governance } from "@ens/ens.t.sol";
import { IENSRoot } from "@ens/interfaces/IENSRoot.sol";
import { IENSRegistryWithFallback } from "@ens/interfaces/IENSRegistryWithFallback.sol";

contract Proposal_ENS_EP_6_17_Draft_Test is ENS_Governance {
    IENSRoot root = IENSRoot(0xaB528d626EC275E3faD363fF1393A41F581c5897);
    IENSRegistryWithFallback ensRegistry = IENSRegistryWithFallback(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);

    address oldOwner;
    address newOwner = 0x63862031C544642024eF9A0B713AF2aB9236A198;
    bytes32 labelhashBytes = labelhash("locker");
    bytes32 node = namehash("locker");

    function _selectFork() public override {
        // Use recent block for draft testing
        vm.createSelectFork({ blockNumber: 23_043_292, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0x534631Bcf33BDb069fB20A93d2fdb9e4D4dD42CF; // slobo.eth
    }

    function _beforeProposal() public override {
        oldOwner = ensRegistry.owner(node);
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
        uint256 numTransactions = 1;

        targets = new address[](numTransactions);
        values = new uint256[](numTransactions);
        calldatas = new bytes[](numTransactions);
        signatures = new string[](numTransactions);

        // 1. Set the owner of the .locker TLD to Orange Domains address
        targets[0] = address(root);
        calldatas[0] = abi.encodeWithSelector(
            IENSRoot.setSubnodeOwner.selector, 
            labelhashBytes, 
            newOwner
        );
        values[0] = 0;
        signatures[0] = "";

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        assertEq(ensRegistry.owner(node), newOwner);
        assertNotEq(oldOwner, newOwner);
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return false; // Draft proposal
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-6-17-draft";
    }
}
```

## Troubleshooting

### Draft-Specific Issues

1. **No draft data returned**
   - Verify the draft ID is correct
   - Check if the draft is still active on Tally
   - Ensure you have proper API access

2. **Calldata mismatch**
   - Draft proposals may be updated - refetch the latest data
   - Verify you're using the correct draft ID

3. **Block number considerations**
   - For drafts, use a recent block or the latest
   - Be aware that state may change between draft review and submission

### Common Patterns

See the main [CALLDATA_REVIEW_GUIDE.md](./CALLDATA_REVIEW_GUIDE.md) for:
- Token transfer patterns
- Registry update patterns
- Safe execTransaction patterns (use `SafeHelper`)
- Zodiac permission patterns (use `ZodiacRolesHelper`)
- Common function selectors
- Key contract addresses

### Available Helpers (`src/ens/helpers/`)

| Helper | Import | Use Case |
|--------|--------|----------|
| `SafeHelper` | `@ens/helpers/SafeHelper.sol` | Build `execTransaction` calldata with pre-approved signatures. Provides `endowmentSafe`, `_buildSafeExecCalldata()`, `_buildSafeExecDelegateCalldata()`, `_buildPreApprovedSignature()` |
| `ZodiacRolesHelper` | `@ens/helpers/ZodiacRolesHelper.sol` | Test Zodiac Roles permissions. Provides `roles`, `karpatkey`, `MANAGER_ROLE`, `_safeExecuteTransaction()`, `_expectConditionViolation()` |