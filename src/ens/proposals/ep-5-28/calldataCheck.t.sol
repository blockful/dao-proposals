// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "@forge-std/src/console2.sol";

import { ENS_Governance } from "@ens/ens.t.sol";
import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";

/**
 * @title Proposal_ENS_EP_5_28_Test
 * @notice Calldata review for ENS EP 5.28 - Reimbursement of eth.limo's ongoing legal fees
 * @dev This proposal transfers 240,632.38 USDC to eth.limo (ethdotlimo.eth) to reimburse
 *      legal fees related to operating eth.limo/eth.link gateway services.
 */
contract Proposal_ENS_EP_5_28_Test is ENS_Governance {
    // Token contract
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    // Recipient: ethdotlimo.eth
    address constant receiver = 0xB352bB4E2A4f27683435f153A259f1B207218b1b;

    // Expected transfer amount (USDC has 6 decimals): $240,632.38
    uint256 constant expectedUSDCtransfer = 240_632_380_000;

    // State tracking
    uint256 USDCbalanceBefore;


    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 21_424_433, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0x983110309620D911731Ac0932219af06091b6744; // brantly.eth
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

        // Transaction 1: Transfer USDC to ethdotlimo.eth for legal fee reimbursement
        targets[0] = address(USDC);
        calldatas[0] = abi.encodeWithSelector(USDC.transfer.selector, receiver, expectedUSDCtransfer);
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
        return "src/ens/proposals/ep-5-28";
    }
}
