// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "@forge-std/src/console2.sol";

import { ENS_Governance } from "@ens/ens.t.sol";
import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";

/**
 * @title Proposal_ENS_EP_6_29_Test
 * @notice Calldata review for ENS EP 6.24 - Collective Working Group Funding (Oct 2025)
 * @dev This proposal executes three Working Group funding requests:
 *      - EP 6.24.1: Meta-Governance WG - 379,000 USDC
 *      - EP 6.24.2: Ecosystem WG - 470,000 USDC
 *      - EP 6.24.3: Public Goods WG - 110,000 USDC + 15 ETH
 */
contract Proposal_ENS_EP_6_29_Test is ENS_Governance {
    // Token contract
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    // Recipient multisig addresses
    address constant metagovMultisig = 0x91c32893216dE3eA0a55ABb9851f581d4503d39b;
    address constant ecosystemMultisig = 0x2686A8919Df194aA7673244549E68D42C1685d03;
    address constant pgMultisig = 0xcD42b4c4D102cc22864e3A1341Bb0529c17fD87d;

    // Expected transfer amounts (USDC has 6 decimals)
    uint256 constant metagovExpectedUSDCtransfer = 379_000 * 10 ** 6;
    uint256 constant ecosystemExpectedUSDCtransfer = 470_000 * 10 ** 6;
    uint256 constant pgExpectedUSDCtransfer = 110_000 * 10 ** 6;
    uint256 constant pgExpectedETHtransfer = 15 ether;

    // State tracking for assertions
    uint256 USDCmetagovBalanceBefore;
    uint256 USDCecosystemBalanceBefore;
    uint256 USDCpgBalanceBefore;
    uint256 ETHpgBalanceBefore;

    function _selectFork() public override {
        // Fork at the block when the proposal was created
        // Proposal created: block 24293146 (2026-01-22T21:55:11Z)
        // Voting start: block 24293147
        // Voting end: block 24338965
        vm.createSelectFork({ blockNumber: 24293146, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        // Proposer address - update if different
        return 0x5BFCB4BE4d7B43437d5A0c57E908c048a4418390; // fireeyesdao.eth
    }

    function _beforeProposal() public override {
        // Capture balances before execution
        USDCmetagovBalanceBefore = USDC.balanceOf(metagovMultisig);
        USDCecosystemBalanceBefore = USDC.balanceOf(ecosystemMultisig);
        USDCpgBalanceBefore = USDC.balanceOf(pgMultisig);
        ETHpgBalanceBefore = address(pgMultisig).balance;
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
        uint256 numTransactions = 4;

        targets = new address[](numTransactions);
        values = new uint256[](numTransactions);
        calldatas = new bytes[](numTransactions);
        signatures = new string[](numTransactions);

        // Transaction 1: USDC transfer to Meta-Governance WG (379,000 USDC)
        targets[0] = address(USDC);
        calldatas[0] = abi.encodeWithSelector(
            USDC.transfer.selector,
            metagovMultisig,
            metagovExpectedUSDCtransfer
        );
        values[0] = 0;
        signatures[0] = "";

        // Transaction 2: USDC transfer to Ecosystem WG (470,000 USDC)
        targets[1] = address(USDC);
        calldatas[1] = abi.encodeWithSelector(
            USDC.transfer.selector,
            ecosystemMultisig,
            ecosystemExpectedUSDCtransfer
        );
        values[1] = 0;
        signatures[1] = "";

        // Transaction 3: USDC transfer to Public Goods WG (110,000 USDC)
        targets[2] = address(USDC);
        calldatas[2] = abi.encodeWithSelector(
            USDC.transfer.selector,
            pgMultisig,
            pgExpectedUSDCtransfer
        );
        values[2] = 0;
        signatures[2] = "";

        // Transaction 4: ETH transfer to Public Goods WG (15 ETH)
        targets[3] = pgMultisig;
        calldatas[3] = hex"";
        values[3] = pgExpectedETHtransfer;
        signatures[3] = "";

        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        // Verify Meta-Gov received USDC
        uint256 USDCmetagovBalanceAfter = USDC.balanceOf(metagovMultisig);
        assertEq(
            USDCmetagovBalanceBefore + metagovExpectedUSDCtransfer,
            USDCmetagovBalanceAfter,
            "Meta-Gov USDC balance mismatch"
        );
        assertNotEq(USDCmetagovBalanceAfter, USDCmetagovBalanceBefore, "Meta-Gov balance unchanged");

        // Verify Ecosystem received USDC
        uint256 USDCecosystemBalanceAfter = USDC.balanceOf(ecosystemMultisig);
        assertEq(
            USDCecosystemBalanceBefore + ecosystemExpectedUSDCtransfer,
            USDCecosystemBalanceAfter,
            "Ecosystem USDC balance mismatch"
        );
        assertNotEq(USDCecosystemBalanceAfter, USDCecosystemBalanceBefore, "Ecosystem balance unchanged");

        // Verify Public Goods received USDC
        uint256 USDCpgBalanceAfter = USDC.balanceOf(pgMultisig);
        assertEq(
            USDCpgBalanceBefore + pgExpectedUSDCtransfer,
            USDCpgBalanceAfter,
            "Public Goods USDC balance mismatch"
        );
        assertNotEq(USDCpgBalanceAfter, USDCpgBalanceBefore, "Public Goods USDC balance unchanged");

        // Verify Public Goods received ETH
        uint256 ETHpgBalanceAfter = address(pgMultisig).balance;
        assertEq(
            ETHpgBalanceBefore + pgExpectedETHtransfer,
            ETHpgBalanceAfter,
            "Public Goods ETH balance mismatch"
        );
        assertNotEq(ETHpgBalanceAfter, ETHpgBalanceBefore, "Public Goods ETH balance unchanged");
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        // Proposal is live on-chain
        return true;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-6-29";
    }
}
