# Troubleshooting

Common issues encountered during proposal calldata reviews.

## Description Mismatch ("Governor: unknown proposal id")

The description hash doesn't match the on-chain proposal. This happens when the Tally API returns a slightly different description than what was submitted on-chain (e.g., trailing newline).

**Fix**: Extract the exact on-chain description from the `ProposalCreated` event:

```bash
# Get the event from the proposal creation block (blockNumber from proposalCalldata.json)
cast logs \
  --from-block BLOCK_NUMBER --to-block BLOCK_NUMBER \
  --address 0x323A76393544d5ecca80cd6ef2A560C6a395b7E3 \
  "ProposalCreated(uint256,address,address[],uint256[],string[],bytes[],uint256,uint256,string)" \
  --rpc-url mainnet
```

Then decode the description from the event data and overwrite `proposalDescription.md` with the exact bytes.

## Calldata Mismatch

Treat any mismatch as a **critical finding** until proven otherwise. Do not publish approval text while mismatch exists.

1. Check decimal places (USDC: 6, ETH/ENS: 18). See [reference.md](reference.md) decimal table.
2. Verify address checksums
3. Ensure parameter order matches function signature
4. For drafts: the draft may have been updated on Tally — refetch with the same command

## Stack Too Deep

```bash
forge test --match-contract Proposal_ENS_EP_X_Y_Test --skip FileName -vvv
```

## Fork Block Issues

Always use the `blockNumber` from `proposalCalldata.json` in `_selectFork()`. This ensures the fork is at the same state as when the proposal was created.

For pre-draft reviews (no JSON), use a recent mainnet block.

## Compilation Errors

- **Wrong pragma**: Must be `>=0.8.25 <0.9.0`
- **Import not found**: Check `remappings.txt` — ENS uses `@ens/`, Uniswap uses `@uniswap/`
- **Redeclared variable**: Do NOT redeclare `targets`, `values`, `calldatas`, `signatures`, `description`, `ensToken`, `governor`, `timelock` — these are inherited from the base class
