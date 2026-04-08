// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";
import { console2 } from "@forge-std/src/console2.sol";

import { ENS_Governance } from "@ens/ens.t.sol";
import { IENSRoot } from "@ens/interfaces/IENSRoot.sol";
import { IENSRegistryWithFallback } from "@ens/interfaces/IENSRegistryWithFallback.sol";

contract Proposal_ENS_EP_6_12_Test is ENS_Governance {
    IENSRoot root = IENSRoot(0xaB528d626EC275E3faD363fF1393A41F581c5897);
    IENSRegistryWithFallback ensRegistry = IENSRegistryWithFallback(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);
    
    address offchainDNSResolver = 0xF142B308cF687d4358410a4cB885513b30A42025;
    address DNSRegistrar = 0xB32cB5677a7C971689228EC835800432B339bA2B;


    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 22_531_399, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0xb8c2C29ee19D8307cb7255e1Cd9CbDE883A267d5; // nick.eth
    }

    function _beforeProposal() public override {
        // Verify the DNS registry is the owner of ceo TLD
        assertEq(ensRegistry.owner(namehash("ceo")), DNSRegistrar);

        // Verify the DNS registry has no resolver for ceo TLD
        assertEq(ensRegistry.resolver(namehash("ceo")), address(0));
    }

    function _generateCallData()
        public
        override
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory, string memory)
    {
        description = getDescriptionFromMarkdown();

        uint256 numTransactions = 3;

        targets = new address[](numTransactions);
        values = new uint256[](numTransactions);
        calldatas = new bytes[](numTransactions);
        signatures = new string[](numTransactions);

        // 1. Set the owner of the ceo TLD to the timelock
        targets[0] = address(root);
        calldatas[0] =
            abi.encodeWithSelector(IENSRoot.setSubnodeOwner.selector, labelhash("ceo"), address(timelock));
        values[0] = 0;
        signatures[0] = "";

        // 2. Set the resolver of the ceo TLD to the offchainDNSResolver
        targets[1] = address(ensRegistry);
        calldatas[1] = abi.encodeWithSelector(IENSRegistryWithFallback.setResolver.selector, namehash("ceo"), offchainDNSResolver);
        values[1] = 0;
        signatures[1] = "";

        // 3. Set the owner of the ceo TLD back to the DNSRegistrar
        targets[2] = address(ensRegistry);
        calldatas[2] = abi.encodeWithSelector(IENSRegistryWithFallback.setOwner.selector, namehash("ceo"), DNSRegistrar);
        values[2] = 0;
        signatures[2] = "";


        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public view override {
        // Verify the DNS registry is still the owner of ceo TLD
        assertEq(ensRegistry.owner(namehash("ceo")), DNSRegistrar);

        // Verify the DNS registry has a resolver for ceo TLD
        assertEq(ensRegistry.resolver(namehash("ceo")), offchainDNSResolver);
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-6-12";
    }
}
