// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";

import { ENS_Governance } from "@ens/ens.t.sol";
import { ENSConstants } from "@ens/Constants.sol";
import { IENSRegistryWithFallback } from "@ens/interfaces/IENSRegistryWithFallback.sol";
import { IEthTLDResolver } from "@ens/interfaces/IEthTLDResolver.sol";
import { ISafe } from "@ens/interfaces/ISafe.sol";

/**
 * @title Proposal_ENS_EP_7_2_Test
 * @notice ENS EP 7.2 — Meta-Governance Working Group funding for Term 7 (October window).
 * @dev Transfers 201,559 USDC from the timelock to main.mg.wg.ens.eth: the 290,040 USDC budget through
 *      30 June 2027 minus the 88,481 USDC the Safe already holds. The description is the text of the
 *      Social vote, so it still calls itself a Social Proposal; that does not change the payload.
 */
contract Proposal_ENS_EP_7_2_Test is ENS_Governance {
    IERC20 constant USDC = IERC20(ENSConstants.USDC);
    IERC20 constant ENS = IERC20(ENSConstants.ENS_TOKEN);
    address constant metagovMultisig = ENSConstants.META_GOV_MULTISIG;

    uint256 constant usdcUnit = 10 ** ENSConstants.USDC_DECIMALS;
    uint256 constant ensUnit = 10 ** ENSConstants.ENS_DECIMALS;

    // Budget lines from the proposal, 1 October 2026 through 30 June 2027
    uint256 constant stewardCompensation = 9 * (5500 + 2 * 4000) * usdcUnit;
    uint256 constant daoCommunications = 9 * 2060 * usdcUnit;
    uint256 constant discretionary = 50_000 * usdcUnit;
    uint256 constant contractAudits = 100_000 * usdcUnit;
    uint256 constant budget = stewardCompensation + daoCommunications + discretionary + contractAudits;

    uint256 constant usdcHeld = 88_481 * usdcUnit;
    uint256 constant usdcTransfer = budget - usdcHeld;

    uint256 constant expectedProposalId =
        29_869_795_646_732_068_004_798_516_302_146_892_294_228_731_133_327_210_892_747_948_610_417_217_569_076;

    uint256 metagovUsdcBefore;
    uint256 metagovEnsBefore;
    uint256 metagovEthBefore;
    uint256 timelockUsdcBefore;
    uint256 timelockEnsBefore;
    uint256 timelockEthBefore;

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 26_307_524, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0x1D5460F896521aD685Ea4c3F2c679Ec0b6806359; // coltron.eth
    }

    function _beforeProposal() public override {
        assertEq(proposalId, expectedProposalId);
        assertEq(budget, 290_040 * usdcUnit);
        assertEq(usdcTransfer, 201_559 * usdcUnit);

        // The recipient is the Safe the proposal names
        bytes32 node = namehash(bytes("main.mg.wg.ens.eth"));
        address resolver = IENSRegistryWithFallback(ENSConstants.ENS_REGISTRY).resolver(node);
        assertEq(IEthTLDResolver(resolver).addr(node), metagovMultisig);

        // 2-of-4 with the timelock in the fourth seat, and no module that could move funds around the owners
        ISafe safe = ISafe(metagovMultisig);
        address[] memory owners = safe.getOwners();
        assertEq(safe.getThreshold(), 2);
        assertEq(owners.length, 4);
        bool timelockIsOwner;
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == address(timelock)) timelockIsOwner = true;
        }
        assertTrue(timelockIsOwner);
        (address[] memory modules,) = safe.getModulesPaginated(address(1), 1);
        assertEq(modules.length, 0);

        metagovUsdcBefore = USDC.balanceOf(metagovMultisig);
        metagovEnsBefore = ENS.balanceOf(metagovMultisig);
        metagovEthBefore = metagovMultisig.balance;
        timelockUsdcBefore = USDC.balanceOf(address(timelock));
        timelockEnsBefore = ENS.balanceOf(address(timelock));
        timelockEthBefore = address(timelock).balance;

        // The balances the request is netted against are still the ones in the proposal
        assertEq(metagovUsdcBefore / usdcUnit, usdcHeld / usdcUnit);
        assertEq(metagovEnsBefore / ensUnit, 117_129);
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

        // 201,559 USDC to the Meta-Gov multisig
        targets[0] = ENSConstants.USDC;
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(IERC20.transfer.selector, metagovMultisig, usdcTransfer);

        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        assertEq(USDC.balanceOf(metagovMultisig), metagovUsdcBefore + usdcTransfer);
        assertEq(USDC.balanceOf(address(timelock)), timelockUsdcBefore - usdcTransfer);
        assertGe(USDC.balanceOf(metagovMultisig), budget);

        // Only USDC moves
        assertEq(ENS.balanceOf(metagovMultisig), metagovEnsBefore);
        assertEq(metagovMultisig.balance, metagovEthBefore);
        assertEq(ENS.balanceOf(address(timelock)), timelockEnsBefore);
        assertEq(address(timelock).balance, timelockEthBefore);
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-7-2";
    }
}
