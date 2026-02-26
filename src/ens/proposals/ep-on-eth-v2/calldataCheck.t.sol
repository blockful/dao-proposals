// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { ENS_Governance } from "@ens/ens.t.sol";
import { IENSRegistrar } from "@ens/interfaces/IENSRegistrar.sol";
import { IENSRegistryWithFallback } from "@ens/interfaces/IENSRegistryWithFallback.sol";

interface IRegistrarSecurityController {
    function addRegistrarController(address controller) external;
    function removeRegistrarController(address controller) external;
    function controllers(address) external view returns (bool);
    function registrar() external view returns (address);
}

interface IChainResolver {
    function owner() external view returns (address);
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

/// @notice Calldata review for updated on.eth registration proposal.
/// @dev This is a correction of EP 6.34 which failed at execution.
///      The difference: TX1 and TX4 now go through the RegistrarSecurityController
///      instead of calling addController/removeController directly on BaseRegistrar.
contract Proposal_ENS_On_Eth_V2_Draft_Test is ENS_Governance {
    IENSRegistrar public constant baseRegistrar = IENSRegistrar(0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85);
    IENSRegistryWithFallback public constant ensRegistry =
        IENSRegistryWithFallback(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);
    IRegistrarSecurityController public constant securityController =
        IRegistrarSecurityController(0x7dd4d97653A67C2FD7fbA0a84825eC09524D4E1b);

    address public constant CHAIN_RESOLVER = 0x2a9B5787207863cf2d63d20172ed1F7bB2c9487A;
    address public constant CHAIN_RESOLVER_OWNER = 0x81c11034FE2b2F0561e9975Df9a45D99172183Af;
    bytes4 public constant IERC165_INTERFACE_ID = 0x01ffc9a7;

    bytes32 public constant ON_LABELHASH = 0x6460d40e0362f6a2c743f205df8181010b7f26e76d5606847fb7be7fb6d135f9;
    bytes32 public constant ON_ETH_NODE = 0xcabf8262fe531c2a7e8cd86e06342bc27fc0591ecd562fbac88280abc18ef899;
    uint256 public constant ON_TOKEN_ID = uint256(ON_LABELHASH);
    uint256 public constant REGISTRATION_DURATION = 315_360_000; // 10 years

    bool public timelockControllerBefore;
    bool public onAvailableBefore;
    address public onNodeOwnerBefore;
    address public onResolverBefore;
    uint256 public onExpiryBefore;

    function setUp() public override {
        super.setUp();

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
        vm.createSelectFork({ blockNumber: 24_535_000, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0xAC50cE326de14dDF9b7e9611Cd2F33a1Af8aC039; // clowes.eth
    }

    function _beforeProposal() public override {
        timelockControllerBefore = baseRegistrar.controllers(address(timelock));
        onAvailableBefore = baseRegistrar.available(ON_TOKEN_ID);
        onNodeOwnerBefore = ensRegistry.owner(ON_ETH_NODE);
        onResolverBefore = ensRegistry.resolver(ON_ETH_NODE);
        onExpiryBefore = baseRegistrar.nameExpires(ON_TOKEN_ID);

        // Verify RegistrarSecurityController is properly configured
        assertEq(
            securityController.registrar(),
            address(baseRegistrar),
            "SecurityController should point to BaseRegistrar"
        );

        assertFalse(timelockControllerBefore, "Timelock should not be registrar controller before execution");
        assertTrue(onAvailableBefore, "on.eth should be available before registration");

        // Verify new contracts are deployed
        assertGt(CHAIN_RESOLVER.code.length, 0, "ChainResolver should be deployed");
        assertGt(address(securityController).code.length, 0, "SecurityController should be deployed");
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

        // TX1: Add timelock as controller via RegistrarSecurityController
        targets[0] = address(securityController);
        values[0] = 0;
        signatures[0] = "";
        calldatas[0] = abi.encodeWithSelector(
            IRegistrarSecurityController.addRegistrarController.selector, address(timelock)
        );

        // TX2: Register on.eth to timelock for 10 years
        targets[1] = address(baseRegistrar);
        values[1] = 0;
        signatures[1] = "";
        calldatas[1] = abi.encodeWithSelector(
            IENSRegistrar.register.selector, ON_TOKEN_ID, address(timelock), REGISTRATION_DURATION
        );

        // TX3: Set resolver for on.eth to ChainResolver
        targets[2] = address(ensRegistry);
        values[2] = 0;
        signatures[2] = "";
        calldatas[2] =
            abi.encodeWithSelector(IENSRegistryWithFallback.setResolver.selector, ON_ETH_NODE, CHAIN_RESOLVER);

        // TX4: Remove timelock as controller via RegistrarSecurityController
        targets[3] = address(securityController);
        values[3] = 0;
        signatures[3] = "";
        calldatas[3] = abi.encodeWithSelector(
            IRegistrarSecurityController.removeRegistrarController.selector, address(timelock)
        );

        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        bool timelockControllerAfter = baseRegistrar.controllers(address(timelock));
        address onTokenOwnerAfter = baseRegistrar.ownerOf(ON_TOKEN_ID);
        address onNodeOwnerAfter = ensRegistry.owner(ON_ETH_NODE);
        address onResolverAfter = ensRegistry.resolver(ON_ETH_NODE);
        uint256 onExpiryAfter = baseRegistrar.nameExpires(ON_TOKEN_ID);
        address chainResolverOwnerAfter = IChainResolver(CHAIN_RESOLVER).owner();
        bool chainResolverSupportsERC165 = IChainResolver(CHAIN_RESOLVER).supportsInterface(IERC165_INTERFACE_ID);

        assertFalse(timelockControllerAfter, "Timelock controller should be removed after execution");
        assertEq(onTokenOwnerAfter, address(timelock), "on.eth NFT owner should be timelock");
        assertEq(onNodeOwnerAfter, address(timelock), "on.eth ENS node owner should be timelock");
        assertEq(onResolverAfter, CHAIN_RESOLVER, "on.eth resolver should be ChainResolver");
        assertGt(CHAIN_RESOLVER.code.length, 0, "ChainResolver should be a deployed contract");
        assertEq(chainResolverOwnerAfter, CHAIN_RESOLVER_OWNER, "Unexpected ChainResolver owner");
        assertTrue(chainResolverSupportsERC165, "ChainResolver should support ERC165");
        assertEq(
            onExpiryAfter, block.timestamp + REGISTRATION_DURATION, "on.eth expiry should be extended by 10 years"
        );
        assertGt(onExpiryAfter, onExpiryBefore, "on.eth expiry should increase");
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return false;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-on-eth-v2";
    }
}
