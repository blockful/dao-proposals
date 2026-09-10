// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { CalldataComparison } from "@contracts/base/CalldataComparison.sol";

interface ICompoundGovernorLive {
    function state(uint256 proposalId) external view returns (uint8);

    function proposalDetails(uint256 proposalId)
        external
        view
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash);
}

interface IArbitrumInboxLive {
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

interface ICrossDomainMessengerLive {
    function sendMessage(address target, bytes calldata message, uint32 gasLimit) external;
}

interface ICometAdminLive {
    function deployAndUpgradeTo(address configurator, address comet) external;
}

/// @notice Live Compound proposal 603 verification anchored to Governor proposalDetails.
contract Proposal_COMP_603_Test is CalldataComparison {
    ICompoundGovernorLive internal constant GOVERNOR =
        ICompoundGovernorLive(0x309a862bbC1A00e45506cB8A802D1ff10004c8C0);
    address internal constant TIMELOCK = 0x6d903f6003cca6255D85CcA4D3B5E5146dC33925;
    uint256 internal constant PROPOSAL_ID = 603;
    uint256 internal constant CREATION_BLOCK = 25_877_862;
    uint256 internal constant VOTING_START = 25_891_002;
    uint256 internal constant VOTING_END = 25_910_712;

    address internal constant ARB_INBOX = 0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f;
    address internal constant BASE_MESSENGER = 0x866E82a600A1414e583f7F13623F1aC5d58b0Afa;
    address internal constant ARB_RECEIVER = 0x42480C37B249e33aABaf4c22B20235656bd38068;
    address internal constant ARB_REFUND = 0x3fB4d38ea7EC20D91917c09591490Eeda38Cf88A;
    address internal constant BASE_RECEIVER = 0x18281dfC4d00905DA1aaA6731414EABa843c468A;

    address internal constant ARB_CONFIGURATOR = 0xb21b06D71c75973babdE35b49fFDAc3F82Ad3775;
    address internal constant ARB_ADMIN = 0xD10b40fF1D92e2267D099Da3509253D9Da4D715e;
    address internal constant BASE_CONFIGURATOR = 0x45939657d1CA34A8FA39A924B71D28Fe8431e581;
    address internal constant BASE_ADMIN = 0xbdE8F31D2DdDA895264e27DD990faB3DC87b372d;

    address internal constant ARB_CUSDT = 0xd98Be00b5D27fc98112BdE293e487f8D4cA57d07;
    address internal constant ARB_CWETH = 0x6f7D514bbD4aFf3BcD1140B7344b32f063dEe486;
    address internal constant BASE_CAERO = 0x784efeB622244d2348d4F2522f8860B96fbEcE89;
    address internal constant BASE_CWETH = 0x46e6b214b524310239732D51387075E0e70970bf;

    uint256 internal constant ARB_VALUE = 3_785_485_000_000_000;
    uint256 internal constant ARB_MAX_SUBMISSION_COST = 5_293_789_062_500;
    uint256 internal constant ARB_GAS_LIMIT = 1_075_065;
    uint256 internal constant ARB_MAX_FEE_PER_GAS = 1_000_000_000;
    uint32 internal constant BASE_GAS_LIMIT = 187_500;

    function setUp() public {
        vm.createSelectFork({ blockNumber: CREATION_BLOCK, urlOrAlias: "mainnet" });
    }

    function test_liveProposalIdentityAndCalldata() public {
        (address[] memory onchainTargets, uint256[] memory onchainValues, bytes[] memory onchainCalldatas, bytes32 hash) =
            GOVERNOR.proposalDetails(PROPOSAL_ID);
        (address[] memory generatedTargets, uint256[] memory generatedValues, bytes[] memory generatedCalldatas) =
            _generateCallData();

        assertEq(hash, keccak256(bytes(_getDescriptionFromMarkdown(dirPath()))), "description hash mismatch");
        assertEq(GOVERNOR.state(PROPOSAL_ID), 0, "proposal was not pending at creation block");
        assertEq(onchainTargets.length, generatedTargets.length, "on-chain action count mismatch");
        for (uint256 i; i < generatedTargets.length; i++) {
            assertEq(onchainTargets[i], generatedTargets[i], "target mismatch against Governor");
            assertEq(onchainValues[i], generatedValues[i], "value mismatch against Governor");
            assertEq(onchainCalldatas[i], generatedCalldatas[i], "calldata mismatch against Governor");
        }

        _compareLiveCalldata(
            vm.readFile(string.concat(dirPath(), "/proposalCalldata.json")),
            generatedTargets,
            generatedValues,
            generatedCalldatas
        );
    }

    function test_crossChainPayloadIntent() public {
        (,, bytes[] memory onchainCalldatas,) = GOVERNOR.proposalDetails(PROPOSAL_ID);

        (address arbTo, uint256 arbL2Value, uint256 arbSubmissionCost, address arbExcessRefund, address arbCallRefund,
            uint256 arbGasLimit, uint256 arbMaxFee, bytes memory arbPayload) = abi.decode(
                _withoutSelector(onchainCalldatas[0]), (address, uint256, uint256, address, address, uint256, uint256, bytes)
            );
        assertEq(arbTo, ARB_RECEIVER, "Arbitrum receiver mismatch");
        assertEq(arbL2Value, 0, "unexpected Arbitrum L2 call value");
        assertEq(arbSubmissionCost, ARB_MAX_SUBMISSION_COST, "Arbitrum submission cost mismatch");
        assertEq(arbExcessRefund, ARB_REFUND, "Arbitrum excess refund mismatch");
        assertEq(arbCallRefund, ARB_REFUND, "Arbitrum call refund mismatch");
        assertEq(arbGasLimit, ARB_GAS_LIMIT, "Arbitrum gas limit mismatch");
        assertEq(arbMaxFee, ARB_MAX_FEE_PER_GAS, "Arbitrum max fee mismatch");
        assertGe(ARB_VALUE, arbSubmissionCost + arbGasLimit * arbMaxFee, "Arbitrum retryable is underfunded");
        _assertDeployPayload(arbPayload, ARB_CONFIGURATOR, ARB_ADMIN, ARB_CUSDT, ARB_CWETH);

        (address baseTo, bytes memory basePayload, uint32 baseGasLimit) = abi.decode(
            _withoutSelector(onchainCalldatas[1]), (address, bytes, uint32)
        );
        assertEq(baseTo, BASE_RECEIVER, "Base receiver mismatch");
        assertEq(baseGasLimit, BASE_GAS_LIMIT, "Base gas limit mismatch");
        _assertDeployPayload(basePayload, BASE_CONFIGURATOR, BASE_ADMIN, BASE_CAERO, BASE_CWETH);
    }

    function test_l1DispatchesExecuteAsTimelock() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas,) =
            GOVERNOR.proposalDetails(PROPOSAL_ID);
        for (uint256 i; i < targets.length; i++) {
            vm.deal(TIMELOCK, values[i]);
            vm.prank(TIMELOCK);
            (bool ok,) = targets[i].call{ value: values[i] }(calldatas[i]);
            assertTrue(ok, string.concat("L1 dispatch reverted at index ", vm.toString(i)));
        }
    }

    function _generateCallData() internal pure returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) {
        targets = new address[](2);
        values = new uint256[](2);
        calldatas = new bytes[](2);

        targets[0] = ARB_INBOX;
        values[0] = ARB_VALUE;
        calldatas[0] = abi.encodeWithSelector(
            IArbitrumInboxLive.createRetryableTicket.selector,
            ARB_RECEIVER,
            0,
            ARB_MAX_SUBMISSION_COST,
            ARB_REFUND,
            ARB_REFUND,
            ARB_GAS_LIMIT,
            ARB_MAX_FEE_PER_GAS,
            _deployPayload(ARB_CONFIGURATOR, ARB_ADMIN, ARB_CUSDT, ARB_CWETH)
        );

        targets[1] = BASE_MESSENGER;
        calldatas[1] = abi.encodeWithSelector(
            ICrossDomainMessengerLive.sendMessage.selector,
            BASE_RECEIVER,
            _deployPayload(BASE_CONFIGURATOR, BASE_ADMIN, BASE_CAERO, BASE_CWETH),
            BASE_GAS_LIMIT
        );
    }

    function _deployPayload(address configurator, address admin, address cometA, address cometB)
        internal
        pure
        returns (bytes memory)
    {
        address[] memory innerTargets = new address[](2);
        uint256[] memory innerValues = new uint256[](2);
        string[] memory signatures = new string[](2);
        bytes[] memory args = new bytes[](2);

        innerTargets[0] = admin;
        innerTargets[1] = admin;
        signatures[0] = "deployAndUpgradeTo(address,address)";
        signatures[1] = "deployAndUpgradeTo(address,address)";
        args[0] = abi.encode(configurator, cometA);
        args[1] = abi.encode(configurator, cometB);
        return abi.encode(innerTargets, innerValues, signatures, args);
    }

    function _assertDeployPayload(bytes memory payload, address configurator, address admin, address cometA, address cometB)
        internal
        pure
    {
        (address[] memory targets, uint256[] memory values, string[] memory signatures, bytes[] memory args) =
            abi.decode(payload, (address[], uint256[], string[], bytes[]));
        assertEq(targets.length, 2, "unexpected inner action count");
        assertEq(targets[0], admin, "inner target 0 mismatch");
        assertEq(targets[1], admin, "inner target 1 mismatch");
        assertEq(values[0], 0, "inner value 0 must be zero");
        assertEq(values[1], 0, "inner value 1 must be zero");
        assertEq(signatures[0], "deployAndUpgradeTo(address,address)", "inner signature 0 mismatch");
        assertEq(signatures[1], "deployAndUpgradeTo(address,address)", "inner signature 1 mismatch");
        (address configurator0, address comet0) = abi.decode(args[0], (address, address));
        assertEq(configurator0, configurator, "inner configurator 0 mismatch");
        assertEq(comet0, cometA, "inner Comet 0 mismatch");
        (address configurator1, address comet1) = abi.decode(args[1], (address, address));
        assertEq(configurator1, configurator, "inner configurator 1 mismatch");
        assertEq(comet1, cometB, "inner Comet 1 mismatch");
    }

    function _withoutSelector(bytes memory callData) internal pure returns (bytes memory args) {
        args = new bytes(callData.length - 4);
        for (uint256 i; i < args.length; i++) args[i] = callData[i + 4];
    }

    function dirPath() public pure override returns (string memory) {
        return "src/compound/proposals/603-arbitrum-base-comet-upgrade";
    }
}
