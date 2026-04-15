// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";
import { console2 } from "@forge-std/src/console2.sol";

import { IToken } from "@ens/interfaces/IToken.sol";
import { IGovernor } from "@ens/interfaces/IGovernor.sol";
import { ITimelock } from "@ens/interfaces/ITimelock.sol";
import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";

import { ENS_Governance } from "@ens/ens.t.sol";
import { ENSConstants } from "@ens/Constants.sol";

contract Proposal_ENS_EP_5_25_Test is ENS_Governance {
    IERC20 USDC = IERC20(ENSConstants.USDC);

    uint256 USDCbalanceBefore;
    uint256 USDCbalanceAfter;
    uint256 metagovExpectedUSDCtransfer = 254_000 * 10 ** ENSConstants.USDC_DECIMALS;
    uint256 ecosystemExpectedUSDCtransfer = 836_000 * 10 ** ENSConstants.USDC_DECIMALS;
    uint256 pgExpectedUSDCtransfer = 226_000 * 10 ** ENSConstants.USDC_DECIMALS;

    address metagovMultisig = ENSConstants.META_GOV_MULTISIG;
    address ecosystemMultisig = ENSConstants.ECOSYSTEM_MULTISIG;
    address pgMultisig = ENSConstants.PUBLIC_GOODS_MULTISIG;

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 21_130_700, urlOrAlias: "mainnet" });
    }

    function _proposer() public view override returns (address) {
        return 0xe52C39327FF7576bAEc3DBFeF0787bd62dB6d726;
    }

    function _beforeProposal() public override {
        USDCbalanceBefore = USDC.balanceOf(address(timelock));
    }

    function _generateCallData()
        public
        override
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory, string memory)
    {
        uint256 items = 3;

        targets = new address[](items);
        targets[0] = ENSConstants.USDC;
        targets[1] = ENSConstants.USDC;
        targets[2] = ENSConstants.USDC;

        values = new uint256[](items);
        values[0] = 0;
        values[1] = 0;
        values[2] = 0;

        calldatas = new bytes[](items);
        calldatas[0] = abi.encodeWithSelector(IERC20.transfer.selector, metagovMultisig, metagovExpectedUSDCtransfer);
        calldatas[1] =
            abi.encodeWithSelector(IERC20.transfer.selector, ecosystemMultisig, ecosystemExpectedUSDCtransfer);
        calldatas[2] = abi.encodeWithSelector(IERC20.transfer.selector, pgMultisig, pgExpectedUSDCtransfer);

        return (targets, values, signatures, calldatas, "");
    }

    function _afterExecution() public override {
        USDCbalanceAfter = USDC.balanceOf(address(timelock));
        assertEq(
            USDCbalanceBefore,
            USDCbalanceAfter + metagovExpectedUSDCtransfer + ecosystemExpectedUSDCtransfer + pgExpectedUSDCtransfer
        );
        assertNotEq(USDCbalanceAfter, USDCbalanceBefore);
    }

    function _isProposalSubmitted() public view override returns (bool) {
        return false;
    }
}
