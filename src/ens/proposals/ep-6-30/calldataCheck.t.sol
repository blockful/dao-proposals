// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "@forge-std/src/console2.sol";

import { ENS_Governance } from "@ens/ens.t.sol";
import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";

/**
 * @title Proposal_ENS_EP_6_30_Test
 * @notice Calldata review for ENS EP 6.28 - ENS Retro: Stakeholder Analysis and Retrospective
 * @dev This proposal transfers 125,000 USDC to Meta-Gov Working Group multisig
 *      to fund the ENS DAO retrospective and stakeholder analysis study.
 */
contract Proposal_ENS_EP_6_30_Test is ENS_Governance {
    // Token contract
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    // Recipient
    address constant metagovMultisig = 0x91c32893216dE3eA0a55ABb9851f581d4503d39b;

    // Expected transfer amount (USDC has 6 decimals)
    uint256 constant expectedUSDCtransfer = 125_000 * 10 ** 6;

    // State tracking
    uint256 USDCmetagovBalanceBefore;

    function _selectFork() public override {
        // Fork at the block when the proposal was created
        // Proposal created: block 24324887 (2026-01-27T08:10:47Z)
        vm.createSelectFork({ blockNumber: 24324887, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0x5BFCB4BE4d7B43437d5A0c57E908c048a4418390; // fireeyesdao.eth
    }

    function _beforeProposal() public override {
        USDCmetagovBalanceBefore = USDC.balanceOf(metagovMultisig);
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

        // Transaction 1: USDC transfer to Meta-Gov WG (125,000 USDC for ENS Retro)
        targets[0] = address(USDC);
        calldatas[0] = abi.encodeWithSelector(
            USDC.transfer.selector,
            metagovMultisig,
            expectedUSDCtransfer
        );
        values[0] = 0;
        signatures[0] = "";

        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        uint256 USDCmetagovBalanceAfter = USDC.balanceOf(metagovMultisig);
        assertEq(
            USDCmetagovBalanceBefore + expectedUSDCtransfer,
            USDCmetagovBalanceAfter,
            "Meta-Gov USDC balance mismatch"
        );
        assertNotEq(USDCmetagovBalanceAfter, USDCmetagovBalanceBefore, "Meta-Gov balance unchanged");
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-6-30";
    }
}
