// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

/// @title Tornado Cash Constants
/// @notice Shared address constants for Tornado Cash governance proposal tests.
///         Use these instead of hardcoding addresses in individual proposals.
library TornadoConstants {
    /// @dev Governance proxy (LoopbackProxy). The DAO's authority and treasury holder.
    address internal constant GOVERNANCE = 0x5efda50f22d34F262c29268506C5Fa42cB56A1Ce;
    /// @dev TORN governance token (ERC20 + permit).
    address internal constant TORN = 0x77777FeDdddFfC19Ff86DB637967013e6C6A116C;
    /// @dev Governance Vault — custodies locked TORN; withdrawTorn is onlyGovernance.
    address internal constant VAULT = 0x2F50508a8a3D323B91336FA3eA6ae50E55f32185;
    /// @dev Governance Staking (relayer-fee rewards).
    address internal constant STAKING = 0x2FC93484614a34f26F7970CBB94615bA109BB4bf;
}
