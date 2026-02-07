// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

/// @title IRegistrarController
/// @notice Minimal interface for ENS registrar controllers that hold ETH revenue.
interface IRegistrarController {
    /// @notice Withdraws accumulated ETH from the registrar controller to its owner.
    function withdraw() external;
}
