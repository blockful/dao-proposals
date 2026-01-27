You’re helping me implement and harden a “Security Council Guard” for Shutter DAO.

Safe: 0x36bD3044ab68f600f6d3e081056F34f2a58432c4
Azorius: 0xAA6BfA174d2f803b517026E93DBBEc1eBa26258e
Voting strategy: 0x4b29d8B250B8b442ECfCd3a4e3D91933d2db720F

Context:
- We have an Azorius module contract (governance execution module) that stores proposals as an ordered list of txHashes and executes via Module.exec().
- Module.exec() calls IAvatar(target).execTransactionFromModule(...) and, if a guard is set, calls IGuard.checkTransaction(...) before execution.
- Guardable is OwnableUpgradeable and exposes setGuard(address) onlyOwner. In our deployment, the OWNER is the DAO (not the council).
- We want no changes to Azorius code, maybe on configurable parameters. The council will veto by proposalId without modifying Azorius.

Goal:
- Implement a Guard contract that can veto an Azorius proposal “by id” by:
  1) taking a proposalId
  2) reading all tx hashes for that proposal onchain via Azorius.getProposalTxHashes(proposalId)
  3) storing those hashes in the guard
  4) blocking any Safe module execution whose computed txHash matches a vetoed hash.

Authorization:
- Only a specific multisig (“council”) can call veto/unveto functions on the guard.
- The DAO (owner) will set this guard once via setGuard(), but routine veto/unveto is done by the council.

Guard behavior:
- In checkTransaction(to,value,data,operation,...), recompute the Azorius hash:
  txHash = Azorius(azorius).getTxHash(to, value, data, operation)
  If vetoedTxHash[txHash] == true -> revert.
- Provide functions:
  - vetoProposal(uint32 proposalId): fetch + store all txHashes, mark vetoed
  - unvetoProposal(uint32 proposalId): delete stored hashes and unveto them
  - optional fine-grained vetoTx/unvetoTx for emergency
  - multicall(bytes[] calls) callable only by council to batch ops.

Edge cases / caveats to account for:
- Gas limits if a proposal has many transactions: consider chunking (vetoProposalRange(proposalId, start, count)) or enforce max tx count.
- Idempotency: calling vetoProposal twice shouldn’t break state; unveto should be safe if called after partial actions.
- Prevent bypass: this guard only blocks module execution routes. Ensure Safe doesn’t have other enabled modules that can execute the same calls unguarded.
- Decide delegatecall policy: optionally block Enum.Operation.DelegateCall at guard level.
- Ensure ERC165 compliance: supportsInterface(type(IGuard).interfaceId) must be true to be set via Guardable.setGuard.

Tasks:
1) Review the guard contract file I pasted. Identify correctness issues with the hashing / calldata types (bytes calldata vs bytes memory) and any compilation errors with interfaces.
2) Improve the design:
   - add optional chunked veto/unveto to avoid gas blowups
   - add events, custom errors, and clear storage layout
   - consider storing only a mapping (txHash=>bool) plus (proposalId=>hashes[]) for unveto convenience
3) Add tests (Foundry preferred):
   - Deploy mock Azorius that exposes getProposalTxHashes and getTxHash exactly like real (or fork mainnet + use real Azorius ABI).
   - Test: vetoProposal blocks execution: simulate checkTransaction call with a tx matching a vetoed hash -> revert.
   - Test: unvetoProposal allows execution again.
   - Test: onlyCouncil enforcement for veto/unveto/multicall.
4) Provide a minimal harness to emulate Safe guard calls:
   - We can directly call guard.checkTransaction(...) in tests with the same parameters Module.exec() passes (the Safe-related fields can be zero).
   - Validate that veto triggers based on computed hash.

Constraints:
- Minimize dependencies; keep guard self-contained.
- Avoid changing Azorius.
- Keep code production-grade (clear errors, minimal footguns).
Return:
- Concrete edits to the contract in-place + Foundry test files
