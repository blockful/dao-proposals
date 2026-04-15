// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "@forge-std/src/console2.sol";

import { INameWrapper } from "@ens/interfaces/INameWrapper.sol";
import { ENS_Governance } from "@ens/ens.t.sol";

/**
 * @title Proposal_ENS_EP_5_27_Test
 * @notice Calldata review for ENS EP 5.27 - Revoke the DAO's ability to upgrade the name wrapper
 * @dev This proposal sets a new metadata service (via proxy) and renounces DAO ownership
 *      of the NameWrapper, preventing future upgrades via the upgrade mechanism.
 */
contract Proposal_ENS_EP_5_27_Test is ENS_Governance {
    INameWrapper nameWrapper = INameWrapper(0xD4416b13d2b3a9aBae7AcD5D6C2BbDBE25686401);

    // New metadata service proxy address
    address constant metadataProxy = 0xaBB76D7e79de010117B147761013f11630a6799f;

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 21_378_687, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0xb8c2C29ee19D8307cb7255e1Cd9CbDE883A267d5; // nick.eth
    }

    function _beforeProposal() public view override {
        assertEq(nameWrapper.owner(), address(timelock));
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

        // Transaction 1: Set the metadata service to the new proxy
        targets[0] = address(nameWrapper);
        calldatas[0] = abi.encodeWithSelector(INameWrapper.setMetadataService.selector, metadataProxy);
        values[0] = 0;
        signatures[0] = "";

        // Transaction 2: Renounce ownership of the NameWrapper
        targets[1] = address(nameWrapper);
        calldatas[1] = abi.encodeWithSelector(INameWrapper.renounceOwnership.selector);
        values[1] = 0;
        signatures[1] = "";

        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public view override {
        assertEq(nameWrapper.owner(), address(0));
        assertEq(nameWrapper.metadataService(), metadataProxy);
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-5-27";
    }
}
