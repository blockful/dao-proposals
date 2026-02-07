// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "@forge-std/src/console2.sol";

import { ENS_Governance } from "@ens/ens.t.sol";
import { SafeHelper } from "@ens/helpers/SafeHelper.sol";
import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";

/**
 * @title Proposal_ENS_EP_6_32_Test
 * @notice Calldata review for ENS EP 6.32 - Transfer $2.5M USDC from Endowment to wallet.ensdao.eth
 * @dev This proposal executes a Safe execTransaction on the ENS Endowment Safe to transfer
 *      2,500,000 USDC to wallet.ensdao.eth (ENS Timelock) to enable execution of previously
 *      approved working group funding (Collective Working Group Funding Request Oct 2025).
 *
 *      The calldata encodes:
 *        - Safe.execTransaction() on the Endowment Safe (0x4F2083...64)
 *        - Inner call: USDC.transfer(wallet.ensdao.eth, 2_500_000e6)
 *        - Pre-approved signature from the Timelock (owner of the Safe)
 */
contract Proposal_ENS_EP_6_32_Test is ENS_Governance, SafeHelper {
    // Contracts
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    // Transfer amount: 2,500,000 USDC (6 decimals)
    uint256 constant expectedUSDCTransfer = 2_500_000 * 10 ** 6;

    // State tracking
    uint256 endowmentUSDCBalanceBefore;
    uint256 walletUSDCBalanceBefore;

    function _selectFork() public override {
        // Fork at the block when the proposal was created
        // Proposal created: block 24405279 (2026-02-07T13:35:35Z)
        // Voting start: block 24405280
        // Voting end: block 24451098
        vm.createSelectFork({ blockNumber: 24_405_279, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0x1D5460F896521aD685Ea4c3F2c679Ec0b6806359; // coltron.eth
    }

    function _beforeProposal() public override {
        // Capture USDC balances before execution
        endowmentUSDCBalanceBefore = USDC.balanceOf(address(endowmentSafe));
        walletUSDCBalanceBefore = USDC.balanceOf(address(timelock));
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

        // Inner call: USDC.transfer(timelock, 2_500_000e6)
        bytes memory innerCalldata = abi.encodeWithSelector(
            USDC.transfer.selector,
            address(timelock),
            expectedUSDCTransfer
        );

        // 1. Call execTransaction on the Endowment Safe to transfer USDC
        (targets[0], calldatas[0]) = _buildSafeExecCalldata(
            address(endowmentSafe),
            address(USDC),
            innerCalldata,
            address(timelock)
        );
        values[0] = 0;
        signatures[0] = "";

        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        // Verify Endowment Safe USDC balance decreased
        uint256 endowmentUSDCBalanceAfter = USDC.balanceOf(address(endowmentSafe));
        assertEq(
            endowmentUSDCBalanceBefore - expectedUSDCTransfer,
            endowmentUSDCBalanceAfter,
            "Endowment USDC balance should decrease by 2.5M"
        );

        // Verify wallet.ensdao.eth (timelock) USDC balance increased
        uint256 walletUSDCBalanceAfter = USDC.balanceOf(address(timelock));
        assertEq(
            walletUSDCBalanceBefore + expectedUSDCTransfer,
            walletUSDCBalanceAfter,
            "wallet.ensdao.eth USDC balance should increase by 2.5M"
        );

        // Sanity check: balances actually changed
        assertNotEq(endowmentUSDCBalanceAfter, endowmentUSDCBalanceBefore, "Endowment balance unchanged");
        assertNotEq(walletUSDCBalanceAfter, walletUSDCBalanceBefore, "Wallet balance unchanged");

        // Log final state
        console2.log("Endowment USDC before:", endowmentUSDCBalanceBefore);
        console2.log("Endowment USDC after:", endowmentUSDCBalanceAfter);
        console2.log("wallet.ensdao.eth USDC before:", walletUSDCBalanceBefore);
        console2.log("wallet.ensdao.eth USDC after:", walletUSDCBalanceAfter);
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true; // Live proposal
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-6-32";
    }
}
