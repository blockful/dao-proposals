// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "@forge-std/src/console2.sol";

import { ENS_Governance } from "@ens/ens.t.sol";
import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";

/**
 * @title Proposal_ENS_EP_5_23_Test
 * @notice Calldata review for ENS EP 5.23 - blockful's governance security bounty
 * @dev This proposal transfers 100,000 USDC and 15,000 ENS to the Meta-Gov multisig.
 */
contract Proposal_ENS_EP_5_23_Test is ENS_Governance {
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 public constant ENS = IERC20(0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72);

    address constant metagovMultisig = 0x91c32893216dE3eA0a55ABb9851f581d4503d39b;

    uint256 constant expectedUSDCtransfer = 100_000 * 10 ** 6;
    uint256 constant expectedENStransfer = 15_000 * 10 ** 18;

    uint256 USDCbalanceBefore;
    uint256 ENSbalanceBefore;


    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 21_089_400, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0x76A6D08b82034b397E7e09dAe4377C18F132BbB8;
    }

    function _beforeProposal() public override {
        USDCbalanceBefore = USDC.balanceOf(address(timelock));
        ENSbalanceBefore = ENS.balanceOf(address(timelock));
    }

    function _generateCallData()
        public
        override
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory, string memory)
    {
        uint256 numTransactions = 2;

        targets = new address[](numTransactions);
        values = new uint256[](numTransactions);
        calldatas = new bytes[](numTransactions);
        signatures = new string[](numTransactions);

        // Transaction 1: Transfer USDC to Meta-Gov multisig
        targets[0] = address(USDC);
        calldatas[0] = abi.encodeWithSelector(USDC.transfer.selector, metagovMultisig, expectedUSDCtransfer);
        values[0] = 0;
        signatures[0] = "";

        // Transaction 2: Transfer ENS to Meta-Gov multisig
        targets[1] = address(ENS);
        calldatas[1] = abi.encodeWithSelector(ENS.transfer.selector, metagovMultisig, expectedENStransfer);
        values[1] = 0;
        signatures[1] = "";

        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        uint256 USDCbalanceAfter = USDC.balanceOf(address(timelock));
        assertEq(USDCbalanceBefore, USDCbalanceAfter + expectedUSDCtransfer);
        assertNotEq(USDCbalanceAfter, USDCbalanceBefore);

        uint256 ENSbalanceAfter = ENS.balanceOf(address(timelock));
        assertEq(ENSbalanceBefore, ENSbalanceAfter + expectedENStransfer);
        assertNotEq(ENSbalanceAfter, ENSbalanceBefore);
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-5-23";
    }
}
