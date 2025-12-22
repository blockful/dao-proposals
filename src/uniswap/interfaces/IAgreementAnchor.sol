// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

/// @title AgreementAnchor Interface
/// @notice Interface for the AgreementAnchor contract used in EAS attestations
/// @dev This anchor stores the content hash of the agreement and the UIDs of attestations for each party
interface IAgreementAnchor {
    /// @notice The content hash of the agreement
    function CONTENT_HASH() external view returns (bytes32);

    /// @notice The address of party A
    function PARTY_A() external view returns (address);

    /// @notice The address of party B
    function PARTY_B() external view returns (address);

    /// @notice The EAS resolver address
    function RESOLVER() external view returns (address);

    /// @notice The attestation UID for party A (non-zero if attested)
    function partyA_attestationUID() external view returns (bytes32);

    /// @notice The attestation UID for party B (non-zero if attested)
    function partyB_attestationUID() external view returns (bytes32);

    /// @notice Callback function called by EAS when an attestation is made
    /// @param party The address of the party making the attestation
    /// @param data The attestation data
    function onAttest(address party, bytes calldata data) external;
}

