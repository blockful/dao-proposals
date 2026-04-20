// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";
import { console2 } from "@forge-std/src/console2.sol";

import { ENS_Governance } from "@ens/ens.t.sol";
import { IENSRoot } from "@ens/interfaces/IENSRoot.sol";
import { IENSRegistryWithFallback } from "@ens/interfaces/IENSRegistryWithFallback.sol";

contract Proposal_ENS_EP_6_7_Test is ENS_Governance {
    IENSRoot root = IENSRoot(0xaB528d626EC275E3faD363fF1393A41F581c5897);
    IENSRegistryWithFallback ensRegistry = IENSRegistryWithFallback(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);

    address DNSRegistrar = 0xB32cB5677a7C971689228EC835800432B339bA2B;

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 22_332_663, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0xb8c2C29ee19D8307cb7255e1Cd9CbDE883A267d5; // nick.eth
    }

    function _beforeProposal() public override {
        assertEq(root.controllers(address(timelock)), false);
        assertNotEq(ensRegistry.owner(namehash("ceo")), DNSRegistrar);
    }

    function _generateCallData()
        public
        override
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory, string memory)
    {
        description = getDescriptionFromMarkdown();

        uint256 numTransactions = 2;

        targets = new address[](numTransactions);
        values = new uint256[](numTransactions);
        calldatas = new bytes[](numTransactions);
        signatures = new string[](numTransactions);

        // 1. Set the timelock as a controller of the ENS root
        targets[0] = address(root);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(IENSRoot.setController.selector, timelock, true);
        signatures[0] = "";

        // 2. Set the offchainDNSRegistrar as the owner of the ceo TLD
        targets[1] = address(root);
        values[1] = 0;
        calldatas[1] = abi.encodeWithSelector(IENSRoot.setSubnodeOwner.selector, labelhash("ceo"), DNSRegistrar);
        signatures[1] = "";

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public view override {
        assertEq(root.controllers(address(timelock)), true);
        assertEq(ensRegistry.owner(namehash("ceo")), DNSRegistrar);
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-6-7";
    }
}
