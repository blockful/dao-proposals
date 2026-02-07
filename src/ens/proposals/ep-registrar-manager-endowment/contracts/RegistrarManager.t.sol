// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { RegistrarManager } from "./RegistrarManager.sol";

// ---------------------------------------------------------------------------
// Mock helpers
// ---------------------------------------------------------------------------

/// @dev A registrar that holds ETH and sends it to its owner on withdraw().
contract MockRegistrar {
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
            require(ok, "MockRegistrar: withdraw failed");
        }
    }

    /// @dev Owner-gated write function to simulate registrar admin operations.
    function setValue(uint256 newValue) external onlyOwner {
        value = newValue;
    }

    receive() external payable { }
}

/// @dev A registrar whose withdraw() always reverts.
contract RevertingRegistrar {
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

/// @dev A registrar that attempts re-entrancy on withdrawAll during withdraw().
contract ReentrantRegistrar {
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

    function setUp() public {
        manager = new RegistrarManager(owner, destination);
    }

    // =====================================================================
    //  Constructor
    // =====================================================================

    function test_constructor_setsOwnerAndDestination() public view {
        assertEq(manager.owner(), owner);
        assertEq(manager.destination(), destination);
        assertEq(manager.registrarCount(), 0);

        address[] memory list = manager.getRegistrars();
        assertEq(list.length, 0);
    }

    function test_constructor_revertsOnZeroDestination() public {
        vm.expectRevert(RegistrarManager.ZeroAddress.selector);
        new RegistrarManager(owner, address(0));
    }

    // =====================================================================
    //  addRegistrar
    // =====================================================================

    function test_addRegistrar_single() public {
        address r = makeAddr("registrar1");

        vm.expectEmit();
        emit RegistrarManager.RegistrarAdded(r);

        vm.prank(owner);
        manager.addRegistrar(r);

        assertTrue(manager.isRegistrar(r));
        assertEq(manager.registrarCount(), 1);

        address[] memory list = manager.getRegistrars();
        assertEq(list.length, 1);
        assertEq(list[0], r);
    }

    function test_addRegistrar_multipleOrdering() public {
        address r1 = makeAddr("r1");
        address r2 = makeAddr("r2");
        address r3 = makeAddr("r3");

        vm.startPrank(owner);
        manager.addRegistrar(r1);
        manager.addRegistrar(r2);
        manager.addRegistrar(r3);
        vm.stopPrank();

        assertEq(manager.registrarCount(), 3);

        // LIFO: last added is first in list
        address[] memory list = manager.getRegistrars();
        assertEq(list.length, 3);
        assertEq(list[0], r3);
        assertEq(list[1], r2);
        assertEq(list[2], r1);
    }

    function test_addRegistrar_revertsOnZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(RegistrarManager.ZeroAddress.selector);
        manager.addRegistrar(address(0));
    }

    function test_addRegistrar_revertsOnSentinel() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(RegistrarManager.InvalidRegistrar.selector, address(0x1)));
        manager.addRegistrar(address(0x1));
    }

    function test_addRegistrar_revertsOnDuplicate() public {
        address r = makeAddr("dup");

        vm.startPrank(owner);
        manager.addRegistrar(r);
        vm.expectRevert(abi.encodeWithSelector(RegistrarManager.RegistrarAlreadyExists.selector, r));
        manager.addRegistrar(r);
        vm.stopPrank();
    }

    function test_addRegistrar_revertsForNonOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        manager.addRegistrar(makeAddr("r"));
    }

    // =====================================================================
    //  removeRegistrar
    // =====================================================================

    function test_removeRegistrar_headOfList() public {
        address r1 = makeAddr("r1");
        address r2 = makeAddr("r2");

        vm.startPrank(owner);
        manager.addRegistrar(r1);
        manager.addRegistrar(r2);
        // List: [r2, r1]. Remove r2 (head).

        vm.expectEmit();
        emit RegistrarManager.RegistrarRemoved(r2);

        manager.removeRegistrar(r2);
        vm.stopPrank();

        assertFalse(manager.isRegistrar(r2));
        assertTrue(manager.isRegistrar(r1));
        assertEq(manager.registrarCount(), 1);

        address[] memory list = manager.getRegistrars();
        assertEq(list.length, 1);
        assertEq(list[0], r1);
    }

    function test_removeRegistrar_tailOfList() public {
        address r1 = makeAddr("r1");
        address r2 = makeAddr("r2");

        vm.startPrank(owner);
        manager.addRegistrar(r1); // tail
        manager.addRegistrar(r2); // head
        // List: [r2, r1]. Remove r1 (tail).
        manager.removeRegistrar(r1);
        vm.stopPrank();

        assertFalse(manager.isRegistrar(r1));
        assertTrue(manager.isRegistrar(r2));
        assertEq(manager.registrarCount(), 1);
    }

    function test_removeRegistrar_middleOfList() public {
        address r1 = makeAddr("r1");
        address r2 = makeAddr("r2");
        address r3 = makeAddr("r3");

        vm.startPrank(owner);
        manager.addRegistrar(r1);
        manager.addRegistrar(r2);
        manager.addRegistrar(r3);
        // List: [r3, r2, r1]. Remove r2 (middle).
        manager.removeRegistrar(r2);
        vm.stopPrank();

        assertFalse(manager.isRegistrar(r2));
        assertEq(manager.registrarCount(), 2);

        address[] memory list = manager.getRegistrars();
        assertEq(list[0], r3);
        assertEq(list[1], r1);
    }

    function test_removeRegistrar_revertsOnNonExistent() public {
        address ghost = makeAddr("ghost");

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(RegistrarManager.RegistrarNotFound.selector, ghost));
        manager.removeRegistrar(ghost);
    }

    function test_removeRegistrar_revertsForNonOwner() public {
        address r = makeAddr("r");
        vm.prank(owner);
        manager.addRegistrar(r);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        manager.removeRegistrar(r);
    }

    function test_addRemoveAdd_sameAddress() public {
        address r = makeAddr("recycle");

        vm.startPrank(owner);
        manager.addRegistrar(r);
        assertTrue(manager.isRegistrar(r));

        manager.removeRegistrar(r);
        assertFalse(manager.isRegistrar(r));
        assertEq(manager.registrarCount(), 0);

        // Re-add
        manager.addRegistrar(r);
        assertTrue(manager.isRegistrar(r));
        assertEq(manager.registrarCount(), 1);
        vm.stopPrank();
    }

    // =====================================================================
    //  isRegistrar
    // =====================================================================

    function test_isRegistrar_falseForZeroAndSentinel() public view {
        assertFalse(manager.isRegistrar(address(0)));
        assertFalse(manager.isRegistrar(address(0x1)));
    }

    function test_isRegistrar_falseForUnknown() public view {
        assertFalse(manager.isRegistrar(address(0xBEEF)));
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

    function test_withdrawAll_singleRegistrar() public {
        MockRegistrar r = new MockRegistrar();
        r.setOwner(address(manager));
        vm.deal(address(r), 5 ether);

        vm.prank(owner);
        manager.addRegistrar(address(r));

        uint256 destBefore = destination.balance;
        manager.withdrawAll();
        uint256 destAfter = destination.balance;

        assertEq(destAfter - destBefore, 5 ether);
    }

    function test_withdrawAll_multipleRegistrars() public {
        MockRegistrar r1 = new MockRegistrar();
        MockRegistrar r2 = new MockRegistrar();
        r1.setOwner(address(manager));
        r2.setOwner(address(manager));
        vm.deal(address(r1), 3 ether);
        vm.deal(address(r2), 7 ether);

        vm.startPrank(owner);
        manager.addRegistrar(address(r1));
        manager.addRegistrar(address(r2));
        vm.stopPrank();

        uint256 destBefore = destination.balance;
        manager.withdrawAll();
        uint256 destAfter = destination.balance;

        assertEq(destAfter - destBefore, 10 ether);
    }

    function test_withdrawAll_revertingRegistrarDoesNotBlock() public {
        MockRegistrar good = new MockRegistrar();
        good.setOwner(address(manager));
        vm.deal(address(good), 2 ether);

        RevertingRegistrar bad = new RevertingRegistrar();
        vm.deal(address(bad), 1 ether);

        vm.startPrank(owner);
        manager.addRegistrar(address(good));
        manager.addRegistrar(address(bad));
        vm.stopPrank();

        // Expect RegistrarWithdrawn(bad, false) for the reverting one
        vm.expectEmit();
        emit RegistrarManager.RegistrarWithdrawn(address(bad), false);

        vm.expectEmit();
        emit RegistrarManager.RegistrarWithdrawn(address(good), true);

        uint256 destBefore = destination.balance;
        manager.withdrawAll();
        uint256 destAfter = destination.balance;

        // Only the good registrar's ETH was withdrawn. The bad registrar's ETH stays in the bad registrar.
        assertEq(destAfter - destBefore, 2 ether);
    }

    function test_withdrawAll_noRegistrars_forwardsDirectETH() public {
        vm.deal(address(manager), 4 ether);

        uint256 destBefore = destination.balance;
        manager.withdrawAll();
        uint256 destAfter = destination.balance;

        assertEq(destAfter - destBefore, 4 ether);
    }

    function test_withdrawAll_zeroBalance_noOp() public {
        // No registrars, no balance — should succeed silently.
        manager.withdrawAll();
        assertEq(destination.balance, 0);
    }

    function test_withdrawAll_rejectsIfDestinationRefusesETH() public {
        RejectingDestination rejector = new RejectingDestination();
        RegistrarManager m = new RegistrarManager(owner, address(rejector));

        vm.deal(address(m), 1 ether);

        vm.expectRevert(RegistrarManager.ForwardFailed.selector);
        m.withdrawAll();
    }

    function test_withdrawAll_isPermissionless() public {
        MockRegistrar r = new MockRegistrar();
        r.setOwner(address(manager));
        vm.deal(address(r), 1 ether);

        vm.prank(owner);
        manager.addRegistrar(address(r));

        // Called by alice (not owner) — should succeed.
        vm.prank(alice);
        manager.withdrawAll();

        assertEq(destination.balance, 1 ether);
    }

    function test_withdrawAll_forwardsRegistrarAndDirectETH() public {
        MockRegistrar r = new MockRegistrar();
        r.setOwner(address(manager));
        vm.deal(address(r), 3 ether);
        vm.deal(address(manager), 2 ether);

        vm.prank(owner);
        manager.addRegistrar(address(r));

        uint256 destBefore = destination.balance;
        manager.withdrawAll();
        uint256 destAfter = destination.balance;

        // 3 from registrar + 2 direct = 5
        assertEq(destAfter - destBefore, 5 ether);
    }

    function test_withdrawAll_emitsFundsForwarded() public {
        MockRegistrar r = new MockRegistrar();
        r.setOwner(address(manager));
        vm.deal(address(r), 1 ether);

        vm.prank(owner);
        manager.addRegistrar(address(r));

        vm.expectEmit();
        emit RegistrarManager.FundsForwarded(destination, 1 ether);

        manager.withdrawAll();
    }

    function testFuzz_withdrawAll_randomAmounts(uint96 amount) public {
        vm.assume(amount > 0);

        MockRegistrar r = new MockRegistrar();
        r.setOwner(address(manager));
        vm.deal(address(r), amount);

        vm.prank(owner);
        manager.addRegistrar(address(r));

        uint256 destBefore = destination.balance;
        manager.withdrawAll();
        uint256 destAfter = destination.balance;

        assertEq(destAfter - destBefore, amount);
    }

    // =====================================================================
    //  execOnRegistrar
    // =====================================================================

    function test_execOnRegistrar_ownerGatedCall() public {
        MockRegistrar r = new MockRegistrar();
        // Transfer registrar ownership to the manager (realistic setup).
        r.setOwner(address(manager));

        vm.prank(owner);
        manager.addRegistrar(address(r));

        // Use execOnRegistrar to call an onlyOwner function on the registrar.
        bytes memory data = abi.encodeWithSelector(MockRegistrar.setValue.selector, 42);

        vm.prank(owner);
        (bool success,) = manager.execOnRegistrar(address(r), 0, data);

        assertTrue(success);
        assertEq(r.value(), 42);
    }

    function test_execOnRegistrar_registrarRejectsNonOwnerCaller() public {
        MockRegistrar r = new MockRegistrar();
        r.setOwner(address(manager));

        vm.prank(owner);
        manager.addRegistrar(address(r));

        // Direct call from alice should fail — only the manager (owner of registrar) can call.
        vm.prank(alice);
        vm.expectRevert(MockRegistrar.OnlyOwner.selector);
        r.setValue(99);

        // But via execOnRegistrar it works, because msg.sender to the registrar is the manager.
        bytes memory data = abi.encodeWithSelector(MockRegistrar.setValue.selector, 99);
        vm.prank(owner);
        (bool success,) = manager.execOnRegistrar(address(r), 0, data);

        assertTrue(success);
        assertEq(r.value(), 99);
    }

    function test_execOnRegistrar_failedCallDoesNotRevert() public {
        MockRegistrar r = new MockRegistrar();

        vm.prank(owner);
        manager.addRegistrar(address(r));

        // Call a non-existent selector — will fail but should not revert the outer tx.
        bytes memory data = abi.encodeWithSelector(bytes4(0xdeadbeef));

        vm.prank(owner);
        (bool success,) = manager.execOnRegistrar(address(r), 0, data);

        assertFalse(success);
    }

    function test_execOnRegistrar_revertsIfNotRegistrar() public {
        address ghost = makeAddr("ghost");

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(RegistrarManager.RegistrarNotFound.selector, ghost));
        manager.execOnRegistrar(ghost, 0, "");
    }

    function test_execOnRegistrar_revertsForNonOwner() public {
        MockRegistrar r = new MockRegistrar();

        vm.prank(owner);
        manager.addRegistrar(address(r));

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        manager.execOnRegistrar(address(r), 0, "");
    }

    function test_execOnRegistrar_forwardsETH() public {
        MockRegistrar r = new MockRegistrar();

        vm.prank(owner);
        manager.addRegistrar(address(r));

        vm.deal(address(manager), 1 ether);

        vm.prank(owner);
        (bool success,) = manager.execOnRegistrar(address(r), 0.5 ether, "");

        assertTrue(success);
        assertEq(address(r).balance, 0.5 ether);
    }

    function test_execOnRegistrar_emitsEvent() public {
        MockRegistrar r = new MockRegistrar();
        r.setOwner(address(manager));

        vm.prank(owner);
        manager.addRegistrar(address(r));

        bytes memory data = abi.encodeWithSelector(MockRegistrar.setValue.selector, 1);

        vm.expectEmit();
        emit RegistrarManager.RegistrarCall(address(r), 0, data, true);

        vm.prank(owner);
        manager.execOnRegistrar(address(r), 0, data);
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

    function test_withdrawAll_reentrancyFromRegistrar() public {
        // A malicious registrar that tries to re-enter withdrawAll.
        // The linked list is not mutated during iteration, so re-entrancy
        // should not corrupt state. The inner withdrawAll will simply
        // iterate the same list again and forward whatever balance exists.
        // The outer call will then forward 0 (already forwarded).
        ReentrantRegistrar reentrant = new ReentrantRegistrar(manager);

        vm.prank(owner);
        manager.addRegistrar(address(reentrant));

        vm.deal(address(manager), 1 ether);

        // Should not revert.
        manager.withdrawAll();

        // All ETH should reach destination (possibly via inner or outer forward).
        assertEq(destination.balance, 1 ether);
        assertEq(address(manager).balance, 0);
    }

    // =====================================================================
    //  Edge: many registrars
    // =====================================================================

    function test_withdrawAll_manyRegistrars() public {
        uint256 count = 20;
        uint256 totalETH = 0;

        vm.startPrank(owner);
        for (uint256 i = 0; i < count; i++) {
            MockRegistrar r = new MockRegistrar();
            r.setOwner(address(manager));
            uint256 amount = (i + 1) * 0.1 ether;
            vm.deal(address(r), amount);
            totalETH += amount;
            manager.addRegistrar(address(r));
        }
        vm.stopPrank();

        assertEq(manager.registrarCount(), count);

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
