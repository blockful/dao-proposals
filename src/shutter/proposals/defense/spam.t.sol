// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";
import { console2 } from "@forge-std/src/console2.sol";

import { Shutter_Governance } from "@shutter/shutter.t.sol";
import { ILinearERC20Voting } from "@shutter/interfaces/ILinearERC20Voting.sol";
import { IShutterToken } from "@shutter/interfaces/IShutterToken.sol";
import { IAzorius } from "@shutter/interfaces/IAzorius.sol";
import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";

contract Proposal_Shutter_Defense_Test is Shutter_Governance {
    uint256 public proposalCount;
    // Spammer address that will attempt to create spam proposals
    address public spammer = makeAddr("spammer");

    
    // Amount of SHU tokens to give to spammer (1 SHU token)
    uint256 public spammerTokenAmount = 1e18; // 1 SHU token

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 23_043_292, urlOrAlias: "mainnet" });
    }

    function _proposer() public view override returns (address) {
        return spammer;
    }

    function _beforeProposal() public override {
        deal(address(governanceToken), spammer, spammerTokenAmount);

        vm.startPrank(spammer);
        governanceToken.delegate(spammer); 
        vm.stopPrank();

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);

        assertEq(_getProposalThreshold(), governanceToken.balanceOf(spammer), "Spammer should have enough voting power to submit proposals");

        proposalCount = azorius.totalProposalCount();
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

        _createSpamProposals();

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        assertEq(azorius.totalProposalCount(), proposalCount + 11, "Proposal count should be incremented by 1");
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return false;
    }
    
    /**
     * @dev Attempts to create 10 empty spam proposals
     */
    function _createSpamProposals() internal {
        console2.log("Attempting to create 10 empty spam proposals...");
        
        uint32 initialProposalCount = azorius.totalProposalCount();
        console2.log("Initial proposal count:", initialProposalCount);
        
        // Create empty transactions array for spam proposals
        IAzorius.Transaction[] memory emptyTransactions = new IAzorius.Transaction[](0);
        
        uint256 successfulSpamProposals = 0;
        
        // Attempt to create 10 spam proposals
        for (uint256 i = 0; i < 10; i++) {
            string memory spamDescription = string(abi.encodePacked("Spam Proposal #", _toString(i + 1)));
            
            vm.startPrank(spammer);
            
            try azorius.submitProposal(
                address(linearERC20VotingStrategy),
                bytes(""),
                emptyTransactions,
                spamDescription
            ) {
                successfulSpamProposals++;
                console2.log("Successfully created spam proposal #", i + 1);
            } catch Error(string memory reason) {
                console2.log("Failed to create spam proposal #", i + 1, "- Reason:", reason);
            } catch {
                console2.log("Failed to create spam proposal #", i + 1, "- Unknown error");
            }
            
            vm.stopPrank();
        }
        
        uint32 finalProposalCount = azorius.totalProposalCount();
        console2.log("Final proposal count:", finalProposalCount);
        console2.log("Successfully created spam proposals:", successfulSpamProposals);
        console2.log("Failed spam proposal attempts:", 10 - successfulSpamProposals);
        
        // TODO: Add assertions based on expected behavior
        // If spam protection works, successfulSpamProposals should be 0
        // If not, it shows vulnerability that needs to be addressed
    }
    
    /**
     * @dev Helper function to convert uint to string
     */
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        
        return string(buffer);
    }
}

anvil --fork-url http://localhost:8545 \
      --fork-block-number 23043292 \
      --port 8546 \
      --accounts 10 \
      --balance 1000
