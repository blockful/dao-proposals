// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { LilNouns_Governance } from "@lil-nouns/lilNouns.t.sol";
import { LilNounsConstants } from "@lil-nouns/Constants.sol";
import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";

interface ILilNounsDebtManager {
    function debtOf(address account) external view returns (uint256);
    function paymentToken() external view returns (address);
    function totalDebt() external view returns (uint256);
}

interface IENSRegistry {
    function resolver(bytes32 node) external view returns (address);
}

interface INameResolver {
    function name(bytes32 node) external view returns (string memory);
}

contract Proposal_LilNouns_392_Test is LilNouns_Governance {
    address internal constant DEBT_MANAGER = 0xF62387d21153fdcbB06Ab3026c2089e418688164;
    address internal constant RECIPIENT = 0x0081e6f9373c1ffB7D7FC702EB15aC805EB50389;
    address internal constant PAYMENT_TOKEN = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant ENS_REGISTRY = 0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e;
    bytes32 internal constant RECIPIENT_REVERSE_NODE =
        0x8739916958e48d71470a6a9a402f5853dd80234398af3b912b6dadcbc4437200;
    uint256 internal constant AMOUNT = 3900e6;
    string internal constant SIGNATURE = "sendOrRegisterDebt(address,uint256)";

    IERC20 internal constant USDC = IERC20(PAYMENT_TOKEN);
    ILilNounsDebtManager internal constant DEBT = ILilNounsDebtManager(DEBT_MANAGER);

    uint256 internal recipientBalanceBefore;
    uint256 internal managerBalanceBefore;
    uint256 internal recipientDebtBefore;
    uint256 internal totalDebtBefore;

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 26_115_220, urlOrAlias: "mainnet" });
    }

    function _proposalId() internal pure override returns (uint256) {
        return 392;
    }

    function _startBlock() internal pure override returns (uint256) {
        return 26_129_620;
    }

    function _endBlock() internal pure override returns (uint256) {
        return 26_158_420;
    }

    function _quorumVotes() internal pure override returns (uint256) {
        return 384;
    }

    function _generateCallData()
        internal
        pure
        override
        returns (
            address[] memory generatedTargets,
            uint256[] memory generatedValues,
            string[] memory signatures,
            bytes[] memory generatedCalldatas
        )
    {
        generatedTargets = new address[](1);
        generatedValues = new uint256[](1);
        signatures = new string[](1);
        generatedCalldatas = new bytes[](1);

        generatedTargets[0] = DEBT_MANAGER;
        generatedValues[0] = 0;
        signatures[0] = SIGNATURE;
        generatedCalldatas[0] = abi.encode(RECIPIENT, AMOUNT);
    }

    function _beforeProposal() internal override {
        assertEq(GOVERNOR.state(_proposalId()), uint8(ProposalState.Pending), "proposal must be Pending at creation");
        assertEq(GOVERNOR.timelock(), LilNounsConstants.TIMELOCK, "unexpected execution timelock");
        assertEq(DEBT.paymentToken(), PAYMENT_TOKEN, "unexpected payment token");
        // Independent identity check: ENS reverse record for RECIPIENT is deguma.eth; forward resolution was checked
        // with cast.
        address resolver = IENSRegistry(ENS_REGISTRY).resolver(RECIPIENT_REVERSE_NODE);
        assertEq(INameResolver(resolver).name(RECIPIENT_REVERSE_NODE), "deguma.eth", "recipient ENS name mismatch");

        recipientBalanceBefore = USDC.balanceOf(RECIPIENT);
        managerBalanceBefore = USDC.balanceOf(DEBT_MANAGER);
        recipientDebtBefore = DEBT.debtOf(RECIPIENT);
        totalDebtBefore = DEBT.totalDebt();

        assertGe(managerBalanceBefore, AMOUNT, "debt manager cannot fund the requested amount");
        assertEq(recipientDebtBefore, 0, "recipient already has debt");
    }

    function _beforeExecution() internal override {
        assertGe(USDC.balanceOf(DEBT_MANAGER), AMOUNT, "debt manager balance changed before execution");
        assertEq(DEBT.debtOf(RECIPIENT), recipientDebtBefore, "recipient debt changed before execution");
    }

    function _afterExecution() internal override {
        assertEq(
            USDC.balanceOf(RECIPIENT), recipientBalanceBefore + AMOUNT, "recipient did not receive exactly 3,900 USDC"
        );
        assertEq(
            USDC.balanceOf(DEBT_MANAGER),
            managerBalanceBefore - AMOUNT,
            "manager balance did not decrease by 3,900 USDC"
        );
        assertEq(DEBT.debtOf(RECIPIENT), recipientDebtBefore, "payment unexpectedly registered as debt");
        assertEq(DEBT.totalDebt(), totalDebtBefore, "total debt changed unexpectedly");
    }

    function dirPath() public pure override returns (string memory) {
        return "src/lil-nouns/proposals/392-lil-nouns-scooter";
    }
}
