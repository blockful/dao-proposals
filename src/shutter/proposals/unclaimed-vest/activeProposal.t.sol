// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";

import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";
import { IGnosisSafe } from "@shutter/interfaces/IGnosisSafe.sol";
import { Shutter_Governance } from "@shutter/shutter.t.sol";
import { IAzorius } from "@shutter/interfaces/IAzorius.sol";
import { IAirdrop } from "@shutter/interfaces/IAirdrop.sol";

contract Proposal_Shutter_Unclaimed_Vest_Test is Shutter_Governance {
    /*//////////////////////////////////////////////////////////////////////////
                                   EXTERNAL CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Shutter Token
    IERC20 constant SHU = IERC20(0xe485E2f1bab389C08721B291f6b59780feC83Fd7);

    /// @dev Treasury Contract
    IGnosisSafe constant TreasuryContract = IGnosisSafe(0x36bD3044ab68f600f6d3e081056F34f2a58432c4);

    /// @dev The Airdrop contract to claim unclaimed tokens
    address constant Airdrop = 0x024574C4C42c72DfAaa3ccA80f73521a4eF5Ca94;
    IAirdrop constant AirdropContract = IAirdrop(Airdrop);

    /// @dev The vesting contract that is a Safe module and must have rights revoked
    address constant VestingPoolManager = 0xD724DBe7e230E400fe7390885e16957Ec246d716;

    /*//////////////////////////////////////////////////////////////////////////
                                   STATE VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    uint256 airdropBalanceBefore;
    uint256 treasuryBalanceBefore;
    bool isModuleEnabledBefore;

    /*//////////////////////////////////////////////////////////////////////////
                                   IMPLEMENTATION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public override {
        super.setUp();
        vm.label(address(AirdropContract), "Airdrop Contract");
        vm.label(address(TreasuryContract), "Treasury Contract");
        vm.label(VestingPoolManager, "VestingPoolManager");
    }

    function _selectFork() public override {
        /// @dev Block 20500000 is approximately when the claim/disable proposal was submitted
        vm.createSelectFork({ blockNumber: 20_500_000, urlOrAlias: "mainnet" });
    }

    function _metadata() public pure override returns (string memory) {
        return "Claim Unclaimed Tokens from Airdrop and Disable Vesting Pool Manager";
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return false;
    }

    function _beforeProposal() public override {
        // Check if the module is enabled
        isModuleEnabledBefore = TreasuryContract.isModuleEnabled(VestingPoolManager);
        assertTrue(isModuleEnabledBefore, "Module should be enabled before proposal");

        // Store balances
        airdropBalanceBefore = SHU.balanceOf(Airdrop);
        assertEq(airdropBalanceBefore, 46_154_583_762_696_716_270_000_000, "Unexpected airdrop balance");

        treasuryBalanceBefore = SHU.balanceOf(ShutterGnosis);
    }

    function _prepareTransactions() internal view override returns (IAzorius.Transaction[] memory transactions) {
        transactions = new IAzorius.Transaction[](2);

        // Step 1: Claim unclaimed tokens from Airdrop
        transactions[0] = IAzorius.Transaction({
            to: address(AirdropContract),
            value: 0,
            data: abi.encodeWithSelector(IAirdrop.claimUnusedTokens.selector, ShutterGnosis),
            operation: IAzorius.Operation.Call
        });

        // Step 2: Disable the VestingPoolManager module
        transactions[1] = IAzorius.Transaction({
            to: address(TreasuryContract),
            value: 0,
            data: abi.encodeWithSelector(IGnosisSafe.disableModule.selector, address(0x1), VestingPoolManager),
            operation: IAzorius.Operation.Call
        });
    }

    function _afterExecution() public view override {
        // Validate the airdrop balance is now 0
        uint256 airdropBalanceAfter = SHU.balanceOf(Airdrop);
        assertEq(airdropBalanceAfter, 0, "Airdrop balance should be 0 after claim");

        // Validate the treasury received the claimed tokens
        uint256 treasuryBalanceAfter = SHU.balanceOf(ShutterGnosis);
        assertEq(
            treasuryBalanceAfter,
            treasuryBalanceBefore + airdropBalanceBefore,
            "Treasury should receive claimed tokens"
        );

        // Validate the module is disabled
        bool isModuleEnabledAfter = TreasuryContract.isModuleEnabled(VestingPoolManager);
        assertFalse(isModuleEnabledAfter, "Module should be disabled after proposal");
    }
}

