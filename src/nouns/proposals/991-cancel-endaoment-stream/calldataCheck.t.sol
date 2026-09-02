// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { NounsConstants } from "@nouns/Constants.sol";
import { Nouns_Governance } from "@nouns/nouns.t.sol";
import { IERC20Balance } from "@nouns/interfaces/IERC20Balance.sol";
import { IStream } from "@nouns/interfaces/IStream.sol";

contract Proposal_NOUNS_991_Test is Nouns_Governance {
    address internal constant STREAM_ADDRESS = 0xE1653109E79A5014f62287104428e6e2a79125A2;
    address internal constant ENDAOMENT_RECIPIENT = 0x8D2a84300d6ce230Ed3Fffc23DBCDf1e6C781FF0;

    IStream internal constant STREAM = IStream(STREAM_ADDRESS);
    IERC20Balance internal constant WETH = IERC20Balance(NounsConstants.WETH);

    uint256 internal streamBalanceBeforeExecution;
    uint256 internal treasuryBalanceBeforeExecution;
    uint256 internal recipientBalanceAtExecution;

    function _selectFork() public override {
        vm.createSelectFork("mainnet", 25_797_920);
    }

    function _proposalId() internal pure override returns (uint256) {
        return 991;
    }

    function _startBlock() internal pure override returns (uint256) {
        return 25_819_520;
    }

    function _endBlock() internal pure override returns (uint256) {
        return 25_848_320;
    }

    function _quorumVotes() internal pure override returns (uint256) {
        return 136;
    }

    function _generateCallData()
        internal
        pure
        override
        returns (
            address[] memory generatedTargets,
            uint256[] memory generatedValues,
            string[] memory generatedSignatures,
            bytes[] memory generatedCalldatas
        )
    {
        generatedTargets = new address[](2);
        generatedValues = new uint256[](2);
        generatedSignatures = new string[](2);
        generatedCalldatas = new bytes[](2);

        generatedTargets[0] = STREAM_ADDRESS;
        generatedSignatures[0] = "cancel()";
        generatedCalldatas[0] = bytes("");

        generatedTargets[1] = STREAM_ADDRESS;
        generatedSignatures[1] = "recoverTokens(address)";
        generatedCalldatas[1] = abi.encode(NounsConstants.TIMELOCK);
    }

    function _beforeProposal() internal override {
        assertEq(STREAM.payer(), NounsConstants.TIMELOCK, "timelock is not stream payer");
        assertEq(STREAM.recipient(), ENDAOMENT_RECIPIENT, "unexpected stream recipient");
        assertEq(STREAM.token(), NounsConstants.WETH, "unexpected stream token");
        assertEq(STREAM.tokenAmount(), 120 ether, "unexpected original stream amount");
        assertEq(WETH.balanceOf(STREAM_ADDRESS), STREAM.remainingBalance(), "stream accounting mismatch");
        assertGt(STREAM.recipientActiveBalance(), 0, "recipient has no vested WETH");
        assertEq(bytes4(keccak256(bytes(signatures[0]))), IStream.cancel.selector, "cancel selector mismatch");
        assertEq(bytes4(keccak256(bytes(signatures[1]))), IStream.recoverTokens.selector, "recover selector mismatch");

        vm.prank(makeAddr("unauthorized"));
        vm.expectRevert(IStream.CallerNotPayerOrRecipient.selector);
        STREAM.cancel();
    }

    function _beforeExecution() internal override {
        streamBalanceBeforeExecution = WETH.balanceOf(STREAM_ADDRESS);
        treasuryBalanceBeforeExecution = WETH.balanceOf(NounsConstants.TIMELOCK);
        recipientBalanceAtExecution = STREAM.recipientBalance();

        assertGt(streamBalanceBeforeExecution, recipientBalanceAtExecution, "no unstreamed balance to return");
        assertEq(STREAM.recipientCancelBalance(), 0, "stream already canceled");
    }

    function _afterExecution() internal override {
        uint256 returnedToTreasury = streamBalanceBeforeExecution - recipientBalanceAtExecution;

        assertEq(
            WETH.balanceOf(NounsConstants.TIMELOCK),
            treasuryBalanceBeforeExecution + returnedToTreasury,
            "treasury did not receive exact unstreamed WETH"
        );
        assertEq(
            WETH.balanceOf(STREAM_ADDRESS), recipientBalanceAtExecution, "recipient's vested WETH was not preserved"
        );
        assertEq(STREAM.recipientCancelBalance(), recipientBalanceAtExecution, "canceled recipient balance mismatch");
        assertEq(STREAM.remainingBalance(), 0, "stream remains active after cancellation");

        vm.expectRevert(IStream.StreamNotActive.selector);
        vm.prank(NounsConstants.TIMELOCK);
        STREAM.cancel();
    }
}
