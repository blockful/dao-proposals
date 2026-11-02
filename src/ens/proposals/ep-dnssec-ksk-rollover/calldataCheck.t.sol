// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { ENS_Governance } from "@ens/ens.t.sol";
import { ENSConstants } from "@ens/Constants.sol";
import { IENSRoot } from "@ens/interfaces/IENSRoot.sol";
import { IENSRegistryWithFallback } from "@ens/interfaces/IENSRegistryWithFallback.sol";
import { IDNSSEC } from "@ens/interfaces/IDNSSEC.sol";
import { IDNSRegistrar, IDNSRegistrar2021 } from "@ens/interfaces/IDNSRegistrar.sol";
import { IOffchainDNSResolver, IPublicSuffixList } from "@ens/interfaces/IOffchainDNSResolver.sol";

interface IAddrResolver {
    function addr(bytes32 node) external view returns (address payable);
}

interface IRegistryV2 {
    function getResolver(string calldata label) external view returns (address);
}

interface IDNSTLDResolverV2 {
    function DNSSEC_ORACLE() external view returns (address);
    function ROOT_REGISTRY() external view returns (address);
}

/// @dev The P256SHA256 algorithm contract calls the P256VERIFY precompile, live since Osaka.
/// forge-config: default.evm_version = "osaka"
contract Proposal_ENS_EP_DNSSEC_KSK_Rollover_Draft_Test is ENS_Governance {
    IENSRoot constant root = IENSRoot(ENSConstants.ENS_ROOT);
    IENSRegistryWithFallback constant registry = IENSRegistryWithFallback(ENSConstants.ENS_REGISTRY);
    IDNSSEC constant currentOracle = IDNSSEC(0x0fc3152971714E5ed7723FAFa650F86A4BaF30C5);
    IDNSRegistrar constant currentRegistrar = IDNSRegistrar(0xB32cB5677a7C971689228EC835800432B339bA2B);
    IDNSRegistrar2021 constant registrar2021 = IDNSRegistrar2021(0x58774Bb8acD458A640aF0B88238369A167546ef2);
    IOffchainDNSResolver constant currentResolver = IOffchainDNSResolver(0xF142B308cF687d4358410a4cB885513b30A42025);
    IPublicSuffixList constant suffixes = IPublicSuffixList(0x823BDa9cA8c47d072376eCD595530c8fb2fAa3ED);

    address constant RSASHA1 = 0x58E0383E21f25DaB957F6664240445A514E9f5e8;
    address constant RSASHA256 = 0xaee0E2c4d5AB2fc164C8b0Cc8D3118C1c752C95E;
    address constant P256SHA256 = 0xB091C4F6FAc16eDDA5Ee1E0f4738f80011905878;
    address constant SHA1_DIGEST = 0x9c9fcEa62bD0A723b62A2F1e98dE0Ee3df813619;
    address constant SHA256_DIGEST = 0xCFe6edBD47a032585834A6921D1d05CB70FcC36d;
    string constant GATEWAY_URL = "https://dnssec-oracle.ens.domains/";

    uint8 constant ALG_RSASHA1 = 5;
    uint8 constant ALG_RSASHA1_NSEC3 = 7;
    uint8 constant ALG_RSASHA256 = 8;
    uint8 constant ALG_P256SHA256 = 13;
    uint8 constant DIGEST_SHA1 = 1;
    uint8 constant DIGEST_SHA256 = 2;
    uint16 constant TYPE_DS = 43;
    uint16 constant TYPE_DNSKEY = 48;
    uint16 constant CLASS_INET = 1;
    uint32 constant ANCHOR_TTL = 3600;

    uint16 constant KSK_2010_TAG = 19_036;
    bytes32 constant KSK_2010_DIGEST = 0x49AAC11D7B6F6446702E54A1607371607A1A41855200FD2CE1CDDE32F24E8FB5;
    uint16 constant KSK_2017_TAG = 20_326;
    bytes32 constant KSK_2017_DIGEST = 0xE06D44B80B8F1D39A95C0B0D7C65D08458E880409BBC683457104237C7F8EC8D;
    uint16 constant KSK_2024_TAG = 38_696;
    bytes32 constant KSK_2024_DIGEST = 0x683D2D0ACB8C9B712A1948B27F741219298D0A450D612C483AF444A4C0FB2B16;

    address constant ENS_DOMAINS_OWNER = 0xb8c2C29ee19D8307cb7255e1Cd9CbDE883A267d5;
    address constant TAYTEMS_ADDR = 0x8e8Db5CcEF88cca9d624701Db544989C996E3216;
    string constant CLAIMED_NAME = "rendyrhey.xyz";
    string constant UNOWNED_LABEL = "notarealtldzz";

    IDNSSEC constant newOracle = IDNSSEC(0x668ad4467129d49ECbe6274d95197797C0E262AA);
    IOffchainDNSResolver constant newResolver = IOffchainDNSResolver(0xEbBcBFBE4A8F3357e7d1d444406C28cFa34f1261);
    IDNSRegistrar constant newRegistrar = IDNSRegistrar(0x8284c9D6e7882Fe1DE49C79062a4c797F0988B3D);

    address constant UNIVERSAL_RESOLVER = 0xeEeEEEeE14D718C2B47D9923Deab1335E144EeEe;
    address constant MANAGED_UNIVERSAL_RESOLVER = 0xcFFd2Ae680CD110D28739a70922636B5937b022B;
    address constant UNIVERSAL_RESOLVER_V2 = 0x06Fdd07F007ADaC667177b46aB2EB9A75132Cfd5;
    IRegistryV2 constant rootRegistryV2 = IRegistryV2(0x2553c09bE6447BeFfdB86FA622ad41fB8f77A91e);
    IDNSTLDResolverV2 constant dnsTldResolverV2 = IDNSTLDResolverV2(0xaB48304A2520CE420E636AaCD48A8bb3e7e485Ee);
    bytes32 constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    string proofs;
    string legacyProofs;
    uint256 proofTime;

    function setUp() public override {
        super.setUp();
        proofs = vm.readFile(string.concat(dirPath(), "/fixtures/proofs.json"));
        legacyProofs = vm.readFile(string.concat(dirPath(), "/fixtures/proofs-2026-10-17.json"));
        assertEq(vm.parseJsonUint(proofs, ".forkBlock"), block.number, "fixtures fetched at a different block");
        proofTime = vm.parseJsonUint(proofs, ".forkTimestamp");

        vm.label(address(newOracle), "newDNSSECImpl");
        vm.label(address(newResolver), "newOffchainDNSResolver");
        vm.label(address(newRegistrar), "newDNSRegistrar");
        vm.label(address(currentOracle), "currentDNSSECImpl");
        vm.label(address(currentRegistrar), "currentDNSRegistrar");
        vm.label(address(registrar2021), "dnsRegistrar2021");
        vm.label(address(currentResolver), "currentOffchainDNSResolver");
        vm.label(address(root), "root");
    }

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 26_295_292, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0xb8c2C29ee19D8307cb7255e1Cd9CbDE883A267d5; // nick.eth, draft author
    }

    function _beforeProposal() public override {
        assertEq(root.owner(), address(timelock));
        assertTrue(root.controllers(address(currentRegistrar)));
        assertTrue(root.controllers(address(registrar2021)));
        assertFalse(root.controllers(address(newRegistrar)));

        assertEq(currentRegistrar.oracle(), address(currentOracle));
        assertEq(currentRegistrar.resolver(), address(currentResolver));
        assertEq(currentRegistrar.suffixes(), address(suffixes));
        assertEq(currentRegistrar.previousRegistrar(), address(registrar2021));
        assertEq(currentResolver.oracle(), address(currentOracle));
        assertEq(currentOracle.owner(), address(timelock));
        assertEq(
            currentOracle.anchors(),
            bytes.concat(_rootAnchor(KSK_2010_TAG, KSK_2010_DIGEST), _rootAnchor(KSK_2017_TAG, KSK_2017_DIGEST))
        );

        _assertMatchesDescription();
        _assertDeployedContractsMatchDraft();
        _assertProofsBeforeExecution();
        _assert2021RegistrarCanTakeUnownedTld();

        _assertTld("domains", address(currentRegistrar), address(currentResolver));
        _assertTld("xyz", address(currentRegistrar), address(currentResolver));
        assertEq(registry.owner(namehash("ens.domains")), ENS_DOMAINS_OWNER);
    }

    function _generateCallData()
        public
        override
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory, string memory)
    {
        uint256 numTransactions = 3;
        targets = new address[](numTransactions);
        values = new uint256[](numTransactions);
        calldatas = new bytes[](numTransactions);
        signatures = new string[](numTransactions);

        targets[0] = address(root);
        calldatas[0] = abi.encodeCall(IENSRoot.setController, (address(newRegistrar), true));

        targets[1] = address(root);
        calldatas[1] = abi.encodeCall(IENSRoot.setController, (address(currentRegistrar), false));

        targets[2] = address(root);
        calldatas[2] = abi.encodeCall(IENSRoot.setController, (address(registrar2021), false));

        description = getDescriptionFromMarkdown();
        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        assertEq(root.owner(), address(timelock));
        assertTrue(root.controllers(address(newRegistrar)));
        assertFalse(root.controllers(address(currentRegistrar)));
        assertFalse(root.controllers(address(registrar2021)));

        _assertControllerRights();
        _assertTldMigration();
        _assertDaoControlsAnchors();
        _assertV2DnsStillOnOldOracle();

        // The fixtures' RRSIGs only hold around the fork block
        vm.warp(proofTime);
        _assertClaims();
        _assertGaslessResolution();
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return false;
    }

    function _assertMatchesDescription() internal {
        string memory body = vm.readFile(string.concat(dirPath(), "/proposalDescription.md"));

        string memory row =
            string.concat("| `", vm.toString(address(root)), "` | 0 ETH | `setController(address,bool)` |");
        assertEq(vm.split(body, row).length - 1, targets.length, "Transactions table rows");
        for (uint256 i; i < targets.length; ++i) {
            assertEq(targets[i], address(root));
            assertEq(values[i], 0);
        }

        string memory compact = vm.replace(body, " ", "");
        uint256 first = _describedAt(compact, _transactionRow(address(newRegistrar), "true"));
        uint256 second = _describedAt(compact, _transactionRow(address(currentRegistrar), "false"));
        uint256 third = _describedAt(compact, _transactionRow(address(registrar2021), "false"));
        assertTrue(first < second && second < third, "Transactions table order");

        string memory lower = vm.toLowercase(body);
        address[11] memory wiring = [
            address(newOracle),
            address(newResolver),
            address(newRegistrar),
            address(suffixes),
            RSASHA1,
            RSASHA256,
            P256SHA256,
            SHA1_DIGEST,
            SHA256_DIGEST,
            ENSConstants.ENS_REGISTRY,
            address(timelock)
        ];
        for (uint256 i; i < wiring.length; ++i) {
            _describedAt(lower, vm.toLowercase(vm.toString(wiring[i])));
        }
        _describedAt(body, GATEWAY_URL);
    }

    function _transactionRow(address controller, string memory enabled) internal pure returns (string memory) {
        return string.concat("|`controller`|`", vm.toString(controller), "`|\n||||`enabled`|`", enabled, "`|");
    }

    function _describedAt(string memory haystack, string memory needle) internal pure returns (uint256 at) {
        at = vm.indexOf(haystack, needle);
        assertTrue(at != type(uint256).max, string.concat("not in description: ", needle));
    }

    function _assertDeployedContractsMatchDraft() internal view {
        assertEq(newOracle.owner(), address(timelock));
        assertEq(
            newOracle.anchors(),
            bytes.concat(_rootAnchor(KSK_2017_TAG, KSK_2017_DIGEST), _rootAnchor(KSK_2024_TAG, KSK_2024_DIGEST))
        );
        uint8[4] memory algorithmIds = [ALG_RSASHA1, ALG_RSASHA1_NSEC3, ALG_RSASHA256, ALG_P256SHA256];
        address[4] memory algorithms = [RSASHA1, RSASHA1, RSASHA256, P256SHA256];
        for (uint256 i; i < algorithmIds.length; ++i) {
            assertEq(newOracle.algorithms(algorithmIds[i]), algorithms[i]);
            assertEq(currentOracle.algorithms(algorithmIds[i]), algorithms[i]);
        }
        assertEq(newOracle.digests(DIGEST_SHA1), SHA1_DIGEST);
        assertEq(newOracle.digests(DIGEST_SHA256), SHA256_DIGEST);
        assertEq(currentOracle.digests(DIGEST_SHA1), SHA1_DIGEST);
        assertEq(currentOracle.digests(DIGEST_SHA256), SHA256_DIGEST);

        assertEq(newResolver.ens(), ENSConstants.ENS_REGISTRY);
        assertEq(newResolver.oracle(), address(newOracle));
        assertEq(newResolver.gatewayURL(), GATEWAY_URL);
        assertEq(newResolver.gatewayURL(), currentResolver.gatewayURL());

        assertEq(newRegistrar.ens(), ENSConstants.ENS_REGISTRY);
        assertEq(newRegistrar.oracle(), address(newOracle));
        assertEq(newRegistrar.resolver(), address(newResolver));
        assertEq(newRegistrar.suffixes(), address(suffixes));
        assertEq(newRegistrar.previousRegistrar(), address(currentRegistrar));
        assertTrue(newRegistrar.wasRegistrar(address(currentRegistrar)));
        assertTrue(newRegistrar.wasRegistrar(address(registrar2021)));
        assertTrue(newRegistrar.wasRegistrar(currentRegistrar.previousRegistrar()));
        assertFalse(newRegistrar.wasRegistrar(address(newRegistrar)));
    }

    function _assertProofsBeforeExecution() internal {
        IDNSSEC.RRSetWithSignature[] memory gateway = _proof("ensDomainsClaim", "gateway");
        IDNSSEC.RRSetWithSignature[] memory staleRoot = _proof("ensDomainsClaim", "staleRoot");

        assertEq(vm.parseJsonUint(proofs, ".proofs.ensDomainsClaim.gatewayRootKeyTag"), KSK_2024_TAG);
        assertEq(vm.parseJsonUint(proofs, ".rootDnskeyKeyTag"), KSK_2024_TAG);
        assertEq(
            keccak256(vm.parseJsonBytes(proofs, ".proofs.ensDomainsClaim.gateway")),
            keccak256(vm.parseJsonBytes(proofs, ".proofs.ensDomainsClaim.ksk2024"))
        );
        vm.expectRevert(abi.encodeWithSelector(IDNSSEC.NoMatchingProof.selector, _dnsName("")));
        currentOracle.verifyRRSet(gateway);

        (bytes memory txtRRset,) = newOracle.verifyRRSet(gateway);
        (bytes memory rrs,) = newOracle.verifyRRSet(staleRoot);
        assertEq(rrs, txtRRset);

        IDNSSEC.RRSetWithSignature[] memory legacyGateway = abi.decode(
            vm.parseJsonBytes(legacyProofs, ".proofs.ensDomainsClaim.gateway"), (IDNSSEC.RRSetWithSignature[])
        );
        assertEq(vm.parseJsonUint(legacyProofs, ".proofs.ensDomainsClaim.gatewayRootKeyTag"), KSK_2017_TAG);
        uint32 lapse = uint32(vm.parseJsonUint(legacyProofs, ".proofs.ensDomainsClaim.gatewayRootExpiration"));
        assertEq(lapse, 1_792_627_200, "2026-10-22T00:00:00Z");
        currentOracle.verifyRRSet(_rootLink(legacyGateway), lapse);
        vm.expectRevert(abi.encodeWithSelector(IDNSSEC.SignatureExpired.selector, lapse, lapse + 1));
        currentOracle.verifyRRSet(_rootLink(legacyGateway), lapse + 1);
    }

    function _assert2021RegistrarCanTakeUnownedTld() internal {
        uint256 snapshot = vm.snapshotState();
        assertEq(registry.owner(namehash(bytes(UNOWNED_LABEL))), address(0));
        assertTrue(IPublicSuffixList(registrar2021.suffixes()).isPublicSuffix(_dnsName(UNOWNED_LABEL)));
        assertFalse(suffixes.isPublicSuffix(_dnsName(UNOWNED_LABEL)));
        vm.prank(makeAddr("anyone"));
        registrar2021.claim(_dnsName(string.concat("x.", UNOWNED_LABEL)), "");
        assertEq(registry.owner(namehash(bytes(UNOWNED_LABEL))), address(registrar2021));
        vm.revertToState(snapshot);
    }

    function _assertControllerRights() internal {
        bytes32 label = labelhash(UNOWNED_LABEL);
        bytes32 node = namehash(bytes(UNOWNED_LABEL));
        assertEq(registry.owner(node), address(0));
        assertFalse(root.locked(label));

        vm.prank(address(currentRegistrar));
        vm.expectRevert(bytes(""));
        root.setSubnodeOwner(label, address(currentRegistrar));

        vm.prank(address(registrar2021));
        vm.expectRevert(bytes(""));
        root.setSubnodeOwner(label, address(registrar2021));

        vm.prank(makeAddr("anyone"));
        vm.expectRevert(bytes(""));
        registrar2021.claim(_dnsName(string.concat("x.", UNOWNED_LABEL)), "");
        assertEq(registry.owner(node), address(0));
    }

    function _assertTldMigration() internal {
        vm.startPrank(makeAddr("anyone"));
        newRegistrar.enableNode(_dnsName("domains"));
        newRegistrar.enableNode(_dnsName("xyz"));
        vm.stopPrank();
        _assertTld("domains", address(newRegistrar), address(newResolver));
        _assertTld("xyz", address(newRegistrar), address(newResolver));

        assertEq(registry.resolver(namehash("hiphop")), address(currentResolver));
        vm.expectRevert(IDNSRegistrar.PreconditionNotMet.selector);
        newRegistrar.enableNode(_dnsName("hiphop"));

        assertEq(registry.owner(namehash("ens.domains")), ENS_DOMAINS_OWNER);
        bytes32 claimed = namehash(bytes(CLAIMED_NAME));
        assertGt(currentRegistrar.inceptions(claimed), 0);
        assertEq(newRegistrar.inceptions(claimed), currentRegistrar.inceptions(claimed));
    }

    // FINDING: Universal Resolver lookups reach DNS TLDs through a resolver bound to the old oracle
    function _assertV2DnsStillOnOldOracle() internal view {
        assertEq(
            address(uint160(uint256(vm.load(UNIVERSAL_RESOLVER, IMPLEMENTATION_SLOT)))), MANAGED_UNIVERSAL_RESOLVER
        );
        assertEq(
            address(uint160(uint256(vm.load(MANAGED_UNIVERSAL_RESOLVER, IMPLEMENTATION_SLOT)))), UNIVERSAL_RESOLVER_V2
        );
        assertEq(rootRegistryV2.getResolver("xyz"), address(dnsTldResolverV2));
        assertEq(dnsTldResolverV2.ROOT_REGISTRY(), address(rootRegistryV2));
        assertEq(dnsTldResolverV2.DNSSEC_ORACLE(), address(currentOracle));
    }

    function _assertDaoControlsAnchors() internal {
        bytes memory anchors = newOracle.anchors();
        address anyone = makeAddr("anyone");
        vm.prank(anyone);
        vm.expectRevert(abi.encodeWithSelector(IDNSSEC.OwnableUnauthorizedAccount.selector, anyone));
        newOracle.setAnchors(anchors);

        vm.prank(address(timelock));
        newOracle.setAnchors(anchors);
        assertEq(newOracle.anchors(), anchors);
    }

    function _assertClaims() internal {
        IDNSSEC.RRSetWithSignature[] memory gateway = _proof("ensDomainsClaim", "gateway");
        IDNSSEC.RRSetWithSignature[] memory staleRoot = _proof("ensDomainsClaim", "staleRoot");
        bytes memory ensDomains = _dnsName("ens.domains");

        vm.expectRevert(abi.encodeWithSelector(IDNSSEC.NoMatchingProof.selector, _dnsName("")));
        currentRegistrar.proveAndClaim(ensDomains, gateway);

        newRegistrar.proveAndClaim(ensDomains, gateway);
        assertEq(registry.owner(namehash("ens.domains")), ENS_DOMAINS_OWNER);
        uint32 rootInception = uint32(vm.parseJsonUint(proofs, ".rootDnskeyInception"));
        assertEq(newRegistrar.getInception(_dnsName(""), TYPE_DNSKEY), rootInception);

        // FINDING: an older, valid signature over the same records is rejected (fixed by ens-contracts #583)
        uint32 staleInception = uint32(vm.parseJsonUint(proofs, ".proofs.ensDomainsClaim.staleRootInception"));
        assertLt(staleInception, rootInception);
        vm.expectRevert(
            abi.encodeWithSelector(
                IDNSRegistrar.StaleProof.selector, _dnsName(""), TYPE_DNSKEY, rootInception, staleInception
            )
        );
        newRegistrar.proveAndClaim(ensDomains, staleRoot);
    }

    function _assertGaslessResolution() internal {
        bytes memory response = vm.parseJsonBytes(proofs, ".proofs.taytemsXyzGasless.gateway");
        bytes memory query = abi.encodeCall(IAddrResolver.addr, (namehash("taytems.xyz")));
        bytes memory extraData = abi.encode(_dnsName("taytems.xyz"), query, bytes4(0));

        assertEq(registry.resolver(namehash("xyz")), address(newResolver));
        assertEq(abi.decode(newResolver.resolveCallback(response, extraData), (address)), TAYTEMS_ADDR);

        vm.expectRevert(abi.encodeWithSelector(IDNSSEC.NoMatchingProof.selector, _dnsName("")));
        currentResolver.resolveCallback(response, extraData);
    }

    function _assertTld(string memory tld, address owner, address resolver) internal view {
        bytes32 node = namehash(bytes(tld));
        assertEq(registry.owner(node), owner, string.concat(tld, " owner"));
        assertEq(registry.resolver(node), resolver, string.concat(tld, " resolver"));
    }

    function _rootAnchor(uint16 keyTag, bytes32 digest) internal pure returns (bytes memory) {
        return abi.encodePacked(
            bytes1(0), // owner name: the root
            TYPE_DS,
            CLASS_INET,
            ANCHOR_TTL,
            uint16(2 + 1 + 1 + 32), // RDLENGTH: key tag, algorithm, digest type, SHA-256 digest
            keyTag,
            ALG_RSASHA256,
            DIGEST_SHA256,
            digest
        );
    }

    function _dnsName(string memory name) internal pure returns (bytes memory out) {
        bytes memory s = bytes(name);
        uint256 start;
        for (uint256 i; i < s.length; ++i) {
            if (s[i] != ".") continue;
            out = bytes.concat(out, _label(s, start, i));
            start = i + 1;
        }
        if (s.length > 0) out = bytes.concat(out, _label(s, start, s.length));
        return bytes.concat(out, bytes1(0));
    }

    function _label(bytes memory s, uint256 from, uint256 to) internal pure returns (bytes memory label) {
        label = new bytes(to - from + 1);
        label[0] = bytes1(uint8(to - from));
        for (uint256 i = from; i < to; ++i) {
            label[i - from + 1] = s[i];
        }
    }

    function _proof(string memory key, string memory kind) internal view returns (IDNSSEC.RRSetWithSignature[] memory) {
        return abi.decode(
            vm.parseJsonBytes(proofs, string.concat(".proofs.", key, ".", kind)), (IDNSSEC.RRSetWithSignature[])
        );
    }

    function _rootLink(IDNSSEC.RRSetWithSignature[] memory proof)
        internal
        pure
        returns (IDNSSEC.RRSetWithSignature[] memory link)
    {
        link = new IDNSSEC.RRSetWithSignature[](1);
        link[0] = proof[0];
    }
}
