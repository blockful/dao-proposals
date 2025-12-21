// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";

import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";
import { Shutter_Governance } from "@shutter/shutter.t.sol";
import { IAzorius } from "@shutter/interfaces/IAzorius.sol";
import { IDssPsm } from "@shutter/interfaces/IDssPsm.sol";
import { ISavingsDai } from "@shutter/interfaces/ISavingsDai.sol";

contract Proposal_Shutter_DSR_Allocation_Test is Shutter_Governance {
    /*//////////////////////////////////////////////////////////////////////////
                                PROPOSAL CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Amount of USDC to be deposited into DSR
    uint256 constant amount = 3_000_000;

    /// @dev Stablecoin decimals
    uint256 constant decimalsUSDC = 10 ** 6;
    uint256 constant decimalsDAI = 10 ** 18;

    /*//////////////////////////////////////////////////////////////////////////
                                   EXTERNAL CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

    /// @dev Maker PSM contracts to convert USDC to DAI
    IDssPsm constant DssPsm = IDssPsm(0x89B78CfA322F6C5dE0aBcEecab66Aee45393cC5A);
    address constant AuthGemJoin5 = 0x0A59649758aa4d66E25f08Dd01271e891fe52199;

    /// @dev Maker DAI Savings Token
    ISavingsDai constant SavingsDai = ISavingsDai(0x83F20F44975D03b1b09e64809B757c47f942BEeA);

    /*//////////////////////////////////////////////////////////////////////////
                                   STATE VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    uint256 initialDaoUSDCbalance;
    uint256 initialDaoSavingsDaibalance;

    /*//////////////////////////////////////////////////////////////////////////
                                   IMPLEMENTATION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public override {
        super.setUp();
        vm.label(address(USDC), "USDC");
        vm.label(address(DAI), "DAI");
        vm.label(address(DssPsm), "DssPsm");
        vm.label(address(SavingsDai), "SavingsDai");
    }

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 20055924, urlOrAlias: "mainnet" });
    }

    function _metadata() public pure override returns (string memory) {
        return "Treasury Management Temporary Solution: Deposit 3M DAI in the DSR Contract";
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return false;
    }

    function _beforeProposal() public override {
        initialDaoUSDCbalance = USDC.balanceOf(ShutterGnosis);
        initialDaoSavingsDaibalance = SavingsDai.balanceOf(ShutterGnosis);
    }

    function _prepareTransactions() internal view override returns (IAzorius.Transaction[] memory transactions) {
        transactions = new IAzorius.Transaction[](4);

        // Step 1: Approve PSM to spend USDC
        transactions[0] = IAzorius.Transaction({
            to: address(USDC),
            value: 0,
            data: abi.encodeWithSelector(IERC20.approve.selector, AuthGemJoin5, amount * decimalsUSDC),
            operation: IAzorius.Operation.Call
        });

        // Step 2: Convert USDC to DAI via PSM
        transactions[1] = IAzorius.Transaction({
            to: address(DssPsm),
            value: 0,
            data: abi.encodeWithSelector(DssPsm.sellGem.selector, ShutterGnosis, amount * decimalsUSDC),
            operation: IAzorius.Operation.Call
        });

        // Step 3: Approve SavingsDai to spend DAI
        transactions[2] = IAzorius.Transaction({
            to: address(DAI),
            value: 0,
            data: abi.encodeWithSelector(IERC20.approve.selector, address(SavingsDai), amount * decimalsDAI),
            operation: IAzorius.Operation.Call
        });

        // Step 4: Deposit DAI into SavingsDai (DSR)
        transactions[3] = IAzorius.Transaction({
            to: address(SavingsDai),
            value: 0,
            data: abi.encodeWithSelector(SavingsDai.deposit.selector, amount * decimalsDAI, ShutterGnosis),
            operation: IAzorius.Operation.Call
        });
    }

    function _afterExecution() public view override {
        // Validate if the Shutter Gnosis contract received the Savings Dai Token (DSR)
        // Since there is a loss of precision in the process, we need to check if the amount is
        // within the expected range using 0.0001% of the amount as the margin of error
        assertGe(
            SavingsDai.maxWithdraw(ShutterGnosis),
            (amount * decimalsDAI * 999_999) / 1_000_000,
            "DSR deposit amount mismatch"
        );

        // Validate if the DAI was transferred to the Shutter Gnosis
        assertGt(
            SavingsDai.balanceOf(ShutterGnosis),
            initialDaoSavingsDaibalance,
            "SavingsDAI balance did not increase"
        );

        // Validate if the USDC was transferred from the DAO
        assertEq(
            USDC.balanceOf(ShutterGnosis),
            initialDaoUSDCbalance - amount * decimalsUSDC,
            "USDC balance mismatch"
        );
    }
}

