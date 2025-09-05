// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface ISafeHarbor {
    error NoAgreement();
    error OwnableInvalidOwner(address owner);
    error OwnableUnauthorizedAccount(address account);

    event ChainValiditySet(string caip2ChainId, bool valid);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event SafeHarborAdoption(address indexed entity, address oldDetails, address newDetails);

    function adoptSafeHarbor(address agreementAddress) external;
    function getAgreement(address adopter) external view returns (address);
    function getValidChains() external view returns (string[] memory);
    function isChainValid(string memory _caip2ChainId) external view returns (bool);
    function owner() external view returns (address);
    function renounceOwnership() external;
    function setFallbackRegistry(address _fallbackRegistry) external;
    function setInvalidChains(string[] memory _caip2ChainIds) external;
    function setValidChains(string[] memory _caip2ChainIds) external;
    function transferOwnership(address newOwner) external;
    function version() external pure returns (string memory);
}
