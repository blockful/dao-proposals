// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

/// @notice ENS gasless DNSSEC resolver (`OffchainDNSResolver`), ensdomains/ens-contracts
///         `contracts/dnsregistrar`.
interface IOffchainDNSResolver {
    function ens() external view returns (address);
    function oracle() external view returns (address);
    function gatewayURL() external view returns (string memory);

    /// @param response ABI-encoded `IDNSSEC.RRSetWithSignature[]` from the gateway.
    /// @param extraData `abi.encode(dnsName, query, bytes4(0))`, as built by `resolve`.
    function resolveCallback(bytes calldata response, bytes calldata extraData) external view returns (bytes memory);
}

/// @notice ENS public suffix list used by the DNS registrar.
interface IPublicSuffixList {
    function isPublicSuffix(bytes calldata name) external view returns (bool);
}
