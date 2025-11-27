// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "@forge-std/src/console2.sol";

import { ENS_Governance } from "@ens/ens.t.sol";
import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";

contract Proposal_ENS_EP_6_25_Test is ENS_Governance {
    // Contract addresses
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    address pgMultisig = 0xcD42b4c4D102cc22864e3A1341Bb0529c17fD87d;
    address ecosystemMultisig = 0x2686A8919Df194aA7673244549E68D42C1685d03;
    address metagovMultisig = 0x91c32893216dE3eA0a55ABb9851f581d4503d39b;

    uint256 USDCmetagovBalanceBefore;
    uint256 USDCecosystemBalanceBefore;
    uint256 USDCpgBalanceBefore;
    uint256 ETHpgBalanceBefore;

    uint256 USDCmetagovBalanceAfter;
    uint256 USDCecosystemBalanceAfter;
    uint256 USDCpgBalanceAfter;
    uint256 ETHpgBalanceAfter;

    uint256 metagovExpectedUSDCtransfer = 379_000 * 10 ** 6;
    uint256 ecosystemExpectedUSDCtransfer = 470_000 * 10 ** 6;
    uint256 pgExpectedUSDCtransfer = 110_000 * 10 ** 6;
    uint256 pgExpectedETHtransfer = 15 ether;

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 23627726, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0x5BFCB4BE4d7B43437d5A0c57E908c048a4418390;
    }

    function _beforeProposal() public override {
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

        // USDC transfer to Metagov
        targets[0] = address(USDC);
        calldatas[0] = abi.encodeWithSelector(
            USDC.transfer.selector,
            metagovMultisig,
            metagovExpectedUSDCtransfer
        );
        values[0] = 0;
        signatures[0] = "";

        // USDC transfer to Ecosystem
        targets[1] = address(USDC);
        calldatas[1] = abi.encodeWithSelector(
            USDC.transfer.selector,
            ecosystemMultisig,
            ecosystemExpectedUSDCtransfer
        );
        values[1] = 0;
        signatures[1] = "";

        // USDC transfer to PG
        targets[2] = address(USDC);
        calldatas[2] = abi.encodeWithSelector(
            USDC.transfer.selector,
            pgMultisig,
            pgExpectedUSDCtransfer
        );
        values[2] = 0;
        signatures[2] = "";

        // ETH transfer to PG
        targets[3] = address(payable(pgMultisig));
        calldatas[3] = hex"";
        values[3] = pgExpectedETHtransfer;
        signatures[3] = "";

        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        USDCmetagovBalanceAfter = USDC.balanceOf(metagovMultisig);
        assertEq(USDCmetagovBalanceBefore + metagovExpectedUSDCtransfer, USDCmetagovBalanceAfter);
        assertNotEq(USDCmetagovBalanceAfter, USDCmetagovBalanceBefore);

        USDCecosystemBalanceAfter = USDC.balanceOf(ecosystemMultisig);
        assertEq(USDCecosystemBalanceBefore + ecosystemExpectedUSDCtransfer, USDCecosystemBalanceAfter);
        assertNotEq(USDCecosystemBalanceAfter, USDCecosystemBalanceBefore);

        USDCpgBalanceAfter = USDC.balanceOf(pgMultisig);
        assertEq(USDCpgBalanceBefore + pgExpectedUSDCtransfer, USDCpgBalanceAfter);
        assertNotEq(USDCpgBalanceAfter, USDCpgBalanceBefore);
       
        ETHpgBalanceAfter = address(pgMultisig).balance;
        assertEq(ETHpgBalanceBefore + pgExpectedETHtransfer, ETHpgBalanceAfter);
        assertNotEq(ETHpgBalanceAfter, ETHpgBalanceBefore);
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return false;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-6-25";
    }
}
