// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";

import { ENS_Governance } from "@ens/ens.t.sol";
import { ENSConstants } from "@ens/Constants.sol";
import { IENSRegistryWithFallback } from "@ens/interfaces/IENSRegistryWithFallback.sol";
import { IEthTLDResolver } from "@ens/interfaces/IEthTLDResolver.sol";

contract Proposal_ENS_EP_7_2_Test is ENS_Governance {
    IERC20 constant USDC = IERC20(ENSConstants.USDC);
    address constant metagovMultisig = ENSConstants.META_GOV_MULTISIG;

    uint256 constant usdcUnit = 10 ** ENSConstants.USDC_DECIMALS;
    uint256 constant usdcTransfer = 201_559 * usdcUnit;
    uint256 constant expectedProposalId =
        29_869_795_646_732_068_004_798_516_302_146_892_294_228_731_133_327_210_892_747_948_610_417_217_569_076;

    uint256 metagovUsdcBefore;
    uint256 timelockUsdcBefore;

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 26_307_524, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0x1D5460F896521aD685Ea4c3F2c679Ec0b6806359; // coltron.eth
    }

    function _beforeProposal() public override {
        assertEq(proposalId, expectedProposalId);

        bytes32 node = namehash(bytes("main.mg.wg.ens.eth"));
        address resolver = IENSRegistryWithFallback(ENSConstants.ENS_REGISTRY).resolver(node);
        assertEq(IEthTLDResolver(resolver).addr(node), metagovMultisig);

        metagovUsdcBefore = USDC.balanceOf(metagovMultisig);
        timelockUsdcBefore = USDC.balanceOf(address(timelock));

        assertEq(metagovUsdcBefore / usdcUnit, 88_481);
        assertGe(timelockUsdcBefore, usdcTransfer);
    }

    function _generateCallData()
        public
        override
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory, string memory)
    {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        signatures = new string[](1);

        targets[0] = ENSConstants.USDC;
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(IERC20.transfer.selector, metagovMultisig, usdcTransfer);

        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        assertEq(USDC.balanceOf(metagovMultisig), metagovUsdcBefore + usdcTransfer);
        assertEq(USDC.balanceOf(address(timelock)), timelockUsdcBefore - usdcTransfer);
        assertEq(USDC.balanceOf(metagovMultisig) / usdcUnit, 290_040);
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-7-2";
    }
}
