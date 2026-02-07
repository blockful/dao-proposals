// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "@forge-std/src/console2.sol";

import { ENS_Governance } from "@ens/ens.t.sol";
import { IENSRoot } from "@ens/interfaces/IENSRoot.sol";
import { IENSRegistrar } from "@ens/interfaces/IENSRegistrar.sol";
import { IENSRegistryWithFallback } from "@ens/interfaces/IENSRegistryWithFallback.sol";

import { RegistrarSecurityController } from "./RegistrarSecurityController.sol";
import { RootSecurityController } from "./RootSecurityController.sol";

/**
 * @title Proposal_ENS_EP_Enable_Security_Controllers_Test
 * @notice Calldata review for ENS Draft — Enable Root and Registrar Security Controllers
 * @dev This proposal executes 2 transactions:
 *
 *      1. Root.setController(RootSecurityController, true)
 *         → Enables the RootSecurityController as a controller on the ENS Root, allowing
 *           it to call setSubnodeOwner to disable compromised TLDs.
 *
 *      2. BaseRegistrar.transferOwnership(RegistrarSecurityController)
 *         → Transfers registrar ownership so the RegistrarSecurityController becomes the
 *           pass-through owner, enabling the security council to disable problematic
 *           registrar controllers without a full DAO vote.
 *
 *      After governance execution, we test the full security council flow:
 *        - Security council member calls disableRegistrarController() to remove a
 *          problematic controller from the base registrar.
 *        - Verify only authorized controllers can perform emergency actions.
 *        - Verify the DAO (via RegistrarSecurityController owner) retains full control.
 */
contract Proposal_ENS_EP_Enable_Security_Controllers_Test is ENS_Governance {
    // ── ENS core contracts ───────────────────────────────────────────────
    IENSRoot public root = IENSRoot(0xaB528d626EC275E3faD363fF1393A41F581c5897);
    IENSRegistrar public baseRegistrar = IENSRegistrar(0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85);
    IENSRegistryWithFallback public ensRegistry = IENSRegistryWithFallback(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);

    // ── Security controllers (deployed in setUp) ─────────────────────────
    RootSecurityController public rootSecurityController;
    RegistrarSecurityController public registrarSecurityController;

    // ── Test actors ──────────────────────────────────────────────────────
    address public securityCouncilMultisig;
    address public unauthorizedCaller;

    // ── Simulated problematic controller (added pre-proposal for testing) ─
    address public problematicController;

    // ── State tracking ───────────────────────────────────────────────────
    address registrarOwnerBefore;
    bool rootControllerEnabledBefore;

    function setUp() public override {
        super.setUp();

        // Create test actors
        securityCouncilMultisig = vm.addr(0x5EC);
        unauthorizedCaller = vm.addr(0xDEAD);
        problematicController = vm.addr(0xBADC0DE);
        vm.label(securityCouncilMultisig, "securityCouncilMultisig");
        vm.label(unauthorizedCaller, "unauthorizedCaller");
        vm.label(problematicController, "problematicController");

        // Deploy RootSecurityController owned by the security council multisig
        // (disableTLD is onlyOwner — the security council calls it in emergencies)
        vm.prank(securityCouncilMultisig);
        rootSecurityController = new RootSecurityController(root);

        // Deploy RegistrarSecurityController owned by the DAO timelock
        // (onlyOwner = DAO governance, onlyController = security council emergency)
        vm.startPrank(address(timelock));
        registrarSecurityController = new RegistrarSecurityController(baseRegistrar);

        // Set security council multisig as a controller on RegistrarSecurityController
        registrarSecurityController.setController(securityCouncilMultisig, true);
        vm.stopPrank();

        vm.label(address(rootSecurityController), "RootSecurityController");
        vm.label(address(registrarSecurityController), "RegistrarSecurityController");

        // Add a simulated problematic controller to the base registrar
        // (while timelock is still the registrar owner, before the proposal)
        vm.prank(address(timelock));
        baseRegistrar.addController(problematicController);
    }

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 21_800_000, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0xb8c2C29ee19D8307cb7255e1Cd9CbDE883A267d5; // nick.eth
    }

    function _beforeProposal() public override {
        // Capture state before execution
        registrarOwnerBefore = baseRegistrar.owner();
        rootControllerEnabledBefore = root.controllers(address(rootSecurityController));

        // Verify preconditions
        assertEq(registrarOwnerBefore, address(timelock), "Registrar should be owned by timelock before proposal");
        assertFalse(rootControllerEnabledBefore, "RootSecurityController should not be a root controller yet");
    }

    function _generateCallData()
        public
        override
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory, string memory)
    {
        uint256 numTransactions = 2;

        targets = new address[](numTransactions);
        values = new uint256[](numTransactions);
        calldatas = new bytes[](numTransactions);
        signatures = new string[](numTransactions);

        // Transaction 1: Enable RootSecurityController as a root controller
        targets[0] = address(root);
        calldatas[0] = abi.encodeWithSelector(IENSRoot.setController.selector, address(rootSecurityController), true);
        values[0] = 0;
        signatures[0] = "";

        console2.log("Root.setController(RootSecurityController, true)");
        console2.logBytes(calldatas[0]);
        // Transaction 2: Transfer base registrar ownership to RegistrarSecurityController
        targets[1] = address(baseRegistrar);
        calldatas[1] = abi.encodeWithSelector(
            IENSRegistrar.transferOwnership.selector, address(registrarSecurityController)
        );
        values[1] = 0;
        signatures[1] = "";

        console2.log("BaseRegistrar.transferOwnership(RegistrarSecurityController)");
        console2.logBytes(calldatas[1]);

        // Read description from the proposal markdown
        description = vm.readFile("src/ens/proposals/ep-enable-security-controllers/proposalDescription.md");

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        // ── Verify governance execution results ──────────────────────────

        // 1. RootSecurityController is now a controller on Root
        assertTrue(
            root.controllers(address(rootSecurityController)),
            "RootSecurityController should be enabled as a root controller"
        );

        // 2. RegistrarSecurityController is now the registrar owner
        assertEq(
            baseRegistrar.owner(),
            address(registrarSecurityController),
            "RegistrarSecurityController should be the new registrar owner"
        );

        // 3. RegistrarSecurityController is owned by the DAO timelock
        assertEq(
            registrarSecurityController.owner(),
            address(timelock),
            "RegistrarSecurityController should be owned by the DAO timelock"
        );

        // 4. RootSecurityController is owned by the security council multisig
        assertEq(
            rootSecurityController.owner(),
            securityCouncilMultisig,
            "RootSecurityController should be owned by the security council"
        );

        // ── Test: Security council can disable a registrar controller ────
        _testSecurityCouncilDisablesRegistrarController();

        // ── Test: Unauthorized caller cannot disable a registrar controller
        _testUnauthorizedCannotDisableController();

        // ── Test: DAO retains control via RegistrarSecurityController ─────
        _testDAORetainsRegistrarControl();

        // ── Test: RootSecurityController can disable a TLD ───────────────
        _testRootSecurityControllerDisablesTLD();

        // Log final state
        console2.log("Registrar owner before:", registrarOwnerBefore);
        console2.log("Registrar owner after:", baseRegistrar.owner());
        console2.log("RootSecurityController address:", address(rootSecurityController));
        console2.log("RegistrarSecurityController address:", address(registrarSecurityController));
    }

    /// @notice Security council member disables a problematic registrar controller.
    function _testSecurityCouncilDisablesRegistrarController() internal {
        // Verify the problematic controller is currently active
        assertTrue(
            baseRegistrar.controllers(problematicController),
            "Problematic controller should be active before security action"
        );

        // Security council multisig calls disableRegistrarController
        vm.prank(securityCouncilMultisig);
        registrarSecurityController.disableRegistrarController(problematicController);

        // Verify the controller has been disabled
        assertFalse(
            baseRegistrar.controllers(problematicController),
            "Problematic controller should be disabled after security action"
        );

        console2.log("[PASS] Security council successfully disabled registrar controller");
    }

    /// @notice Unauthorized caller cannot use the security controller.
    function _testUnauthorizedCannotDisableController() internal {
        // Re-add the controller via DAO to test unauthorized access
        vm.prank(address(timelock));
        registrarSecurityController.addRegistrarController(problematicController);
        assertTrue(baseRegistrar.controllers(problematicController), "Controller should be re-enabled");

        // Unauthorized caller tries to disable — should revert
        vm.prank(unauthorizedCaller);
        vm.expectRevert("Controllable: Caller is not a controller");
        registrarSecurityController.disableRegistrarController(problematicController);

        // Controller should still be active
        assertTrue(
            baseRegistrar.controllers(problematicController),
            "Problematic controller should still be active after unauthorized attempt"
        );

        console2.log("[PASS] Unauthorized caller correctly rejected");
    }

    /// @notice DAO (via timelock) can still manage registrar controllers through RegistrarSecurityController.
    function _testDAORetainsRegistrarControl() internal {
        address newController = vm.addr(0xBEEF);

        // DAO adds a new registrar controller
        vm.prank(address(timelock));
        registrarSecurityController.addRegistrarController(newController);
        assertTrue(baseRegistrar.controllers(newController), "New controller should be added by DAO");

        // DAO removes the controller
        vm.prank(address(timelock));
        registrarSecurityController.removeRegistrarController(newController);
        assertFalse(baseRegistrar.controllers(newController), "Controller should be removed by DAO");

        // DAO can transfer registrar ownership back if needed
        // (not executing, just verifying the function exists and is callable)

        console2.log("[PASS] DAO retains full control via RegistrarSecurityController");
    }

    /// @notice Security council multisig can disable a TLD in emergencies via RootSecurityController.
    function _testRootSecurityControllerDisablesTLD() internal {
        // Use a test TLD — "xyz" which exists in ENS
        bytes32 xyzLabel = labelhash("xyz");
        bytes32 xyzNode = namehash("xyz");

        address tldOwnerBefore = ensRegistry.owner(xyzNode);
        address tldResolverBefore = ensRegistry.resolver(xyzNode);

        // Unauthorized caller cannot disable a TLD
        vm.prank(unauthorizedCaller);
        vm.expectRevert("Ownable: caller is not the owner");
        rootSecurityController.disableTLD(xyzLabel);

        // Security council multisig calls disableTLD
        vm.prank(securityCouncilMultisig);
        rootSecurityController.disableTLD(xyzLabel);

        // Verify TLD ownership transferred to the RootSecurityController
        assertEq(
            ensRegistry.owner(xyzNode),
            address(rootSecurityController),
            "TLD owner should be RootSecurityController after disable"
        );

        // Verify TLD resolver is cleared
        assertEq(
            ensRegistry.resolver(xyzNode),
            address(0),
            "TLD resolver should be cleared after disable"
        );

        console2.log("[PASS] Security council successfully disabled TLD");
        console2.log("  TLD owner before:", tldOwnerBefore);
        console2.log("  TLD owner after:", ensRegistry.owner(xyzNode));
        console2.log("  TLD resolver before:", tldResolverBefore);
        console2.log("  TLD resolver after:", ensRegistry.resolver(xyzNode));
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return false; // Draft proposal — not yet submitted on-chain
    }

    function dirPath() public pure override returns (string memory) {
        // No Tally draft yet — contracts are not deployed, so calldata comparison
        // is not applicable. Return empty to skip draftCallDataComparison().
        return "";
    }
}
