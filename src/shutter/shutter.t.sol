// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Test } from "@forge-std/src/Test.sol";
import { console2 } from "@forge-std/src/console2.sol";

import { IAzorius } from "@shutter/interfaces/IAzorius.sol";
import { ILinearERC20Voting } from "@shutter/interfaces/ILinearERC20Voting.sol";
import { IShutterToken } from "@shutter/interfaces/IShutterToken.sol";
import { IDAO } from "@contracts/utils/interfaces/IDAO.sol";

abstract contract Shutter_Governance is Test, IDAO {
    enum ProposalState {
        ACTIVE,
        TIMELOCKED,
        EXECUTABLE,
        EXECUTED,
        EXPIRED,
        FAILED
    }

    enum Operation {Call, DelegateCall}

    enum VoteType {
        NO,     // disapproves of executing the Proposal
        YES,    // approves of executing the Proposal
        ABSTAIN // neither YES nor NO, i.e. voting "present"
    }

    struct Transaction {
        address to; // destination address of the transaction
        uint256 value; // amount of ETH to transfer with the transaction
        bytes data; // encoded function call data of the transaction
        Operation operation; // Operation type, Call or DelegateCall
    }

    /*//////////////////////////////////////////////////////////////////////////
                                GOVERNANCE VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    address public proposer;
    address[] public voters;

    /*//////////////////////////////////////////////////////////////////////////
                                PROPOSAL VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    uint32 public proposalId;
    address[] public targets;
    uint256[] public values;
    string[] public signatures;
    bytes[] public calldatas;
    string public description;
    bytes32 public descriptionHash;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    IAzorius public azorius;
    ILinearERC20Voting public linearERC20VotingStrategy;
    IShutterToken public governanceToken;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        _selectFork();

        // Governance contracts Shutter
        azorius = IAzorius(0xAA6BfA174d2f803b517026E93DBBEc1eBa26258e);
        linearERC20VotingStrategy = ILinearERC20Voting(0x4b29d8B250B8b442ECfCd3a4e3D91933d2db720F);
        governanceToken = IShutterToken(0xe485E2f1bab389C08721B291f6b59780feC83Fd7);
        proposer = _proposer();
        voters = _voters();
        // Label the base test contracts.
        vm.label(address(azorius), "azorius");
        vm.label(address(linearERC20VotingStrategy), "linearERC20VotingStrategy");
        vm.label(address(governanceToken), "governanceToken");
    }

    // Executing each step necessary on the proposal lifecycle
    function test_proposal() public {
        // Validate if voters achieve quorum
        uint256 totalVotes = 0;
        for (uint256 i = 0; i < voters.length; i++) {
            totalVotes += _getVotes(voters[i]);
        }
        assertGt(totalVotes, _getQuorum());

        // Validate if proposer has enough votes to submit a proposal
        assertGe(_getVotes(proposer), _getProposalThreshold());

        // Generate call data
        (targets, values, signatures, calldatas, description) = _generateCallData();

        // Calculate proposalId
        
        // Store parameters to be validated after execution
        _beforeProposal();

        if (!_isProposalSubmitted()) {
            // Proposal does not exists onchain, so we need to propose it
            vm.startPrank(proposer);
            proposalId = azorius.totalProposalCount();
            // console bytes
            console2.logBytes(bytes(""));
            // console Transaction[]
            {
                IAzorius.Transaction[] memory transactions = _getTransactions(targets, values, calldatas);
                for (uint256 i = 0; i < transactions.length; i++) {
                    console2.log("Transaction", i);
                    console2.log("  to:      %s", address(transactions[i].to));
                    console2.log("  value:   %s", transactions[i].value);
                    console2.logBytes(transactions[i].data);
                    console2.log("  operation: %s", uint256(transactions[i].operation));
                }
            }
            azorius.submitProposal(address(linearERC20VotingStrategy), bytes(""), _getTransactions(targets, values, calldatas), description);
            vm.stopPrank();

            console2.log("proposalId", proposalId);
            console2.log("proposalState", _getProposalState(proposalId));
            console2.log("ProposalState.ACTIVE", uint256(ProposalState.ACTIVE));

            assertEq(_getProposalState(proposalId), uint8(ProposalState.ACTIVE));
        }

        // Make proposal ready to vote
        uint256 blocksToWait = _getVotingDelay() + 1;
        vm.roll(block.number + blocksToWait);
        vm.warp(block.timestamp + blocksToWait * 12);
        assertEq(_getProposalState(proposalId), uint8(ProposalState.ACTIVE));

        // Delegates vote for the proposal
        for (uint256 i = 0; i < voters.length; i++) {
            vm.prank(voters[i]);
            _vote(proposalId, uint8(VoteType.YES));
        }

        // Let the voting end
        blocksToWait = _getVotingPeriod();
        vm.roll(block.number + blocksToWait);
        vm.warp(block.timestamp + blocksToWait * 12);
        assertEq(_getProposalState(proposalId), uint8(ProposalState.EXECUTABLE));

        // Execute proposal
        _execute(proposalId, targets, values, calldatas, description);
        assertEq(_getProposalState(proposalId), uint8(ProposalState.EXECUTED));

        // Assert parameters modified after execution
        _afterExecution();

        // if (keccak256(abi.encodePacked(jsonPath())) != keccak256(abi.encodePacked(""))) {
        //     draftCallDataComparison();
        // }
    }

    function _getVotes(address account) public view virtual returns (uint256) {
        return governanceToken.getVotes(account);
    }

    function _getVotingDelay() public view virtual returns (uint256) {
        return 0;
    }

    function _getVotingPeriod() public view virtual returns (uint256) {
        return linearERC20VotingStrategy.votingPeriod() + 1;
    }

    function _getQuorum() public view virtual returns (uint256) {
        return governanceToken.getPastTotalSupply(block.number - 1) *
        linearERC20VotingStrategy.quorumNumerator() /
        linearERC20VotingStrategy.QUORUM_DENOMINATOR();
    }

    function _getProposalThreshold() public view virtual returns (uint256) {
        return linearERC20VotingStrategy.requiredProposerWeight();
    }
    
    function _getProposalState(uint32 proposalId) public view virtual returns (uint8) {
        return uint8(azorius.proposalState(proposalId));
    }

    function _vote(uint32 proposalId, uint8 voteType) public virtual {
        linearERC20VotingStrategy.vote(proposalId, voteType);
    }

    function _execute(uint32 proposalId, address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas, string memory _description) public virtual {
        IAzorius.Operation[] memory operations = new IAzorius.Operation[](_targets.length);
        azorius.executeProposal(proposalId, _targets, _values, _calldatas, operations);
    }

    function _selectFork() public virtual {
        vm.createSelectFork({ urlOrAlias: "mainnet" });
    }

    function _proposer() public view virtual returns (address) {
        return _voters()[0];
    }

    function _voters() public view virtual returns (address[] memory votersArray) {
        votersArray = new address[](5);
        votersArray[0] = 0xad95859a35A566a4aFA61f25c9b0Ce7a1c19d3B6;
        votersArray[1] = 0x28B2CE9B54232720E53bcaf4784044E3e4700356;
        votersArray[2] = 0x543dA850A9DFB64BaD9aF1c0297f2051B65f3fF0;
        votersArray[3] = 0xd376e27E283Db82A7aa260d9E67B82e05BA0B52a;
        votersArray[4] = 0x06c2c4dB3776D500636DE63e4F109386dCBa6Ae2;
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

    function _getTransactions(address[] memory targets_, uint256[] memory values_, bytes[] memory calldatas_) public virtual returns (IAzorius.Transaction[] memory transactions) {
        transactions = new IAzorius.Transaction[](targets_.length);
        
        for (uint256 i = 0; i < targets_.length; i++) {
            transactions[i] = IAzorius.Transaction({
                to: targets_[i],
                value: values_[i],
                data: calldatas_[i],
                operation: IAzorius.Operation.Call // Default to Call operation
            });
        }
    }

    function _isProposalSubmitted() public view virtual returns (bool);

    function _beforeProposal() public virtual;

    function _afterExecution() public virtual;

    function jsonPath() public virtual returns (string memory) {
        return "";
    }

    function draftCallDataComparison() public {
        string memory jsonContent = vm.readFile(jsonPath());
    
        address[] memory jsonTargets = parseJsonTargets(jsonContent);
        string[] memory jsonValues = parseJsonValues(jsonContent);
        bytes[] memory jsonCalldatas = parseJsonCalldatas(jsonContent);

        console2.log("JSON parsed successfully with", jsonTargets.length, "operations");

        // Generate calldata from the contract
        (
            address[] memory generatedTargets,
            uint256[] memory generatedValues,
            string[] memory generatedSignatures,
            bytes[] memory generatedCalldatas,
            string memory generatedDescription
        ) = _generateCallData();
        
        // Compare lengths
        assertEq(
            jsonTargets.length,
            generatedTargets.length,
            "Number of executable calls mismatch"
        );
        
        // Compare each operation
        for (uint256 i = 0; i < jsonTargets.length; i++) {
            // Compare target addresses
            assertEq(
                jsonTargets[i],
                generatedTargets[i],
                string(abi.encodePacked("Target mismatch at index ", vm.toString(i)))
            );
            
            // Compare values
            assertEq(
                vm.parseUint(jsonValues[i]),
                generatedValues[i],
                string(abi.encodePacked("Value mismatch at index ", vm.toString(i)))
            );
            
            // Compare calldata
            assertEq(
                jsonCalldatas[i],
                generatedCalldatas[i],
                string(abi.encodePacked("Calldata mismatch at index ", vm.toString(i)))
            );
        }

        assertEq(jsonTargets.length, jsonValues.length, "Targets and values arrays length mismatch");
        assertEq(jsonTargets.length, jsonCalldatas.length, "Targets and calldata arrays length mismatch");
    }

    function decodeTargetsArray(string memory jsonContent) public returns (address[] memory) {
        return abi.decode(vm.parseJson(jsonContent, ".executableCalls[*].target"), (address[]));
    }

    function decodeTargetSingle(string memory jsonContent) public returns (address) {
        return abi.decode(vm.parseJson(jsonContent, ".executableCalls[*].target"), (address));
    }

    function parseJsonTargets(string memory jsonContent) public returns (address[] memory jsonTargets) {
        bytes memory data = abi.encodeWithSelector(this.decodeTargetsArray.selector, jsonContent);
        (bool success, bytes memory returnData) = address(this).call(data);

        if (success) {
            jsonTargets = abi.decode(returnData, (address[]));
        } else {
            bytes memory singleData = abi.encodeWithSelector(this.decodeTargetSingle.selector, jsonContent);
            (bool ok, bytes memory ret) = address(this).call(singleData);
            require(ok, "Single decode failed");
            jsonTargets = new address[](1);
            jsonTargets[0] = abi.decode(ret, (address));
        }
    }

    function decodeValuesArray(string memory jsonContent) public returns (string[] memory) {
        return abi.decode(vm.parseJson(jsonContent, ".executableCalls[*].value"), (string[]));
    }

    function decodeValueSingle(string memory jsonContent) public returns (string memory) {
        return abi.decode(vm.parseJson(jsonContent, ".executableCalls[*].value"), (string));
    }   
    
    function parseJsonValues(string memory jsonContent) public returns (string[] memory jsonValues) {
        bytes memory data = abi.encodeWithSelector(this.decodeValuesArray.selector, jsonContent);
        (bool success, bytes memory returnData) = address(this).call(data);

        if (success) {
            jsonValues = abi.decode(returnData, (string[]));
        } else {
            bytes memory singleData = abi.encodeWithSelector(this.decodeValueSingle.selector, jsonContent);
            (bool ok, bytes memory ret) = address(this).call(singleData);
            require(ok, "Single decode failed");
            jsonValues = new string[](1);
            jsonValues[0] = abi.decode(ret, (string));
        }
    }

    function decodeCalldatasArray(string memory jsonContent) public returns (bytes[] memory) {
        return abi.decode(vm.parseJson(jsonContent, ".executableCalls[*].calldata"), (bytes[]));
    }

    function decodeCalldataSingle(string memory jsonContent) public returns (bytes memory) {
        return abi.decode(vm.parseJson(jsonContent, ".executableCalls[*].calldata"), (bytes));
    }
    
    function parseJsonCalldatas(string memory jsonContent) public returns (bytes[] memory jsonCalldatas) {
        bytes memory data = abi.encodeWithSelector(this.decodeCalldatasArray.selector, jsonContent);
        (bool success, bytes memory returnData) = address(this).call(data);

        if (success) {
            jsonCalldatas = abi.decode(returnData, (bytes[]));
        } else {
            bytes memory singleData = abi.encodeWithSelector(this.decodeCalldataSingle.selector, jsonContent);
            (bool ok, bytes memory ret) = address(this).call(singleData);
            require(ok, "Single decode failed");
            jsonCalldatas = new bytes[](1);
            jsonCalldatas[0] = abi.decode(ret, (bytes));
        }
    }
}
