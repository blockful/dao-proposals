// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "@forge-std/src/console2.sol";

import { ENS_Governance } from "@ens/ens.t.sol";
import { IENSReverseRegistrar } from "@ens/interfaces/IENSReverseRegistrar.sol";
import { ISafe } from "@ens/interfaces/ISafe.sol";
import { IEthTLDResolver } from "@ens/interfaces/IEthTLDResolver.sol";

contract ProposalENS_EP_Naming_Core_Contracts_Test is ENS_Governance {
    // Contract addresses
    IENSReverseRegistrar reverseRegistrar = IENSReverseRegistrar(0xa58E81fe9b61B5c3fE2AFD33CF304c454AbFc7Cb);
    IEthTLDResolver resolver = IEthTLDResolver(0xF29100983E058B709F3D539b0c765937B804AC15);

    address token = 0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72;
    address endowment = 0x4F2083f5fBede34C2714aFfb3105539775f7FE64;

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 23484400, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0x5BFCB4BE4d7B43437d5A0c57E908c048a4418390;
    }

    function _beforeProposal() public view override {
        assertEq(resolver.name(reverseRegistrar.node(endowment)), "");
        assertEq(resolver.name(reverseRegistrar.node(token)), "");
        assertEq(resolver.name(reverseRegistrar.node(address(timelock))), "");
    }

    function _generateCallData()
        public
        override
        returns (
            address[] memory,
            uint256[] memory,
            string[] memory,
            bytes[] memory,
            string memory
        )
    {
        uint256 numTransactions = 3;

        targets = new address[](numTransactions);
        values = new uint256[](numTransactions);
        calldatas = new bytes[](numTransactions);
        signatures = new string[](numTransactions);

        targets[0] = address(reverseRegistrar);
        calldatas[0] = abi.encodeWithSelector(
            reverseRegistrar.setName.selector,
            "wallet.ensdao.eth"
        );
        values[0] = 0;
        signatures[0] = "";

        targets[1] = address(reverseRegistrar);
        calldatas[1] = abi.encodeWithSelector(
            reverseRegistrar.setNameForAddr.selector,
            token,
            timelock,
            resolver,
            "token.ensdao.eth"
        );
        values[1] = 0;
        signatures[1] = "";

        targets[2] = address(endowment);
        calldatas[2] = abi.encodeWithSelector(
            ISafe.execTransaction.selector,
            address(reverseRegistrar),
            0,
            abi.encodeWithSelector(
                reverseRegistrar.setName.selector,
                "endowment.ensdao.eth"
            ),
            0,
            0,
            0,
            0,
            address(0x0),
            address(0x0),
            hex"000000000000000000000000fe89cc7abb2c4183683ab71653c4cdc9b02d44b7000000000000000000000000000000000000000000000000000000000000000001"
        );
        values[2] = 0;
        signatures[2] = "";

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public view override {
        assertEq(resolver.name(reverseRegistrar.node(endowment)), "endowment.ensdao.eth");
        assertEq(resolver.name(reverseRegistrar.node(token)), "token.ensdao.eth");
        assertEq(resolver.name(reverseRegistrar.node(address(timelock))), "wallet.ensdao.eth");
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return false;
    }
}
