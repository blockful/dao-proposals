// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "@forge-std/src/console2.sol";

import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";
import { ENS_Governance } from "@ens/ens.t.sol";

/**
 * @title Proposal_ENS_EP_6_11_Test
 * @notice Calldata review for ENS EP 6.11 - Collective Working Group Funding Request (April 2025)
 * @dev This proposal transfers:
 *      1. 589,000 USDC to Meta-Gov WG multisig
 *      2. 100,000 ENS to Meta-Gov WG multisig
 *      3. 356,000 USDC to Public Goods WG multisig
 */
contract Proposal_ENS_EP_6_11_Test is ENS_Governance {
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    address constant metagovMultisig = 0x91c32893216dE3eA0a55ABb9851f581d4503d39b;
    address constant publicGoodsMultisig = 0xcD42b4c4D102cc22864e3A1341Bb0529c17fD87d;

    uint256 constant expectedUSDCtransfer = (589_000 + 356_000) * 10 ** 6;
    uint256 constant expectedENStransfer = 100_000 ether;

    uint256 USDCbalanceBefore;
    uint256 ENSbalanceBefore;

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 22_532_129, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0xe52C39327FF7576bAEc3DBFeF0787bd62dB6d726; // 5pence.eth
    }

    function _beforeProposal() public override {
        USDCbalanceBefore = USDC.balanceOf(address(timelock));
        ENSbalanceBefore = ensToken.balanceOf(address(timelock));
    }

    function _generateCallData()
        public
        override
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory, string memory)
    {
        uint256 numTransactions = 3;

        targets = new address[](numTransactions);
        values = new uint256[](numTransactions);
        calldatas = new bytes[](numTransactions);
        signatures = new string[](numTransactions);

        // Transaction 1: Transfer 589,000 USDC to Meta-Gov multisig
        targets[0] = address(USDC);
        calldatas[0] = abi.encodeWithSelector(IERC20.transfer.selector, metagovMultisig, 589_000 * 10 ** 6);
        values[0] = 0;
        signatures[0] = "";

        // Transaction 2: Transfer 100,000 ENS to Meta-Gov multisig
        targets[1] = address(ensToken);
        calldatas[1] = abi.encodeWithSelector(IERC20.transfer.selector, metagovMultisig, expectedENStransfer);
        values[1] = 0;
        signatures[1] = "";

        // Transaction 3: Transfer 356,000 USDC to Public Goods multisig
        targets[2] = address(USDC);
        calldatas[2] = abi.encodeWithSelector(IERC20.transfer.selector, publicGoodsMultisig, 356_000 * 10 ** 6);
        values[2] = 0;
        signatures[2] = "";

        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public view override {
        uint256 USDCbalanceAfter = USDC.balanceOf(address(timelock));
        assertEq(USDCbalanceAfter, USDCbalanceBefore - expectedUSDCtransfer);

        uint256 ENSbalanceAfter = ensToken.balanceOf(address(timelock));
        assertEq(ENSbalanceAfter, ENSbalanceBefore - expectedENStransfer);
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-6-11";
    }
}
