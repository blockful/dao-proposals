// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "@forge-std/src/console2.sol";

import { IDAO } from "@contracts/utils/interfaces/IDAO.sol";
import { CalldataComparison } from "@contracts/base/CalldataComparison.sol";
import { IToken } from "@uniswap/interfaces/IToken.sol";
import { IGovernor } from "@uniswap/interfaces/IGovernor.sol";
import { ITimelock } from "@uniswap/interfaces/ITimelock.sol";

abstract contract UNI_Governance is CalldataComparison, IDAO {
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
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    IToken public uniToken;
    IGovernor public governor;
    ITimelock public timelock;

    /*//////////////////////////////////////////////////////////////////////////
                                GOVERNANCE VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    uint256 public votingDelay;
    uint256 public votingPeriod;
    uint256 public proposalThresholdValue;
    uint256 public quorumVotesValue;

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

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        _selectFork();

        // Governance parameters
        votingDelay = 13_140; // 43 hours and 48 minutes
        votingPeriod = 40_320; // 5 days and 14 hours and 24 minutes
        proposalThresholdValue = 1_000_000_000_000_000_000_000_000; // 1,000,000 UNI
        quorumVotesValue = 40_000_000_000_000_000_000_000_000; // 40,000,000 UNI

        // Governance contracts
        uniToken = IToken(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
        governor = IGovernor(0x408ED6354d4973f66138C91495F2f2FCbd8724C3);
        timelock = ITimelock(payable(0x1a9C8182C09F50C8318d769245beA52c32BE35BC));

        proposer = _proposer();
        voters = _voters();

        // Label contracts for better debugging
        vm.label(address(uniToken), "uniToken");
        vm.label(address(governor), "governor");
        vm.label(address(timelock), "timelock");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  TEST FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    // Executing each step necessary on the proposal lifecycle
    function test_proposal() public {
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);

        // Validate if voters achieve quorum
        uint256 totalVotes = 0;
        for (uint256 i = 0; i < voters.length; i++) {
            totalVotes += uniToken.getCurrentVotes(voters[i]);
        }
        assertGt(totalVotes, governor.quorumVotes(), "Voters do not achieve quorum");

        // Validate if proposer has enough votes to submit a proposal
        assertGe(
            uniToken.getPriorVotes(proposer, block.number - 1),
            governor.proposalThreshold(),
            "Proposer does not have enough votes"
        );

        // Generate call data
        (targets, values, signatures, calldatas, description) = _generateCallData();

        // Store parameters to be validated after execution
        _beforeProposal();

        if (!_isProposalSubmitted()) {
            // Proposal does not exist onchain, so we need to propose it
            vm.prank(proposer);
            proposalId = governor.propose(targets, values, signatures, calldatas, description);
            assertEq(
                IGovernor.ProposalState.unwrap(governor.state(proposalId)),
                uint8(ProposalState.Pending),
                "Proposal should be Pending"
            );
        }

        // Make proposal ready to vote
        uint256 blocksToWait = governor.votingDelay() + 1;
        vm.roll(block.number + blocksToWait);
        vm.warp(block.timestamp + blocksToWait * 12);
        assertEq(
            IGovernor.ProposalState.unwrap(governor.state(proposalId)),
            uint8(ProposalState.Active),
            "Proposal should be Active"
        );

        // Delegates vote for the proposal
        for (uint256 i = 0; i < voters.length; i++) {
            vm.prank(voters[i]);
            governor.castVote(proposalId, 1);
        }

        // Let the voting end
        blocksToWait = governor.votingPeriod();
        vm.roll(block.number + blocksToWait);
        vm.warp(block.timestamp + blocksToWait * 12);
        assertEq(
            IGovernor.ProposalState.unwrap(governor.state(proposalId)),
            uint8(ProposalState.Succeeded),
            "Proposal should be Succeeded"
        );

        // Queue the proposal to be executed
        governor.queue(proposalId);
        assertEq(
            IGovernor.ProposalState.unwrap(governor.state(proposalId)),
            uint8(ProposalState.Queued),
            "Proposal should be Queued"
        );

        // Wait the operation in the timelock to be ready
        uint256 timeToWait = timelock.delay() + 1;
        vm.roll(block.number + timeToWait / 12);
        vm.warp(block.timestamp + timeToWait);

        // Execute proposal
        governor.execute(proposalId);
        assertEq(
            IGovernor.ProposalState.unwrap(governor.state(proposalId)),
            uint8(ProposalState.Executed),
            "Proposal should be Executed"
        );

        // Assert parameters modified after execution
        _afterExecution();

        // Compare calldata with JSON if dirPath is set
        string memory _dirPath = dirPath();
        if (bytes(_dirPath).length > 0) {
            string memory jsonPath = string.concat(_dirPath, "/proposalCalldata.json");
            if (vm.isFile(jsonPath)) {
                string memory jsonContent = vm.readFile(jsonPath);
                if (_isProposalSubmitted()) {
                    _compareLiveCalldata(jsonContent, targets, values, calldatas);
                } else {
                    _compareDraftCalldata(jsonContent, targets, values, signatures, calldatas);
                }
            }
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                              VIRTUAL FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function _selectFork() public virtual {
        vm.createSelectFork({ urlOrAlias: "mainnet" });
    }

    function _proposer() public view virtual returns (address) {
        return 0x8E4ED221fa034245F14205f781E0b13C5bd6a42E;
    }

    function _voters() public view virtual returns (address[] memory votersArray) {
        votersArray = new address[](10);
        votersArray[0] = 0x8E4ED221fa034245F14205f781E0b13C5bd6a42E;
        votersArray[1] = 0x53689948444CfD03d2Ad77266b05e61B8Eed3132;
        votersArray[2] = 0xe7925D190aea9279400cD9a005E33CEB9389Cc2b; // jessewldn
        votersArray[3] = 0x1d8F369F05343F5A642a78BD65fF0da136016452;
        votersArray[4] = 0xe02457a1459b6C49469Bf658d4Fe345C636326bF;
        votersArray[5] = 0x88E15721936c6eBA757A27E54e7aE84b1EA34c05;
        votersArray[6] = 0x8962285fAac45a7CBc75380c484523Bb7c32d429; // Consensys
        votersArray[7] = 0xcb70D1b61919daE81f5Ca620F1e5d37B2241e638;
        votersArray[8] = 0x88FB3D509fC49B515BFEb04e23f53ba339563981; // Robert Leshner
        votersArray[9] = 0x683a4F9915D6216f73d6Df50151725036bD26C02; // Gauntlet
    }

    function _beforeProposal() public virtual;

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

    function _afterExecution() public virtual;

    function _isProposalSubmitted() public view virtual returns (bool);

    function dirPath() public virtual returns (string memory) {
        return "";
    }

    /*//////////////////////////////////////////////////////////////////////////
                    DRAFT CALLDATA COMPARISON (with signatures)
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Compare draft calldata including signatures (Uniswap Governor Alpha format)
    function _compareDraftCalldata(
        string memory jsonContent,
        address[] memory generatedTargets,
        uint256[] memory generatedValues,
        string[] memory generatedSignatures,
        bytes[] memory generatedCalldatas
    ) internal {
        address[] memory jsonTargets = _parseJsonTargets(jsonContent);
        string[] memory jsonValues = _parseJsonValues(jsonContent);
        string[] memory jsonSignatures = _parseJsonSignatures(jsonContent);
        bytes[] memory jsonCalldatas = _parseJsonCalldatas(jsonContent);

        console2.log("JSON parsed successfully with", jsonTargets.length, "operations");

        assertEq(jsonTargets.length, generatedTargets.length, "Number of executable calls mismatch");

        for (uint256 i = 0; i < jsonTargets.length; i++) {
            assertEq(
                jsonTargets[i],
                generatedTargets[i],
                string(abi.encodePacked("Target mismatch at index ", vm.toString(i)))
            );
            assertEq(
                vm.parseUint(jsonValues[i]),
                generatedValues[i],
                string(abi.encodePacked("Value mismatch at index ", vm.toString(i)))
            );
            assertEq(
                keccak256(bytes(jsonSignatures[i])),
                keccak256(bytes(generatedSignatures[i])),
                string(abi.encodePacked("Signature mismatch at index ", vm.toString(i)))
            );
            assertEq(
                jsonCalldatas[i],
                generatedCalldatas[i],
                string(abi.encodePacked("Calldata mismatch at index ", vm.toString(i)))
            );
        }

        assertEq(jsonTargets.length, jsonValues.length, "Targets and values arrays length mismatch");
        assertEq(jsonTargets.length, jsonCalldatas.length, "Targets and calldata arrays length mismatch");
        assertEq(jsonTargets.length, jsonSignatures.length, "Targets and signatures arrays length mismatch");
    }

    /*//////////////////////////////////////////////////////////////////////////
                    SIGNATURE PARSING (Uniswap-specific, not in CalldataComparison)
    //////////////////////////////////////////////////////////////////////////*/

    function _decodeSignaturesArray(string memory j) public pure returns (string[] memory) {
        return abi.decode(vm.parseJson(j, ".executableCalls[*].signature"), (string[]));
    }

    function _decodeSignatureSingle(string memory j) public pure returns (string memory) {
        return abi.decode(vm.parseJson(j, ".executableCalls[*].signature"), (string));
    }

    function _parseJsonSignatures(string memory j) internal returns (string[] memory result) {
        (bool ok, bytes memory ret) = address(this).call(
            abi.encodeWithSelector(this._decodeSignaturesArray.selector, j)
        );
        if (ok) return abi.decode(ret, (string[]));

        (bool ok2, bytes memory ret2) = address(this).call(
            abi.encodeWithSelector(this._decodeSignatureSingle.selector, j)
        );
        require(ok2, "JSON signature decode failed");
        result = new string[](1);
        result[0] = abi.decode(ret2, (string));
    }

    /*//////////////////////////////////////////////////////////////////////////
                              MARKDOWN DESCRIPTION
    //////////////////////////////////////////////////////////////////////////*/

    function getDescriptionFromMarkdown() public returns (string memory) {
        return _getDescriptionFromMarkdown(dirPath());
    }
}
