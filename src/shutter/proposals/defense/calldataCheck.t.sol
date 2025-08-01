// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";
import { console2 } from "@forge-std/src/console2.sol";

import { Shutter_Governance } from "@shutter/shutter.t.sol";
import { ILinearERC20Voting } from "@shutter/interfaces/ILinearERC20Voting.sol";

contract Proposal_Shutter_Defense_Test is Shutter_Governance {
    uint32 newVotingPeriod = 41600;
    uint32 oldVotingPeriod;

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 23_043_292, urlOrAlias: "mainnet" });
    }

    function _proposer() public view override returns (address) {
        return _voters()[0];
    }

    function _beforeProposal() public override {
        oldVotingPeriod = linearERC20VotingStrategy.votingPeriod();
        assertEq(oldVotingPeriod, 21600, "Voting period should be 21600");
    }

    function _generateCallData()
        public
        override
        returns (
            address[] memory,
            uint256[] memory,
            string[] memory,
            bytes[] memory,
            string memory
        )
    {
        uint256 numTransactions = 1;

        targets = new address[](numTransactions);
        values = new uint256[](numTransactions);
        calldatas = new bytes[](numTransactions);
        signatures = new string[](numTransactions);

        // 1. update voting period to 21,600 blocks (~3 days)
        uint32 newVotingPeriod = 41600;
        targets[0] = address(linearERC20VotingStrategy);
        calldatas[0] = abi.encodeWithSelector(ILinearERC20Voting.updateVotingPeriod.selector, newVotingPeriod);
        values[0] = 0;
        signatures[0] = "";

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        // Verify the voting period was updated correctly
        uint32 currentVotingPeriod = linearERC20VotingStrategy.votingPeriod();
        assertEq(currentVotingPeriod, newVotingPeriod, "Voting period should be updated to 21,600 blocks");
        assertNotEq(oldVotingPeriod, newVotingPeriod, "Voting period should be updated");
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return false;
    }
}
