// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ENS_Governance } from "@ens/ens.t.sol";
import { ENSConstants } from "@ens/Constants.sol";
import { IENSRegistrar } from "@ens/interfaces/IENSRegistrar.sol";
import { IENSRegistryWithFallback } from "@ens/interfaces/IENSRegistryWithFallback.sol";
import { IENSReverseRegistrar } from "@ens/interfaces/IENSReverseRegistrar.sol";
import { IENSNewReverseRegistrar } from "@ens/interfaces/IENSNewReverseRegistrar.sol";

interface IRegistrarSecurityController {
    function owner() external view returns (address);
    function addRegistrarController(address controller) external;
    function removeRegistrarController(address controller) external;
    function setRegistrarResolver(address resolver) external;
    function transferRegistrarOwnership(address newOwner) external;
}

interface IUniversalResolverProxy {
    function upgradeTo(address newImplementation) external;
    function implementation() external view returns (address);
    function admin() external view returns (address);
}

interface IUniversalResolver {
    function resolve(bytes calldata name, bytes calldata data) external view returns (bytes memory, address);
}

interface IAddrResolver {
    function addr(bytes32 node) external view returns (address);
}

struct RenewData {
    string label;
    uint64 duration;
    bytes32 referrer;
}

interface IETHRenewerV1 {
    function renew(RenewData calldata rd, IERC20 paymentToken) external;
    function getRenewPrice(string calldata label, uint64 duration, IERC20 paymentToken) external view returns (uint256);
}

interface IAddressSet {
    function approve(address addr, bool approved) external;
    function includes(address addr) external view returns (bool);
}

interface IStandaloneHCAFactory {
    function setImplementationApproval(address implementation, bool approved) external;
    function approvedImplementations(address implementation) external view returns (bool);
}

contract Proposal_ENS_EP_Activate_ENSv2_Test is ENS_Governance {
    IENSRegistrar baseRegistrar = IENSRegistrar(0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85);
    IENSRegistryWithFallback ensRegistry = IENSRegistryWithFallback(ENSConstants.ENS_REGISTRY);
    IRegistrarSecurityController rsc = IRegistrarSecurityController(0x7dd4d97653A67C2FD7fbA0a84825eC09524D4E1b);
    IENSReverseRegistrar reverseRegistrar = IENSReverseRegistrar(0xa58E81fe9b61B5c3fE2AFD33CF304c454AbFc7Cb);
    IENSNewReverseRegistrar defaultReverseRegistrar =
        IENSNewReverseRegistrar(0x283F227c4Bd38ecE252C4Ae7ECE650B0e913f1f9);
    IUniversalResolverProxy universalResolver = IUniversalResolverProxy(0xeEeEEEeE14D718C2B47D9923Deab1335E144EeEe);

    address constant UNIVERSAL_RESOLVER_V1 = 0xED73a03F19e8D849E44a39252d222c6ad5217E1e;
    address constant ETH_OWNED_RESOLVER = 0x30200E0cb040F38E474E53EF437c95A1bE723b2B;
    address constant SECURITY_COUNCIL_SAFE = 0x7101B78638e34444F0a5AdE9e1149fbEeC029931;

    // v1 controllers removed in calls 4-8
    address constant ETH_REGISTRAR_CONTROLLER = 0x59E16fcCd424Cc24e280Be16E11Bcd56fb0CE547;
    address constant ETH_REGISTRAR_CONTROLLER_2023 = 0x253553366Da8546fC250F225fe3d25d0C782303b;
    address constant LEGACY_ETH_REGISTRAR_CONTROLLER = 0x283Af0B28c62C092C9727F1Ee09c02CA627EB7F5;
    address constant REGISTRAR_MIGRATION = 0x60C7C2A24b5e86C38639Fd1586917a8FEF66a56d;
    address constant LEGACY_MULTISIG = 0xCF60916b6CB4753f58533808fA610FcbD4098Ec0;

    // v2 contracts deployed by Labs on 2 Oct 2026 (the draft still shows them in angle brackets)
    address constant ENS_V2_RESOLVER = 0x8486D32948cDeF5c24236718318c6326D5d006A9;
    address constant REVERSE_REGISTRAR_ADAPTER = 0x349151735790269a9C14668B58D7C83b5ecb9607;
    address constant DEFAULT_REVERSE_REGISTRAR_ADAPTER = 0xd86E32499eCAFe9c181dd7410f93A1a9bB61ef0d;
    address constant ETH_RENEWER_V1 = 0xE038B778b1fbF47A84018820626afc908c9C62B1;
    address constant GRAVEYARD = 0xDa021A2C1C2F99574D861Ef8c6fA745851BEB7F6;
    address constant MANAGED_UNIVERSAL_RESOLVER = 0xcFFd2Ae680CD110D28739a70922636B5937b022B;
    IAddressSet publicResolverSet = IAddressSet(0xfFCedA021CBDF20f1a66ebbef32E49d208cAbf62);
    address constant PUBLIC_RESOLVER_2023 = 0x231b0Ee14048e9dCcD1d247744d114a4EB5E8E63;
    address constant PUBLIC_RESOLVER_CURRENT = 0xF29100983E058B709F3D539b0c765937B804AC15;
    IStandaloneHCAFactory hcaFactory = IStandaloneHCAFactory(0x742bf21897a78e2C98cC5f5C5473A370a081e561);
    address constant HCA_IMPLEMENTATION = 0x0e03Ae22bA5F4F6af8f51AC7a6d84488Db33A98a;

    address[6] removedControllers;
    bytes nickAddrBefore;

    function setUp() public override {
        super.setUp();
        removedControllers = [
            ETH_REGISTRAR_CONTROLLER,
            ETH_REGISTRAR_CONTROLLER_2023,
            LEGACY_ETH_REGISTRAR_CONTROLLER,
            ENSConstants.NAME_WRAPPER,
            REGISTRAR_MIGRATION,
            LEGACY_MULTISIG
        ];
    }

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 26_151_800, urlOrAlias: "mainnet" });
    }

    function _beforeProposal() public override {
        assertEq(rsc.owner(), address(timelock));
        assertEq(baseRegistrar.owner(), address(rsc));
        for (uint256 i; i < removedControllers.length; i++) {
            assertTrue(baseRegistrar.controllers(removedControllers[i]));
        }
        assertFalse(baseRegistrar.controllers(ETH_RENEWER_V1));
        assertFalse(baseRegistrar.controllers(GRAVEYARD));
        assertEq(ensRegistry.resolver(namehash("eth")), ETH_OWNED_RESOLVER);
        assertEq(universalResolver.implementation(), UNIVERSAL_RESOLVER_V1);
        assertEq(IUniversalResolverProxy(MANAGED_UNIVERSAL_RESOLVER).admin(), SECURITY_COUNCIL_SAFE);
        assertFalse(publicResolverSet.includes(PUBLIC_RESOLVER_2023));
        assertFalse(hcaFactory.approvedImplementations(HCA_IMPLEMENTATION));

        nickAddrBefore = _resolveNick();
    }

    function _generateCallData()
        public
        override
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory, string memory)
    {
        uint256 numTransactions = 16;

        targets = new address[](numTransactions);
        values = new uint256[](numTransactions);
        calldatas = new bytes[](numTransactions);
        signatures = new string[](numTransactions);

        // 1. .eth resolves through v2
        targets[0] = address(rsc);
        calldatas[0] =
            abi.encodeWithSelector(IRegistrarSecurityController.setRegistrarResolver.selector, ENS_V2_RESOLVER);

        // 2-3. reverse adapters
        targets[1] = address(reverseRegistrar);
        calldatas[1] =
            abi.encodeWithSelector(IENSReverseRegistrar.setController.selector, REVERSE_REGISTRAR_ADAPTER, true);
        targets[2] = address(defaultReverseRegistrar);
        calldatas[2] = abi.encodeWithSelector(
            IENSNewReverseRegistrar.setController.selector, DEFAULT_REVERSE_REGISTRAR_ADAPTER, true
        );

        // 4-9. remove the v1 controllers
        for (uint256 i; i < removedControllers.length; i++) {
            targets[3 + i] = address(rsc);
            calldatas[3 + i] = abi.encodeWithSelector(
                IRegistrarSecurityController.removeRegistrarController.selector, removedControllers[i]
            );
        }

        // 10-11. renewer and graveyard
        targets[9] = address(rsc);
        calldatas[9] =
            abi.encodeWithSelector(IRegistrarSecurityController.addRegistrarController.selector, ETH_RENEWER_V1);
        targets[10] = address(rsc);
        calldatas[10] = abi.encodeWithSelector(IRegistrarSecurityController.addRegistrarController.selector, GRAVEYARD);

        // 12. renewer takes the BaseRegistrar
        targets[11] = address(rsc);
        calldatas[11] =
            abi.encodeWithSelector(IRegistrarSecurityController.transferRegistrarOwnership.selector, ETH_RENEWER_V1);

        // 13. Universal Resolver goes through the managed proxy
        targets[12] = address(universalResolver);
        calldatas[12] = abi.encodeWithSelector(IUniversalResolverProxy.upgradeTo.selector, MANAGED_UNIVERSAL_RESOLVER);

        // 14-15. public resolvers for locked names
        targets[13] = address(publicResolverSet);
        calldatas[13] = abi.encodeWithSelector(IAddressSet.approve.selector, PUBLIC_RESOLVER_2023, true);
        targets[14] = address(publicResolverSet);
        calldatas[14] = abi.encodeWithSelector(IAddressSet.approve.selector, PUBLIC_RESOLVER_CURRENT, true);

        // 16. HCA implementation
        targets[15] = address(hcaFactory);
        calldatas[15] =
            abi.encodeWithSelector(IStandaloneHCAFactory.setImplementationApproval.selector, HCA_IMPLEMENTATION, true);

        description = "Pre-draft: EP X.Y Activate ENSv2";

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        assertEq(baseRegistrar.owner(), ETH_RENEWER_V1);
        assertTrue(baseRegistrar.controllers(ETH_RENEWER_V1));
        assertTrue(baseRegistrar.controllers(GRAVEYARD));
        for (uint256 i; i < removedControllers.length; i++) {
            assertFalse(baseRegistrar.controllers(removedControllers[i]));
        }
        assertEq(ensRegistry.resolver(namehash("eth")), ENS_V2_RESOLVER);
        assertTrue(reverseRegistrar.controllers(REVERSE_REGISTRAR_ADAPTER));
        assertTrue(defaultReverseRegistrar.controllers(DEFAULT_REVERSE_REGISTRAR_ADAPTER));
        assertEq(universalResolver.implementation(), MANAGED_UNIVERSAL_RESOLVER);
        assertTrue(publicResolverSet.includes(PUBLIC_RESOLVER_2023));
        assertTrue(publicResolverSet.includes(PUBLIC_RESOLVER_CURRENT));
        assertTrue(hcaFactory.approvedImplementations(HCA_IMPLEMENTATION));

        // v1 registrations are closed
        vm.prank(ETH_REGISTRAR_CONTROLLER);
        vm.expectRevert();
        baseRegistrar.register(uint256(labelhash("ensv2-freeze-check")), address(this), 365 days);

        // lookups don't change
        assertEq(_resolveNick(), nickAddrBefore);

        // renewals work in USDC and pay the timelock
        IERC20 usdc = IERC20(ENSConstants.USDC);
        IETHRenewerV1 renewer = IETHRenewerV1(ETH_RENEWER_V1);
        uint256 price = renewer.getRenewPrice("nick", 365 days, usdc);
        uint256 expiry = baseRegistrar.nameExpires(uint256(labelhash("nick")));
        uint256 timelockBalance = usdc.balanceOf(address(timelock));
        address payer = makeAddr("payer");
        deal(address(usdc), payer, price);
        vm.startPrank(payer);
        usdc.approve(ETH_RENEWER_V1, price);
        renewer.renew(RenewData("nick", 365 days, bytes32(0)), usdc);
        vm.stopPrank();
        assertEq(baseRegistrar.nameExpires(uint256(labelhash("nick"))), expiry + 365 days);
        assertEq(usdc.balanceOf(address(timelock)), timelockBalance + price);
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return false;
    }

    function dirPath() public pure override returns (string memory) {
        return "";
    }

    function _resolveNick() internal view returns (bytes memory result) {
        bytes memory name = abi.encodePacked(uint8(4), "nick", uint8(3), "eth", uint8(0));
        bytes memory data = abi.encodeWithSelector(IAddrResolver.addr.selector, namehash("nick.eth"));
        (result,) = IUniversalResolver(address(universalResolver)).resolve(name, data);
    }
}
