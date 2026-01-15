// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";
import { console2 } from "@forge-std/src/console2.sol";

import { ENS_Governance } from "@ens/ens.t.sol";
import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";
import { IENSRoot } from "@ens/interfaces/IENSRoot.sol";
import { IENSRegistryWithFallback } from "@ens/interfaces/IENSRegistryWithFallback.sol";

contract Proposal_ENS_EP_6_28_Test is ENS_Governance {
    IENSRoot root = IENSRoot(0xaB528d626EC275E3faD363fF1393A41F581c5897);
    IENSRegistryWithFallback ensRegistry = IENSRegistryWithFallback(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);

    string tld = "kred";      
    address oldOwner;
    address newOwner = 0xb9ef2c160D908A4F7a9DFcdba46662C4a7EC4FD9;
    bytes32 labelhashBytes = labelhash(tld);
    bytes32 node = namehash(abi.encodePacked(tld));

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 24225260, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0xb8c2C29ee19D8307cb7255e1Cd9CbDE883A267d5; // nick.eth
    }

    function _beforeProposal() public override {
        oldOwner = ensRegistry.owner(node);
    }

    function _generateCallData()
        public
        override
        returns (
            address[] memory,
            uint256[] memory,
            string[] memory,
            bytes[] memory,
            string memory
        )
    {
        uint256 numTransactions = 1;

        targets = new address[](numTransactions);
        values = new uint256[](numTransactions);
        calldatas = new bytes[](numTransactions);
        signatures = new string[](numTransactions);

        // 1. Set the owner of the .locker TLD to Orange Domains address
        targets[0] = address(root);
        calldatas[0] =
            abi.encodeWithSelector(IENSRoot.setSubnodeOwner.selector, labelhashBytes, newOwner);
        values[0] = 0;
        signatures[0] = "";

        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        assertEq(ensRegistry.owner(node), newOwner);
        assertNotEq(oldOwner, newOwner);
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-6-28";
    }
}
