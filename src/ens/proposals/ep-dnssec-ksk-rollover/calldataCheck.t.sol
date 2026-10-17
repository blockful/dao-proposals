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

/// @notice Draft "[Executable] Upgrade DNSSEC oracle and registrar for the 2026 root KSK rollover"
///         (ens.gov.blockful.io draft a9adfa71-3cde-44f5-950b-ff97602bdeef, by nick.eth).
/// @dev The draft has no actions attached and its new contracts are `0x<TBD>`, so there is no
///      proposalCalldata.json to compare against. The calldata is built from the draft's
///      Specification / Transactions sections, and the three new contracts are deployed on the fork
///      from ensdomains/ens-contracts commit f0151aa (see upstream/build.sh), wired as the draft's
///      "Deployed contracts" table says. Proofs in fixtures/proofs.json were fetched at the fork
///      block (see fixtures/fetch_proofs.py).
///      Runs on Osaka: the P256SHA256 algorithm contract (id 13) calls the P256VERIFY precompile at
///      0x100 (EIP-7951), which mainnet has since Osaka. Under the repo default (cancun) every P-256
///      signature fails to verify.
/// forge-config: default.evm_version = "osaka"
contract Proposal_ENS_EP_DNSSEC_KSK_Rollover_Draft_Test is ENS_Governance {
    // ─── Existing contracts
    // ─────────────────────────────────────────────
    IENSRoot constant root = IENSRoot(ENSConstants.ENS_ROOT);
    IENSRegistryWithFallback constant registry = IENSRegistryWithFallback(ENSConstants.ENS_REGISTRY);
    // DNSSECImpl from January 2024, anchors fixed at deployment
    IDNSSEC constant currentOracle = IDNSSEC(0x0fc3152971714E5ed7723FAFa650F86A4BaF30C5);
    // DNSRegistrar from January 2024, made a Root controller by the proposal created at block 19_033_106
    IDNSRegistrar constant currentRegistrar = IDNSRegistrar(0xB32cB5677a7C971689228EC835800432B339bA2B);
    // DNSRegistrar from 2021, currentRegistrar.previousRegistrar(); never removed as a Root controller
    IDNSRegistrar2021 constant registrar2021 = IDNSRegistrar2021(0x58774Bb8acD458A640aF0B88238369A167546ef2);
    // OffchainDNSResolver used as the resolver of every DNS TLD the current registrar holds
    IOffchainDNSResolver constant currentResolver = IOffchainDNSResolver(0xF142B308cF687d4358410a4cB885513b30A42025);
    // Public suffix list passed as `suffixes` to the new DNSRegistrar (unchanged)
    IPublicSuffixList constant suffixes = IPublicSuffixList(0x823BDa9cA8c47d072376eCD595530c8fb2fAa3ED);

    // Algorithm and digest contracts from the draft's table
    address constant RSASHA1 = 0x58E0383E21f25DaB957F6664240445A514E9f5e8;
    address constant RSASHA256 = 0xaee0E2c4d5AB2fc164C8b0Cc8D3118C1c752C95E;
    address constant P256SHA256 = 0xB091C4F6FAc16eDDA5Ee1E0f4738f80011905878;
    address constant SHA1_DIGEST = 0x9c9fcEa62bD0A723b62A2F1e98dE0Ee3df813619;
    address constant SHA256_DIGEST = 0xCFe6edBD47a032585834A6921D1d05CB70FcC36d;
    string constant GATEWAY_URL = "https://dnssec-oracle.ens.domains/";

    // ─── DNSSEC parameters (RFC 4034, IANA DNSSEC registries)
    // ───────────
    uint8 constant ALG_RSASHA1 = 5;
    uint8 constant ALG_RSASHA1_NSEC3 = 7;
    uint8 constant ALG_RSASHA256 = 8;
    uint8 constant ALG_P256SHA256 = 13;
    uint8 constant DIGEST_SHA1 = 1;
    uint8 constant DIGEST_SHA256 = 2;
    uint16 constant TYPE_DS = 43;
    uint16 constant TYPE_DNSKEY = 48;
    uint16 constant CLASS_INET = 1;
    // TTL of the anchor records, as in the current oracle and upstream test/fixtures/anchors.ts
    uint32 constant ANCHOR_TTL = 3600;

    // Root KSKs, https://data.iana.org/root-anchors/root-anchors.xml
    uint16 constant KSK_2010_TAG = 19_036;
    bytes32 constant KSK_2010_DIGEST = 0x49AAC11D7B6F6446702E54A1607371607A1A41855200FD2CE1CDDE32F24E8FB5;
    uint16 constant KSK_2017_TAG = 20_326;
    bytes32 constant KSK_2017_DIGEST = 0xE06D44B80B8F1D39A95C0B0D7C65D08458E880409BBC683457104237C7F8EC8D;
    uint16 constant KSK_2024_TAG = 38_696;
    bytes32 constant KSK_2024_DIGEST = 0x683D2D0ACB8C9B712A1948B27F741219298D0A450D612C483AF444A4C0FB2B16;

    // ─── Names exercised end to end
    // ─────────────────────────────────────
    // _ens.ens.domains TXT "a=0xb8c2...": ens.domains is imported and owned by nick.eth
    address constant ENS_DOMAINS_OWNER = 0xb8c2C29ee19D8307cb7255e1Cd9CbDE883A267d5;
    // taytems.xyz TXT "ENS1 dnsname.ens.eth 0x8e8D...": gasless, never imported
    address constant TAYTEMS_ADDR = 0x8e8Db5CcEF88cca9d624701Db544989C996E3216;
    // Claimed through the current registrar, so it has a stored `_ens` TXT inception there
    string constant CLAIMED_NAME = "rendyrhey.xyz";
    // Not a TLD in DNS or ENS, and not in the current public suffix list
    string constant UNOWNED_LABEL = "notarealtldzz";

    // ─── Stand-ins for the contracts ENS Labs will deploy (`0x<TBD>` in the draft)
    // ─
    IDNSSEC newOracle;
    IOffchainDNSResolver newResolver;
    IDNSRegistrar newRegistrar;

    string proofs;
    uint256 proofTime;

    function setUp() public override {
        super.setUp();
        proofs = vm.readFile(string.concat(dirPath(), "/fixtures/proofs.json"));
        assertEq(vm.parseJsonUint(proofs, ".forkBlock"), block.number, "fixtures fetched at a different block");
        proofTime = vm.parseJsonUint(proofs, ".forkTimestamp");
        _deployNewContracts();
    }

    function _selectFork() public override {
        // Block fixtures/proofs.json was fetched at; every RRSIG in it is valid at this block's timestamp
        vm.createSelectFork({ blockNumber: 26_214_036, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0xb8c2C29ee19D8307cb7255e1Cd9CbDE883A267d5; // nick.eth, draft author
    }

    function _beforeProposal() public override {
        // Root is DAO-owned; both earlier registrars are controllers, the new one is not yet
        assertEq(root.owner(), address(timelock));
        assertTrue(root.controllers(address(currentRegistrar)));
        assertTrue(root.controllers(address(registrar2021)));
        assertFalse(root.controllers(address(newRegistrar)));

        // The current stack, as the draft describes it
        assertEq(currentRegistrar.oracle(), address(currentOracle));
        assertEq(currentRegistrar.resolver(), address(currentResolver));
        assertEq(currentRegistrar.suffixes(), address(suffixes));
        assertEq(currentRegistrar.previousRegistrar(), address(registrar2021));
        assertEq(currentResolver.oracle(), address(currentOracle));
        assertEq(currentOracle.owner(), address(timelock));
        // Trusts KSK-2010 and KSK-2017 only. Also checks _rootAnchor() against the on-chain encoding.
        assertEq(
            currentOracle.anchors(),
            bytes.concat(_rootAnchor(KSK_2010_TAG, KSK_2010_DIGEST), _rootAnchor(KSK_2017_TAG, KSK_2017_DIGEST))
        );

        _assertMatchesDescription();
        _assertNewContractsMatchDraft();
        _assertProofsBeforeExecution();

        // TLDs exercised below are held by the current registrar and resolved by the current resolver
        _assertTld("domains", address(currentRegistrar), address(currentResolver));
        _assertTld("xyz", address(currentRegistrar), address(currentResolver));
        assertEq(registry.owner(namehash("ens.domains")), ENS_DOMAINS_OWNER);
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

        // TX1: authorise the new DNSRegistrar as a controller of the root
        targets[0] = address(root);
        calldatas[0] = abi.encodeCall(IENSRoot.setController, (address(newRegistrar), true));

        // TX2: deauthorise the current DNSRegistrar
        targets[1] = address(root);
        calldatas[1] = abi.encodeCall(IENSRoot.setController, (address(currentRegistrar), false));

        description = getDescriptionFromMarkdown();
        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        assertEq(root.owner(), address(timelock));
        assertTrue(root.controllers(address(newRegistrar)));
        assertFalse(root.controllers(address(currentRegistrar)));
        // FINDING: the draft leaves the 2021 registrar as a Root controller
        assertTrue(root.controllers(address(registrar2021)));

        _assertControllerRights();
        _assertTldMigration();
        _assertDaoControlsAnchors();

        // The lifecycle moved the clock ~9 days past the fixtures' RRSIG windows. Rewind to the fetch
        // time so the proofs are submitted as if freshly fetched; contract state is unaffected.
        vm.warp(proofTime);
        _assertClaims();
        _assertGaslessResolution();
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return false;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    DEPLOYMENT
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Mirrors upstream deploy/dnssec-oracle/10_deploy_oracle.ts and deploy/dnsregistrar/{00,10},
    ///      plus the ownership transfer the draft says ENS Labs will make.
    function _deployNewContracts() internal {
        string memory out = string.concat(dirPath(), "/upstream/artifacts/");

        newOracle = IDNSSEC(
            deployCode(
                string.concat(out, "DNSSECImpl.json"),
                abi.encode(
                    bytes.concat(_rootAnchor(KSK_2017_TAG, KSK_2017_DIGEST), _rootAnchor(KSK_2024_TAG, KSK_2024_DIGEST))
                )
            )
        );
        newOracle.setAlgorithm(ALG_RSASHA1, RSASHA1);
        newOracle.setAlgorithm(ALG_RSASHA1_NSEC3, RSASHA1);
        newOracle.setAlgorithm(ALG_RSASHA256, RSASHA256);
        newOracle.setAlgorithm(ALG_P256SHA256, P256SHA256);
        newOracle.setDigest(DIGEST_SHA1, SHA1_DIGEST);
        newOracle.setDigest(DIGEST_SHA256, SHA256_DIGEST);
        newOracle.transferOwnership(address(timelock));

        newResolver = IOffchainDNSResolver(
            deployCode(
                string.concat(out, "OffchainDNSResolver.json"),
                abi.encode(ENSConstants.ENS_REGISTRY, address(newOracle), GATEWAY_URL)
            )
        );

        // As 10_deploy_dnsregistrar.ts builds it: walk previousRegistrar() from the current deployment
        address[] memory previousRegistrars = new address[](2);
        previousRegistrars[0] = address(currentRegistrar);
        previousRegistrars[1] = address(registrar2021);
        newRegistrar = IDNSRegistrar(
            deployCode(
                string.concat(out, "DNSRegistrar.json"),
                abi.encode(
                    previousRegistrars,
                    address(newResolver),
                    address(newOracle),
                    address(suffixes),
                    ENSConstants.ENS_REGISTRY
                )
            )
        );

        vm.label(address(newOracle), "newDNSSECImpl");
        vm.label(address(newResolver), "newOffchainDNSResolver");
        vm.label(address(newRegistrar), "newDNSRegistrar");
        vm.label(address(currentOracle), "currentDNSSECImpl");
        vm.label(address(currentRegistrar), "currentDNSRegistrar");
        vm.label(address(registrar2021), "dnsRegistrar2021");
        vm.label(address(currentResolver), "currentOffchainDNSResolver");
        vm.label(address(root), "root");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                BEFORE EXECUTION
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev The draft has no actions attached, so the comparison target is its description: the
    ///      Transactions table (target, value, function) and the Calldata block. The new registrar's
    ///      address is a placeholder there and is filled in with the stand-in's.
    function _assertMatchesDescription() internal {
        string memory body = vm.readFile(string.concat(dirPath(), "/proposalDescription.md"));

        // Transactions table: both rows call setController(address,bool) on Root with 0 ETH
        string memory row =
            string.concat("| `", vm.toString(address(root)), "` | 0 ETH | `setController(address,bool)` |");
        assertEq(vm.split(body, row).length - 1, targets.length, "Transactions table rows");
        assertEq(IENSRoot.setController.selector, bytes4(keccak256("setController(address,bool)")));
        for (uint256 i; i < targets.length; ++i) {
            assertEq(targets[i], address(root));
            assertEq(values[i], 0);
        }

        // Calldata block: one hex line per transaction, in order
        string memory placeholder = "<new DNSRegistrar, 20 bytes>";
        string memory standIn = vm.replace(vm.toLowercase(vm.toString(address(newRegistrar))), "0x", "");
        string[] memory lines = vm.split(body, "\n");
        uint256 n;
        for (uint256 i; i < lines.length; ++i) {
            if (vm.indexOf(lines[i], "0x") != 0) continue;
            assertLt(n, calldatas.length, "more calldata lines than transactions");
            assertEq(vm.parseBytes(vm.replace(lines[i], placeholder, standIn)), calldatas[n], "description calldata");
            ++n;
        }
        assertEq(n, calldatas.length, "calldata lines in the description");

        _assertDescribedArguments(body);
    }

    /// @dev The Transactions table's argument cells, in row order, and every existing address the
    ///      stand-ins are wired with.
    function _assertDescribedArguments(string memory body) internal {
        string memory compact = vm.replace(body, " ", "");
        uint256 newController = _describedAt(compact, "|`controller`|`0x<newDNSRegistrar>`|");
        uint256 enabled = _describedAt(compact, "|`enabled`|`true`|");
        uint256 oldController =
            _describedAt(compact, string.concat("|`controller`|`", vm.toString(address(currentRegistrar)), "`|"));
        uint256 disabled = _describedAt(compact, "|`enabled`|`false`|");
        assertTrue(
            newController < enabled && enabled < oldController && oldController < disabled,
            "Transactions table argument order"
        );

        string memory lower = vm.toLowercase(body);
        address[9] memory wiring = [
            address(suffixes),
            RSASHA1,
            RSASHA256,
            P256SHA256,
            SHA1_DIGEST,
            SHA256_DIGEST,
            ENSConstants.ENS_REGISTRY,
            address(registrar2021),
            address(timelock)
        ];
        for (uint256 i; i < wiring.length; ++i) {
            _describedAt(lower, vm.toLowercase(vm.toString(wiring[i])));
        }
        _describedAt(body, GATEWAY_URL);
    }

    function _describedAt(string memory haystack, string memory needle) internal pure returns (uint256 at) {
        at = vm.indexOf(haystack, needle);
        assertTrue(at != type(uint256).max, string.concat("not in description: ", needle));
    }

    /// @dev The draft's "Deployed contracts" table and "Verifying this proposal" checklist.
    function _assertNewContractsMatchDraft() internal view {
        assertEq(newOracle.owner(), address(timelock));
        assertEq(
            newOracle.anchors(),
            bytes.concat(_rootAnchor(KSK_2017_TAG, KSK_2017_DIGEST), _rootAnchor(KSK_2024_TAG, KSK_2024_DIGEST))
        );
        // Same algorithm and digest contracts as the current oracle, matching the draft's table
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
        // The list 10_deploy_dnsregistrar.ts builds by walking previousRegistrar() on-chain
        assertTrue(newRegistrar.wasRegistrar(currentRegistrar.previousRegistrar()));
        assertFalse(newRegistrar.wasRegistrar(address(newRegistrar)));
    }

    function _assertProofsBeforeExecution() internal {
        IDNSSEC.RRSetWithSignature[] memory gateway = _proof("ensDomainsClaim", "gateway");
        IDNSSEC.RRSetWithSignature[] memory ksk2024 = _proof("ensDomainsClaim", "ksk2024");

        // The gateway still serves a root DNSKEY RRset signed by KSK-2017 before the rollover, so the
        // current oracle still verifies its proofs today...
        assertEq(vm.parseJsonUint(proofs, ".proofs.ensDomainsClaim.gatewayRootKeyTag"), KSK_2017_TAG);
        (bytes memory txtRRset,) = currentOracle.verifyRRSet(gateway);

        // ...but not a chain that starts from the root DNSKEY RRset the root servers serve now
        assertEq(vm.parseJsonUint(proofs, ".rootDnskeyKeyTag"), KSK_2024_TAG);
        vm.expectRevert(abi.encodeWithSelector(IDNSSEC.NoMatchingProof.selector, _dnsName("")));
        currentOracle.verifyRRSet(ksk2024);

        // The new oracle verifies both, ending in the same _ens.ens.domains TXT RRset
        (bytes memory rrs,) = newOracle.verifyRRSet(ksk2024);
        assertEq(rrs, txtRRset);
        (rrs,) = newOracle.verifyRRSet(gateway);
        assertEq(rrs, txtRRset);

        // The gateway's KSK-2017 root signature lapses at 2026-10-22 00:00 UTC; after that the current
        // oracle cannot verify the root link at all. The KSK-2024 one is valid until 2026-11-01.
        uint32 lapse = uint32(vm.parseJsonUint(proofs, ".proofs.ensDomainsClaim.gatewayRootExpiration"));
        assertEq(lapse, 1_792_627_200, "2026-10-22T00:00:00Z");
        currentOracle.verifyRRSet(_rootLink(gateway), lapse);
        vm.expectRevert(abi.encodeWithSelector(IDNSSEC.SignatureExpired.selector, lapse, lapse + 1));
        currentOracle.verifyRRSet(_rootLink(gateway), lapse + 1);
        newOracle.verifyRRSet(_rootLink(ksk2024), lapse + 1);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                AFTER EXECUTION
    //////////////////////////////////////////////////////////////////////////*/

    function _assertControllerRights() internal {
        bytes32 label = labelhash(UNOWNED_LABEL);
        bytes32 node = namehash(bytes(UNOWNED_LABEL));
        assertEq(registry.owner(node), address(0));
        assertFalse(root.locked(label));

        // The current registrar can no longer assign TLDs through the root (Controllable's bare require)
        vm.prank(address(currentRegistrar));
        vm.expectRevert(bytes(""));
        root.setSubnodeOwner(label, address(currentRegistrar));

        // The 2021 registrar still can, and anyone can make it: `claim` enables the parent name before
        // looking at the proof, an empty proof for a name with no stored TXT record does not revert, and
        // its suffix list accepts any single label. So any unowned TLD can be pulled under it.
        IPublicSuffixList suffixes2021 = IPublicSuffixList(registrar2021.suffixes());
        assertTrue(suffixes2021.isPublicSuffix(_dnsName(UNOWNED_LABEL)));
        assertFalse(suffixes.isPublicSuffix(_dnsName(UNOWNED_LABEL)));
        vm.prank(makeAddr("anyone"));
        registrar2021.claim(_dnsName(string.concat("x.", UNOWNED_LABEL)), "");
        assertEq(registry.owner(node), address(registrar2021));
    }

    /// @dev What 20_set_tlds.ts does for every DNS TLD, for the two TLDs exercised here.
    function _assertTldMigration() internal {
        vm.startPrank(makeAddr("anyone"));
        newRegistrar.enableNode(_dnsName("domains"));
        newRegistrar.enableNode(_dnsName("xyz"));
        vm.stopPrank();
        _assertTld("domains", address(newRegistrar), address(newResolver));
        _assertTld("xyz", address(newRegistrar), address(newResolver));

        // A TLD held by a third party is not migrated, even if it uses the current resolver: .hiphop's
        // owner has to point it at the new resolver, or gasless names under it stay broken
        assertEq(registry.resolver(namehash("hiphop")), address(currentResolver));
        vm.expectRevert(IDNSRegistrar.PreconditionNotMet.selector);
        newRegistrar.enableNode(_dnsName("hiphop"));

        // Imported names stay with their owners
        assertEq(registry.owner(namehash("ens.domains")), ENS_DOMAINS_OWNER);
        // Stored `_ens` TXT inceptions carry over from the current registrar
        bytes32 claimed = namehash(bytes(CLAIMED_NAME));
        assertGt(currentRegistrar.inceptions(claimed), 0);
        assertEq(newRegistrar.inceptions(claimed), currentRegistrar.inceptions(claimed));
    }

    /// @dev The draft's "future rollovers are a single setAnchors call": only the DAO can make it.
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
        IDNSSEC.RRSetWithSignature[] memory ksk2024 = _proof("ensDomainsClaim", "ksk2024");
        bytes memory ensDomains = _dnsName("ens.domains");

        // The current registrar cannot verify a KSK-2024 chain
        vm.expectRevert(abi.encodeWithSelector(IDNSSEC.NoMatchingProof.selector, _dnsName("")));
        currentRegistrar.proveAndClaim(ensDomains, ksk2024);

        // The new registrar can; the claim re-asserts the owner in the TXT record
        newRegistrar.proveAndClaim(ensDomains, ksk2024);
        assertEq(registry.owner(namehash("ens.domains")), ENS_DOMAINS_OWNER);
        uint32 rootInception = uint32(vm.parseJsonUint(proofs, ".rootDnskeyInception"));
        assertEq(newRegistrar.getInception(_dnsName(""), TYPE_DNSKEY), rootInception);

        // A chain with an older, still unexpired root signature (the gateway's 2026-10-01 KSK-2017
        // one) is now rejected: the stale-ancestor check the draft describes
        uint32 gatewayRootInception = uint32(vm.parseJsonUint(proofs, ".proofs.ensDomainsClaim.gatewayRootInception"));
        assertLt(gatewayRootInception, rootInception);
        vm.expectRevert(
            abi.encodeWithSelector(
                IDNSRegistrar.StaleProof.selector, _dnsName(""), TYPE_DNSKEY, rootInception, gatewayRootInception
            )
        );
        newRegistrar.proveAndClaim(ensDomains, gateway);
    }

    function _assertGaslessResolution() internal {
        bytes memory response = vm.parseJsonBytes(proofs, ".proofs.taytemsXyzGasless.ksk2024");
        bytes memory query = abi.encodeCall(IAddrResolver.addr, (namehash("taytems.xyz")));
        bytes memory extraData = abi.encode(_dnsName("taytems.xyz"), query, bytes4(0));

        // The resolver the TLD now points at answers from a KSK-2024 chain
        assertEq(registry.resolver(namehash("xyz")), address(newResolver));
        assertEq(abi.decode(newResolver.resolveCallback(response, extraData), (address)), TAYTEMS_ADDR);

        // The resolver it pointed at before cannot
        vm.expectRevert(abi.encodeWithSelector(IDNSSEC.NoMatchingProof.selector, _dnsName("")));
        currentResolver.resolveCallback(response, extraData);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    function _assertTld(string memory tld, address owner, address resolver) internal view {
        bytes32 node = namehash(bytes(tld));
        assertEq(registry.owner(node), owner, string.concat(tld, " owner"));
        assertEq(registry.resolver(node), resolver, string.concat(tld, " resolver"));
    }

    /// @dev A root DS record in wire format (RFC 4034 5.1), the form the oracle stores anchors in.
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

    /// @dev "ens.domains" -> 0x03656e7307646f6d61696e7300; "" -> the root, 0x00.
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

    /// @dev Just the root DNSKEY link of a proof.
    function _rootLink(IDNSSEC.RRSetWithSignature[] memory proof)
        internal
        pure
        returns (IDNSSEC.RRSetWithSignature[] memory link)
    {
        link = new IDNSSEC.RRSetWithSignature[](1);
        link[0] = proof[0];
    }
}
