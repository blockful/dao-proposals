// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { ENS_Governance } from "@ens/ens.t.sol";
import { IENSRegistryWithFallback } from "@ens/interfaces/IENSRegistryWithFallback.sol";
import { IENSRegistrar } from "@ens/interfaces/IENSRegistrar.sol";
import { IENSReverseRegistrar } from "@ens/interfaces/IENSReverseRegistrar.sol";
import { IENSNewReverseRegistrar } from "@ens/interfaces/IENSNewReverseRegistrar.sol";
import { IEthTLDResolver } from "@ens/interfaces/IEthTLDResolver.sol";
import { INewEthRegistrarController } from "@ens/interfaces/INewEthRegistrarController.sol";
import { IArbitrumReverseResolver } from "@ens/interfaces/IArbitrumReverseResolver.sol";
import { IBaseReverseResolver } from "@ens/interfaces/IBaseReverseResolver.sol";
import { ILineaReverseResolver } from "@ens/interfaces/ILineaReverseResolver.sol";
import { IOptimismReverseResolver } from "@ens/interfaces/IOptimismReverseResolver.sol";
import { IScrollReverseResolver } from "@ens/interfaces/IScrollReverseResolver.sol";
import { IDefaultReverseEnsAddr } from "@ens/interfaces/IDefaultReverseEnsAddr.sol";

contract Proposal_ENS_EP_6_35_Test is ENS_Governance {
    IENSRegistryWithFallback internal constant ensRegistry =
        IENSRegistryWithFallback(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);
    IENSRegistrar internal constant ensRegistrar = IENSRegistrar(0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85);
    IENSReverseRegistrar internal constant reverseRegistrar =
        IENSReverseRegistrar(0xa58E81fe9b61B5c3fE2AFD33CF304c454AbFc7Cb);
    IENSNewReverseRegistrar internal constant defaultReverseRegistrar =
        IENSNewReverseRegistrar(0x283F227c4Bd38ecE252C4Ae7ECE650B0e913f1f9);
    IEthTLDResolver internal constant ethTLDResolver = IEthTLDResolver(0x30200E0cb040F38E474E53EF437c95A1bE723b2B);

    INewEthRegistrarController internal constant newEthRegistrarController =
        INewEthRegistrarController(0x59E16fcCd424Cc24e280Be16E11Bcd56fb0CE547);
    address internal constant NEW_DEFAULT_REVERSE_RESOLVER = 0xA7d635c8de9a58a228AA69353a1699C7Cc240DCF;
    address internal constant NEW_PUBLIC_RESOLVER = 0xF29100983E058B709F3D539b0c765937B804AC15;

    IArbitrumReverseResolver internal constant arbitrumReverseResolver =
        IArbitrumReverseResolver(0x4b9572C03AAa8b0Efa4B4b0F0cc0f0992bEDB898);
    IBaseReverseResolver internal constant baseReverseResolver =
        IBaseReverseResolver(0xc800DBc8ff9796E58EfBa2d7b35028DdD1997E5e);
    ILineaReverseResolver internal constant lineaReverseResolver =
        ILineaReverseResolver(0x0Ce08a41bdb10420FB5Cac7Da8CA508EA313aeF8);
    IOptimismReverseResolver internal constant optimismReverseResolver =
        IOptimismReverseResolver(0xF9Edb1A21867aC11b023CE34Abad916D29aBF107);
    IScrollReverseResolver internal constant scrollReverseResolver =
        IScrollReverseResolver(0xd38bf7c18c25AC1b4ce2CC077cbC35b2B97f01e7);

    IDefaultReverseEnsAddr internal constant defaultReverseEnsAddr =
        IDefaultReverseEnsAddr(0x283F227c4Bd38ecE252C4Ae7ECE650B0e913f1f9);

    address internal constant DNSSEC_ENS_ADDR = 0x0fc3152971714E5ed7723FAFa650F86A4BaF30C5;
    address internal constant ROOT_ENS_ADDR = 0xaB528d626EC275E3faD363fF1393A41F581c5897;

    bytes32 internal constant REVERSE_NODE = 0xa097f6721ce401e757d1223a763fef49b8b5f90bb18567ddb86fd205dff71d34;
    bytes32 internal constant ARBITRUM_LABEL = 0x7d8e29b968b7788e83efa746345c315e0cf10df6950259a7cb05ce0149b8b6e3;
    bytes32 internal constant BASE_LABEL = 0x4056cb788b3af93d9486e35f4d0aff6b21a4da32161ef55acba5a78d69dad5b6;
    bytes32 internal constant LINEA_LABEL = 0x44495acbb270e33daa2b6b957b8713b55ab4a023300855e3adeb370f8bfcd47a;
    bytes32 internal constant OPTIMISM_LABEL = 0xf66cf533d101dfb2f2352e61965e14aa7e9c4164b3bfc91cbe188645e0f16336;
    bytes32 internal constant SCROLL_LABEL = 0x2e83a9aa4cc1622acc9e36e8853598634e92fa0eb10aec9b07fc68664b2ad87e;

    // This bytes32 node is taken from the on-chain calldata for tx #10.
    bytes32 internal constant ETH_INTERFACE_NODE =
        0x58665280491fc90c59d3e71704f32f95343423627fb87cf300bb02544c671cdb;

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 22_888_159, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0xb8c2C29ee19D8307cb7255e1Cd9CbDE883A267d5; // nick.eth
    }

    function _beforeProposal() public view override {
        assertEq(defaultReverseRegistrar.owner(), address(timelock), "default reverse registrar owner mismatch");
        assertEq(newEthRegistrarController.owner(), address(timelock), "new controller owner mismatch");
        assertEq(arbitrumReverseResolver.owner(), address(timelock), "arbitrum resolver owner mismatch");
        assertEq(baseReverseResolver.owner(), address(timelock), "base resolver owner mismatch");
        assertEq(lineaReverseResolver.owner(), address(timelock), "linea resolver owner mismatch");
        assertEq(optimismReverseResolver.owner(), address(timelock), "optimism resolver owner mismatch");
        assertEq(scrollReverseResolver.owner(), address(timelock), "scroll resolver owner mismatch");
        assertEq(defaultReverseEnsAddr.owner(), address(timelock), "default reverse ENS addr owner mismatch");
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

        targets[0] = address(ensRegistry);
        calldatas[0] = abi.encodeWithSelector(
            IENSRegistryWithFallback.setResolver.selector, REVERSE_NODE, NEW_DEFAULT_REVERSE_RESOLVER
        );

        targets[1] = address(ensRegistry);
        calldatas[1] = abi.encodeWithSelector(
            IENSRegistryWithFallback.setSubnodeRecord.selector,
            REVERSE_NODE,
            ARBITRUM_LABEL,
            address(timelock),
            address(arbitrumReverseResolver),
            0
        );

        targets[2] = address(ensRegistry);
        calldatas[2] = abi.encodeWithSelector(
            IENSRegistryWithFallback.setSubnodeRecord.selector,
            REVERSE_NODE,
            BASE_LABEL,
            address(timelock),
            address(baseReverseResolver),
            0
        );

        targets[3] = address(ensRegistry);
        calldatas[3] = abi.encodeWithSelector(
            IENSRegistryWithFallback.setSubnodeRecord.selector,
            REVERSE_NODE,
            LINEA_LABEL,
            address(timelock),
            address(lineaReverseResolver),
            0
        );

        targets[4] = address(ensRegistry);
        calldatas[4] = abi.encodeWithSelector(
            IENSRegistryWithFallback.setSubnodeRecord.selector,
            REVERSE_NODE,
            OPTIMISM_LABEL,
            address(timelock),
            address(optimismReverseResolver),
            0
        );

        targets[5] = address(ensRegistry);
        calldatas[5] = abi.encodeWithSelector(
            IENSRegistryWithFallback.setSubnodeRecord.selector,
            REVERSE_NODE,
            SCROLL_LABEL,
            address(timelock),
            address(scrollReverseResolver),
            0
        );

        targets[6] = address(ensRegistrar);
        calldatas[6] = abi.encodeWithSelector(IENSRegistrar.addController.selector, address(newEthRegistrarController));

        targets[7] = address(reverseRegistrar);
        calldatas[7] = abi.encodeWithSelector(
            IENSReverseRegistrar.setController.selector, address(newEthRegistrarController), true
        );

        targets[8] = address(defaultReverseRegistrar);
        calldatas[8] = abi.encodeWithSelector(
            IENSNewReverseRegistrar.setController.selector, address(newEthRegistrarController), true
        );

        bytes4 controllerInterfaceId = calculateNewEthRegistrarControllerInterfaceId();
        assertEq(controllerInterfaceId, bytes4(0xe4f37f79), "new controller interface id mismatch");

        targets[9] = address(ethTLDResolver);
        calldatas[9] = abi.encodeWithSelector(
            IEthTLDResolver.setInterface.selector, ETH_INTERFACE_NODE, controllerInterfaceId, address(newEthRegistrarController)
        );

        targets[10] = address(reverseRegistrar);
        calldatas[10] = abi.encodeWithSelector(IENSReverseRegistrar.setDefaultResolver.selector, NEW_PUBLIC_RESOLVER);

        targets[11] = address(reverseRegistrar);
        calldatas[11] = abi.encodeWithSelector(
            IENSReverseRegistrar.setNameForAddr.selector, DNSSEC_ENS_ADDR, address(timelock), NEW_PUBLIC_RESOLVER, "dnssec.ens.eth"
        );

        targets[12] = address(reverseRegistrar);
        calldatas[12] = abi.encodeWithSelector(
            IENSReverseRegistrar.setNameForAddr.selector,
            address(ensRegistrar),
            address(timelock),
            NEW_PUBLIC_RESOLVER,
            "registrar.ens.eth"
        );

        targets[13] = address(reverseRegistrar);
        calldatas[13] = abi.encodeWithSelector(
            IENSReverseRegistrar.setNameForAddr.selector, ROOT_ENS_ADDR, address(timelock), NEW_PUBLIC_RESOLVER, "root.ens.eth"
        );

        targets[14] = address(reverseRegistrar);
        calldatas[14] = abi.encodeWithSelector(
            IENSReverseRegistrar.setNameForAddr.selector,
            address(newEthRegistrarController),
            address(timelock),
            NEW_PUBLIC_RESOLVER,
            "controller.ens.eth"
        );

        targets[15] = address(reverseRegistrar);
        calldatas[15] = abi.encodeWithSelector(
            IENSReverseRegistrar.setNameForAddr.selector,
            address(defaultReverseEnsAddr),
            address(timelock),
            NEW_PUBLIC_RESOLVER,
            "default.reverse.ens.eth"
        );

        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public view override {
        assertEq(ensRegistry.resolver(REVERSE_NODE), NEW_DEFAULT_REVERSE_RESOLVER, "reverse resolver mismatch");

        assertEq(
            ensRegistry.resolver(keccak256(abi.encodePacked(REVERSE_NODE, ARBITRUM_LABEL))),
            address(arbitrumReverseResolver),
            "arbitrum resolver not set"
        );
        assertEq(
            ensRegistry.resolver(keccak256(abi.encodePacked(REVERSE_NODE, BASE_LABEL))),
            address(baseReverseResolver),
            "base resolver not set"
        );
        assertEq(
            ensRegistry.resolver(keccak256(abi.encodePacked(REVERSE_NODE, LINEA_LABEL))),
            address(lineaReverseResolver),
            "linea resolver not set"
        );
        assertEq(
            ensRegistry.resolver(keccak256(abi.encodePacked(REVERSE_NODE, OPTIMISM_LABEL))),
            address(optimismReverseResolver),
            "optimism resolver not set"
        );
        assertEq(
            ensRegistry.resolver(keccak256(abi.encodePacked(REVERSE_NODE, SCROLL_LABEL))),
            address(scrollReverseResolver),
            "scroll resolver not set"
        );

        assertTrue(ensRegistrar.controllers(address(newEthRegistrarController)), "registrar controller not set");
        assertTrue(reverseRegistrar.controllers(address(newEthRegistrarController)), "reverse registrar controller not set");
        assertTrue(
            defaultReverseRegistrar.controllers(address(newEthRegistrarController)),
            "default reverse registrar controller not set"
        );

        assertEq(
            ethTLDResolver.interfaceImplementer(ETH_INTERFACE_NODE, bytes4(0xe4f37f79)),
            address(newEthRegistrarController),
            "interface implementer mismatch"
        );

        assertEq(reverseRegistrar.defaultResolver(), NEW_PUBLIC_RESOLVER, "default resolver mismatch");

        assertEq(ensRegistry.resolver(reverseRegistrar.node(DNSSEC_ENS_ADDR)), NEW_PUBLIC_RESOLVER, "dnssec reverse mismatch");
        assertEq(
            ensRegistry.resolver(reverseRegistrar.node(address(ensRegistrar))), NEW_PUBLIC_RESOLVER, "registrar reverse mismatch"
        );
        assertEq(ensRegistry.resolver(reverseRegistrar.node(ROOT_ENS_ADDR)), NEW_PUBLIC_RESOLVER, "root reverse mismatch");
        assertEq(
            ensRegistry.resolver(reverseRegistrar.node(address(newEthRegistrarController))),
            NEW_PUBLIC_RESOLVER,
            "controller reverse mismatch"
        );
        assertEq(
            ensRegistry.resolver(reverseRegistrar.node(address(defaultReverseEnsAddr))),
            NEW_PUBLIC_RESOLVER,
            "default reverse reverse mismatch"
        );
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true;
    }

    function calculateNewEthRegistrarControllerInterfaceId() public pure returns (bytes4) {
        return INewEthRegistrarController.rentPrice.selector ^ INewEthRegistrarController.available.selector
            ^ INewEthRegistrarController.makeCommitment.selector ^ INewEthRegistrarController.commit.selector
            ^ INewEthRegistrarController.register.selector ^ INewEthRegistrarController.renew.selector;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-6-35";
    }
}
