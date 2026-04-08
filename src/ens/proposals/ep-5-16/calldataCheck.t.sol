// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "@forge-std/src/console2.sol";

import { ENS_Governance } from "@ens/ens.t.sol";
import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";

/**
 * @title Proposal_ENS_EP_5_16_Test
 * @notice Calldata review for ENS EP 5.16 - Reimbursement of ENS Labs' legal fees in eth.link litigation
 * @dev This proposal transfers 1,218,669.76 USDC to ENS Labs.
 */
contract Proposal_ENS_EP_5_16_Test is ENS_Governance {
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    address constant ensLabs = 0x690F0581eCecCf8389c223170778cD9D029606F2;
    uint256 constant expectedUSDCtransfer = 1_218_669_760_000;

    uint256 USDCbalanceBefore;

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 20_828_677, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0xb8c2C29ee19D8307cb7255e1Cd9CbDE883A267d5; // nick.eth
    }

    function _beforeProposal() public override {
        USDCbalanceBefore = USDC.balanceOf(address(timelock));
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

        // Transaction 1: Transfer USDC to ENS Labs for legal fee reimbursement
        targets[0] = address(USDC);
        calldatas[0] = abi.encodeWithSelector(USDC.transfer.selector, ensLabs, expectedUSDCtransfer);
        values[0] = 0;
        signatures[0] = "";

        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        uint256 USDCbalanceAfter = USDC.balanceOf(address(timelock));
        assertEq(USDCbalanceBefore, USDCbalanceAfter + expectedUSDCtransfer);
        assertNotEq(USDCbalanceAfter, USDCbalanceBefore);
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-5-16";
    }
}
