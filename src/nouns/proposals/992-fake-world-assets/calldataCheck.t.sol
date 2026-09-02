// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { NounsConstants } from "@nouns/Constants.sol";
import { Nouns_Governance } from "@nouns/nouns.t.sol";
import { INounsListingManager } from "@nouns/interfaces/INounsListingManager.sol";
import { INounsNFT } from "@nouns/interfaces/INounsNFT.sol";

contract Proposal_NOUNS_992_Test is Nouns_Governance {
    address internal constant MANAGER = 0x89ec417Fa93F02926bF9c28316dA4E7d0F28089b;
    address internal constant FWA = 0xB276F62DB0ce8CA2Ca5bc522695bE604521eAc1c;
    address internal constant REWARDS = 0x6a1a1C0CfB3D3C538e13D36d608a5bcaa992fc78;
    address internal constant OPERATOR = 0x387a161C6b25aA854100aBaED39274e51aaffffd;
    uint256 internal constant FUNDING = 30 ether;

    INounsNFT internal constant NOUN_TOKEN = INounsNFT(NounsConstants.TOKEN);
    INounsListingManager internal constant LISTING_MANAGER = INounsListingManager(MANAGER);

    uint256 internal treasuryBalanceBeforeExecution;
    uint256 internal managerBalanceBeforeExecution;

    function _selectFork() public override {
        vm.createSelectFork("mainnet", 25_811_309);
    }

    function _proposalId() internal pure override returns (uint256) {
        return 992;
    }

    function _startBlock() internal pure override returns (uint256) {
        return 25_832_909;
    }

    function _endBlock() internal pure override returns (uint256) {
        return 25_861_709;
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
        generatedTargets = new address[](4);
        generatedValues = new uint256[](4);
        generatedSignatures = new string[](4);
        generatedCalldatas = new bytes[](4);

        generatedTargets[0] = NounsConstants.TOKEN;
        generatedSignatures[0] = "setApprovalForAll(address,bool)";
        generatedCalldatas[0] = abi.encode(MANAGER, true);

        generatedTargets[1] = MANAGER;
        generatedSignatures[1] = "pull(uint256[])";
        generatedCalldatas[1] = abi.encode(_nounIds());

        generatedTargets[2] = NounsConstants.TOKEN;
        generatedSignatures[2] = "setApprovalForAll(address,bool)";
        generatedCalldatas[2] = abi.encode(MANAGER, false);

        generatedTargets[3] = MANAGER;
        generatedValues[3] = FUNDING;
        generatedSignatures[3] = "";
        generatedCalldatas[3] = bytes("");
    }

    function _beforeProposal() internal override {
        assertEq(LISTING_MANAGER.NOUNS(), NounsConstants.TOKEN, "manager has wrong Nouns token");
        assertEq(LISTING_MANAGER.FWA(), FWA, "manager has wrong FWA contract");
        assertEq(LISTING_MANAGER.REWARDS(), REWARDS, "manager has wrong rewards contract");
        assertEq(LISTING_MANAGER.TREASURY(), NounsConstants.TIMELOCK, "manager has wrong treasury");
        assertEq(LISTING_MANAGER.operator(), OPERATOR, "manager has wrong operator");
        assertEq(LISTING_MANAGER.MIN_BACKING(), 1 ether, "manager has wrong minimum backing");
        assertFalse(NOUN_TOKEN.isApprovedForAll(NounsConstants.TIMELOCK, MANAGER), "manager already approved");
        _assertAllNounsOwnedBy(NounsConstants.TIMELOCK);

        assertEq(
            bytes4(keccak256(bytes(signatures[0]))), INounsNFT.setApprovalForAll.selector, "approval selector mismatch"
        );
        assertEq(bytes4(keccak256(bytes(signatures[1]))), INounsListingManager.pull.selector, "pull selector mismatch");

        vm.prank(makeAddr("unauthorized"));
        vm.expectRevert(INounsListingManager.NotTreasury.selector);
        LISTING_MANAGER.pull(_nounIds());
    }

    function _beforeExecution() internal override {
        treasuryBalanceBeforeExecution = NounsConstants.TIMELOCK.balance;
        managerBalanceBeforeExecution = MANAGER.balance;

        assertGe(treasuryBalanceBeforeExecution, FUNDING, "treasury cannot fund manager");
        assertFalse(NOUN_TOKEN.isApprovedForAll(NounsConstants.TIMELOCK, MANAGER), "manager already approved");
        _assertAllNounsOwnedBy(NounsConstants.TIMELOCK);
    }

    function _afterExecution() internal override {
        _assertAllNounsOwnedBy(MANAGER);
        assertFalse(NOUN_TOKEN.isApprovedForAll(NounsConstants.TIMELOCK, MANAGER), "approval was not revoked");
        assertEq(MANAGER.balance, managerBalanceBeforeExecution + FUNDING, "manager funding mismatch");
        assertEq(
            NounsConstants.TIMELOCK.balance, treasuryBalanceBeforeExecution - FUNDING, "treasury ETH delta mismatch"
        );
    }

    function _assertAllNounsOwnedBy(address expectedOwner) internal view {
        uint256[] memory nounIds = _nounIds();
        for (uint256 i = 0; i < nounIds.length; ++i) {
            assertEq(NOUN_TOKEN.ownerOf(nounIds[i]), expectedOwner, "unexpected Noun owner");
        }
    }

    function _nounIds() internal pure returns (uint256[] memory nounIds) {
        nounIds = new uint256[](24);
        nounIds[0] = 11;
        nounIds[1] = 26;
        nounIds[2] = 82;
        nounIds[3] = 89;
        nounIds[4] = 279;
        nounIds[5] = 408;
        nounIds[6] = 548;
        nounIds[7] = 559;
        nounIds[8] = 801;
        nounIds[9] = 861;
        nounIds[10] = 1914;
        nounIds[11] = 1917;
        nounIds[12] = 1929;
        nounIds[13] = 1933;
        nounIds[14] = 1942;
        nounIds[15] = 1950;
        nounIds[16] = 1954;
        nounIds[17] = 1957;
        nounIds[18] = 1958;
        nounIds[19] = 1969;
        nounIds[20] = 1980;
        nounIds[21] = 1983;
        nounIds[22] = 1988;
        nounIds[23] = 1989;
    }
}
