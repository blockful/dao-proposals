// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "@forge-std/src/console2.sol";

import { ENS_Governance } from "@ens/ens.t.sol";

interface IWithdraw {
    function withdraw() external;
}

/**
 * @title Proposal_ENS_EP_6_1_Test
 * @notice Calldata review for ENS EP 6.1 - Convert 6,000 ETH to USDC for DAO Operating Expenses
 * @dev This proposal sends 6,000 ETH to a TWAP Safe for conversion to USDC
 *      and withdraws all ETH from the Old Registrar Controller to the DAO wallet.
 */
contract Proposal_ENS_EP_6_1_Test is ENS_Governance {
    IWithdraw OldRegistrarController = IWithdraw(0x283Af0B28c62C092C9727F1Ee09c02CA627EB7F5);

    address constant receiver = 0x02D61347e5c6EA5604f3f814C5b5498421cEBdEB; // TWAP Safe
    uint256 constant expectedETHtransferTimelock = 6000 * 10 ** 18;

    uint256 ETHbalanceBeforeRegistrar;
    uint256 ETHbalanceBeforeTimelock;

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 21_723_989, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0xb8c2C29ee19D8307cb7255e1Cd9CbDE883A267d5; // nick.eth
    }

    function _beforeProposal() public override {
        ETHbalanceBeforeTimelock = address(timelock).balance;
        ETHbalanceBeforeRegistrar = address(OldRegistrarController).balance;
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

        // Transaction 1: Send 6,000 ETH to the TWAP Safe (empty calldata = plain ETH transfer)
        targets[0] = receiver;
        calldatas[0] = new bytes(0);
        values[0] = expectedETHtransferTimelock;
        signatures[0] = "";

        // Transaction 2: Withdraw all ETH from Old Registrar Controller to DAO wallet
        targets[1] = address(OldRegistrarController);
        calldatas[1] = abi.encodeWithSelector(OldRegistrarController.withdraw.selector);
        values[1] = 0;
        signatures[1] = "";

        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public view override {
        uint256 ETHbalanceAfterTimelock = address(timelock).balance;
        assertEq(
            ETHbalanceAfterTimelock, ETHbalanceBeforeTimelock + ETHbalanceBeforeRegistrar - expectedETHtransferTimelock
        );

        uint256 safeBalance = receiver.balance;
        assertEq(safeBalance, expectedETHtransferTimelock);

        uint256 registrarBalance = address(OldRegistrarController).balance;
        assertEq(registrarBalance, 0);
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-6-1";
    }
}
