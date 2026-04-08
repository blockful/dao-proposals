// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "@forge-std/src/console2.sol";

import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";
import { ENS_Governance } from "@ens/ens.t.sol";
import { SafeHelper } from "@ens/helpers/SafeHelper.sol";

struct Allowance {
    uint96 amount;
    uint96 spent;
    uint16 resetTimeMin;
    uint32 lastResetMin;
    uint16 nonce;
}

interface IAllowanceModule {
    function setAllowance(
        address delegate,
        address token,
        uint96 allowanceAmount,
        uint16 resetTimeMin,
        uint32 resetBaseMin
    ) external;

    function allowances(address owner, address delegate, address token) external view returns (Allowance memory);
}

/**
 * @title Proposal_ENS_EP_6_2_Test
 * @notice Calldata review for ENS EP 6.2 - Endowment expansion (3rd tranche)
 * @dev This proposal:
 *      1. Transfers 5,000 ETH to the Endowment Safe
 *      2. Updates the Allowance Module on the Endowment Safe (resetTime 30d -> 25d)
 */
contract Proposal_ENS_EP_6_2_Test is ENS_Governance, SafeHelper {
    uint256 constant expectedETHtransfer = 5000 * 10 ** 18;

    IAllowanceModule allowanceModule = IAllowanceModule(0xCFbFaC74C26F8647cBDb8c5caf80BB5b32E43134);

    uint256 ETHbalanceBefore;


    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 21_724_691, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0xe52C39327FF7576bAEc3DBFeF0787bd62dB6d726; // 5pence.eth
    }

    function _beforeProposal() public override {
        ETHbalanceBefore = address(timelock).balance;
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

        // Transaction 1: Transfer 5,000 ETH to Endowment Safe
        targets[0] = address(endowmentSafe);
        calldatas[0] = new bytes(0);
        values[0] = expectedETHtransfer;
        signatures[0] = "";

        // Transaction 2: Update Allowance Module via Safe execTransaction
        // Sets resetTimeMin from 43,200 (30 days) to 36,000 (25 days) for Meta-Gov WG
        bytes memory callData = abi.encodeWithSelector(
            IAllowanceModule.setAllowance.selector,
            0x91c32893216dE3eA0a55ABb9851f581d4503d39b, // delegate: Meta-Gov WG
            0x0000000000000000000000000000000000000000, // token: ETH
            30 ether, // allowanceAmount
            36_000, // resetTimeMin (25 days)
            28_825_613 // resetBaseMin
        );

        (, calldatas[1]) = _buildSafeExecCalldata(
            address(endowmentSafe),
            address(allowanceModule),
            callData,
            address(timelock)
        );
        targets[1] = address(endowmentSafe);
        values[1] = 0;
        signatures[1] = "";

        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public view override {
        uint256 ETHbalanceAfter = address(timelock).balance;
        assertEq(ETHbalanceBefore, ETHbalanceAfter + expectedETHtransfer);

        Allowance memory allowance = allowanceModule.allowances(
            address(endowmentSafe),
            0x91c32893216dE3eA0a55ABb9851f581d4503d39b,
            address(0)
        );

        assertEq(allowance.amount, 30 ether);
        assertEq(allowance.spent, 0);
        assertEq(allowance.resetTimeMin, 36_000);
        assertEq(allowance.lastResetMin, 28_969_613);
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-6-2";
    }
}
