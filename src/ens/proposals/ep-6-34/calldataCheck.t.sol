// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { ENS_Governance } from "@ens/ens.t.sol";
import { IENSRegistrar } from "@ens/interfaces/IENSRegistrar.sol";
import { IENSRegistryWithFallback } from "@ens/interfaces/IENSRegistryWithFallback.sol";

contract Proposal_ENS_EP_6_34_Draft_Test is ENS_Governance {
    IENSRegistrar public constant baseRegistrar = IENSRegistrar(0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85);
    IENSRegistryWithFallback public constant ensRegistry =
        IENSRegistryWithFallback(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);

    address public constant CHAIN_RESOLVER = 0x2a9B5787207863cf2d63d20172ed1F7bB2c9487A;

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

        // Tally drafts are off-chain and may not satisfy the on-chain proposal threshold.
        // For lifecycle simulation, top up proposer voting power on the fork when needed.
        uint256 threshold = governor.proposalThreshold();
        uint256 proposerVotes = ensToken.getVotes(proposer);

        if (proposerVotes < threshold) {
            uint256 neededVotes = threshold - proposerVotes;

            vm.prank(address(timelock));
            ensToken.transfer(proposer, neededVotes);

            vm.prank(proposer);
            ensToken.delegate(proposer);

            // Governor checks proposer voting power at block.number - 1.
            vm.roll(block.number + 1);
            vm.warp(block.timestamp + 12);
        }
    }

    function _selectFork() public override {
        // Near draft creation time on Tally (2026-02-12).
        vm.createSelectFork({ blockNumber: 24_440_213, urlOrAlias: "mainnet" });
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

        assertFalse(timelockControllerBefore, "Timelock should not be registrar controller before execution");
        assertTrue(onAvailableBefore, "on.eth should be available before registration");
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

        // 1) Grant temporary registrar controller rights to wallet.ensdao.eth (timelock)
        targets[0] = address(baseRegistrar);
        values[0] = 0;
        signatures[0] = "";
        calldatas[0] = abi.encodeWithSelector(IENSRegistrar.addController.selector, address(timelock));

        // 2) Register on.eth to wallet.ensdao.eth for 10 years
        targets[1] = address(baseRegistrar);
        values[1] = 0;
        signatures[1] = "";
        calldatas[1] = abi.encodeWithSelector(
            IENSRegistrar.register.selector, ON_TOKEN_ID, address(timelock), REGISTRATION_DURATION
        );

        // 3) Set resolver for on.eth to ChainResolver proxy
        targets[2] = address(ensRegistry);
        values[2] = 0;
        signatures[2] = "";
        calldatas[2] =
            abi.encodeWithSelector(IENSRegistryWithFallback.setResolver.selector, ON_ETH_NODE, CHAIN_RESOLVER);

        // 4) Revoke temporary registrar controller rights from wallet.ensdao.eth
        targets[3] = address(baseRegistrar);
        values[3] = 0;
        signatures[3] = "";
        calldatas[3] = abi.encodeWithSelector(IENSRegistrar.removeController.selector, address(timelock));

        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        bool timelockControllerAfter = baseRegistrar.controllers(address(timelock));
        address onTokenOwnerAfter = baseRegistrar.ownerOf(ON_TOKEN_ID);
        address onNodeOwnerAfter = ensRegistry.owner(ON_ETH_NODE);
        address onResolverAfter = ensRegistry.resolver(ON_ETH_NODE);
        uint256 onExpiryAfter = baseRegistrar.nameExpires(ON_TOKEN_ID);

        assertFalse(timelockControllerAfter, "Timelock controller should be removed after execution");
        assertEq(onTokenOwnerAfter, address(timelock), "on.eth NFT owner should be timelock");
        assertEq(onNodeOwnerAfter, address(timelock), "on.eth ENS node owner should be timelock");
        assertEq(onResolverAfter, CHAIN_RESOLVER, "on.eth resolver should be ChainResolver");
        assertEq(onExpiryAfter, block.timestamp + REGISTRATION_DURATION, "on.eth expiry should be extended by 10 years");
        assertGt(onExpiryAfter, onExpiryBefore, "on.eth expiry should increase");
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return false;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-6-34";
    }
}
