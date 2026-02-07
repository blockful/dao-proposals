# ENS Live Calldata Review Guide

Use this guide when a proposal is **live on-chain** (submitted to the ENS Governor). This covers fetching the on-chain data, updating the test, and verifying the live calldata.

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
node src/utils/fetchLiveProposal.js <TALLY_URL_OR_ONCHAIN_ID> <OUTPUT_DIR>
```

Examples:
```bash
node src/utils/fetchLiveProposal.js https://www.tally.xyz/gov/ens/proposal/10731397... src/ens/proposals/ep-6-32
node src/utils/fetchLiveProposal.js 107313977323541760723614084561841045035159333942448750767795024713131429640046 src/ens/proposals/ep-6-32
```

This overwrites:
- `proposalCalldata.json` — executable calls with block info
- `proposalDescription.md` — proposal description

**Important**: The description from Tally may differ from the on-chain description (trailing whitespace, encoding). If the test fails with "Governor: unknown proposal id", see [Description Mismatch](#description-mismatch) below.

## 3. Update Test File

Update the existing `calldataCheck.t.sol` with these changes:

### What changes from draft to live

| Field | Draft | Live |
|-------|-------|------|
| `_isProposalSubmitted()` | `false` | `true` |
| `_selectFork()` | Recent block | Proposal creation block (from JSON `blockNumber`) |
| `_proposer()` | Draft proposer | On-chain proposer (from Tally) |
| `dirPath()` | May need update | `"src/ens/proposals/ep-X-Y"` |
| Contract name | `_Draft_Test` | `_Test` |

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
5. Runs `callDataComparison()` — compares generated calldata against the live `proposalCalldata.json`

## 4. Run Test

```bash
forge test --match-contract Proposal_ENS_EP_X_Y_Test -vvv
```

## 5. Commit and PR

```bash
git add src/ens/proposals/ep-X-Y/
git commit -m "test(ens): live proposal X.Y"
git push origin ens/ep-X-Y
```

## 6. Post to Forum

```markdown
## Live proposal calldata security verification

This proposal is finally [live](https://www.tally.xyz/gov/ens/proposal/ONCHAIN_ID)!

Calldata executed the expected outcome. The simulation and tests of the **live** proposal can be found [here](https://github.com/blockful/dao-proposals/blob/COMMIT_HASH/src/ens/proposals/ep-X-Y/calldataCheck.t.sol).

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

## Troubleshooting

### Description Mismatch

If the test fails with `Governor: unknown proposal id`, the description hash doesn't match the on-chain proposal. This happens when the Tally API returns a slightly different description than what was submitted on-chain (e.g., trailing newline).

**Fix**: Extract the exact on-chain description from the `ProposalCreated` event:

```bash
# Get the event from the proposal creation block (blockNumber from JSON)
cast logs \
  --from-block BLOCK_NUMBER --to-block BLOCK_NUMBER \
  --address 0x323A76393544d5ecca80cd6ef2A560C6a395b7E3 \
  "ProposalCreated(uint256,address,address[],uint256[],string[],bytes[],uint256,uint256,string)" \
  --rpc-url mainnet
```

Then decode the description from the event data and overwrite `proposalDescription.md` with the exact bytes.

### Calldata Mismatch

1. Check decimal places (USDC: 6, ETH/ENS: 18)
2. Verify address checksums
3. Ensure parameter order matches function signature

### Stack Too Deep

```bash
forge test --match-contract Proposal_ENS_EP_X_Y_Test --skip FileName -vvv
```

### Fork Block Issues

Always use the `blockNumber` from `proposalCalldata.json` in `_selectFork()`. This ensures the fork is at the same state as when the proposal was created.

---

## Key Addresses

| Contract | Address |
|----------|---------|
| ENS Token | `0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72` |
| ENS Governor | `0x323A76393544d5ecca80cd6ef2A560C6a395b7E3` |
| ENS Timelock | `0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7` |
| ENS Root | `0xaB528d626EC275E3faD363fF1393A41F581c5897` |
| ENS Registry | `0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e` |
| USDC | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` |
| Zodiac Roles | `0x703806E61847984346d2D7DDd853049627e50A40` |
| ENS Endowment Safe | `0x4F2083f5fBede34C2714aFfb3105539775f7FE64` |
| Meta-Gov Multisig | `0x91c32893216dE3eA0a55ABb9851f581d4503d39b` |
| Ecosystem Multisig | `0x2686A8919Df194aA7673244549E68D42C1685d03` |
| Public Goods Multisig | `0xcD42b4c4D102cc22864e3A1341Bb0529c17fD87d` |

## Available Helpers

| Helper | Import | Use Case |
|--------|--------|----------|
| `SafeHelper` | `@ens/helpers/SafeHelper.sol` | Build `execTransaction` calldata. Provides `endowmentSafe`, `_buildSafeExecCalldata()`, `_buildSafeExecDelegateCalldata()` |
| `ZodiacRolesHelper` | `@ens/helpers/ZodiacRolesHelper.sol` | Test Zodiac Roles permissions. Provides `roles`, `karpatkey`, `MANAGER_ROLE`, `_safeExecuteTransaction()`, `_expectConditionViolation()` |

## Common Function Selectors

| Selector | Function |
|----------|----------|
| `0xa9059cbb` | `transfer(address,uint256)` |
| `0x095ea7b3` | `approve(address,uint256)` |
| `0x23b872dd` | `transferFrom(address,address,uint256)` |
| `0x6a761202` | `execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes)` |
