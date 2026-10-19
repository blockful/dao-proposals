// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { ENS_Governance } from "@ens/ens.t.sol";
import { IENSRegistrar } from "@ens/interfaces/IENSRegistrar.sol";
import { IENSRegistryWithFallback } from "@ens/interfaces/IENSRegistryWithFallback.sol";
import { IENSReverseRegistrar } from "@ens/interfaces/IENSReverseRegistrar.sol";

interface IRegistrarSecurityController {
    function setRegistrarResolver(address resolver) external;
    function removeRegistrarController(address controller) external;
    function addRegistrarController(address controller) external;
    function transferRegistrarOwnership(address newOwner) external;
}

interface IPublicResolverSet {
    function approve(address resolver, bool approved) external;
    function includes(address resolver) external view returns (bool);
}

interface IStandaloneHCAFactory {
    function setImplementationApproval(address implementation, bool approved) external;
    function approvedImplementations(address implementation) external view returns (bool);
}

interface IUniversalResolverProxy {
    function upgradeTo(address implementation) external;
    function implementation() external view returns (address);
}

contract Proposal_ENS_Activate_ENSv2_Test is ENS_Governance {
    IRegistrarSecurityController public constant REGISTRAR_SECURITY_CONTROLLER =
        IRegistrarSecurityController(0x7dd4d97653A67C2FD7fbA0a84825eC09524D4E1b);
    IENSRegistrar public constant BASE_REGISTRAR =
        IENSRegistrar(0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85);
    IENSRegistryWithFallback public constant ENS_REGISTRY =
        IENSRegistryWithFallback(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);
    IENSReverseRegistrar public constant DEFAULT_REVERSE_REGISTRAR =
        IENSReverseRegistrar(0x283F227c4Bd38ecE252C4Ae7ECE650B0e913f1f9);
    IENSReverseRegistrar public constant REVERSE_REGISTRAR =
        IENSReverseRegistrar(0xa58E81fe9b61B5c3fE2AFD33CF304c454AbFc7Cb);
    IPublicResolverSet public constant PUBLIC_RESOLVER_SET =
        IPublicResolverSet(0xfFCedA021CBDF20f1a66ebbef32E49d208cAbf62);
    IStandaloneHCAFactory public constant HCA_FACTORY =
        IStandaloneHCAFactory(0x742bf21897a78e2C98cC5f5C5473A370a081e561);
    IUniversalResolverProxy public constant UNIVERSAL_RESOLVER_PROXY =
        IUniversalResolverProxy(0xeEeEEEeE14D718C2B47D9923Deab1335E144EeEe);

    address public constant ENSV2_RESOLVER = 0x3071AD643cE4Ed8b3D67b289845b45dB82b068A4;
    address public constant DEFAULT_REVERSE_ADAPTER = 0xd86E32499eCAFe9c181dd7410f93A1a9bB61ef0d;
    address public constant REVERSE_ADAPTER = 0x349151735790269a9C14668B58D7C83b5ecb9607;
    address public constant PUBLIC_RESOLVER_2023 = 0x231b0Ee14048e9dCcD1d247744d114a4EB5E8E63;
    address public constant PUBLIC_RESOLVER_CURRENT = 0xF29100983E058B709F3D539b0c765937B804AC15;
    address public constant HCA_IMPLEMENTATION = 0x116F462FA078ec0009e9b25DCd60309E70aaC4F4;
    address public constant GRAVEYARD = 0xDa021A2C1C2F99574D861Ef8c6fA745851BEB7F6;
    address public constant ETH_RENEWER_V1 = 0x56c447F308F463A01121C41E72b0E7e7557fCb68;
    address public constant ETH_REGISTRAR_CONTROLLER = 0x59E16fcCd424Cc24e280Be16E11Bcd56fb0CE547;
    address public constant NAME_WRAPPER = 0xD4416b13d2b3a9aBae7AcD5D6C2BbDBE25686401;
    address public constant REGISTRAR_MIGRATION = 0x60C7C2A24b5e86C38639Fd1586917a8FEF66a56d;
    address public constant LEGACY_SAFE = 0xCF60916b6CB4753f58533808fA610FcbD4098Ec0;
    address public constant ORIGINAL_REGISTRAR_CONTROLLER = 0x283Af0B28c62C092C9727F1Ee09c02CA627EB7F5;
    address public constant MANAGED_UNIVERSAL_RESOLVER = 0xcFFd2Ae680CD110D28739a70922636B5937b022B;

    bytes32 private constant ETH_NODE =
        0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae;
    address private resolverBefore;
    address private registrarOwnerBefore;
    address private proxyImplementationBefore;

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 26_221_944, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0xb8c2C29ee19D8307cb7255e1Cd9CbDE883A267d5;
    }

    function _beforeProposal() public override {
        registrarOwnerBefore = BASE_REGISTRAR.owner();
        resolverBefore = ENS_REGISTRY.resolver(ETH_NODE);
        proxyImplementationBefore = UNIVERSAL_RESOLVER_PROXY.implementation();

        assertEq(
            registrarOwnerBefore,
            address(REGISTRAR_SECURITY_CONTROLLER),
            "BaseRegistrar must be owned by RegistrarSecurityController before execution"
        );
        assertTrue(BASE_REGISTRAR.controllers(ETH_REGISTRAR_CONTROLLER), "ETHRegistrarController must be active before execution");
        assertTrue(BASE_REGISTRAR.controllers(NAME_WRAPPER), "NameWrapper must be active before execution");
        assertTrue(BASE_REGISTRAR.controllers(REGISTRAR_MIGRATION), "RegistrarMigration must be active before execution");
        assertTrue(BASE_REGISTRAR.controllers(LEGACY_SAFE), "Legacy Safe must be active before execution");
        assertTrue(BASE_REGISTRAR.controllers(ORIGINAL_REGISTRAR_CONTROLLER), "Original controller must be active before execution");
        assertFalse(BASE_REGISTRAR.controllers(GRAVEYARD), "Graveyard must not be active before execution");
        assertFalse(BASE_REGISTRAR.controllers(ETH_RENEWER_V1), "ETHRenewerV1 must not be active before execution");
        assertFalse(DEFAULT_REVERSE_REGISTRAR.controllers(DEFAULT_REVERSE_ADAPTER), "Default reverse adapter must be disabled before execution");
        assertFalse(REVERSE_REGISTRAR.controllers(REVERSE_ADAPTER), "Reverse adapter must be disabled before execution");
        assertFalse(PUBLIC_RESOLVER_SET.includes(PUBLIC_RESOLVER_2023), "2023 PublicResolver must be unapproved before execution");
        assertFalse(PUBLIC_RESOLVER_SET.includes(PUBLIC_RESOLVER_CURRENT), "Current PublicResolver must be unapproved before execution");
        assertFalse(HCA_FACTORY.approvedImplementations(HCA_IMPLEMENTATION), "HCA implementation must be unapproved before execution");
        assertNotEq(resolverBefore, ENSV2_RESOLVER, "ENSv2 resolver must not already be configured");
        assertNotEq(proxyImplementationBefore, MANAGED_UNIVERSAL_RESOLVER, "Managed resolver proxy must not already be configured");
    }

    function _generateCallData()
        public
        override
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory, string memory)
    {
        uint256 callCount = 15;
        targets = new address[](callCount);
        values = new uint256[](callCount);
        signatures = new string[](callCount);
        calldatas = new bytes[](callCount);

        targets[0] = address(REGISTRAR_SECURITY_CONTROLLER);
        calldatas[0] = abi.encodeWithSelector(IRegistrarSecurityController.setRegistrarResolver.selector, ENSV2_RESOLVER);

        targets[1] = address(DEFAULT_REVERSE_REGISTRAR);
        calldatas[1] = abi.encodeWithSelector(IENSReverseRegistrar.setController.selector, DEFAULT_REVERSE_ADAPTER, true);

        targets[2] = address(REVERSE_REGISTRAR);
        calldatas[2] = abi.encodeWithSelector(IENSReverseRegistrar.setController.selector, REVERSE_ADAPTER, true);

        targets[3] = address(PUBLIC_RESOLVER_SET);
        calldatas[3] = abi.encodeWithSelector(IPublicResolverSet.approve.selector, PUBLIC_RESOLVER_2023, true);

        targets[4] = address(PUBLIC_RESOLVER_SET);
        calldatas[4] = abi.encodeWithSelector(IPublicResolverSet.approve.selector, PUBLIC_RESOLVER_CURRENT, true);

        targets[5] = address(HCA_FACTORY);
        calldatas[5] = abi.encodeWithSelector(IStandaloneHCAFactory.setImplementationApproval.selector, HCA_IMPLEMENTATION, true);

        targets[6] = address(REGISTRAR_SECURITY_CONTROLLER);
        calldatas[6] = abi.encodeWithSelector(IRegistrarSecurityController.removeRegistrarController.selector, ETH_REGISTRAR_CONTROLLER);
        targets[7] = address(REGISTRAR_SECURITY_CONTROLLER);
        calldatas[7] = abi.encodeWithSelector(IRegistrarSecurityController.removeRegistrarController.selector, NAME_WRAPPER);
        targets[8] = address(REGISTRAR_SECURITY_CONTROLLER);
        calldatas[8] = abi.encodeWithSelector(IRegistrarSecurityController.removeRegistrarController.selector, REGISTRAR_MIGRATION);
        targets[9] = address(REGISTRAR_SECURITY_CONTROLLER);
        calldatas[9] = abi.encodeWithSelector(IRegistrarSecurityController.removeRegistrarController.selector, LEGACY_SAFE);
        targets[10] = address(REGISTRAR_SECURITY_CONTROLLER);
        calldatas[10] = abi.encodeWithSelector(IRegistrarSecurityController.removeRegistrarController.selector, ORIGINAL_REGISTRAR_CONTROLLER);

        targets[11] = address(REGISTRAR_SECURITY_CONTROLLER);
        calldatas[11] = abi.encodeWithSelector(IRegistrarSecurityController.addRegistrarController.selector, GRAVEYARD);
        targets[12] = address(REGISTRAR_SECURITY_CONTROLLER);
        calldatas[12] = abi.encodeWithSelector(IRegistrarSecurityController.addRegistrarController.selector, ETH_RENEWER_V1);
        targets[13] = address(REGISTRAR_SECURITY_CONTROLLER);
        calldatas[13] = abi.encodeWithSelector(IRegistrarSecurityController.transferRegistrarOwnership.selector, ETH_RENEWER_V1);

        targets[14] = address(UNIVERSAL_RESOLVER_PROXY);
        calldatas[14] = abi.encodeWithSelector(IUniversalResolverProxy.upgradeTo.selector, MANAGED_UNIVERSAL_RESOLVER);

        description = getDescriptionFromMarkdown();
        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        assertEq(ENS_REGISTRY.resolver(ETH_NODE), ENSV2_RESOLVER, "Call 1: .eth resolver mismatch");
        assertTrue(DEFAULT_REVERSE_REGISTRAR.controllers(DEFAULT_REVERSE_ADAPTER), "Call 2: default reverse adapter not enabled");
        assertTrue(REVERSE_REGISTRAR.controllers(REVERSE_ADAPTER), "Call 3: reverse adapter not enabled");
        assertTrue(PUBLIC_RESOLVER_SET.includes(PUBLIC_RESOLVER_2023), "Call 4: 2023 PublicResolver not approved");
        assertTrue(PUBLIC_RESOLVER_SET.includes(PUBLIC_RESOLVER_CURRENT), "Call 5: current PublicResolver not approved");
        assertTrue(HCA_FACTORY.approvedImplementations(HCA_IMPLEMENTATION), "Call 6: HCA implementation not approved");

        assertFalse(BASE_REGISTRAR.controllers(ETH_REGISTRAR_CONTROLLER), "Call 7: ETHRegistrarController remains active");
        assertFalse(BASE_REGISTRAR.controllers(NAME_WRAPPER), "Call 8: NameWrapper remains active");
        assertFalse(BASE_REGISTRAR.controllers(REGISTRAR_MIGRATION), "Call 9: RegistrarMigration remains active");
        assertFalse(BASE_REGISTRAR.controllers(LEGACY_SAFE), "Call 10: legacy Safe remains active");
        assertFalse(BASE_REGISTRAR.controllers(ORIGINAL_REGISTRAR_CONTROLLER), "Call 11: original controller remains active");
        assertTrue(BASE_REGISTRAR.controllers(GRAVEYARD), "Call 12: Graveyard was not enabled");
        assertTrue(BASE_REGISTRAR.controllers(ETH_RENEWER_V1), "Call 13: ETHRenewerV1 was not enabled");
        assertEq(BASE_REGISTRAR.owner(), ETH_RENEWER_V1, "Call 14: BaseRegistrar owner mismatch");
        assertEq(UNIVERSAL_RESOLVER_PROXY.implementation(), MANAGED_UNIVERSAL_RESOLVER, "Call 15: resolver implementation mismatch");

        assertNotEq(registrarOwnerBefore, BASE_REGISTRAR.owner(), "BaseRegistrar owner did not change");
        assertNotEq(resolverBefore, ENS_REGISTRY.resolver(ETH_NODE), "Resolver did not change");
        assertNotEq(proxyImplementationBefore, UNIVERSAL_RESOLVER_PROXY.implementation(), "Resolver proxy did not change");
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-activate-ensv2";
    }
}
