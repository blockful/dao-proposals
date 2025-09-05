// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "@forge-std/src/console2.sol";

import { ENS_Governance } from "@ens/ens.t.sol";
import { ISafeHarbor } from "@ens/interfaces/ISafeHarbor.sol";
import { IAgreement } from "@ens/interfaces/IAgreement.sol";

contract ProposalENSEPReactivateStreamDraftTest is ENS_Governance {
    // Contract addresses
    ISafeHarbor public constant safeHarbor = ISafeHarbor(0x1eaCD100B0546E433fbf4d773109cAD482c34686);
    IAgreement public constant agreement = IAgreement(0x3303a9A3eb71836c0e88E8AB4eaf0d478e29E04c);

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 23282724, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0xb8c2C29ee19D8307cb7255e1Cd9CbDE883A267d5;
    }

    function _beforeProposal() public override {

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

        targets[0] = address(safeHarbor);
        calldatas[0] = abi.encodeWithSelector(
            ISafeHarbor.adoptSafeHarbor.selector,
            address(agreement)
        );
        values[0] = 0;
        signatures[0] = "";

        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        // check owner of the agreement
        assertEq(agreement.owner(), address(timelock));

        // check that the agreement is in the safe harbor
        assertEq(safeHarbor.getAgreement(address(timelock)), address(agreement));

        // log the agreement details
        IAgreement.AgreementDetailsV2 memory details = agreement.getDetails();
        // console2.log("=== Agreement Details ===");
        // console2.log("Protocol Name:", details.protocolName);
        // console2.log("Agreement URI:", details.agreementURI);
        // console2.log("=== Contact Details ===");
        // for (uint i = 0; i < details.contactDetails.length; i++) {
        //     console2.log("Contact", i, "- Name:", details.contactDetails[i].name);
        //     console2.log("Contact", i, "- Contact:", details.contactDetails[i].contact);
        // }
        // console2.log("=== Bounty Terms ===");
        // console2.log("Bounty Percentage:", details.bountyTerms.bountyPercentage);
        // console2.log("Bounty Cap USD:", details.bountyTerms.bountyCapUSD);
        // console2.log("Retainable:", details.bountyTerms.retainable);
        // console2.log("Identity Requirements:", IAgreement.IdentityRequirements.unwrap(details.bountyTerms.identity));
        // console2.log("Diligence Requirements:", details.bountyTerms.diligenceRequirements);
        // console2.log("Aggregate Bounty Cap USD:", details.bountyTerms.aggregateBountyCapUSD);

    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-safe-harbor";
    }
}
