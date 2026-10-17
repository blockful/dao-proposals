// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { IDNSSEC } from "./IDNSSEC.sol";

/// @notice ENS DNS registrar (`DNSRegistrar`), ensdomains/ens-contracts `contracts/dnsregistrar`.
/// @dev `wasRegistrar`, `getInception` and `StaleProof`'s arguments exist from PR #572 onwards. The
///      2021 deployment has no `previousRegistrar` either.
interface IDNSRegistrar {
    error StaleProof(bytes name, uint16 typeCovered, uint32 lastTime, uint32 time);

    function ens() external view returns (address);
    function oracle() external view returns (address);
    function resolver() external view returns (address);
    function suffixes() external view returns (address);
    function previousRegistrar() external view returns (address);
    function wasRegistrar(address registrar) external view returns (bool);
    function inceptions(bytes32 node) external view returns (uint32);
    function getInception(bytes calldata name, uint16 typeCovered) external view returns (uint32);

    function enableNode(bytes memory domain) external returns (bytes32 node);
    function proveAndClaim(bytes memory name, IDNSSEC.RRSetWithSignature[] memory input) external;
}

/// @notice The 2021 DNSRegistrar (0x58774Bb8...), built on the stateful oracle of that era: claims read
///         TXT records previously submitted to the oracle. It has no external `enableNode`; `claim`
///         enables the parent name before checking the proof.
interface IDNSRegistrar2021 {
    function oracle() external view returns (address);
    function suffixes() external view returns (address);
    function claim(bytes memory name, bytes memory proof) external;
}
