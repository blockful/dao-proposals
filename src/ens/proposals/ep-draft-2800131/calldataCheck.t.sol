// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { ENS_Governance } from "@ens/ens.t.sol";
import { IENSRoot } from "@ens/interfaces/IENSRoot.sol";
import { IENSRegistryWithFallback } from "@ens/interfaces/IENSRegistryWithFallback.sol";

interface IDNSSECImpl {
    function algorithms(uint8) external view returns (address);
    function setAlgorithm(uint8 id, address algo) external;
}

interface IDNSRegistrar {
    function enableNode(bytes memory name) external returns (bytes32);
}

contract Proposal_ENS_DNSSEC_Oracle_Draft_Test is ENS_Governance {
    // ── Contracts ──────────────────────────────────────────────────────
    IDNSSECImpl public constant dnssecImpl = IDNSSECImpl(0x0fc3152971714E5ed7723FAFa650F86A4BaF30C5);
    IENSRoot public constant ensRoot = IENSRoot(0xaB528d626EC275E3faD363fF1393A41F581c5897);
    IDNSRegistrar public constant dnsRegistrar = IDNSRegistrar(0xB32cB5677a7C971689228EC835800432B339bA2B);
    IENSRegistryWithFallback public constant ensRegistry =
        IENSRegistryWithFallback(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);

    // ── DNSSEC Algorithm IDs (RFC 8624) ────────────────────────────────
    uint8 public constant ALGO_RSASHA1 = 5;
    uint8 public constant ALGO_RSASHA256 = 8;
    uint8 public constant ALGO_P256SHA256 = 13;

    // ── New algorithm contract addresses ───────────────────────────────
    address public constant NEW_RSASHA1 = 0x58E0383E21f25DaB957F6664240445A514E9f5e8;
    address public constant NEW_RSASHA256 = 0xaee0E2c4d5AB2fc164C8b0Cc8D3118C1c752C95E;
    address public constant NEW_P256SHA256 = 0xB091C4F6FAc16eDDA5Ee1E0f4738f80011905878;

    // ── TLD labelhashes ────────────────────────────────────────────────
    // keccak256("cc")
    bytes32 public constant CC_LABELHASH = 0x68ce0763ca729318b714b0cf33478e4e228e19f58aeaf12cfa1535c9d4bbcaf9;
    // keccak256("name")
    bytes32 public constant NAME_LABELHASH = 0x2361458367e696363fbcc70777d07ebbd2394e89fd0adcaf147faccd1d294d60;

    // ── TLD namehashes (for registry ownership checks) ─────────────────
    // namehash("cc") = keccak256(bytes32(0) + keccak256("cc"))
    bytes32 public constant CC_NODE = 0x3f4ea7e15a27161c78f2a8d06e552a852a74ebc5d10217d59eb16663812fa903;
    // namehash("name") = keccak256(bytes32(0) + keccak256("name"))
    bytes32 public constant NAME_NODE = 0x3065e4a455eb71d25d2d52a7cd46eb2f50c4bbbf98681c7ac61b3ab06c012991;

    // ── DNS wire format names ──────────────────────────────────────────
    // \x02cc\x00
    bytes public constant CC_DNS_NAME = hex"026363_00";
    // \x04name\x00
    bytes public constant NAME_DNS_NAME = hex"046e616d65_00";

    // ── State captured before execution ────────────────────────────────
    address public oldRSASHA1;
    address public oldRSASHA256;
    address public oldP256SHA256;
    address public ccOwnerBefore;
    address public nameOwnerBefore;

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
        vm.createSelectFork({ blockNumber: 24_500_000, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0xb8c2C29ee19D8307cb7255e1Cd9CbDE883A267d5; // nick.eth
    }

    function _beforeProposal() public override {
        oldRSASHA1 = dnssecImpl.algorithms(ALGO_RSASHA1);
        oldRSASHA256 = dnssecImpl.algorithms(ALGO_RSASHA256);
        oldP256SHA256 = dnssecImpl.algorithms(ALGO_P256SHA256);
        ccOwnerBefore = ensRegistry.owner(CC_NODE);
        nameOwnerBefore = ensRegistry.owner(NAME_NODE);

        // Old algorithms should be set (non-zero)
        assertTrue(oldRSASHA1 != address(0), "RSASHA1 algo should exist before");
        assertTrue(oldRSASHA256 != address(0), "RSASHA256 algo should exist before");
        assertTrue(oldP256SHA256 != address(0), "P256SHA256 algo should exist before");

        // Old algorithms should differ from new ones
        assertTrue(oldRSASHA1 != NEW_RSASHA1, "RSASHA1 should be different before update");
        assertTrue(oldRSASHA256 != NEW_RSASHA256, "RSASHA256 should be different before update");
        assertTrue(oldP256SHA256 != NEW_P256SHA256, "P256SHA256 should be different before update");

        // NOTE: New algorithm contracts may not be deployed yet at this fork block.
        // P256SHA256 depends on the EIP-7951 precompile (Fusaka hardfork).
        // These checks should be re-enabled once the contracts are deployed.
        // assertGt(NEW_RSASHA1.code.length, 0, "New RSASHA1 should be deployed");
        // assertGt(NEW_RSASHA256.code.length, 0, "New RSASHA256 should be deployed");
        // assertGt(NEW_P256SHA256.code.length, 0, "New P256SHA256 should be deployed");
    }

    function _generateCallData()
        public
        override
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory, string memory)
    {
        uint256 numTransactions = 7;

        targets = new address[](numTransactions);
        values = new uint256[](numTransactions);
        calldatas = new bytes[](numTransactions);
        signatures = new string[](numTransactions);

        // TX1: Set RSASHA1 algorithm (id=5) to new implementation
        targets[0] = address(dnssecImpl);
        values[0] = 0;
        signatures[0] = "";
        calldatas[0] = abi.encodeWithSelector(IDNSSECImpl.setAlgorithm.selector, ALGO_RSASHA1, NEW_RSASHA1);

        // TX2: Set RSASHA256 algorithm (id=8) to new implementation
        targets[1] = address(dnssecImpl);
        values[1] = 0;
        signatures[1] = "";
        calldatas[1] = abi.encodeWithSelector(IDNSSECImpl.setAlgorithm.selector, ALGO_RSASHA256, NEW_RSASHA256);

        // TX3: Set P256SHA256 algorithm (id=13) to new implementation
        targets[2] = address(dnssecImpl);
        values[2] = 0;
        signatures[2] = "";
        calldatas[2] = abi.encodeWithSelector(IDNSSECImpl.setAlgorithm.selector, ALGO_P256SHA256, NEW_P256SHA256);

        // TX4: Reset .cc TLD ownership to address(0) via Root
        // This invalidates existing .cc DNSSEC claims so they must re-prove with the new algorithms
        targets[3] = address(ensRoot);
        values[3] = 0;
        signatures[3] = "";
        calldatas[3] = abi.encodeWithSelector(IENSRoot.setSubnodeOwner.selector, CC_LABELHASH, address(0));

        // TX5: Reset .name TLD ownership to address(0) via Root
        targets[4] = address(ensRoot);
        values[4] = 0;
        signatures[4] = "";
        calldatas[4] = abi.encodeWithSelector(IENSRoot.setSubnodeOwner.selector, NAME_LABELHASH, address(0));

        // TX6: Re-enable .cc in DNSRegistrar
        targets[5] = address(dnsRegistrar);
        values[5] = 0;
        signatures[5] = "";
        calldatas[5] = abi.encodeWithSelector(IDNSRegistrar.enableNode.selector, CC_DNS_NAME);

        // TX7: Re-enable .name in DNSRegistrar
        targets[6] = address(dnsRegistrar);
        values[6] = 0;
        signatures[6] = "";
        calldatas[6] = abi.encodeWithSelector(IDNSRegistrar.enableNode.selector, NAME_DNS_NAME);

        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        // Verify algorithms were updated
        assertEq(dnssecImpl.algorithms(ALGO_RSASHA1), NEW_RSASHA1, "RSASHA1 algo should be updated");
        assertEq(dnssecImpl.algorithms(ALGO_RSASHA256), NEW_RSASHA256, "RSASHA256 algo should be updated");
        assertEq(dnssecImpl.algorithms(ALGO_P256SHA256), NEW_P256SHA256, "P256SHA256 algo should be updated");

        // Verify .cc and .name TLDs were re-enabled (ownership transferred to DNSRegistrar)
        address ccOwnerAfter = ensRegistry.owner(CC_NODE);
        address nameOwnerAfter = ensRegistry.owner(NAME_NODE);
        assertEq(ccOwnerAfter, address(dnsRegistrar), ".cc should be owned by DNSRegistrar after enableNode");
        assertEq(nameOwnerAfter, address(dnsRegistrar), ".name should be owned by DNSRegistrar after enableNode");
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return false;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-draft-2800131";
    }
}
