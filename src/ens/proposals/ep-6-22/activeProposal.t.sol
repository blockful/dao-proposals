// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "@forge-std/src/console2.sol";

import { ENS_Governance } from "@ens/ens.t.sol";
import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";

contract Proposal_ENS_EP_6_22_Test is ENS_Governance {
    // Contract addresses
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 public constant ENS = IERC20(0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72);

    address receiver = 0x8Bf6F9F91D70a9a3c2FCe45dF30EcE735C54D624;

    uint256 USDCbalanceBefore;
    uint256 expectedUSDCtransfer = 75_000 * 10 ** 6;
    uint256 USDCbalanceAfter;

    uint256 ENSbalanceBefore;
    uint256 expectedENStransfer = 10_000 * 10 ** 18;
    uint256 ENSbalanceAfter;

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 23627726, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0x5BFCB4BE4d7B43437d5A0c57E908c048a4418390; // slobo.eth
    }

    function _beforeProposal() public override {
        USDCbalanceBefore = USDC.balanceOf(address(timelock));
        ENSbalanceBefore = ENS.balanceOf(address(timelock));
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
        uint256 numTransactions = 2;

        targets = new address[](numTransactions);
        values = new uint256[](numTransactions);
        calldatas = new bytes[](numTransactions);
        signatures = new string[](numTransactions);

        targets[0] = address(ENS);
        calldatas[0] = abi.encodeWithSelector(
            ENS.transfer.selector,
            receiver,
            expectedENStransfer
        );
        values[0] = 0;
        signatures[0] = "";

        targets[1] = address(USDC);
        calldatas[1] = abi.encodeWithSelector(
            USDC.transfer.selector,
            receiver,
            expectedUSDCtransfer
        );
        values[1] = 0;
        signatures[1] = "";
        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        USDCbalanceAfter = USDC.balanceOf(address(timelock));
        assertEq(USDCbalanceBefore, USDCbalanceAfter + expectedUSDCtransfer);
        assertNotEq(USDCbalanceAfter, USDCbalanceBefore);

        ENSbalanceAfter = ENS.balanceOf(address(timelock));
        assertEq(ENSbalanceBefore, ENSbalanceAfter + expectedENStransfer);
        assertNotEq(ENSbalanceAfter, ENSbalanceBefore);
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-6-22";
    }
}
