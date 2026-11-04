// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Compound_Governance } from "@compound/compound.t.sol";
import { ICompToken } from "@compound/interfaces/ICompToken.sol";

interface ICompoundCometGovernor {
    function proposalDetails(uint256 proposalId)
        external
        view
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash);
    function state(uint256 proposalId) external view returns (uint8);
    function castVote(uint256 proposalId, uint8 support) external returns (uint256);
    function queue(uint256 proposalId) external;
    function execute(uint256 proposalId) external payable;
}

/// @notice Independent reconstruction of Compound proposal 608 from its on-chain payload and description.
contract Proposal_COMP_608_Test is Compound_Governance {
    ICompoundCometGovernor constant COMPOUND_GOVERNOR =
        ICompoundCometGovernor(0x309a862bbC1A00e45506cB8A802D1ff10004c8C0);

    uint256 constant PROPOSAL_ID = 608;
    uint256 constant CREATION_BLOCK = 26_010_608;
    uint256 constant VOTE_START = 26_023_748;
    uint256 constant VOTE_END = 26_045_391;
    address constant PROPOSER = 0x5b2962121b4334fe563F7062feA975f51313EDE3;
    address constant TEST_VOTER = address(0x608);

    function setUp() public {
        vm.createSelectFork({ blockNumber: CREATION_BLOCK, urlOrAlias: "mainnet" });
    }

    function test_liveProposalExistsOnchain() public view {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas,) =
            COMPOUND_GOVERNOR.proposalDetails(PROPOSAL_ID);
        assertEq(targets.length, 1, "unexpected on-chain call count");
        assertEq(targets[0], PROPOSER, "unexpected on-chain target");
        assertEq(values[0], 0, "unexpected on-chain value");
        assertEq(calldatas[0], bytes(""), "unexpected on-chain calldata");
    }

    function test_fixtureMatchesOnchainProposal() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash) =
            COMPOUND_GOVERNOR.proposalDetails(PROPOSAL_ID);
        string memory json = vm.readFile(string.concat(dirPath(), "/proposalCalldata.json"));
        assertEq(vm.parseJsonUint(json, ".proposalId"), PROPOSAL_ID);
        _compareLiveCalldata(json, targets, values, calldatas);
        assertEq(
            descriptionHash,
            keccak256(bytes(vm.readFile(string.concat(dirPath(), "/proposalDescription.md")))),
            "description does not match on-chain hash"
        );
    }

    function test_manuallyDerivedCalldataMatchesOnchainProposal() public view {
        (address[] memory liveTargets, uint256[] memory liveValues, bytes[] memory liveCalldatas,) =
            COMPOUND_GOVERNOR.proposalDetails(PROPOSAL_ID);
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = _generateCallData();

        assertEq(liveTargets.length, targets.length, "on-chain action count mismatch");
        for (uint256 i; i < targets.length; ++i) {
            assertEq(liveTargets[i], targets[i], "target mismatch");
            assertEq(liveValues[i], values[i], "value mismatch");
            assertEq(liveCalldatas[i], calldatas[i], "calldata mismatch");
        }
    }

    function test_fullLifecycleExecutesNoopAndLeavesTargetUnchanged() public {
        uint256 targetBalanceBefore = _beforeProposal();

        vm.mockCall(
            address(COMP),
            abi.encodeWithSelector(ICompToken.getPriorVotes.selector, TEST_VOTER, VOTE_START),
            abi.encode(uint96(1_000_000 ether))
        );
        vm.roll(VOTE_START + 1);
        vm.prank(TEST_VOTER);
        COMPOUND_GOVERNOR.castVote(PROPOSAL_ID, 1);
        vm.roll(VOTE_END + 1);
        assertEq(COMPOUND_GOVERNOR.state(PROPOSAL_ID), 4, "proposal did not succeed");

        COMPOUND_GOVERNOR.queue(PROPOSAL_ID);
        vm.warp(block.timestamp + TIMELOCK.delay() + 1);
        COMPOUND_GOVERNOR.execute(PROPOSAL_ID);
        assertEq(COMPOUND_GOVERNOR.state(PROPOSAL_ID), 7, "proposal was not executed");

        _afterExecution(targetBalanceBefore);
    }

    function _beforeProposal() internal view returns (uint256 targetBalanceBefore) {
        assertEq(PROPOSER.code.length, 0, "proposal target is not an EOA");
        assertGt(address(TIMELOCK).code.length, 0, "timelock has no code");
        assertEq(COMPOUND_GOVERNOR.state(PROPOSAL_ID), 0, "proposal is not pending at creation block");
        targetBalanceBefore = PROPOSER.balance;
    }

    function _afterExecution(uint256 targetBalanceBefore) internal view {
        assertEq(PROPOSER.code.length, 0, "no-op target changed code");
        assertEq(PROPOSER.balance, targetBalanceBefore, "zero-value no-op changed target balance");
        assertEq(COMPOUND_GOVERNOR.state(PROPOSAL_ID), 7, "proposal execution state mismatch");
    }

    function _generateCallData()
        internal
        pure
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        targets[0] = PROPOSER;
        calldatas[0] = bytes("");
    }

    function dirPath() public pure override returns (string memory) {
        return "src/compound/proposals/608-ultimate-control-institutional-comet";
    }
}
