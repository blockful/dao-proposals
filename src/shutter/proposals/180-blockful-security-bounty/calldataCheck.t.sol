// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { CalldataComparison } from "@contracts/base/CalldataComparison.sol";
import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";
import { IAzorius } from "@shutter/interfaces/IAzorius.sol";
import { Shutter_Governance } from "@shutter/shutter.t.sol";

contract Proposal_Shutter_180_Blockful_Security_Bounty_Test is Shutter_Governance, CalldataComparison {
    uint32 internal constant EXPECTED_PROPOSAL_ID = 180;
    uint256 internal constant SUSDS_SHARE_AMOUNT = 135_549_395_254_089_312_263_335;
    uint256 internal constant ETH_AMOUNT = 53_370_430_576_814_417;

    IERC20 internal constant SUSDS = IERC20(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD);
    address internal constant BLOCKFUL_RECIPIENT = 0xBD28c6FeeeFf61254D00A1E8FB1fB863F9B75b3c;
    address internal constant LIVE_PROPOSER = 0x1F3D3A7A9c548bE39539b39D7400302753E20591;

    uint256 internal treasurySusdsBalanceBefore;
    uint256 internal recipientSusdsBalanceBefore;
    uint256 internal treasuryEthBalanceBefore;
    uint256 internal recipientEthBalanceBefore;

    function setUp() public override {
        super.setUp();
        vm.label(address(SUSDS), "sUSDS");
        vm.label(BLOCKFUL_RECIPIENT, "blockful bounty recipient");
    }

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 25_728_670, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return LIVE_PROPOSER;
    }

    function _metadata() public pure override returns (string memory) {
        return "Security Bounty for blockful";
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true;
    }

    function _beforeProposal() public override {
        assertEq(Azorius.totalProposalCount() - 1, EXPECTED_PROPOSAL_ID, "Unexpected latest proposal ID");
        assertEq(
            uint8(Azorius.proposalState(EXPECTED_PROPOSAL_ID)),
            uint8(IAzorius.ProposalState.ACTIVE),
            "Proposal 180 should be active at the fork block"
        );

        treasurySusdsBalanceBefore = SUSDS.balanceOf(ShutterGnosis);
        recipientSusdsBalanceBefore = SUSDS.balanceOf(BLOCKFUL_RECIPIENT);
        treasuryEthBalanceBefore = ShutterGnosis.balance;
        recipientEthBalanceBefore = BLOCKFUL_RECIPIENT.balance;

        assertGe(treasurySusdsBalanceBefore, SUSDS_SHARE_AMOUNT, "Treasury cannot fund the sUSDS bounty");
        assertGe(treasuryEthBalanceBefore, ETH_AMOUNT, "Treasury cannot fund the ETH transfer");
    }

    function _prepareTransactions() internal pure override returns (IAzorius.Transaction[] memory transactions) {
        transactions = new IAzorius.Transaction[](2);

        transactions[0] = IAzorius.Transaction({
            to: address(SUSDS),
            value: 0,
            data: abi.encodeWithSelector(IERC20.transfer.selector, BLOCKFUL_RECIPIENT, SUSDS_SHARE_AMOUNT),
            operation: IAzorius.Operation.Call
        });

        transactions[1] = IAzorius.Transaction({
            to: BLOCKFUL_RECIPIENT, value: ETH_AMOUNT, data: bytes(""), operation: IAzorius.Operation.Call
        });
    }

    function _afterExecution() public view override {
        assertEq(
            SUSDS.balanceOf(ShutterGnosis),
            treasurySusdsBalanceBefore - SUSDS_SHARE_AMOUNT,
            "Treasury sUSDS decrease does not equal the bounty"
        );
        assertEq(
            SUSDS.balanceOf(BLOCKFUL_RECIPIENT),
            recipientSusdsBalanceBefore + SUSDS_SHARE_AMOUNT,
            "Recipient sUSDS increase does not equal the bounty"
        );
        assertEq(
            ShutterGnosis.balance,
            treasuryEthBalanceBefore - ETH_AMOUNT,
            "Treasury ETH decrease does not equal the gas funding"
        );
        assertEq(
            BLOCKFUL_RECIPIENT.balance,
            recipientEthBalanceBefore + ETH_AMOUNT,
            "Recipient ETH increase does not equal the gas funding"
        );
    }

    function test_liveCalldataMatchesManualDerivation() public {
        IAzorius.Transaction[] memory transactions = _prepareTransactions();
        (address[] memory targets, uint256[] memory values, bytes[] memory data,) =
            _prepareTransactionsForExecution(transactions);

        string memory jsonContent =
            vm.readFile("src/shutter/proposals/180-blockful-security-bounty/proposalCalldata.json");
        _compareLiveCalldata(jsonContent, targets, values, data);
    }
}
