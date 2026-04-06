// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { IRegistrarController } from "./IRegistrarController.sol";

/// @title RegistrarManager
/// @notice Manages a set of ENS registrar controllers, allowing batch withdrawal of accumulated
///         ETH and forwarding to a configurable destination address. Provides the owner with
///         arbitrary call access to each registrar controller for administrative operations
///         (e.g. transferOwnership, recoverFunds).
/// @dev Registrar controllers are stored in a singly-linked list (sentinel pattern) for O(1) add
///      and gas-efficient enumeration. The sentinel address(0x1) is never a valid entry.
contract RegistrarManager is Ownable {
    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error ZeroAddress();
    error InvalidRegistrarController(address registrarController);
    error RegistrarControllerAlreadyExists(address registrarController);
    error RegistrarControllerNotFound(address registrarController);
    error DestinationUnchanged();
    error ForwardFailed();

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /// @notice Emitted when the destination address is updated.
    /// @param previousDestination The old destination address.
    /// @param newDestination The new destination address.
    event DestinationUpdated(address indexed previousDestination, address indexed newDestination);

    /// @notice Emitted when a registrar controller is added to the managed set.
    /// @param registrarController The registrar controller address that was added.
    event RegistrarControllerAdded(address indexed registrarController);

    /// @notice Emitted when a registrar controller is removed from the managed set.
    /// @param registrarController The registrar controller address that was removed.
    event RegistrarControllerRemoved(address indexed registrarController);

    /// @notice Emitted for each registrar controller during `withdrawAll`, indicating success or failure.
    /// @param registrarController The registrar controller address that was withdrawn from.
    /// @param success Whether the withdraw call succeeded.
    event RegistrarControllerWithdrawn(address indexed registrarController, bool success);

    /// @notice Emitted when an arbitrary call is executed on a registrar controller via `execOnRegistrarController`.
    /// @param registrarController The target registrar controller address.
    /// @param data The calldata forwarded to the registrar controller.
    event RegistrarControllerCall(address indexed registrarController, bytes data);

    /// @notice Emitted when the contract's ETH balance is forwarded to the destination.
    /// @param destination The address that received the funds.
    /// @param amount The amount of ETH forwarded.
    event FundsForwarded(address indexed destination, uint256 amount);

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    /// @dev Sentinel node for the linked list. Never a valid registrar controller.
    address private constant _HEAD = address(0x1);

    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------

    /// @notice Address that receives ETH after withdrawal.
    address public destination;

    /// @notice Number of registrar controllers currently managed.
    uint256 public registrarControllerCount;

    /// @dev Linked list: registrarController -> next registrarController. _HEAD is the sentinel.
    mapping(address registrarController => address nextRegistrarController) private _next;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /// @param owner_ Initial owner of the contract (typically a DAO timelock).
    /// @param destination_ Address that will receive forwarded ETH.
    /// @param initialControllers Registrar controller addresses to add at deployment.
    constructor(
        address owner_,
        address destination_,
        address[] memory initialControllers
    ) Ownable(owner_) {
        if (destination_ == address(0)) revert ZeroAddress();
        destination = destination_;
        _next[_HEAD] = _HEAD;

        for (uint256 i = 0; i < initialControllers.length; ++i) {
            _addRegistrarController(initialControllers[i]);
        }
    }

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------

    /// @notice Returns the full ordered list of managed registrar controllers.
    /// @return controllers Array of registrar controller addresses.
    function getRegistrarControllers() external view returns (address[] memory controllers) {
        controllers = new address[](registrarControllerCount);
        address current = _next[_HEAD];
        for (uint256 i = 0; i < registrarControllerCount; ++i) {
            controllers[i] = current;
            current = _next[current];
        }
    }

    /// @notice Checks whether an address is a managed registrar controller.
    /// @param registrarController Address to check.
    /// @return True if the address is currently in the managed set.
    function isRegistrarController(address registrarController) public view returns (bool) {
        return registrarController != _HEAD && _next[registrarController] != address(0);
    }

    // -------------------------------------------------------------------------
    // Owner-only: Registrar controller management
    // -------------------------------------------------------------------------

    /// @notice Adds a registrar controller to the managed set.
    /// @param registrarController Address of the registrar controller to add.
    function addRegistrarController(address registrarController) external onlyOwner {
        _addRegistrarController(registrarController);
    }

    /// @notice Removes a registrar controller from the managed set.
    /// @dev Traverses the linked list to find the previous node. The list is expected to be
    ///      small (handful of registrar controllers), so the linear scan is acceptable.
    /// @param registrarController Address of the registrar controller to remove.
    function removeRegistrarController(address registrarController) external onlyOwner {
        if (!isRegistrarController(registrarController)) revert RegistrarControllerNotFound(registrarController);

        address prev = _HEAD;
        while (_next[prev] != registrarController) {
            prev = _next[prev];
        }

        _next[prev] = _next[registrarController];
        delete _next[registrarController];
        --registrarControllerCount;

        emit RegistrarControllerRemoved(registrarController);
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

    /// @notice Calls `withdraw()` on every managed registrar controller, then forwards the
    ///         contract's entire ETH balance to `destination`. Permissionless — anyone may
    ///         trigger this.
    /// @dev Individual registrar controller withdrawals that revert are caught and logged; they
    ///      do not prevent the remaining controllers from being processed.
    function withdrawAll() external {
        address controller = _next[_HEAD];
        while (controller != _HEAD) {
            bool success = _withdrawRegistrarController(controller);
            emit RegistrarControllerWithdrawn(controller, success);
            controller = _next[controller];
        }
        _forwardBalance();
    }

    // -------------------------------------------------------------------------
    // Owner-only: Arbitrary registrar controller calls
    // -------------------------------------------------------------------------

    /// @notice Executes an arbitrary call on a managed registrar controller.
    /// @dev Reverts on call failure, bubbling up the original revert reason. This ensures that
    ///      when called as part of a governance proposal, a failed controller call causes the
    ///      entire proposal to revert rather than leaving the system in an inconsistent state.
    /// @param registrarController Target registrar controller (must be in the managed set).
    /// @param data Calldata to forward.
    /// @return result The raw bytes returned by the call.
    function execOnRegistrarController(
        address registrarController,
        bytes calldata data
    )
        external
        onlyOwner
        returns (bytes memory result)
    {
        if (!isRegistrarController(registrarController)) revert RegistrarControllerNotFound(registrarController);

        bool success;
        (success, result) = registrarController.call(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }

        emit RegistrarControllerCall(registrarController, data);
    }

    // -------------------------------------------------------------------------
    // Receive
    // -------------------------------------------------------------------------

    /// @notice Allows the contract to receive ETH (e.g. from registrar controller withdrawals).
    receive() external payable { }

    // -------------------------------------------------------------------------
    // Internal
    // -------------------------------------------------------------------------

    /// @notice Adds a registrar controller to the managed set (used by constructor and external setter).
    function _addRegistrarController(address registrarController) internal {
        if (registrarController == address(0)) revert ZeroAddress();
        if (registrarController == _HEAD) revert InvalidRegistrarController(registrarController);
        if (isRegistrarController(registrarController)) revert RegistrarControllerAlreadyExists(registrarController);

        _next[registrarController] = _next[_HEAD];
        _next[_HEAD] = registrarController;
        ++registrarControllerCount;

        emit RegistrarControllerAdded(registrarController);
    }

    /// @notice Attempts to call `withdraw()` on a registrar controller.
    /// @param controller The registrar controller to call withdraw() on.
    /// @return True if the call succeeded, false if it reverted.
    function _withdrawRegistrarController(address controller) internal returns (bool) {
        try IRegistrarController(controller).withdraw() {
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
