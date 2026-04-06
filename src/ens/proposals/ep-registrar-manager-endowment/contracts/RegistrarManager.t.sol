// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { RegistrarManager } from "./RegistrarManager.sol";

// ---------------------------------------------------------------------------
// Mock helpers
// ---------------------------------------------------------------------------

/// @dev A registrar controller that holds ETH and sends it to its owner on withdraw().
contract MockRegistrarController {
    address public owner;
    uint256 public value;

    error OnlyOwner();

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    function setOwner(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    function withdraw() external {
        uint256 bal = address(this).balance;
        if (bal > 0) {
            (bool ok,) = owner.call{ value: bal }("");
            require(ok, "MockRegistrarController: withdraw failed");
        }
    }

    /// @dev Owner-gated write function to simulate registrar controller admin operations.
    function setValue(uint256 newValue) external onlyOwner {
        value = newValue;
    }

    receive() external payable { }
}

/// @dev A registrar controller whose withdraw() always reverts.
contract RevertingRegistrarController {
    function withdraw() external pure {
        revert("I always revert");
    }

    receive() external payable { }
}

/// @dev A destination that rejects ETH transfers.
contract RejectingDestination {
    receive() external payable {
        revert("no ETH accepted");
    }
}

/// @dev A registrar controller that attempts re-entrancy on withdrawAll during withdraw().
contract ReentrantRegistrarController {
    RegistrarManager public target;

    constructor(RegistrarManager target_) {
        target = target_;
    }

    function withdraw() external {
        // Attempt to re-enter withdrawAll.
        // This should not cause issues because the linked list is not mutated during iteration.
        try target.withdrawAll() { } catch { }
    }

    receive() external payable { }
}

// ===========================================================================
//  Test Suite
// ===========================================================================

contract RegistrarManagerTest is Test {
    RegistrarManager internal manager;

    address internal owner = makeAddr("owner");
    address internal destination = makeAddr("destination");
    address internal alice = makeAddr("alice");

    function _emptyControllers() internal pure returns (address[] memory) {
        return new address[](0);
    }

    function setUp() public {
        manager = new RegistrarManager(owner, destination, _emptyControllers());
    }

    // =====================================================================
    //  Constructor
    // =====================================================================

    function test_constructor_setsOwnerAndDestination() public view {
        assertEq(manager.owner(), owner);
        assertEq(manager.destination(), destination);
        assertEq(manager.registrarControllerCount(), 0);

        address[] memory list = manager.getRegistrarControllers();
        assertEq(list.length, 0);
    }

    function test_constructor_revertsOnZeroDestination() public {
        vm.expectRevert(RegistrarManager.ZeroAddress.selector);
        new RegistrarManager(owner, address(0), _emptyControllers());
    }

    function test_constructor_withInitialControllers() public {
        address r1 = makeAddr("r1");
        address r2 = makeAddr("r2");

        address[] memory initial = new address[](2);
        initial[0] = r1;
        initial[1] = r2;

        RegistrarManager m = new RegistrarManager(owner, destination, initial);

        assertEq(m.registrarControllerCount(), 2);
        assertTrue(m.isRegistrarController(r1));
        assertTrue(m.isRegistrarController(r2));

        address[] memory list = m.getRegistrarControllers();
        assertEq(list.length, 2);
        // LIFO: last added is first
        assertEq(list[0], r2);
        assertEq(list[1], r1);
    }

    function test_constructor_revertsOnDuplicateInitialController() public {
        address r = makeAddr("dup");
        address[] memory initial = new address[](2);
        initial[0] = r;
        initial[1] = r;

        vm.expectRevert(abi.encodeWithSelector(RegistrarManager.RegistrarControllerAlreadyExists.selector, r));
        new RegistrarManager(owner, destination, initial);
    }

    // =====================================================================
    //  addRegistrarController
    // =====================================================================

    function test_addRegistrarController_single() public {
        address r = makeAddr("registrar1");

        vm.expectEmit();
        emit RegistrarManager.RegistrarControllerAdded(r);

        vm.prank(owner);
        manager.addRegistrarController(r);

        assertTrue(manager.isRegistrarController(r));
        assertEq(manager.registrarControllerCount(), 1);

        address[] memory list = manager.getRegistrarControllers();
        assertEq(list.length, 1);
        assertEq(list[0], r);
    }

    function test_addRegistrarController_multipleOrdering() public {
        address r1 = makeAddr("r1");
        address r2 = makeAddr("r2");
        address r3 = makeAddr("r3");

        vm.startPrank(owner);
        manager.addRegistrarController(r1);
        manager.addRegistrarController(r2);
        manager.addRegistrarController(r3);
        vm.stopPrank();

        assertEq(manager.registrarControllerCount(), 3);

        // LIFO: last added is first in list
        address[] memory list = manager.getRegistrarControllers();
        assertEq(list.length, 3);
        assertEq(list[0], r3);
        assertEq(list[1], r2);
        assertEq(list[2], r1);
    }

    function test_addRegistrarController_revertsOnZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(RegistrarManager.ZeroAddress.selector);
        manager.addRegistrarController(address(0));
    }

    function test_addRegistrarController_revertsOnSentinel() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(RegistrarManager.InvalidRegistrarController.selector, address(0x1)));
        manager.addRegistrarController(address(0x1));
    }

    function test_addRegistrarController_revertsOnDuplicate() public {
        address r = makeAddr("dup");

        vm.startPrank(owner);
        manager.addRegistrarController(r);
        vm.expectRevert(abi.encodeWithSelector(RegistrarManager.RegistrarControllerAlreadyExists.selector, r));
        manager.addRegistrarController(r);
        vm.stopPrank();
    }

    function test_addRegistrarController_revertsForNonOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        manager.addRegistrarController(makeAddr("r"));
    }

    // =====================================================================
    //  removeRegistrarController
    // =====================================================================

    function test_removeRegistrarController_headOfList() public {
        address r1 = makeAddr("r1");
        address r2 = makeAddr("r2");

        vm.startPrank(owner);
        manager.addRegistrarController(r1);
        manager.addRegistrarController(r2);
        // List: [r2, r1]. Remove r2 (head).

        vm.expectEmit();
        emit RegistrarManager.RegistrarControllerRemoved(r2);

        manager.removeRegistrarController(r2);
        vm.stopPrank();

        assertFalse(manager.isRegistrarController(r2));
        assertTrue(manager.isRegistrarController(r1));
        assertEq(manager.registrarControllerCount(), 1);

        address[] memory list = manager.getRegistrarControllers();
        assertEq(list.length, 1);
        assertEq(list[0], r1);
    }

    function test_removeRegistrarController_tailOfList() public {
        address r1 = makeAddr("r1");
        address r2 = makeAddr("r2");

        vm.startPrank(owner);
        manager.addRegistrarController(r1); // tail
        manager.addRegistrarController(r2); // head
        // List: [r2, r1]. Remove r1 (tail).
        manager.removeRegistrarController(r1);
        vm.stopPrank();

        assertFalse(manager.isRegistrarController(r1));
        assertTrue(manager.isRegistrarController(r2));
        assertEq(manager.registrarControllerCount(), 1);
    }

    function test_removeRegistrarController_middleOfList() public {
        address r1 = makeAddr("r1");
        address r2 = makeAddr("r2");
        address r3 = makeAddr("r3");

        vm.startPrank(owner);
        manager.addRegistrarController(r1);
        manager.addRegistrarController(r2);
        manager.addRegistrarController(r3);
        // List: [r3, r2, r1]. Remove r2 (middle).
        manager.removeRegistrarController(r2);
        vm.stopPrank();

        assertFalse(manager.isRegistrarController(r2));
        assertEq(manager.registrarControllerCount(), 2);

        address[] memory list = manager.getRegistrarControllers();
        assertEq(list[0], r3);
        assertEq(list[1], r1);
    }

    function test_removeRegistrarController_revertsOnNonExistent() public {
        address ghost = makeAddr("ghost");

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(RegistrarManager.RegistrarControllerNotFound.selector, ghost));
        manager.removeRegistrarController(ghost);
    }

    function test_removeRegistrarController_revertsForNonOwner() public {
        address r = makeAddr("r");
        vm.prank(owner);
        manager.addRegistrarController(r);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        manager.removeRegistrarController(r);
    }

    function test_addRemoveAdd_sameAddress() public {
        address r = makeAddr("recycle");

        vm.startPrank(owner);
        manager.addRegistrarController(r);
        assertTrue(manager.isRegistrarController(r));

        manager.removeRegistrarController(r);
        assertFalse(manager.isRegistrarController(r));
        assertEq(manager.registrarControllerCount(), 0);

        // Re-add
        manager.addRegistrarController(r);
        assertTrue(manager.isRegistrarController(r));
        assertEq(manager.registrarControllerCount(), 1);
        vm.stopPrank();
    }

    // =====================================================================
    //  isRegistrarController
    // =====================================================================

    function test_isRegistrarController_falseForZeroAndSentinel() public view {
        assertFalse(manager.isRegistrarController(address(0)));
        assertFalse(manager.isRegistrarController(address(0x1)));
    }

    function test_isRegistrarController_falseForUnknown() public view {
        assertFalse(manager.isRegistrarController(address(0xBEEF)));
    }

    // =====================================================================
    //  setDestination
    // =====================================================================

    function test_setDestination_updatesAndEmits() public {
        address newDest = makeAddr("newDest");

        vm.expectEmit();
        emit RegistrarManager.DestinationUpdated(destination, newDest);

        vm.prank(owner);
        manager.setDestination(newDest);

        assertEq(manager.destination(), newDest);
    }

    function test_setDestination_revertsOnZero() public {
        vm.prank(owner);
        vm.expectRevert(RegistrarManager.ZeroAddress.selector);
        manager.setDestination(address(0));
    }

    function test_setDestination_revertsOnSameValue() public {
        vm.prank(owner);
        vm.expectRevert(RegistrarManager.DestinationUnchanged.selector);
        manager.setDestination(destination);
    }

    function test_setDestination_revertsForNonOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        manager.setDestination(makeAddr("x"));
    }

    // =====================================================================
    //  withdrawAll
    // =====================================================================

    function test_withdrawAll_singleRegistrarController() public {
        MockRegistrarController r = new MockRegistrarController();
        r.setOwner(address(manager));
        vm.deal(address(r), 5 ether);

        vm.prank(owner);
        manager.addRegistrarController(address(r));

        uint256 destBefore = destination.balance;
        manager.withdrawAll();
        uint256 destAfter = destination.balance;

        assertEq(destAfter - destBefore, 5 ether);
    }

    function test_withdrawAll_multipleRegistrarControllers() public {
        MockRegistrarController r1 = new MockRegistrarController();
        MockRegistrarController r2 = new MockRegistrarController();
        r1.setOwner(address(manager));
        r2.setOwner(address(manager));
        vm.deal(address(r1), 3 ether);
        vm.deal(address(r2), 7 ether);

        vm.startPrank(owner);
        manager.addRegistrarController(address(r1));
        manager.addRegistrarController(address(r2));
        vm.stopPrank();

        uint256 destBefore = destination.balance;
        manager.withdrawAll();
        uint256 destAfter = destination.balance;

        assertEq(destAfter - destBefore, 10 ether);
    }

    function test_withdrawAll_revertingControllerDoesNotBlock() public {
        MockRegistrarController good = new MockRegistrarController();
        good.setOwner(address(manager));
        vm.deal(address(good), 2 ether);

        RevertingRegistrarController bad = new RevertingRegistrarController();
        vm.deal(address(bad), 1 ether);

        vm.startPrank(owner);
        manager.addRegistrarController(address(good));
        manager.addRegistrarController(address(bad));
        vm.stopPrank();

        // Expect RegistrarControllerWithdrawn(bad, false) for the reverting one
        vm.expectEmit();
        emit RegistrarManager.RegistrarControllerWithdrawn(address(bad), false);

        vm.expectEmit();
        emit RegistrarManager.RegistrarControllerWithdrawn(address(good), true);

        uint256 destBefore = destination.balance;
        manager.withdrawAll();
        uint256 destAfter = destination.balance;

        // Only the good controller's ETH was withdrawn. The bad one's ETH stays in the bad controller.
        assertEq(destAfter - destBefore, 2 ether);
    }

    function test_withdrawAll_noControllers_forwardsDirectETH() public {
        vm.deal(address(manager), 4 ether);

        uint256 destBefore = destination.balance;
        manager.withdrawAll();
        uint256 destAfter = destination.balance;

        assertEq(destAfter - destBefore, 4 ether);
    }

    function test_withdrawAll_zeroBalance_noOp() public {
        // No controllers, no balance — should succeed silently.
        manager.withdrawAll();
        assertEq(destination.balance, 0);
    }

    function test_withdrawAll_rejectsIfDestinationRefusesETH() public {
        RejectingDestination rejector = new RejectingDestination();
        RegistrarManager m = new RegistrarManager(owner, address(rejector), _emptyControllers());

        vm.deal(address(m), 1 ether);

        vm.expectRevert(RegistrarManager.ForwardFailed.selector);
        m.withdrawAll();
    }

    function test_withdrawAll_isPermissionless() public {
        MockRegistrarController r = new MockRegistrarController();
        r.setOwner(address(manager));
        vm.deal(address(r), 1 ether);

        vm.prank(owner);
        manager.addRegistrarController(address(r));

        // Called by alice (not owner) — should succeed.
        vm.prank(alice);
        manager.withdrawAll();

        assertEq(destination.balance, 1 ether);
    }

    function test_withdrawAll_forwardsControllerAndDirectETH() public {
        MockRegistrarController r = new MockRegistrarController();
        r.setOwner(address(manager));
        vm.deal(address(r), 3 ether);
        vm.deal(address(manager), 2 ether);

        vm.prank(owner);
        manager.addRegistrarController(address(r));

        uint256 destBefore = destination.balance;
        manager.withdrawAll();
        uint256 destAfter = destination.balance;

        // 3 from controller + 2 direct = 5
        assertEq(destAfter - destBefore, 5 ether);
    }

    function test_withdrawAll_emitsFundsForwarded() public {
        MockRegistrarController r = new MockRegistrarController();
        r.setOwner(address(manager));
        vm.deal(address(r), 1 ether);

        vm.prank(owner);
        manager.addRegistrarController(address(r));

        vm.expectEmit();
        emit RegistrarManager.FundsForwarded(destination, 1 ether);

        manager.withdrawAll();
    }

    function testFuzz_withdrawAll_randomAmounts(uint96 amount) public {
        vm.assume(amount > 0);

        MockRegistrarController r = new MockRegistrarController();
        r.setOwner(address(manager));
        vm.deal(address(r), amount);

        vm.prank(owner);
        manager.addRegistrarController(address(r));

        uint256 destBefore = destination.balance;
        manager.withdrawAll();
        uint256 destAfter = destination.balance;

        assertEq(destAfter - destBefore, amount);
    }

    // =====================================================================
    //  execOnRegistrarController
    // =====================================================================

    function test_execOnRegistrarController_ownerGatedCall() public {
        MockRegistrarController r = new MockRegistrarController();
        // Transfer controller ownership to the manager (realistic setup).
        r.setOwner(address(manager));

        vm.prank(owner);
        manager.addRegistrarController(address(r));

        // Use execOnRegistrarController to call an onlyOwner function on the controller.
        bytes memory data = abi.encodeWithSelector(MockRegistrarController.setValue.selector, 42);

        vm.prank(owner);
        manager.execOnRegistrarController(address(r), data);

        assertEq(r.value(), 42);
    }

    function test_execOnRegistrarController_controllerRejectsNonOwnerCaller() public {
        MockRegistrarController r = new MockRegistrarController();
        r.setOwner(address(manager));

        vm.prank(owner);
        manager.addRegistrarController(address(r));

        // Direct call from alice should fail — only the manager (owner of controller) can call.
        vm.prank(alice);
        vm.expectRevert(MockRegistrarController.OnlyOwner.selector);
        r.setValue(99);

        // But via execOnRegistrarController it works, because msg.sender to the controller is the manager.
        bytes memory data = abi.encodeWithSelector(MockRegistrarController.setValue.selector, 99);
        vm.prank(owner);
        manager.execOnRegistrarController(address(r), data);

        assertEq(r.value(), 99);
    }

    function test_execOnRegistrarController_failedCallReverts() public {
        MockRegistrarController r = new MockRegistrarController();

        vm.prank(owner);
        manager.addRegistrarController(address(r));

        // Call setValue without being the registrar's owner — the inner call reverts,
        // and execOnRegistrarController bubbles up the revert.
        bytes memory data = abi.encodeWithSelector(MockRegistrarController.setValue.selector, 42);

        vm.prank(owner);
        vm.expectRevert(MockRegistrarController.OnlyOwner.selector);
        manager.execOnRegistrarController(address(r), data);
    }

    function test_execOnRegistrarController_revertsIfNotController() public {
        address ghost = makeAddr("ghost");

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(RegistrarManager.RegistrarControllerNotFound.selector, ghost));
        manager.execOnRegistrarController(ghost, "");
    }

    function test_execOnRegistrarController_revertsForNonOwner() public {
        MockRegistrarController r = new MockRegistrarController();

        vm.prank(owner);
        manager.addRegistrarController(address(r));

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        manager.execOnRegistrarController(address(r), "");
    }

    function test_execOnRegistrarController_doesNotForwardETH() public {
        MockRegistrarController r = new MockRegistrarController();

        vm.prank(owner);
        manager.addRegistrarController(address(r));

        vm.deal(address(manager), 5 ether);

        vm.prank(owner);
        manager.execOnRegistrarController(address(r), "");

        // Contract balance is untouched — execOnRegistrarController never sends ETH
        assertEq(address(r).balance, 0);
        assertEq(address(manager).balance, 5 ether);
    }

    function test_execOnRegistrarController_emitsEvent() public {
        MockRegistrarController r = new MockRegistrarController();
        r.setOwner(address(manager));

        vm.prank(owner);
        manager.addRegistrarController(address(r));

        bytes memory data = abi.encodeWithSelector(MockRegistrarController.setValue.selector, 1);

        vm.expectEmit();
        emit RegistrarManager.RegistrarControllerCall(address(r), data);

        vm.prank(owner);
        manager.execOnRegistrarController(address(r), data);
    }

    // =====================================================================
    //  receive()
    // =====================================================================

    function test_receive_acceptsETH() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        (bool ok,) = address(manager).call{ value: 1 ether }("");
        assertTrue(ok);
        assertEq(address(manager).balance, 1 ether);
    }

    // =====================================================================
    //  Re-entrancy
    // =====================================================================

    function test_withdrawAll_reentrancyFromController() public {
        // A malicious controller that tries to re-enter withdrawAll.
        // The linked list is not mutated during iteration, so re-entrancy
        // should not corrupt state. The inner withdrawAll will simply
        // iterate the same list again and forward whatever balance exists.
        // The outer call will then forward 0 (already forwarded).
        ReentrantRegistrarController reentrant = new ReentrantRegistrarController(manager);

        vm.prank(owner);
        manager.addRegistrarController(address(reentrant));

        vm.deal(address(manager), 1 ether);

        // Should not revert.
        manager.withdrawAll();

        // All ETH should reach destination (possibly via inner or outer forward).
        assertEq(destination.balance, 1 ether);
        assertEq(address(manager).balance, 0);
    }

    // =====================================================================
    //  Edge: many registrar controllers
    // =====================================================================

    function test_withdrawAll_manyControllers() public {
        uint256 count = 20;
        uint256 totalETH = 0;

        vm.startPrank(owner);
        for (uint256 i = 0; i < count; i++) {
            MockRegistrarController r = new MockRegistrarController();
            r.setOwner(address(manager));
            uint256 amount = (i + 1) * 0.1 ether;
            vm.deal(address(r), amount);
            totalETH += amount;
            manager.addRegistrarController(address(r));
        }
        vm.stopPrank();

        assertEq(manager.registrarControllerCount(), count);

        uint256 destBefore = destination.balance;
        manager.withdrawAll();
        uint256 destAfter = destination.balance;

        assertEq(destAfter - destBefore, totalETH);
    }

    // =====================================================================
    //  Event: DestinationUpdated includes both old and new
    // =====================================================================

    function test_setDestination_eventIncludesPrevious() public {
        address dest2 = makeAddr("dest2");
        address dest3 = makeAddr("dest3");

        vm.startPrank(owner);

        vm.expectEmit();
        emit RegistrarManager.DestinationUpdated(destination, dest2);
        manager.setDestination(dest2);

        vm.expectEmit();
        emit RegistrarManager.DestinationUpdated(dest2, dest3);
        manager.setDestination(dest3);

        vm.stopPrank();
    }
}
