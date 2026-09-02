// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { LilNounsConstants } from "@lil-nouns/Constants.sol";
import { LilNouns_Governance } from "@lil-nouns/lilNouns.t.sol";
import { IStETH } from "@lil-nouns/interfaces/IStETH.sol";

interface IENSRegistry {
    function resolver(bytes32 node) external view returns (address);
}

interface IENSResolver {
    function name(bytes32 node) external view returns (string memory);
    function addr(bytes32 node) external view returns (address);
}

contract Proposal_LIL_NOUNS_387_Test is LilNouns_Governance {
    address internal constant RECIPIENT = 0x72D4e991040e3B65FdDbE5f340f65Cf03C506e6F;
    uint256 internal constant FUNDING = 0.8 ether;

    IENSRegistry internal constant ENS_REGISTRY = IENSRegistry(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);

    /// @dev namehash("72d4e991040e3b65fddbe5f340f65cf03c506e6f.addr.reverse")
    bytes32 internal constant RECIPIENT_REVERSE_NODE =
        0xfdc4cfdc50a53ad63c6214c2128e4767a216a14148ffa2739cd1735a83b61dd9;
    /// @dev namehash("kimmydeuk.eth")
    bytes32 internal constant RECIPIENT_FORWARD_NODE =
        0x235f44d7e7064e3646264e378bd2569a52e5e6a7d19c1bff3e824d97e180f220;
    string internal constant RECIPIENT_ENS_NAME = "kimmydeuk.eth";

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

    /// @notice The one thing a byte comparison cannot prove: that this address belongs to the
    ///         person the proposal names. RECIPIENT is the same 20 bytes that appear in the
    ///         payload, so asserting it against the payload is transcription, not verification —
    ///         a proposal paying the wrong party would pass every other check in this file.
    ///         Bind it to an identity instead, both directions: the reverse record must claim
    ///         "kimmydeuk.eth", and that name must forward-resolve back to this address. Reverse
    ///         records are self-set and provable only in combination with the forward lookup.
    function test_recipientResolvesToTheNamedArtist() public view {
        IENSResolver reverseResolver = IENSResolver(ENS_REGISTRY.resolver(RECIPIENT_REVERSE_NODE));
        assertTrue(address(reverseResolver) != address(0), "recipient has no reverse resolver");
        assertEq(reverseResolver.name(RECIPIENT_REVERSE_NODE), RECIPIENT_ENS_NAME, "unexpected reverse record");

        IENSResolver forwardResolver = IENSResolver(ENS_REGISTRY.resolver(RECIPIENT_FORWARD_NODE));
        assertTrue(address(forwardResolver) != address(0), "named recipient has no forward resolver");
        assertEq(forwardResolver.addr(RECIPIENT_FORWARD_NODE), RECIPIENT, "forward record does not match recipient");
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
