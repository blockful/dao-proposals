// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { IRegistrarController } from "./IRegistrarController.sol";

/// @title RegistrarManager
/// @notice Manages a set of ENS registrar controllers, allowing batch withdrawal of accumulated
///         ETH and forwarding to a configurable destination address. Provides the owner with
///         arbitrary call access to each registrar for administrative operations
///         (e.g. transferOwnership, recoverFunds).
/// @dev Registrars are stored in a singly-linked list (sentinel pattern) for O(1) add and
///      gas-efficient enumeration. The sentinel address(0x1) is never a valid registrar.
contract RegistrarManager is Ownable {
    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error ZeroAddress();
    error InvalidRegistrar(address registrar);
    error RegistrarAlreadyExists(address registrar);
    error RegistrarNotFound(address registrar);
    error DestinationUnchanged();
    error ForwardFailed();

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /// @notice Emitted when the destination address is updated.
    /// @param previousDestination The old destination address.
    /// @param newDestination The new destination address.
    event DestinationUpdated(address indexed previousDestination, address indexed newDestination);

    /// @notice Emitted when a registrar is added to the managed set.
    /// @param registrar The registrar address that was added.
    event RegistrarAdded(address indexed registrar);

    /// @notice Emitted when a registrar is removed from the managed set.
    /// @param registrar The registrar address that was removed.
    event RegistrarRemoved(address indexed registrar);

    /// @notice Emitted for each registrar during `withdrawAll`, indicating success or failure.
    /// @param registrar The registrar address that was withdrawn from.
    /// @param success Whether the withdraw call succeeded.
    event RegistrarWithdrawn(address indexed registrar, bool success);

    /// @notice Emitted when an arbitrary call is executed on a registrar via `execOnRegistrar`.
    /// @param registrar The target registrar address.
    /// @param value The ETH value sent with the call.
    /// @param data The calldata forwarded to the registrar.
    /// @param success Whether the low-level call succeeded.
    event RegistrarCall(address indexed registrar, uint256 value, bytes data, bool success);

    /// @notice Emitted when the contract's ETH balance is forwarded to the destination.
    /// @param destination The address that received the funds.
    /// @param amount The amount of ETH forwarded.
    event FundsForwarded(address indexed destination, uint256 amount);

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    /// @dev Sentinel node for the linked list. Never a valid registrar.
    address private constant _HEAD = address(0x1);

    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------

    /// @notice Address that receives ETH after withdrawal.
    address public destination;

    /// @notice Number of registrars currently managed.
    uint256 public registrarCount;

    /// @dev Linked list: registrar -> next registrar. _HEAD is the sentinel.
    mapping(address registrar => address nextRegistrar) private _next;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /// @param owner_ Initial owner of the contract (typically a DAO timelock).
    /// @param destination_ Address that will receive forwarded ETH.
    constructor(address owner_, address destination_) Ownable(owner_) {
        if (destination_ == address(0)) revert ZeroAddress();
        destination = destination_;
        _next[_HEAD] = _HEAD;
    }

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------

    /// @notice Returns the full ordered list of managed registrars.
    /// @return registrars Array of registrar addresses.
    function getRegistrars() external view returns (address[] memory registrars) {
        registrars = new address[](registrarCount);
        address current = _next[_HEAD];
        for (uint256 i = 0; i < registrarCount; ++i) {
            registrars[i] = current;
            current = _next[current];
        }
    }

    /// @notice Checks whether an address is a managed registrar.
    /// @param registrar Address to check.
    /// @return True if the address is currently in the managed set.
    function isRegistrar(address registrar) public view returns (bool) {
        return registrar != _HEAD && _next[registrar] != address(0);
    }

    // -------------------------------------------------------------------------
    // Owner-only: Registrar management
    // -------------------------------------------------------------------------

    /// @notice Adds a registrar to the managed set.
    /// @param registrar Address of the registrar controller to add.
    function addRegistrar(address registrar) external onlyOwner {
        if (registrar == address(0)) revert ZeroAddress();
        if (registrar == _HEAD) revert InvalidRegistrar(registrar);
        if (isRegistrar(registrar)) revert RegistrarAlreadyExists(registrar);

        _next[registrar] = _next[_HEAD];
        _next[_HEAD] = registrar;
        ++registrarCount;

        emit RegistrarAdded(registrar);
    }

    /// @notice Removes a registrar from the managed set.
    /// @dev Traverses the linked list to find the previous node. The list is expected to be
    ///      small (handful of registrars), so the linear scan is acceptable.
    /// @param registrar Address of the registrar controller to remove.
    function removeRegistrar(address registrar) external onlyOwner {
        if (!isRegistrar(registrar)) revert RegistrarNotFound(registrar);

        address prev = _HEAD;
        while (_next[prev] != registrar) {
            prev = _next[prev];
        }

        _next[prev] = _next[registrar];
        delete _next[registrar];
        --registrarCount;

        emit RegistrarRemoved(registrar);
    }

    // -------------------------------------------------------------------------
    // Owner-only: Destination management
    // -------------------------------------------------------------------------

    /// @notice Updates the address that receives forwarded ETH.
    /// @param newDestination New destination address.
    function setDestination(address newDestination) external onlyOwner {
        if (newDestination == address(0)) revert ZeroAddress();
        if (newDestination == destination) revert DestinationUnchanged();

        address previousDestination = destination;
        destination = newDestination;

        emit DestinationUpdated(previousDestination, newDestination);
    }

    // -------------------------------------------------------------------------
    // Withdraw
    // -------------------------------------------------------------------------

    /// @notice Calls `withdraw()` on every managed registrar, then forwards the contract's
    ///         entire ETH balance to `destination`. Permissionless — anyone may trigger this.
    /// @dev Individual registrar withdrawals that revert are caught and logged; they do not
    ///      prevent the remaining registrars from being processed.
    function withdrawAll() external {
        address registrar = _next[_HEAD];
        while (registrar != _HEAD) {
            bool success = _withdrawRegistrar(registrar);
            emit RegistrarWithdrawn(registrar, success);
            registrar = _next[registrar];
        }
        _forwardBalance();
    }

    // -------------------------------------------------------------------------
    // Owner-only: Arbitrary registrar calls
    // -------------------------------------------------------------------------

    /// @notice Executes an arbitrary call on a managed registrar.
    /// @dev Does NOT revert on call failure — the caller can inspect the returned `success`
    ///      flag and `result` bytes. This is intentional: it allows the owner to observe
    ///      failure data without the entire transaction reverting.
    /// @param registrar Target registrar (must be in the managed set).
    /// @param value ETH value to send with the call.
    /// @param data Calldata to forward.
    /// @return success Whether the low-level call succeeded.
    /// @return result The raw bytes returned by the call.
    function execOnRegistrar(
        address registrar,
        uint256 value,
        bytes calldata data
    )
        external
        onlyOwner
        returns (bool success, bytes memory result)
    {
        if (!isRegistrar(registrar)) revert RegistrarNotFound(registrar);
        (success, result) = registrar.call{ value: value }(data);
        emit RegistrarCall(registrar, value, data, success);
    }

    // -------------------------------------------------------------------------
    // Receive
    // -------------------------------------------------------------------------

    /// @notice Allows the contract to receive ETH (e.g. from registrar withdrawals).
    receive() external payable { }

    // -------------------------------------------------------------------------
    // Internal
    // -------------------------------------------------------------------------

    /// @notice Attempts to call `withdraw()` on a registrar.
    /// @param registrar The registrar to call withdraw() on.
    /// @return True if the call succeeded, false if it reverted.
    function _withdrawRegistrar(address registrar) internal returns (bool) {
        try IRegistrarController(registrar).withdraw() {
            return true;
        } catch {
            return false;
        }
    }

    /// @notice Sends the contract's entire ETH balance to `destination`. No-ops if balance is zero.
    function _forwardBalance() internal {
        uint256 amount = address(this).balance;
        if (amount == 0) return;

        (bool success,) = destination.call{ value: amount }("");
        if (!success) revert ForwardFailed();

        emit FundsForwarded(destination, amount);
    }
}
