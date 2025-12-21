// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";

import { IAzorius } from "@shutter/interfaces/IAzorius.sol";
import { ILinearERC20Voting } from "@shutter/interfaces/ILinearERC20Voting.sol";
import { IVotes } from "@shutter/interfaces/IVotes.sol";
import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";

abstract contract Shutter_Governance is Test {
    /*//////////////////////////////////////////////////////////////////////////
                                GOVERNANCE VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    address public proposer;
    address[] public voters;

    /*//////////////////////////////////////////////////////////////////////////
                                PROPOSAL VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    uint32 public proposalId;
    string public metadata;

    /*//////////////////////////////////////////////////////////////////////////
                                   GOVERNANCE CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Azorius contract to submit proposals
    IAzorius public constant Azorius = IAzorius(0xAA6BfA174d2f803b517026E93DBBEc1eBa26258e);

    /// @dev Shutter DAO Voting contract
    ILinearERC20Voting public constant LinearERC20Voting = ILinearERC20Voting(0x4b29d8B250B8b442ECfCd3a4e3D91933d2db720F);

    /// @dev Shutter Gnosis Safe (Treasury)
    address public constant ShutterGnosis = 0x36bD3044ab68f600f6d3e081056F34f2a58432c4;

    /// @dev Shutter Token
    address public constant ShutterToken = 0xe485E2f1bab389C08721B291f6b59780feC83Fd7;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        _selectFork();

        proposer = _proposer();
        voters = _voters();

        // Label the base contracts
        vm.label(address(Azorius), "Azorius");
        vm.label(address(LinearERC20Voting), "LinearERC20Voting");
        vm.label(ShutterGnosis, "ShutterGnosis");
        vm.label(ShutterToken, "ShutterToken");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  MAIN TEST FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Executing each step necessary on the proposal lifecycle
    function test_proposal() public {
        // Validate if voters achieve quorum by delegating their votes
        _delegateVoters();

        // Generate transactions for the proposal
        IAzorius.Transaction[] memory transactions = _prepareTransactions();
        metadata = _metadata();

        // Store parameters to be validated after execution
        _beforeProposal();

        if (!_isProposalSubmitted()) {
            // Submit the proposal
            proposalId = _submitProposal(transactions);
        } else {
            // Get the existing proposal ID
            proposalId = Azorius.totalProposalCount() - 1;
        }

        // Mine block so proposal can be voted on
        vm.roll(block.number + 1);

        // Vote for the proposal
        _voteForProposal(proposalId);

        // Mine blocks until voting period ends
        vm.roll(block.number + 21_600);

        // Check if the proposal passed
        bool passed = LinearERC20Voting.isPassed(proposalId);
        assertTrue(passed, "Proposal did not pass");

        // Execute the proposal
        _executeProposal(proposalId, transactions);

        // Validate if the proposal was executed correctly
        IAzorius.ProposalState state = Azorius.proposalState(proposalId);
        assertEq(uint8(state), uint8(IAzorius.ProposalState.EXECUTED), "Proposal not executed");

        // Assert parameters modified after execution
        _afterExecution();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  GOVERNANCE HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Delegates votes from all voters to themselves (or the proposer)
    function _delegateVoters() internal {
        for (uint256 i = 0; i < voters.length; i++) {
            vm.prank(voters[i]);
            IVotes(ShutterToken).delegate(voters[i]);
        }
    }

    /// @dev Submits a proposal to the Azorius governor contract
    function _submitProposal(IAzorius.Transaction[] memory transactions) internal returns (uint32) {
        uint32 newProposalId = Azorius.totalProposalCount();

        vm.prank(proposer);
        Azorius.submitProposal(address(LinearERC20Voting), "0x", transactions, metadata);

        return newProposalId;
    }

    /// @dev Votes for a proposal with all voters
    function _voteForProposal(uint32 _proposalId) internal {
        // NO = 0 | YES = 1 | ABSTAIN = 2
        for (uint256 i = 0; i < voters.length; i++) {
            vm.prank(voters[i]);
            LinearERC20Voting.vote(_proposalId, 1);
        }
    }

    /// @dev Executes a proposal
    function _executeProposal(uint32 _proposalId, IAzorius.Transaction[] memory transactions) internal {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory data,
            IAzorius.Operation[] memory operations
        ) = _prepareTransactionsForExecution(transactions);

        Azorius.executeProposal(_proposalId, targets, values, data, operations);
    }

    /// @dev Prepares the transactions for execution format
    function _prepareTransactionsForExecution(IAzorius.Transaction[] memory transactions)
        internal
        pure
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory data,
            IAzorius.Operation[] memory operations
        )
    {
        uint256 length = transactions.length;

        targets = new address[](length);
        values = new uint256[](length);
        data = new bytes[](length);
        operations = new IAzorius.Operation[](length);

        for (uint256 i = 0; i < length; i++) {
            targets[i] = transactions[i].to;
            values[i] = transactions[i].value;
            data[i] = transactions[i].data;
            operations[i] = transactions[i].operation;
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  ABSTRACT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Selects the fork for the test
    function _selectFork() public virtual;

    /// @dev Returns the proposer address
    function _proposer() public view virtual returns (address) {
        return 0x9Cc9C7F874eD77df06dCd41D95a2C858cd2a2506; // Joseph - default proposer
    }

    /// @dev Returns the array of voters
    function _voters() public view virtual returns (address[] memory votersArray) {
        // Default: just use ShutterGnosis as voter (has majority of tokens)
        votersArray = new address[](1);
        votersArray[0] = ShutterGnosis;
    }

    /// @dev Prepares the transactions to be submitted in the proposal
    function _prepareTransactions() internal view virtual returns (IAzorius.Transaction[] memory);

    /// @dev Returns the metadata for the proposal
    function _metadata() public view virtual returns (string memory);

    /// @dev Checks if the proposal is already submitted onchain
    function _isProposalSubmitted() public view virtual returns (bool);

    /// @dev Stores state before proposal execution
    function _beforeProposal() public virtual;

    /// @dev Validates state after proposal execution
    function _afterExecution() public virtual;
}

