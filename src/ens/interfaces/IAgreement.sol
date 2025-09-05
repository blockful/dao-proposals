// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IAgreement {
    type ChildContractScope is uint8;
    type IdentityRequirements is uint8;

    struct Account {
        string accountAddress;
        ChildContractScope childContractScope;
    }

    struct AgreementDetailsV2 {
        string protocolName;
        Contact[] contactDetails;
        Chain[] chains;
        BountyTerms bountyTerms;
        string agreementURI;
    }

    struct BountyTerms {
        uint256 bountyPercentage;
        uint256 bountyCapUSD;
        bool retainable;
        IdentityRequirements identity;
        string diligenceRequirements;
        uint256 aggregateBountyCapUSD;
    }

    struct Chain {
        string assetRecoveryAddress;
        Account[] accounts;
        string caip2ChainId;
    }

    struct Contact {
        string name;
        string contact;
    }

    error AccountNotFound();
    error AccountNotFoundByAddress(string caip2ChainId, string accountAddress);
    error CannotSetBothAggregateBountyCapUSDAndRetainable();
    error ChainNotFound();
    error ChainNotFoundByCaip2Id(string caip2ChainId);
    error DuplicateChainId(string caip2ChainId);
    error InvalidChainId(string caip2ChainId);
    error OwnableInvalidOwner(address owner);
    error OwnableUnauthorizedAccount(address account);

    event AgreementUpdated();
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function addAccounts(string memory _caip2ChainId, Account[] memory _accounts) external;
    function addChains(Chain[] memory _chains) external;
    function getDetails() external view returns (AgreementDetailsV2 memory);
    function owner() external view returns (address);
    function removeAccounts(string memory _caip2ChainId, string[] memory _accountAddresses) external;
    function removeChains(string[] memory _caip2ChainIds) external;
    function renounceOwnership() external;
    function setBountyTerms(BountyTerms memory _bountyTerms) external;
    function setChains(Chain[] memory _chains) external;
    function setContactDetails(Contact[] memory _contactDetails) external;
    function setProtocolName(string memory _protocolName) external;
    function transferOwnership(address newOwner) external;
}
