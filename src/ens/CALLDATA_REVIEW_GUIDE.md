# ENS Calldata Review Process

## 1. Create Branch

```bash
git checkout -b ens/ep-X-Y
```

## 2. Fetch Proposal Data

```bash
node src/utils/fetchLiveProposal.js
```

Output files:
- `proposalCalldata.json` - Executable calls with block info
- `proposalDescription.md` - Proposal description

## 3. Create Proposal Directory

```bash
mkdir -p src/ens/proposals/ep-X-Y
cp proposalCalldata.json proposalDescription.md src/ens/proposals/ep-X-Y/
```

## 4. Analyze Proposal Type

Read the proposal description and identify the type:

| Type | Examples | Key Contracts |
|------|----------|---------------|
| **Token Transfers** | Working group funding | USDC, ENS Token |
| **Registry Updates** | TLD ownership, resolver changes | ENS Root, ENS Registry |
| **Zodiac Permissions** | Treasury management roles | IZodiacRoles, ISafe |
| **Protocol Upgrades** | Contract upgrades, parameter changes | Various |

## 5. Write Test File

Create `calldataCheck.t.sol` extending `ENS_Governance`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { ENS_Governance } from "@ens/ens.t.sol";
// Import relevant interfaces

contract Proposal_ENS_EP_X_Y_Test is ENS_Governance {
    
    function _selectFork() public override {
        // Use blockNumber from proposalCalldata.json
        vm.createSelectFork({ blockNumber: BLOCK_NUMBER, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return PROPOSER_ADDRESS;
    }

    function _beforeProposal() public override {
        // Capture state before execution
    }

    function _generateCallData() public override returns (...) {
        // Reconstruct calldata - must match proposalCalldata.json
    }

    function _afterExecution() public override {
        // Assert expected state changes
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true; // true if live, false if draft
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-X-Y";
    }
}
```

## 6. Run Test

```bash
forge test --match-contract Proposal_ENS_EP_X_Y_Test -vvv
```

## 7. Commit and Open PR

```bash
git add src/ens/proposals/ep-X-Y/
git commit -m "test(ens): live proposal X.Y"
git push origin ens/ep-X-Y
```

Open a PR on GitHub targeting `main`.

## 8. Post to Forum

After the PR is merged, post the verification to the governance forum:

```markdown
## Live proposal calldata security verification

This proposal is finally [live](https://anticapture.com/ens/governance/proposal/PROPOSAL_ID)! 

Calldata executed the expected outcome. The simulation and tests of the **live** proposal can be found [here](https://github.com/blockful-io/dao-proposals/blob/COMMIT_HASH/src/ens/proposals/ep-X-Y/calldataCheck.t.sol).

It can be checked by cloning the repo and running:
`forge test --match-path "src/ens/proposals/ep-X-Y/*" -vv`
```

Replace:
- `PROPOSAL_ID` - The onchain proposal ID (from `proposalCalldata.json`)
- `COMMIT_HASH` - The merged commit hash
- `ep-X-Y` - The proposal number

---

## Proposal Type Examples

### Token Transfers

Transfer USDC/ETH to working group multisigs.

```solidity
IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

// USDC transfer (6 decimals)
targets[0] = address(USDC);
calldatas[0] = abi.encodeWithSelector(USDC.transfer.selector, recipient, amount * 10 ** 6);
values[0] = 0;

// ETH transfer
targets[1] = recipient;
calldatas[1] = hex"";
values[1] = ethAmount;
```

**Assertions:**
```solidity
function _beforeProposal() public override {
    balanceBefore = USDC.balanceOf(recipient);
}

function _afterExecution() public override {
    assertEq(USDC.balanceOf(recipient), balanceBefore + expectedAmount);
}
```

Reference: `ep-6-25`, `ep-6-29`

---

### Registry Updates

Transfer TLD ownership or update resolvers.

```solidity
IENSRoot root = IENSRoot(0xaB528d626EC275E3faD363fF1393A41F581c5897);
IENSRegistryWithFallback ensRegistry = IENSRegistryWithFallback(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);

string tld = "kred";
bytes32 labelhashBytes = labelhash(tld);
bytes32 node = namehash(abi.encodePacked(tld));

// Transfer TLD ownership
targets[0] = address(root);
calldatas[0] = abi.encodeWithSelector(IENSRoot.setSubnodeOwner.selector, labelhashBytes, newOwner);
values[0] = 0;
```

**Assertions:**
```solidity
function _beforeProposal() public override {
    oldOwner = ensRegistry.owner(node);
}

function _afterExecution() public override {
    assertEq(ensRegistry.owner(node), newOwner);
    assertNotEq(oldOwner, newOwner);
}
```

Reference: `ep-6-28`

---

### Zodiac Permissions

Update treasury management roles via Zodiac Roles Modifier.

```solidity
IZodiacRoles roles = IZodiacRoles(0x703806E61847984346d2D7DDd853049627e50A40);
ISafe safe = ISafe(0x4F2083f5fBede34C2714aFfb3105539775f7FE64);

// Test that permissions are correctly scoped
function _beforeProposal() public override {
    vm.startPrank(managerAddress);
    
    // Should revert before proposal
    vm.expectRevert();
    _safeExecuteTransaction(target, calldata);
}

function _afterExecution() public override {
    vm.startPrank(managerAddress);
    
    // Should succeed after proposal
    _safeExecuteTransaction(target, calldata);
}
```

Reference: `ep-6-27`

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

---

## Common Function Selectors

| Selector | Function |
|----------|----------|
| `0xa9059cbb` | `transfer(address,uint256)` |
| `0x095ea7b3` | `approve(address,uint256)` |
| `0x23b872dd` | `transferFrom(address,address,uint256)` |

---

## Troubleshooting

### Stack Too Deep

Diagnosis:
```bash
forge build 2>&1 | tail -20
git status --short  # Check recently changed files
```

Workarounds:
```bash
# Skip specific file
forge test --match-contract Proposal_ENS_EP_X_Y_Test --skip FileName -vvv

# Or temporarily move the file
mv path/to/problematic.sol /tmp/
forge test --match-contract Proposal_ENS_EP_X_Y_Test -vvv
```

### Calldata Mismatch

1. Check decimal places (USDC: 6, ETH/ENS: 18)
2. Verify address checksums
3. Ensure parameter order matches function signature

### Fork Block Issues

Use the `blockNumber` from `proposalCalldata.json` in `_selectFork()`.
