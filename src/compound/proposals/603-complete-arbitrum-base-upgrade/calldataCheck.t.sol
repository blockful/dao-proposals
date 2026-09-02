// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Compound_Governance } from "@compound/compound.t.sol";

interface IArbitrumInbox {
    function bridge() external view returns (address);
    function createRetryableTicket(
        address to,
        uint256 l2CallValue,
        uint256 maxSubmissionCost,
        address excessFeeRefundAddress,
        address callValueRefundAddress,
        uint256 gasLimit,
        uint256 maxFeePerGas,
        bytes calldata data
    )
        external
        payable
        returns (uint256);
}

interface IArbitrumBridge {
    function delayedMessageCount() external view returns (uint256);
}

interface ICrossDomainMessenger {
    function messageNonce() external view returns (uint256);
    function sendMessage(address target, bytes calldata message, uint32 gasLimit) external;
}

interface ICometAdmin {
    function deployAndUpgradeTo(address configurator, address comet) external;
}

/// @notice Independent reconstruction of COMP proposal 603 from its specification and typed interfaces.
contract Proposal_COMP_603_Test is Compound_Governance {
    uint256 internal constant PROPOSAL_ID = 603;
    uint256 internal constant VOTE_START = 25_891_002;
    uint256 internal constant VOTE_END = 25_910_712;
    address internal constant TEST_VOTER = address(0x603);

    IArbitrumInbox internal constant ARB_INBOX = IArbitrumInbox(0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f);
    ICrossDomainMessenger internal constant BASE_MESSENGER =
        ICrossDomainMessenger(0x866E82a600A1414e583f7F13623F1aC5d58b0Afa);

    address internal constant ARB_RECEIVER = 0x42480C37B249e33aABaf4c22B20235656bd38068;
    address internal constant ARB_REFUND = 0x3fB4d38ea7EC20D91917c09591490Eeda38Cf88A;
    address internal constant ARB_CONFIGURATOR = 0xb21b06D71c75973babdE35b49fFDAc3F82Ad3775;
    address internal constant ARB_COMET_ADMIN = 0xD10b40fF1D92e2267D099Da3509253D9Da4D715e;
    address internal constant ARB_USDT_COMET = 0xd98Be00b5D27fc98112BdE293e487f8D4cA57d07;
    address internal constant ARB_WETH_COMET = 0x6f7D514bbD4aFf3BcD1140B7344b32f063dEe486;

    address internal constant BASE_RECEIVER = 0x18281dfC4d00905DA1aaA6731414EABa843c468A;
    address internal constant BASE_CONFIGURATOR = 0x45939657d1CA34A8FA39A924B71D28Fe8431e581;
    address internal constant BASE_COMET_ADMIN = 0xbdE8F31D2DdDA895264e27DD990faB3DC87b372d;
    address internal constant BASE_AERO_COMET = 0x784efeB622244d2348d4F2522f8860B96fbEcE89;
    address internal constant BASE_WETH_COMET = 0x46e6b214b524310239732D51387075E0e70970bf;

    uint256 internal constant ARB_TICKET_VALUE = 3_785_485_000_000_000;
    uint256 internal constant ARB_MAX_SUBMISSION_COST = 1_355_210_000_000_000;
    uint256 internal constant ARB_GAS_LIMIT = 1_075_065;
    uint256 internal constant ARB_MAX_FEE_PER_GAS = 1_000_000_000;
    uint32 internal constant BASE_GAS_LIMIT = 3_000_000;

    struct BridgeState {
        uint256 timelockBalance;
        uint256 arbitrumDelayedMessages;
        uint256 baseMessageNonce;
    }

    function setUp() public {
        vm.createSelectFork({ blockNumber: VOTE_START + 1, urlOrAlias: "mainnet" });
    }

    function test_liveProposalExistsOnchain() public view {
        uint8 proposalState = GOVERNOR.state(PROPOSAL_ID);
        assertTrue(
            proposalState == 0 || proposalState == 1 || proposalState == 4 || proposalState == 5 || proposalState == 7
        );
    }

    function test_fixtureMatchesOnchainProposal() public {
        (address[] memory liveTargets, uint256[] memory liveValues, bytes[] memory liveCalldatas,) =
            GOVERNOR.proposalDetails(PROPOSAL_ID);
        string memory json = vm.readFile(string.concat(dirPath(), "/proposalCalldata.json"));

        assertEq(vm.parseJsonUint(json, ".proposalId"), PROPOSAL_ID);
        _compareLiveCalldata(json, liveTargets, liveValues, liveCalldatas);
    }

    function test_manuallyDerivedCalldataMatchesOnchainProposal() public view {
        (address[] memory liveTargets, uint256[] memory liveValues, bytes[] memory liveCalldatas,) =
            GOVERNOR.proposalDetails(PROPOSAL_ID);
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = _generateCallData();

        assertEq(liveTargets.length, 2, "unexpected call count");
        for (uint256 i; i < targets.length; ++i) {
            assertEq(liveTargets[i], targets[i], "target mismatch");
            assertEq(liveValues[i], values[i], "value mismatch");
            assertEq(liveCalldatas[i], calldatas[i], "calldata mismatch");
        }
    }

    function test_fullLifecycleDispatchesBothCrossChainUpgrades() public {
        BridgeState memory beforeState = _beforeProposal();
        _executeLiveProposal(PROPOSAL_ID, VOTE_START, VOTE_END, TEST_VOTER);
        _afterExecution(beforeState);
    }

    function _beforeProposal() internal view returns (BridgeState memory stateBefore) {
        address arbitrumBridge = ARB_INBOX.bridge();
        assertNotEq(arbitrumBridge, address(0), "Arbitrum bridge is zero");

        stateBefore.timelockBalance = address(TIMELOCK).balance;
        stateBefore.arbitrumDelayedMessages = IArbitrumBridge(arbitrumBridge).delayedMessageCount();
        stateBefore.baseMessageNonce = BASE_MESSENGER.messageNonce();

        assertGe(stateBefore.timelockBalance, ARB_TICKET_VALUE, "timelock cannot fund retryable ticket");
        assertGt(stateBefore.arbitrumDelayedMessages, 0, "invalid Arbitrum delayed-message count");
        assertGt(stateBefore.baseMessageNonce, 0, "invalid Base messenger nonce");
    }

    function _afterExecution(BridgeState memory stateBefore) internal view {
        assertEq(
            address(TIMELOCK).balance,
            stateBefore.timelockBalance - ARB_TICKET_VALUE,
            "retryable-ticket funding mismatch"
        );
        assertEq(
            IArbitrumBridge(ARB_INBOX.bridge()).delayedMessageCount(),
            stateBefore.arbitrumDelayedMessages + 1,
            "Arbitrum upgrade message was not enqueued"
        );
        assertEq(
            BASE_MESSENGER.messageNonce(), stateBefore.baseMessageNonce + 1, "Base upgrade message was not enqueued"
        );
    }

    function _generateCallData()
        internal
        pure
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        targets = new address[](2);
        values = new uint256[](2);
        calldatas = new bytes[](2);

        bytes memory arbitrumPayload =
            _upgradePayload(ARB_COMET_ADMIN, ARB_CONFIGURATOR, ARB_USDT_COMET, ARB_WETH_COMET);
        targets[0] = address(ARB_INBOX);
        values[0] = ARB_TICKET_VALUE;
        calldatas[0] = abi.encodeWithSelector(
            IArbitrumInbox.createRetryableTicket.selector,
            ARB_RECEIVER,
            0,
            ARB_MAX_SUBMISSION_COST,
            ARB_REFUND,
            ARB_REFUND,
            ARB_GAS_LIMIT,
            ARB_MAX_FEE_PER_GAS,
            arbitrumPayload
        );

        bytes memory basePayload =
            _upgradePayload(BASE_COMET_ADMIN, BASE_CONFIGURATOR, BASE_AERO_COMET, BASE_WETH_COMET);
        targets[1] = address(BASE_MESSENGER);
        calldatas[1] = abi.encodeWithSelector(
            ICrossDomainMessenger.sendMessage.selector, BASE_RECEIVER, basePayload, BASE_GAS_LIMIT
        );
    }

    function _upgradePayload(
        address admin,
        address configurator,
        address firstComet,
        address secondComet
    )
        internal
        pure
        returns (bytes memory)
    {
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        string[] memory signatures = new string[](2);
        bytes[] memory arguments = new bytes[](2);

        targets[0] = admin;
        targets[1] = admin;
        signatures[0] = "deployAndUpgradeTo(address,address)";
        signatures[1] = "deployAndUpgradeTo(address,address)";
        arguments[0] = abi.encode(configurator, firstComet);
        arguments[1] = abi.encode(configurator, secondComet);

        return abi.encode(targets, values, signatures, arguments);
    }

    function dirPath() public pure override returns (string memory) {
        return "src/compound/proposals/603-complete-arbitrum-base-upgrade";
    }
}
