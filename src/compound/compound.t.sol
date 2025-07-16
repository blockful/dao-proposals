// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Test } from "@forge-std/src/Test.sol";
import { console2 } from "@forge-std/src/console2.sol";

import { IGovernor } from "@compound/interfaces/IGovernor.sol";
import { ITimelock } from "@compound/interfaces/ITimelock.sol";
import { ICompoundToken } from "@compound/interfaces/ICompoundToken.sol";
import { IDAO } from "@contracts/utils/interfaces/IDAO.sol";

abstract contract Compound_Governance is Test, IDAO {
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }
    /*//////////////////////////////////////////////////////////////////////////
                                GOVERNANCE VARIABLES
    //////////////////////////////////////////////////////////////////////////*/ 

    address public proposer;
    address[] public voters;

    /*//////////////////////////////////////////////////////////////////////////
                                PROPOSAL VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    uint256 public proposalId;
    address[] public targets;
    uint256[] public values;
    string[] public signatures;
    bytes[] public calldatas;
    string public description;
    bytes32 public descriptionHash;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    IGovernor public governor;
    ITimelock public timelock;
    ICompoundToken public governanceToken;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        _selectFork();

        // Governance contracts
        governanceToken = ICompoundToken(0xc00e94Cb662C3520282E6f5717214004A7f26888);
        governor = IGovernor(payable(0x309a862bbC1A00e45506cB8A802D1ff10004c8C0));
        timelock = ITimelock(payable(0x6d903f6003cca6255D85CcA4D3B5E5146dC33925));
        proposer = _proposer();
        voters = _voters();
        // Label the base test contracts.
        vm.label(address(governor), "governor");
        vm.label(address(timelock), "timelock");
        vm.label(address(governanceToken), "governanceToken");
    }

    // Executing each step necessary on the proposal lifecycle
    function test_proposal() public {
        // Validate if voters achieve quorum
        uint256 totalVotes = 0;
        for (uint256 i = 0; i < voters.length; i++) {
            totalVotes += governanceToken.getCurrentVotes(voters[i]);
        }
        assertGt(totalVotes, governor.quorum(block.number - 1));

        // Validate if proposer has enough votes to submit a proposal
        assertGe(governanceToken.getCurrentVotes(proposer), governor.proposalThreshold());

        // Generate call data
        (targets, values, signatures, calldatas, description) = _generateCallData();

        // Hash the description
        descriptionHash = keccak256(bytes(description));

        // Calculate proposalId
        // proposalId = governor.hashProposal(targets, values, calldatas, descriptionHash);
        
        // Store parameters to be validated after execution
        _beforeProposal();

        if (!_isProposalSubmitted()) {
            // Proposal does not exists onchain, so we need to propose it
            vm.prank(proposer);
            proposalId = governor.propose(targets, values, calldatas, description);
            assertEq(governor.state(proposalId), uint8(ProposalState.Pending));
        }

        // Make proposal ready to vote
        uint256 blocksToWait = governor.votingDelay() + 1;
        vm.roll(block.number + blocksToWait);
        vm.warp(block.timestamp + blocksToWait * 12);
        assertEq(governor.state(proposalId), uint8(ProposalState.Active));

        // Delegates vote for the proposal
        for (uint256 i = 0; i < voters.length; i++) {
            vm.prank(voters[i]);
            governor.castVote(proposalId, 1);
        }

        // Let the voting end
        blocksToWait = governor.votingPeriod();
        vm.roll(block.number + blocksToWait);
        vm.warp(block.timestamp + blocksToWait * 12);
        assertEq(governor.state(proposalId), uint8(ProposalState.Succeeded));

        // Queue the proposal to be executed
        governor.queue(targets, values, calldatas, descriptionHash);
        assertEq(governor.state(proposalId), uint8(ProposalState.Queued));

        // Wait the operation in the DAO wallet timelock to be Ready
        uint256 timeToWait = timelock.delay() + 1;
        vm.warp(block.timestamp + timeToWait);
        vm.roll(block.number + timeToWait * 12);
        assertEq(governor.state(proposalId), uint8(ProposalState.Queued));

        // Execute proposal
        governor.execute(targets, values, calldatas, descriptionHash);
        assertEq(governor.state(proposalId), uint8(ProposalState.Executed));

        // Assert parameters modified after execution
        _afterExecution();
    }

    function _selectFork() public virtual {
        vm.createSelectFork({ urlOrAlias: "mainnet" });
    }

    function _proposer() public view virtual returns (address) {
        return 0x9AA835Bc7b8cE13B9B0C9764A52FbF71AC62cCF1; // a16z
    }

    function _voters() public view virtual returns (address[] memory votersArray) {
        votersArray = new address[](7);
        votersArray[0] = 0x9AA835Bc7b8cE13B9B0C9764A52FbF71AC62cCF1; // a16z
        votersArray[1] = 0xb06DF4dD01a5c5782f360aDA9345C87E86ADAe3D;
        votersArray[2] = 0x8169522c2C57883E8EF80C498aAB7820dA539806; // Geoffrey Hayes
        votersArray[3] = 0x66cD62c6F8A4BB0Cd8720488BCBd1A6221B765F9; // allthecolors.eth
        votersArray[4] = 0x3FB19771947072629C8EEE7995a2eF23B72d4C8A; // pgov.eth
        votersArray[5] = 0x36cc7B13029B5DEe4034745FB4F24034f3F2ffc6; // humpy.eth
        votersArray[6] = 0x7E959eAB54932f5cFd10239160a7fd6474171318;
    }

    function _generateCallData()
        public
        virtual
        returns (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas,
            string memory description
        );

    function _isProposalSubmitted() public view virtual returns (bool);

    function _beforeProposal() public virtual;

    function _afterExecution() public virtual;
}
