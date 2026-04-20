// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "@forge-std/src/console2.sol";

import { ENS_Governance } from "@ens/ens.t.sol";
import { IENSRoot } from "@ens/interfaces/IENSRoot.sol";

/**
 * @title Proposal_ENS_EP_6_9_Test
 * @notice Calldata review for ENS EP 6.9 - Revoke root controller role from legacy ENS multisig
 * @dev This proposal calls setController(legacyMultisig, false) on the ENS Root contract
 *      to remove the legacy multisig's ability to manage ENS TLDs.
 */
contract Proposal_ENS_EP_6_9_Test is ENS_Governance {
    IENSRoot root = IENSRoot(0xaB528d626EC275E3faD363fF1393A41F581c5897);
    address legacyMultisig = 0xCF60916b6CB4753f58533808fA610FcbD4098Ec0;

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 22_337_300, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0xb8c2C29ee19D8307cb7255e1Cd9CbDE883A267d5; // nick.eth
    }

    function _beforeProposal() public override {
        assertTrue(root.controllers(legacyMultisig));
    }

    function _generateCallData()
        public
        override
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory, string memory)
    {
        uint256 numTransactions = 1;

        targets = new address[](numTransactions);
        values = new uint256[](numTransactions);
        calldatas = new bytes[](numTransactions);
        signatures = new string[](numTransactions);

        // Transaction 1: Revoke controller role from legacy multisig
        targets[0] = address(root);
        calldatas[0] = abi.encodeWithSelector(IENSRoot.setController.selector, legacyMultisig, false);
        values[0] = 0;
        signatures[0] = "";

        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public view override {
        assertFalse(root.controllers(legacyMultisig));
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-6-9";
    }
}
