// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { CalldataComparison } from "@contracts/base/CalldataComparison.sol";
import { Shutter_Governance } from "@shutter/shutter.t.sol";
import { IAzorius } from "@shutter/interfaces/IAzorius.sol";
import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";

contract Proposal_Shutter_178_Brainbot_Grant_Test is Shutter_Governance, CalldataComparison {
    uint32 internal constant EXPECTED_PROPOSAL_ID = 178;
    uint256 internal constant GRANT_AMOUNT = 107_000 * 10 ** 6;

    IERC20 internal constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address internal constant BRAINBOT = 0xb75E2fB01521Bd7b6369F831414840A54a3C7234;
    address internal constant LIVE_PROPOSER = 0x0f853a4c50763e0553Ac44E2546C0178B417c0Ba;

    uint256 internal treasuryBalanceBefore;
    uint256 internal brainbotBalanceBefore;

    function setUp() public override {
        super.setUp();
        vm.label(address(USDC), "USDC");
        vm.label(BRAINBOT, "brainbot gmbh");
    }

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 25_522_491, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return LIVE_PROPOSER;
    }

    function _metadata() public pure override returns (string memory) {
        return string.concat(
            '{"title":"Provide a grant to brainbot gmbh (July 2026) ",',
            '"description":"https://shutternetwork.discourse.group/t/provide-a-grant-to-brainbot-gmbh-july-2026/895',
            "\\n\\nProvide a one time grant of 107,000 USDC to brainbot gmbh (July 2026)\"}"
        );
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true;
    }

    function _beforeProposal() public override {
        assertEq(Azorius.totalProposalCount() - 1, EXPECTED_PROPOSAL_ID, "Unexpected latest proposal ID");
        assertEq(
            uint8(Azorius.proposalState(EXPECTED_PROPOSAL_ID)),
            uint8(IAzorius.ProposalState.ACTIVE),
            "Proposal 178 should be active at the fork block"
        );

        treasuryBalanceBefore = USDC.balanceOf(ShutterGnosis);
        brainbotBalanceBefore = USDC.balanceOf(BRAINBOT);

        assertGe(treasuryBalanceBefore, GRANT_AMOUNT, "Treasury cannot fund the grant");
    }

    function _prepareTransactions() internal pure override returns (IAzorius.Transaction[] memory transactions) {
        transactions = new IAzorius.Transaction[](1);
        transactions[0] = IAzorius.Transaction({
            to: address(USDC),
            value: 0,
            data: abi.encodeWithSelector(IERC20.transfer.selector, BRAINBOT, GRANT_AMOUNT),
            operation: IAzorius.Operation.Call
        });
    }

    function _afterExecution() public view override {
        assertEq(
            USDC.balanceOf(ShutterGnosis),
            treasuryBalanceBefore - GRANT_AMOUNT,
            "Treasury USDC decrease does not equal the grant"
        );
        assertEq(
            USDC.balanceOf(BRAINBOT),
            brainbotBalanceBefore + GRANT_AMOUNT,
            "brainbot USDC increase does not equal the grant"
        );
    }

    function test_liveCalldataMatchesManualDerivation() public {
        IAzorius.Transaction[] memory transactions = _prepareTransactions();
        (address[] memory targets, uint256[] memory values, bytes[] memory data,) =
            _prepareTransactionsForExecution(transactions);

        string memory jsonContent = vm.readFile("src/shutter/proposals/178-brainbot-grant/proposalCalldata.json");
        _compareLiveCalldata(jsonContent, targets, values, data);
    }
}
