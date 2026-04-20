// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";

/// @title BaseGovernance
/// @notice Abstract base for all DAO governance proposal tests.
///         Provides the shared lifecycle: setUp -> test_proposal -> assertions.
///         Governance-specific logic (propose, vote, queue, execute) is delegated
///         to adapter methods that each DAO implements.
abstract contract BaseGovernance is Test {
    // ─── Proposal State
    // ─────────────────────────────────────────────────
    address public proposer;
    address[] public voters;

    // ─── Lifecycle
    // ──────────────────────────────────────────────────────

    /// @notice Override in DAO base class to initialize governance contracts
    function setUp() public virtual {
        _selectFork();
        proposer = _proposer();
        voters = _voters();
        _labelContracts();
    }

    // ─── Abstract: Must be implemented by each DAO
    // ──────────────────────

    /// @notice Select the fork (chain + block) for the test
    function _selectFork() public virtual;

    /// @notice Return the proposer address
    function _proposer() public view virtual returns (address);

    /// @notice Return the voter addresses (must achieve quorum)
    function _voters() public view virtual returns (address[] memory);

    /// @notice Label governance contracts for trace readability
    function _labelContracts() internal virtual;

    /// @notice Store state before proposal execution for comparison
    function _beforeProposal() public virtual;

    /// @notice Assert state changes after proposal execution
    function _afterExecution() public virtual;

    /// @notice Whether the proposal is already submitted on-chain
    function _isProposalSubmitted() public view virtual returns (bool);

    /// @notice Return the directory path for JSON calldata comparison.
    ///         Empty string skips comparison.
    function dirPath() public virtual returns (string memory) {
        return "";
    }
}
