# DAO Proposals

This is a collection of DAO proposals developed and mantained by [Blockful](https://github.com/blockful-io). 

## Getting Started

Start by getting `foundryup` latest version and installing the dependencies:

```sh
$ curl -L https://foundry.paradigm.xyz | bash
$ yarn
```

If this is your first time with Foundry, check out the
[installation](https://github.com/foundry-rs/foundry#installation) instructions.

### Clean

Delete the build artifacts and cache directories:

```sh
$ forge clean
```

### Compile

Compile the contracts:

```sh
$ forge build
```

## Calldata Review Process

### Folder Naming

Proposal folders use the EP number: `src/<dao>/proposals/ep-<number>/`

Examples: `ep-6-37`, `ep-6-38`, `ep-5-29`

If a draft was created with a descriptive name (e.g. `ep-kpk-update-8`), rename it to the EP number when updating to the live review.

### Draft → Live Update Checklist

When a proposal moves from draft to on-chain vote:

1. **Rename the folder** to match the EP number (e.g. `ep-kpk-update-8` → `ep-6-38`)
2. **Update internal path references** in `calldataCheck.t.sol` (`dirPath()`, `vm.readFile()` calls)
3. **Verify on-chain calldata matches the draft** — extract calldata from the `ProposalCreated` event and diff against the draft's `proposalCalldata.json`
4. **Update `proposalCalldata.json`**:
   - Set `proposalId` to the on-chain proposal ID
   - Add `blockNumber`, `votingStart`, `votingEnd`, `createdAt`
   - Remove `type: "draft"` if present
5. **Update `calldataCheck.t.sol`**:
   - Set `_isProposalSubmitted()` to return `true`
   - Pin the fork to the proposal creation block: `vm.createSelectFork({ blockNumber: <block>, urlOrAlias: "mainnet" })`
   - Update `@notice` and `@dev` natspec to reference the live proposal URL
6. **Run tests** — `forge test --match-path src/<dao>/proposals/ep-<number>/calldataCheck.t.sol -v`
7. **Open PR** from branch `<dao>/ep-<number>-live`

## License

This project is licensed under MIT.
