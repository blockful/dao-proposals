// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { LilNounsConstants } from "@lil-nouns/Constants.sol";
import { LilNouns_Governance } from "@lil-nouns/lilNouns.t.sol";
import { IStETH } from "@lil-nouns/interfaces/IStETH.sol";

contract Proposal_LIL_NOUNS_387_Test is LilNouns_Governance {
    address internal constant RECIPIENT = 0x72D4e991040e3B65FdDbE5f340f65Cf03C506e6F;
    uint256 internal constant FUNDING = 0.8 ether;

    IStETH internal constant STETH = IStETH(LilNounsConstants.STETH);

    uint256 internal treasuryBalanceBeforeExecution;
    uint256 internal recipientBalanceBeforeExecution;

    function _selectFork() public override {
        vm.createSelectFork("mainnet", 25_828_881);
    }

    function _proposalId() internal pure override returns (uint256) {
        return 387;
    }

    function _startBlock() internal pure override returns (uint256) {
        return 25_843_281;
    }

    function _endBlock() internal pure override returns (uint256) {
        return 25_872_081;
    }

    function _quorumVotes() internal pure override returns (uint256) {
        return 384;
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
        generatedTargets = new address[](1);
        generatedValues = new uint256[](1);
        generatedSignatures = new string[](1);
        generatedCalldatas = new bytes[](1);

        generatedTargets[0] = LilNounsConstants.STETH;
        generatedSignatures[0] = "transfer(address,uint256)";
        generatedCalldatas[0] = abi.encode(RECIPIENT, FUNDING);
    }

    function _beforeProposal() internal override {
        assertEq(targets.length, 1, "unexpected action count");
        assertEq(targets[0], LilNounsConstants.STETH, "unexpected token target");
        assertEq(values[0], 0, "unexpected ETH value");
        assertEq(bytes4(keccak256(bytes(signatures[0]))), IStETH.transfer.selector, "transfer selector mismatch");
        (address decodedRecipient, uint256 decodedAmount) = abi.decode(calldatas[0], (address, uint256));
        assertEq(decodedRecipient, RECIPIENT, "unexpected transfer recipient");
        assertEq(decodedAmount, FUNDING, "unexpected transfer amount");
    }

    function _beforeExecution() internal override {
        treasuryBalanceBeforeExecution = STETH.balanceOf(LilNounsConstants.TIMELOCK);
        recipientBalanceBeforeExecution = STETH.balanceOf(RECIPIENT);
        assertGe(treasuryBalanceBeforeExecution, FUNDING, "treasury cannot fund transfer");
    }

    function _afterExecution() internal override {
        assertApproxEqAbs(
            STETH.balanceOf(RECIPIENT) - recipientBalanceBeforeExecution, FUNDING, 1, "recipient stETH delta mismatch"
        );
        assertApproxEqAbs(
            treasuryBalanceBeforeExecution - STETH.balanceOf(LilNounsConstants.TIMELOCK),
            FUNDING,
            1,
            "treasury stETH delta mismatch"
        );
    }

    function dirPath() public pure override returns (string memory) {
        return "src/lil-nouns/proposals/387-artober-2026";
    }
}
