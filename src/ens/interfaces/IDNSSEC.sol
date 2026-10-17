// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

/// @notice ENS DNSSEC oracle (`DNSSECImpl`), ensdomains/ens-contracts `contracts/dnssec-oracle`.
/// @dev `setAnchors` and the OZ `Ownable` surface exist from PR #572 onwards; earlier deployments
///      expose `setOwner` instead and have immutable anchors.
interface IDNSSEC {
    struct RRSetWithSignature {
        bytes rrset;
        bytes sig;
    }

    error SignatureExpired(uint32 expiration, uint32 now);
    error NoMatchingProof(bytes signerName);

    function anchors() external view returns (bytes memory);
    function algorithms(uint8 id) external view returns (address);
    function digests(uint8 id) external view returns (address);
    function owner() external view returns (address);

    function setAnchors(bytes calldata anchors) external;
    function setAlgorithm(uint8 id, address algo) external;
    function setDigest(uint8 id, address digest) external;
    function transferOwnership(address newOwner) external;

    function verifyRRSet(RRSetWithSignature[] memory input) external view returns (bytes memory rrs, uint32 inception);
    function verifyRRSet(
        RRSetWithSignature[] memory input,
        uint256 currentTime
    )
        external
        view
        returns (bytes memory rrs, uint32 inception);
}
