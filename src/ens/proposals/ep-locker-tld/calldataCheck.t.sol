// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";
import { console2 } from "@forge-std/src/console2.sol";

import { ENS_Governance } from "@ens/ens.t.sol";
import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";
import { IENSRoot } from "@ens/interfaces/IENSRoot.sol";
import { IENSRegistryWithFallback } from "@ens/interfaces/IENSRegistryWithFallback.sol";

abstract contract NameResolver {
    function setName(bytes32 node, string memory name) public virtual;
}

contract Proposal_ENS_EP_Locker_TLD_Test is ENS_Governance {
    // Contract addresses - Update with actual addresses
    IENSRoot root = IENSRoot(0xaB528d626EC275E3faD363fF1393A41F581c5897);
    IENSRegistryWithFallback ensRegistry = IENSRegistryWithFallback(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);

    address oldOwner;
    address newOwner = 0x63862031C544642024eF9A0B713AF2aB9236A198;
    bytes32 labelhashBytes = labelhash("locker");
    bytes32 node = namehash("locker");

    function _selectFork() public override {
        // TODO: Update with appropriate block number for the proposal
        vm.createSelectFork({ blockNumber: 23_043_292, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        // TODO: Update with actual proposer address
        return 0xe52C39327FF7576bAEc3DBFeF0787bd62dB6d726; // Update with actual proposer
    }

    function _beforeProposal() public override {
        oldOwner = ensRegistry.owner(node);
        console2.log("oldOwner", oldOwner);
        console2.log("labelhashBytes");
        console2.logBytes32(labelhashBytes);

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

        // 1. Set the owner of the locker TLD to Orange Domains address
        targets[0] = address(root);
        calldatas[0] =
            abi.encodeWithSelector(IENSRoot.setSubnodeOwner.selector, labelhashBytes, newOwner);
        values[0] = 0;
        signatures[0] = "";

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public view override {
        assertEq(ensRegistry.owner(node), newOwner);

        vm.startPrank(newOwner);
        ensRegistry.setResolver(node, offchainDNSResolver);
        vm.stopPrank();
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        // TODO: Set to true if proposal already exists on-chain, false if it needs to be submitted
        return false; // Update based on proposal status
    }

    function jsonPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-locker-tld/draftCalldata.json";
    }
}
