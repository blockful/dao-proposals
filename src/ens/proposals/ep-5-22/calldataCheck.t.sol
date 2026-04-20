// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "@forge-std/src/console2.sol";

import { ENS_Governance } from "@ens/ens.t.sol";
import { ITokenStreamingEP5_22 } from "@ens/interfaces/ITokenStreamingEP5-22.sol";
import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";

/**
 * @title Proposal_ENS_EP_5_22_Test
 * @notice Calldata review for ENS EP 5.22 - ENSv2 Development Funding
 * @dev This proposal approves unlimited USDC spending for the streaming contract
 *      to fund ENSv2 development via a daily stream of 15,075.33 USDC to ENS Labs.
 */
contract Proposal_ENS_EP_5_22_Test is ENS_Governance {
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    ITokenStreamingEP5_22 streamingContract = ITokenStreamingEP5_22(0x05C8f60e24FcDd9B8Ed7bB85dF8164C41cB4DA16);
    address streamingContractAdmin = 0xb8c2C29ee19D8307cb7255e1Cd9CbDE883A267d5; // nick.eth
    address receiver = 0x690F0581eCecCf8389c223170778cD9D029606F2; // ENS Labs

    uint256 expectedUSDCtransfer = 15_075_331_200;

    uint256 timelockUSDCbalanceBefore;

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 21_086_802, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0xE3919F3f971C4589089DaA930aaFa81B8A27b406;
    }

    function _beforeProposal() public override {
        timelockUSDCbalanceBefore = USDC.balanceOf(address(timelock));
    }

    function _generateCallData()
        public
        override
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory, string memory)
    {
        uint256 numTransactions = 1;

        targets = new address[](numTransactions);
        values = new uint256[](numTransactions);
        calldatas = new bytes[](numTransactions);
        signatures = new string[](numTransactions);

        // Transaction 1: Approve streaming contract to spend unlimited USDC from treasury
        targets[0] = address(USDC);
        calldatas[0] = abi.encodeWithSelector(USDC.approve.selector, address(streamingContract), type(uint256).max);
        values[0] = 0;
        signatures[0] = "";

        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        console2.log("Claimable balance", streamingContract.claimableBalance());
        console2.log("Total claimed", streamingContract.totalClaimed());

        vm.warp(streamingContract.startTime() + 1 days);
        console2.log("Claimable balance before claim", streamingContract.claimableBalance());

        vm.startPrank(streamingContractAdmin);
        streamingContract.claim(receiver, streamingContract.claimableBalance());
        vm.stopPrank();

        console2.log("Claimable balance after claim", streamingContract.claimableBalance());
        console2.log("Total claimed", streamingContract.totalClaimed());

        uint256 timelockUSDCbalanceAfter = USDC.balanceOf(address(timelock));
        assertEq(timelockUSDCbalanceBefore, timelockUSDCbalanceAfter + expectedUSDCtransfer);
        assertNotEq(timelockUSDCbalanceAfter, timelockUSDCbalanceBefore);
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-5-22";
    }
}
