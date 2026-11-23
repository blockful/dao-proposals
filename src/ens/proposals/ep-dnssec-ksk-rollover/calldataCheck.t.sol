// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { ENS_Governance } from "@ens/ens.t.sol";
import { ENSConstants } from "@ens/Constants.sol";
import { SafeHelper } from "@ens/helpers/SafeHelper.sol";
import { ISafe } from "@ens/interfaces/ISafe.sol";
import { IENSRoot } from "@ens/interfaces/IENSRoot.sol";
import { IENSRegistryWithFallback } from "@ens/interfaces/IENSRegistryWithFallback.sol";
import { IDNSSEC } from "@ens/interfaces/IDNSSEC.sol";
import { IDNSRegistrar, IDNSRegistrar2021 } from "@ens/interfaces/IDNSRegistrar.sol";
import { IOffchainDNSResolver, IPublicSuffixList } from "@ens/interfaces/IOffchainDNSResolver.sol";

interface IAddrResolver {
    function addr(bytes32 node) external view returns (address payable);
}

interface IRootRegistryV2 {
    function grantRootRoles(uint256 roleBitmap, address account) external returns (bool);
    function hasRootRoles(uint256 roleBitmap, address account) external view returns (bool);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function getStatus(uint256 anyId) external view returns (uint8);
    function getOwner(uint256 anyId) external view returns (address);
    function getResolver(string calldata label) external view returns (address);
}

interface IDNSTLDResolverV2 {
    error OffchainLookup(address sender, string[] urls, bytes callData, bytes4 callbackFunction, bytes extraData);

    function DNSSEC_ORACLE() external view returns (address);
    function getResolver(bytes calldata name) external view returns (address, bool);
}

interface ITemporaryDNSRegistrar {
    error TLDNotPublic(string label);

    function owner() external view returns (address);
    function ROOT_REGISTRY() external view returns (address);
    function TOKEN_OWNER() external view returns (address);
    function PUBLIC_SUFFIX_LIST() external view returns (address);
    function defaultResolver() external view returns (address);
    function setDefaultResolver(address resolver) external;
    function syncTLD(string calldata label) external;
    function syncTLDs(string[] calldata labels) external;
}

interface ITLDToken {
    function owner() external view returns (address);
    function mintTLD(string memory name, address owner, string memory tokenURI) external;
    function claim(uint256 tokenId, address ensowner) external;
}

/// forge-config: default.evm_version = "osaka"
contract Proposal_ENS_EP_DNSSEC_KSK_Rollover_Draft_Test is ENS_Governance, SafeHelper {
    IENSRoot constant root = IENSRoot(ENSConstants.ENS_ROOT);
    IENSRegistryWithFallback constant registry = IENSRegistryWithFallback(ENSConstants.ENS_REGISTRY);
    IPublicSuffixList constant suffixes = IPublicSuffixList(0x823BDa9cA8c47d072376eCD595530c8fb2fAa3ED);

    IDNSSEC constant currentOracle = IDNSSEC(0x0fc3152971714E5ed7723FAFa650F86A4BaF30C5);
    IDNSRegistrar constant currentRegistrar = IDNSRegistrar(0xB32cB5677a7C971689228EC835800432B339bA2B);
    IOffchainDNSResolver constant currentResolver = IOffchainDNSResolver(0xF142B308cF687d4358410a4cB885513b30A42025);
    IDNSRegistrar2021 constant registrar2021 = IDNSRegistrar2021(0x58774Bb8acD458A640aF0B88238369A167546ef2);
    ITLDToken constant tldToken = ITLDToken(0xF5823a1BB20d01F1b9d17d27882C5EAcA7C510bd);
    address constant LEGACY_MULTISIG = 0xCF60916b6CB4753f58533808fA610FcbD4098Ec0;

    IDNSSEC constant newOracle = IDNSSEC(0x668ad4467129d49ECbe6274d95197797C0E262AA);
    IDNSRegistrar constant newRegistrar = IDNSRegistrar(0x084462610A20eFbDB686b30fe587ecA0E234D2EF);
    IOffchainDNSResolver constant newResolver = IOffchainDNSResolver(0xA4A2d86B30896fe5c4f2A7F2Ee0BDE3dbff26924);

    IRootRegistryV2 constant rootRegistryV2 = IRootRegistryV2(0x2553c09bE6447BeFfdB86FA622ad41fB8f77A91e);
    ITemporaryDNSRegistrar constant temporaryRegistrar =
        ITemporaryDNSRegistrar(0x9d6D535f08be25A9A2FdA1a1C21217D27d81cC61);
    address constant DAO_TOKEN_SAFE = 0x5B716D6587d241166bC8914858640F8684F3A2F3;
    IDNSTLDResolverV2 constant currentTldResolverV2 = IDNSTLDResolverV2(0xaB48304A2520CE420E636AaCD48A8bb3e7e485Ee);
    IDNSTLDResolverV2 constant newTldResolverV2 = IDNSTLDResolverV2(0x6695327EE70F41151d2cBADC3ABBb6e4a58e739c);

    uint256 constant ROLE_REGISTRAR = 1 << 0;
    uint256 constant ROLE_REGISTER_RESERVED = 1 << 4;
    uint8 constant RESERVED = 1;
    uint8 constant REGISTERED = 2;

    address constant RSASHA1 = 0x58E0383E21f25DaB957F6664240445A514E9f5e8;
    address constant RSASHA256 = 0xaee0E2c4d5AB2fc164C8b0Cc8D3118C1c752C95E;
    address constant P256SHA256 = 0xB091C4F6FAc16eDDA5Ee1E0f4738f80011905878;
    address constant SHA1_DIGEST = 0x9c9fcEa62bD0A723b62A2F1e98dE0Ee3df813619;
    address constant SHA256_DIGEST = 0xCFe6edBD47a032585834A6921D1d05CB70FcC36d;
    string constant GATEWAY_URL = "https://dnssec-oracle.ens.domains/";

    uint16 constant TYPE_DS = 43;
    uint16 constant CLASS_INET = 1;
    uint32 constant ANCHOR_TTL = 3600;
    uint8 constant ALG_RSASHA256 = 8;
    uint8 constant DIGEST_SHA256 = 2;
    uint16 constant KSK_2017_TAG = 20_326;
    bytes32 constant KSK_2017_DIGEST = 0xE06D44B80B8F1D39A95C0B0D7C65D08458E880409BBC683457104237C7F8EC8D;
    uint16 constant KSK_2024_TAG = 38_696;
    bytes32 constant KSK_2024_DIGEST = 0x683D2D0ACB8C9B712A1948B27F741219298D0A450D612C483AF444A4C0FB2B16;

    address constant ENS_DOMAINS_OWNER = 0xb8c2C29ee19D8307cb7255e1Cd9CbDE883A267d5;
    address constant TAYTEMS_ADDR = 0x8e8Db5CcEF88cca9d624701Db544989C996E3216;
    string constant UNOWNED_LABEL = "notarealtldzz";
    uint256 constant SLICES = 8;

    string proofs;
    string suffixList;
    uint256 proofTime;

    function setUp() public override {
        super.setUp();
        proofs = vm.readFile(string.concat(dirPath(), "/fixtures/proofs.json"));
        assertEq(vm.parseJsonUint(proofs, ".forkBlock"), block.number);
        proofTime = vm.parseJsonUint(proofs, ".forkTimestamp");
        suffixList = vm.readFile(string.concat(dirPath(), "/fixtures/suffixes.json"));
    }

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 26_442_227, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0xb8c2C29ee19D8307cb7255e1Cd9CbDE883A267d5; // nick.eth
    }

    function _beforeProposal() public override {
        assertEq(root.owner(), address(timelock));
        assertTrue(root.controllers(address(currentRegistrar)));
        assertTrue(root.controllers(address(registrar2021)));
        assertTrue(root.controllers(address(tldToken)));
        assertFalse(root.controllers(address(newRegistrar)));
        _assertTld("xyz", address(currentRegistrar), address(currentResolver));

        _assertNewV1Contracts();
        _assertV2Before();

        IDNSSEC.RRSetWithSignature[] memory proof = _proof("ensDomainsClaim");
        assertEq(vm.parseJsonUint(proofs, ".proofs.ensDomainsClaim.rootSignature.keyTag"), KSK_2024_TAG);
        vm.expectRevert(abi.encodeWithSelector(IDNSSEC.NoMatchingProof.selector, _dnsName("")));
        currentOracle.verifyRRSet(proof);
        newOracle.verifyRRSet(proof);
    }

    function _generateCallData()
        public
        override
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory, string memory)
    {
        targets = new address[](6);
        values = new uint256[](6);
        calldatas = new bytes[](6);
        signatures = new string[](6);

        targets[0] = address(root);
        calldatas[0] = abi.encodeCall(IENSRoot.setController, (address(currentRegistrar), false));

        targets[1] = address(root);
        calldatas[1] = abi.encodeCall(IENSRoot.setController, (address(newRegistrar), true));

        targets[2] = address(rootRegistryV2);
        calldatas[2] = abi.encodeCall(
            IRootRegistryV2.grantRootRoles, (ROLE_REGISTRAR | ROLE_REGISTER_RESERVED, address(temporaryRegistrar))
        );

        (targets[3], calldatas[3]) = _buildSafeExecCalldata(
            DAO_TOKEN_SAFE,
            address(rootRegistryV2),
            abi.encodeCall(IRootRegistryV2.setApprovalForAll, (address(temporaryRegistrar), true)),
            address(timelock)
        );

        targets[4] = address(root);
        calldatas[4] = abi.encodeCall(IENSRoot.setController, (address(registrar2021), false));

        targets[5] = address(root);
        calldatas[5] = abi.encodeCall(IENSRoot.setController, (address(tldToken), false));

        description = getDescriptionFromMarkdown();
        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        assertFalse(root.controllers(address(currentRegistrar)));
        assertTrue(root.controllers(address(newRegistrar)));
        assertTrue(rootRegistryV2.hasRootRoles(ROLE_REGISTRAR | ROLE_REGISTER_RESERVED, address(temporaryRegistrar)));
        assertTrue(rootRegistryV2.isApprovedForAll(DAO_TOKEN_SAFE, address(temporaryRegistrar)));

        vm.prank(address(currentRegistrar));
        vm.expectRevert(bytes(""));
        root.setSubnodeOwner(labelhash(UNOWNED_LABEL), address(currentRegistrar));

        assertFalse(root.controllers(address(registrar2021)));
        vm.prank(makeAddr("anyone"));
        vm.expectRevert(bytes(""));
        registrar2021.claim(_dnsName(string.concat("x.", UNOWNED_LABEL)), "");

        assertFalse(root.controllers(address(tldToken)));
        assertEq(tldToken.owner(), LEGACY_MULTISIG);
        vm.startPrank(LEGACY_MULTISIG);
        tldToken.mintTLD("reverse", LEGACY_MULTISIG, "");
        vm.expectRevert(bytes(""));
        tldToken.claim(_labelId("reverse"), LEGACY_MULTISIG);
        vm.stopPrank();
        assertEq(registry.owner(namehash("reverse")), address(timelock));

        _assertV1Migration();
        _assertV2Sync();
        _assertThirdPartyTlds();
        _assertDaoControlsAnchors();

        vm.warp(proofTime);
        _assertClaimAndResolution();
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return false;
    }

    function test_suffixList0() public {
        _assertSuffixList(0);
    }

    function test_suffixList1() public {
        _assertSuffixList(1);
    }

    function test_suffixList2() public {
        _assertSuffixList(2);
    }

    function test_suffixList3() public {
        _assertSuffixList(3);
    }

    function test_suffixList4() public {
        _assertSuffixList(4);
    }

    function test_suffixList5() public {
        _assertSuffixList(5);
    }

    function test_suffixList6() public {
        _assertSuffixList(6);
    }

    function test_suffixList7() public {
        _assertSuffixList(7);
    }

    function _executeAsTimelock() internal {
        (targets, values, signatures, calldatas, description) = _generateCallData();
        vm.warp(block.timestamp + 9 days);
        for (uint256 i; i < targets.length; ++i) {
            vm.prank(address(timelock));
            (bool ok,) = targets[i].call{ value: values[i] }(calldatas[i]);
            assertTrue(ok);
        }
    }

    function _assertSuffixList(uint256 slice) internal {
        _executeAsTimelock();
        string[] memory all = vm.parseJsonStringArray(suffixList, ".labels");
        string[] memory tlds = new string[]((all.length + SLICES - 1 - slice) / SLICES);
        vm.startPrank(makeAddr("anyone"));
        for (uint256 i; i < tlds.length; ++i) {
            tlds[i] = all[slice + i * SLICES];
            bytes memory name = _dnsName(tlds[i]);
            assertTrue(suffixes.isPublicSuffix(name));
            address owner = registry.owner(namehash(bytes(tlds[i])));
            if (owner == address(0) || newRegistrar.wasRegistrar(owner)) {
                newRegistrar.enableNode(name);
                _assertTld(tlds[i], address(newRegistrar), address(newResolver));
            } else {
                assertTrue(_isThirdParty(tlds[i]));
            }
        }
        temporaryRegistrar.syncTLDs(tlds);
        vm.stopPrank();
        for (uint256 i; i < tlds.length; ++i) {
            assertEq(rootRegistryV2.getStatus(_labelId(tlds[i])), REGISTERED);
            assertEq(rootRegistryV2.getOwner(_labelId(tlds[i])), DAO_TOKEN_SAFE);
            assertEq(rootRegistryV2.getResolver(tlds[i]), address(newTldResolverV2));
        }
    }

    function _assertNewV1Contracts() internal view {
        assertEq(newOracle.owner(), address(timelock));
        assertEq(
            newOracle.anchors(),
            bytes.concat(_rootAnchor(KSK_2017_TAG, KSK_2017_DIGEST), _rootAnchor(KSK_2024_TAG, KSK_2024_DIGEST))
        );
        uint8[4] memory algorithmIds = [5, 7, ALG_RSASHA256, 13];
        address[4] memory algorithms = [RSASHA1, RSASHA1, RSASHA256, P256SHA256];
        for (uint256 i; i < algorithmIds.length; ++i) {
            assertEq(newOracle.algorithms(algorithmIds[i]), algorithms[i]);
        }
        assertEq(newOracle.digests(1), SHA1_DIGEST);
        assertEq(newOracle.digests(DIGEST_SHA256), SHA256_DIGEST);

        assertEq(newResolver.ens(), ENSConstants.ENS_REGISTRY);
        assertEq(newResolver.oracle(), address(newOracle));
        assertEq(newResolver.gatewayURL(), GATEWAY_URL);

        assertEq(newRegistrar.ens(), ENSConstants.ENS_REGISTRY);
        assertEq(newRegistrar.oracle(), address(newOracle));
        assertEq(newRegistrar.resolver(), address(newResolver));
        assertEq(newRegistrar.suffixes(), address(suffixes));
        assertEq(newRegistrar.previousRegistrar(), address(currentRegistrar));
        assertTrue(newRegistrar.wasRegistrar(address(currentRegistrar)));
        assertTrue(newRegistrar.wasRegistrar(currentRegistrar.previousRegistrar()));
    }

    function _assertV2Before() internal view {
        assertEq(temporaryRegistrar.owner(), address(timelock));
        assertEq(temporaryRegistrar.ROOT_REGISTRY(), address(rootRegistryV2));
        assertEq(temporaryRegistrar.TOKEN_OWNER(), DAO_TOKEN_SAFE);
        assertEq(temporaryRegistrar.PUBLIC_SUFFIX_LIST(), address(suffixes));
        assertEq(temporaryRegistrar.defaultResolver(), address(newTldResolverV2));
        assertEq(newTldResolverV2.DNSSEC_ORACLE(), address(newOracle));
        assertEq(currentTldResolverV2.DNSSEC_ORACLE(), address(currentOracle));

        address[] memory owners = ISafe(DAO_TOKEN_SAFE).getOwners();
        assertEq(owners.length, 1);
        assertEq(owners[0], address(timelock));
        assertEq(ISafe(DAO_TOKEN_SAFE).getThreshold(), 1);

        assertFalse(rootRegistryV2.hasRootRoles(ROLE_REGISTRAR | ROLE_REGISTER_RESERVED, address(temporaryRegistrar)));
        assertFalse(rootRegistryV2.isApprovedForAll(DAO_TOKEN_SAFE, address(temporaryRegistrar)));
        assertEq(rootRegistryV2.getStatus(_labelId("xyz")), RESERVED);
        assertEq(rootRegistryV2.getResolver("xyz"), address(currentTldResolverV2));
    }

    function _assertV1Migration() internal {
        vm.startPrank(makeAddr("anyone"));
        newRegistrar.enableNode(_dnsName("domains"));
        newRegistrar.enableNode(_dnsName("xyz"));
        vm.stopPrank();
        _assertTld("domains", address(newRegistrar), address(newResolver));
        _assertTld("xyz", address(newRegistrar), address(newResolver));
        assertEq(registry.owner(namehash("ens.domains")), ENS_DOMAINS_OWNER);
    }

    function _assertV2Sync() internal {
        vm.prank(makeAddr("anyone"));
        temporaryRegistrar.syncTLD("xyz");
        assertEq(rootRegistryV2.getStatus(_labelId("xyz")), REGISTERED);
        assertEq(rootRegistryV2.getOwner(_labelId("xyz")), DAO_TOKEN_SAFE);
        assertEq(rootRegistryV2.getResolver("xyz"), address(newTldResolverV2));

        vm.prank(address(timelock));
        temporaryRegistrar.setDefaultResolver(address(currentTldResolverV2));
        temporaryRegistrar.syncTLD("xyz");
        assertEq(rootRegistryV2.getResolver("xyz"), address(currentTldResolverV2));
        vm.prank(address(timelock));
        temporaryRegistrar.setDefaultResolver(address(newTldResolverV2));
        temporaryRegistrar.syncTLD("xyz");
        assertEq(rootRegistryV2.getResolver("xyz"), address(newTldResolverV2));

        vm.expectRevert(abi.encodeWithSelector(ITemporaryDNSRegistrar.TLDNotPublic.selector, "eth"));
        temporaryRegistrar.syncTLD("eth");
        vm.expectRevert(abi.encodeWithSelector(ITemporaryDNSRegistrar.TLDNotPublic.selector, "reverse"));
        temporaryRegistrar.syncTLD("reverse");
    }

    function _assertDaoControlsAnchors() internal {
        bytes memory anchors = newOracle.anchors();
        address anyone = makeAddr("anyone");
        vm.prank(anyone);
        vm.expectRevert(abi.encodeWithSelector(IDNSSEC.OwnableUnauthorizedAccount.selector, anyone));
        newOracle.setAnchors(anchors);
        vm.prank(address(timelock));
        newOracle.setAnchors(anchors);
    }

    function _assertClaimAndResolution() internal {
        IDNSSEC.RRSetWithSignature[] memory claim = _proof("ensDomainsClaim");
        vm.expectRevert(abi.encodeWithSelector(IDNSSEC.NoMatchingProof.selector, _dnsName("")));
        currentRegistrar.proveAndClaim(_dnsName("ens.domains"), claim);
        newRegistrar.proveAndClaim(_dnsName("ens.domains"), claim);
        assertEq(registry.owner(namehash("ens.domains")), ENS_DOMAINS_OWNER);

        bytes memory response = vm.parseJsonBytes(proofs, ".proofs.taytemsXyzGasless.gateway");
        bytes memory query = abi.encodeCall(IAddrResolver.addr, (namehash("taytems.xyz")));
        bytes memory extraData = abi.encode(_dnsName("taytems.xyz"), query, bytes4(0));
        assertEq(abi.decode(newResolver.resolveCallback(response, extraData), (address)), TAYTEMS_ADDR);
        vm.expectRevert(abi.encodeWithSelector(IDNSSEC.NoMatchingProof.selector, _dnsName("")));
        currentResolver.resolveCallback(response, extraData);
    }

    function _assertThirdPartyTlds() internal {
        string[7] memory tlds = _thirdPartyTlds();
        for (uint256 i; i < tlds.length; ++i) {
            address owner = registry.owner(namehash(bytes(tlds[i])));
            assertTrue(owner != address(0) && !newRegistrar.wasRegistrar(owner));
            vm.expectRevert(IDNSRegistrar.PreconditionNotMet.selector);
            newRegistrar.enableNode(_dnsName(tlds[i]));
            temporaryRegistrar.syncTLD(tlds[i]);
            assertEq(rootRegistryV2.getResolver(tlds[i]), address(newTldResolverV2));
            assertEq(_resolvesWithOldOracle(tlds[i]), keccak256(bytes(tlds[i])) == keccak256("hiphop"));
        }
        assertEq(registry.owner(namehash("hiphop")).code.length, 0);
        assertEq(currentResolver.oracle(), address(currentOracle));
    }

    function _resolvesWithOldOracle(string memory tld) internal view returns (bool) {
        try newTldResolverV2.getResolver(_dnsName(string.concat("test.", tld))) returns (address resolver, bool) {
            return resolver == address(currentResolver);
        } catch (bytes memory err) {
            assertEq(bytes4(err), IDNSTLDResolverV2.OffchainLookup.selector);
            return false;
        }
    }

    function _thirdPartyTlds() internal pure returns (string[7] memory) {
        return ["art", "box", "club", "hiphop", "kred", "locker", "luxe"];
    }

    function _isThirdParty(string memory tld) internal pure returns (bool) {
        string[7] memory tlds = _thirdPartyTlds();
        for (uint256 i; i < tlds.length; ++i) {
            if (keccak256(bytes(tlds[i])) == keccak256(bytes(tld))) return true;
        }
        return false;
    }

    function _assertTld(string memory tld, address owner, address resolver) internal view {
        assertEq(registry.owner(namehash(bytes(tld))), owner);
        assertEq(registry.resolver(namehash(bytes(tld))), resolver);
    }

    function _labelId(string memory label) internal pure returns (uint256) {
        return uint256(keccak256(bytes(label)));
    }

    function _rootAnchor(uint16 keyTag, bytes32 digest) internal pure returns (bytes memory) {
        return abi.encodePacked(
            bytes1(0), TYPE_DS, CLASS_INET, ANCHOR_TTL, uint16(36), keyTag, ALG_RSASHA256, DIGEST_SHA256, digest
        );
    }

    function _dnsName(string memory name) internal pure returns (bytes memory out) {
        bytes memory s = bytes(name);
        uint256 start;
        for (uint256 i; i <= s.length; ++i) {
            if (i < s.length && s[i] != ".") continue;
            if (i > start) out = bytes.concat(out, _label(s, start, i));
            start = i + 1;
        }
        return bytes.concat(out, bytes1(0));
    }

    function _label(bytes memory s, uint256 from, uint256 to) internal pure returns (bytes memory label) {
        label = new bytes(to - from + 1);
        label[0] = bytes1(uint8(to - from));
        for (uint256 i = from; i < to; ++i) {
            label[i - from + 1] = s[i];
        }
    }

    function _proof(string memory key) internal view returns (IDNSSEC.RRSetWithSignature[] memory) {
        return abi.decode(
            vm.parseJsonBytes(proofs, string.concat(".proofs.", key, ".gateway")), (IDNSSEC.RRSetWithSignature[])
        );
    }
}
