// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "@forge-std/src/console2.sol";

import { ENS_Governance } from "@ens/ens.t.sol";
import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";

contract ProposalENS_EP_6_20_Test is ENS_Governance {
    // Contract addresses
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    uint256 USDCbalanceBefore;
    uint256 expectedUSDCtransfer = 109_818_820_000;
    uint256 USDCbalanceAfter;

    address receiver = 0xB352bB4E2A4f27683435f153A259f1B207218b1b;

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 23442264, urlOrAlias: "mainnet" });
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

        targets[0] = address(USDC);
        calldatas[0] = abi.encodeWithSelector(
            USDC.transfer.selector,
            receiver,
            expectedUSDCtransfer
        );
        values[0] = 0;
        signatures[0] = "";

        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        USDCbalanceAfter = USDC.balanceOf(address(timelock));
        assertEq(USDCbalanceBefore, USDCbalanceAfter + expectedUSDCtransfer);
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-6-20";
    }
}
