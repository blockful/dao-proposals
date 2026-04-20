// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { ENS_Governance } from "@ens/ens.t.sol";
import { IENSRegistrar } from "@ens/interfaces/IENSRegistrar.sol";
import { IENSRegistryWithFallback } from "@ens/interfaces/IENSRegistryWithFallback.sol";

interface IRegistrarSecurityController {
    function addRegistrarController(address controller) external;
    function removeRegistrarController(address controller) external;
    function owner() external view returns (address);
}

/**
 * @title Proposal_ENS_EP_6_36_Test
 * @notice Calldata review for ENS EP 6.36 — Register on.eth to ENS DAO wallet and set resolver
 * @dev This is a re-submission of EP 6.34, updated to account for the new ownership model
 *      introduced by EP 6.33 (Enable Root and Registrar Security Controllers).
 *
 *      The proposal executes 4 transactions:
 *
 *      1. RegistrarSecurityController.addRegistrarController(timelock)
 *         — Grants the DAO timelock controller permissions on the BaseRegistrar
 *
 *      2. BaseRegistrar.register(labelhash("on"), timelock, 315360000)
 *         — Registers "on.eth" to the DAO wallet for ~10 years
 *
 *      3. ENSRegistry.setResolver(namehash("on.eth"), ChainResolver)
 *         — Sets the Chain Registry-Resolver as the resolver for on.eth
 *
 *      4. RegistrarSecurityController.removeRegistrarController(timelock)
 *         — Revokes the temporary controller permissions granted in step 1
 *
 *      Key security property: the timelock is only a registrar controller
 *      transiently (steps 1-4 execute atomically within the same proposal).
 */
contract Proposal_ENS_EP_6_36_Test is ENS_Governance {
    // ── Contracts
    // ──────────────────────────────────────────────────────
    IRegistrarSecurityController public constant registrarSecurityController =
        IRegistrarSecurityController(0x7dd4d97653A67C2FD7fbA0a84825eC09524D4E1b);
    IENSRegistrar public constant baseRegistrar = IENSRegistrar(0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85);
    IENSRegistryWithFallback public constant ensRegistry =
        IENSRegistryWithFallback(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);

    // ── Constants
    // ──────────────────────────────────────────────────────
    address public constant DAO_WALLET = 0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7; // ENS Timelock
    address public constant CHAIN_RESOLVER = 0x2a9B5787207863cf2d63d20172ed1F7bB2c9487A;
    uint256 public constant REGISTRATION_DURATION = 315_360_000; // ~10 years

    // ── Derived hashes
    // ─────────────────────────────────────────────────
    bytes32 public onLabelhash;
    bytes32 public onNode;

    // ── State captured before execution
    // ────────────────────────────────
    bool public timelockIsControllerBefore;
    address public onOwnerBefore;
    address public onResolverBefore;

    function setUp() public override {
        super.setUp();

        onLabelhash = labelhash("on");
        onNode = namehash("on.eth");

        uint256 threshold = governor.proposalThreshold();
        uint256 proposerVotes = ensToken.getVotes(proposer);

        if (proposerVotes < threshold) {
            uint256 neededVotes = threshold - proposerVotes;
            vm.prank(address(timelock));
            ensToken.transfer(proposer, neededVotes);
            vm.prank(proposer);
            ensToken.delegate(proposer);
            vm.roll(block.number + 1);
            vm.warp(block.timestamp + 12);
        }
    }

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 24_569_499, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0xAC50cE326de14dDF9b7e9611Cd2F33a1Af8aC039; // clowes.eth
    }

    function _beforeProposal() public override {
        // RegistrarSecurityController should own the BaseRegistrar (set by EP 6.33)
        assertEq(
            baseRegistrar.owner(),
            address(registrarSecurityController),
            "RegistrarSecurityController should own the BaseRegistrar"
        );

        // RegistrarSecurityController should be owned by the DAO timelock
        assertEq(
            registrarSecurityController.owner(),
            address(timelock),
            "RegistrarSecurityController should be owned by the timelock"
        );

        // Timelock should NOT be a registrar controller before the proposal
        timelockIsControllerBefore = baseRegistrar.controllers(DAO_WALLET);
        assertFalse(timelockIsControllerBefore, "Timelock should not be a registrar controller before proposal");

        // ChainResolver should be deployed
        assertGt(CHAIN_RESOLVER.code.length, 0, "ChainResolver should be deployed");

        // Capture on.eth state before
        onOwnerBefore = ensRegistry.owner(onNode);
        onResolverBefore = ensRegistry.resolver(onNode);

        // Verify labelhash("on") matches expected value from calldata
        assertEq(
            onLabelhash, 0x6460d40e0362f6a2c743f205df8181010b7f26e76d5606847fb7be7fb6d135f9, "labelhash('on') mismatch"
        );

        // Verify namehash("on.eth") matches expected value from calldata
        assertEq(
            onNode, 0xcabf8262fe531c2a7e8cd86e06342bc27fc0591ecd562fbac88280abc18ef899, "namehash('on.eth') mismatch"
        );
    }

    function _generateCallData()
        public
        override
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory, string memory)
    {
        uint256 numTransactions = 4;

        targets = new address[](numTransactions);
        values = new uint256[](numTransactions);
        calldatas = new bytes[](numTransactions);
        signatures = new string[](numTransactions);

        // TX1: Add DAO wallet as a controller on BaseRegistrar via RegistrarSecurityController
        targets[0] = address(registrarSecurityController);
        values[0] = 0;
        signatures[0] = "";
        calldatas[0] = abi.encodeWithSelector(IRegistrarSecurityController.addRegistrarController.selector, DAO_WALLET);

        // TX2: Register "on.eth" to the DAO wallet for ~10 years
        targets[1] = address(baseRegistrar);
        values[1] = 0;
        signatures[1] = "";
        calldatas[1] =
            abi.encodeWithSelector(IENSRegistrar.register.selector, onLabelhash, DAO_WALLET, REGISTRATION_DURATION);

        // TX3: Set the ChainResolver as the resolver for on.eth
        targets[2] = address(ensRegistry);
        values[2] = 0;
        signatures[2] = "";
        calldatas[2] = abi.encodeWithSelector(IENSRegistryWithFallback.setResolver.selector, onNode, CHAIN_RESOLVER);

        // TX4: Remove DAO wallet as controller on BaseRegistrar via RegistrarSecurityController
        targets[3] = address(registrarSecurityController);
        values[3] = 0;
        signatures[3] = "";
        calldatas[3] =
            abi.encodeWithSelector(IRegistrarSecurityController.removeRegistrarController.selector, DAO_WALLET);

        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        // 1. Timelock should NOT be a registrar controller after execution
        assertFalse(
            baseRegistrar.controllers(DAO_WALLET), "Timelock should not be a registrar controller after proposal"
        );

        // 2. on.eth should be owned by the DAO wallet in the ENS Registry
        assertEq(ensRegistry.owner(onNode), DAO_WALLET, "on.eth should be owned by the DAO wallet");

        // 3. on.eth resolver should be set to the ChainResolver
        assertEq(ensRegistry.resolver(onNode), CHAIN_RESOLVER, "on.eth resolver should be the ChainResolver");

        // 4. RegistrarSecurityController should still own the BaseRegistrar
        assertEq(
            baseRegistrar.owner(),
            address(registrarSecurityController),
            "RegistrarSecurityController should still own the BaseRegistrar"
        );

        // 5. RegistrarSecurityController should still be owned by the timelock
        assertEq(
            registrarSecurityController.owner(),
            address(timelock),
            "RegistrarSecurityController should still be timelock-owned"
        );
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-6-36";
    }
}
