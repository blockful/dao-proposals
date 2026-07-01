// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";

import { ENS_Governance } from "@ens/ens.t.sol";
import { ENSConstants } from "@ens/Constants.sol";

/**
 * @title Proposal_ENS_EP_6_47_Test
 * @notice ENS EP 6.47 — Delegation Incentives Program funding transfer.
 * @dev Transfers 5 ETH and 90,000 ENS from the timelock to the Meta-Gov multisig.
 */
contract Proposal_ENS_EP_6_47_Test is ENS_Governance {
    IERC20 constant ENS = IERC20(ENSConstants.ENS_TOKEN);
    address constant metagovMultisig = ENSConstants.META_GOV_MULTISIG;

    uint256 constant ethTransfer = 5 ether;
    uint256 constant ensTransfer = 90_000 * 10 ** ENSConstants.ENS_DECIMALS;
    uint256 constant expectedProposalId =
        104_212_182_161_850_550_962_744_337_399_787_220_583_533_293_984_710_381_556_645_937_262_731_963_073_399;

    uint256 metagovEthBefore;
    uint256 metagovEnsBefore;
    uint256 timelockEthBefore;
    uint256 timelockEnsBefore;

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 25_424_099, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0x809FA673fe2ab515FaA168259cB14E2BeDeBF68e; // avsa.eth
    }

    function _beforeProposal() public override {
        assertEq(proposalId, expectedProposalId);

        metagovEthBefore = metagovMultisig.balance;
        metagovEnsBefore = ENS.balanceOf(metagovMultisig);
        timelockEthBefore = address(timelock).balance;
        timelockEnsBefore = ENS.balanceOf(address(timelock));

        assertGe(timelockEthBefore, ethTransfer);
        assertGe(timelockEnsBefore, ensTransfer);
    }

    function _generateCallData()
        public
        override
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory, string memory)
    {
        targets = new address[](2);
        values = new uint256[](2);
        calldatas = new bytes[](2);
        signatures = new string[](2);

        // 5 ETH to the Meta-Gov multisig
        targets[0] = metagovMultisig;
        values[0] = ethTransfer;
        calldatas[0] = "";

        // 90,000 ENS to the Meta-Gov multisig
        targets[1] = ENSConstants.ENS_TOKEN;
        values[1] = 0;
        calldatas[1] = abi.encodeWithSelector(IERC20.transfer.selector, metagovMultisig, ensTransfer);

        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        assertEq(metagovMultisig.balance, metagovEthBefore + ethTransfer);
        assertEq(ENS.balanceOf(metagovMultisig), metagovEnsBefore + ensTransfer);
        assertEq(address(timelock).balance, timelockEthBefore - ethTransfer);
        assertEq(ENS.balanceOf(address(timelock)), timelockEnsBefore - ensTransfer);
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-6-47";
    }
}
