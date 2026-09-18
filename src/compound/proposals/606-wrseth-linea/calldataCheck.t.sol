// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Vm } from "@forge-std/src/Vm.sol";
import { Compound_Governance } from "@compound/compound.t.sol";

interface ILineaMessageService {
    function sendMessage(address to, uint256 fee, bytes calldata data) external payable;
}

/// @notice Independent reconstruction of COMP proposal 606 from its specification and the live Governor actions.
contract Proposal_COMP_606_Test is Compound_Governance {
    ILineaMessageService internal constant LINEA_MESSAGE_SERVICE =
        ILineaMessageService(0xd19d4B5d358258f05D7B411E21A1460D11B0876F);

    address internal constant LINEA_RECEIVER = 0x1F71901daf98d70B4BAF40DE080321e5C2676856;
    address internal constant LINEA_CONFIGURATOR = 0x970FfD8E335B8fa4cd5c869c7caC3a90671d5Dc3;
    address internal constant LINEA_ADMIN = 0x4b5DeE60531a72C1264319Ec6A22678a4D0C8118;
    address internal constant LINEA_COMET = 0x60F2058379716A64a7A5d29219397e79bC552194;
    address internal constant OLD_PRICE_FEED = 0xD2671165570f41BBB3B0097893300b6EB6101E6C;
    address internal constant NEW_PRICE_FEED = 0x9feAc5a70435ef209F4013D46945AC1d4cba9397;

    uint256 internal constant PROPOSAL_ID = 606;
    uint256 internal constant CREATION_BLOCK = 25_991_920;

    struct PreState {
        bytes32 messageServiceCodeHash;
        bytes32 receiverCodeHash;
    }

    function setUp() public {
        vm.createSelectFork({ blockNumber: CREATION_BLOCK, urlOrAlias: "mainnet" });
    }

    function test_liveProposalExistsOnchain() public view {
        uint8 proposalState = GOVERNOR.state(PROPOSAL_ID);
        assertTrue(
            proposalState == 0 || proposalState == 1 || proposalState == 4 || proposalState == 5 || proposalState == 7,
            "proposal 606 is not executable"
        );
    }

    /// @notice The committed fixture must be exactly what the Compound Governor stores at the pinned creation block.
    function test_fixtureMatchesOnchainProposal() public {
        (address[] memory liveTargets, uint256[] memory liveValues, bytes[] memory liveCalldatas,) =
            GOVERNOR.proposalDetails(PROPOSAL_ID);
        string memory json = vm.readFile(string.concat(dirPath(), "/proposalCalldata.json"));
        assertEq(vm.parseJsonUint(json, ".proposalId"), PROPOSAL_ID);
        _compareLiveCalldata(json, liveTargets, liveValues, liveCalldatas);
    }

    /// @notice Reconstruct the L1 dispatch and its destination-chain governance payload from typed values.
    function test_manuallyDerivedCalldataMatchesOnchainProposal() public view {
        (address[] memory liveTargets, uint256[] memory liveValues, bytes[] memory liveCalldatas,) =
            GOVERNOR.proposalDetails(PROPOSAL_ID);
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = _generateCallData();

        assertEq(liveTargets.length, 1, "unexpected call count");
        assertEq(liveValues.length, targets.length, "live values length mismatch");
        assertEq(liveCalldatas.length, targets.length, "live calldata length mismatch");
        assertEq(values.length, targets.length, "derived values length mismatch");
        assertEq(calldatas.length, targets.length, "derived calldata length mismatch");
        for (uint256 i; i < targets.length; ++i) {
            assertEq(liveTargets[i], targets[i], "target mismatch");
            assertEq(liveValues[i], values[i], "value mismatch");
            assertEq(liveCalldatas[i], calldatas[i], "calldata mismatch");
        }

        _assertInnerPayload(_innerPayloadFromLive(liveCalldatas[0]));
    }

    /// @notice Execute the L1 Linea dispatch as the Compound Timelock and require the messenger to emit a message.
    ///         Delivery and execution on Linea are intentionally outside this mainnet fork.
    function test_l1DispatchExecutesAndEmitsMessage() public {
        PreState memory beforeState = _beforeProposal();
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas,) =
            GOVERNOR.proposalDetails(PROPOSAL_ID);

        vm.recordLogs();
        vm.prank(address(TIMELOCK));
        (bool ok,) = targets[0].call{ value: values[0] }(calldatas[0]);
        assertTrue(ok, "Linea message dispatch reverted");

        _afterExecution(beforeState, vm.getRecordedLogs());
    }

    function _beforeProposal() internal view returns (PreState memory beforeState) {
        assertGt(address(LINEA_MESSAGE_SERVICE).code.length, 0, "Linea message service has no code");
        assertGt(LINEA_RECEIVER.code.length, 0, "Linea receiver has no mainnet code");

        (address[] memory liveTargets, uint256[] memory liveValues, bytes[] memory liveCalldatas,) =
            GOVERNOR.proposalDetails(PROPOSAL_ID);
        assertEq(liveTargets.length, 1, "expected one bridge dispatch");
        assertEq(liveTargets[0], address(LINEA_MESSAGE_SERVICE), "unexpected bridge target");
        assertEq(liveValues[0], 0, "bridge dispatch must not send ETH");
        assertEq(liveCalldatas.length, 1, "expected one bridge calldata");
        _assertInnerPayload(_innerPayloadFromLive(liveCalldatas[0]));

        beforeState.messageServiceCodeHash = address(LINEA_MESSAGE_SERVICE).codehash;
        beforeState.receiverCodeHash = LINEA_RECEIVER.codehash;
    }

    function _afterExecution(PreState memory beforeState, Vm.Log[] memory logs) internal view {
        assertEq(address(LINEA_MESSAGE_SERVICE).codehash, beforeState.messageServiceCodeHash);
        assertEq(LINEA_RECEIVER.codehash, beforeState.receiverCodeHash);

        bool emittedByMessageService;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(LINEA_MESSAGE_SERVICE)) {
                emittedByMessageService = true;
            }
        }
        assertTrue(emittedByMessageService, "Linea message service emitted no message event");
    }

    function _generateCallData()
        internal
        pure
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        targets[0] = address(LINEA_MESSAGE_SERVICE);
        calldatas[0] = abi.encodeWithSelector(
            ILineaMessageService.sendMessage.selector,
            LINEA_RECEIVER,
            0,
            _destinationPayload()
        );
    }

    function _destinationPayload() internal pure returns (bytes memory) {
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        string[] memory signatures = new string[](2);
        bytes[] memory args = new bytes[](2);

        targets[0] = LINEA_CONFIGURATOR;
        targets[1] = LINEA_ADMIN;
        signatures[0] = "updateAssetPriceFeed(address,address,address)";
        signatures[1] = "deployAndUpgradeTo(address,address)";
        args[0] = abi.encode(LINEA_COMET, OLD_PRICE_FEED, NEW_PRICE_FEED);
        args[1] = abi.encode(LINEA_CONFIGURATOR, LINEA_COMET);

        return abi.encode(targets, values, signatures, args);
    }

    function _innerPayloadFromLive(bytes memory callData) internal pure returns (bytes memory) {
        bytes memory args = _args(callData);
        (,, bytes memory payload) = abi.decode(args, (address, uint256, bytes));
        return payload;
    }

    function _assertInnerPayload(bytes memory payload) internal pure {
        (address[] memory targets, uint256[] memory values, string[] memory signatures, bytes[] memory args) =
            abi.decode(payload, (address[], uint256[], string[], bytes[]));
        assertEq(targets.length, 2, "unexpected destination action count");
        assertEq(values.length, targets.length, "destination values length mismatch");
        assertEq(signatures.length, targets.length, "destination signatures length mismatch");
        assertEq(args.length, targets.length, "destination args length mismatch");

        assertEq(targets[0], LINEA_CONFIGURATOR, "unexpected configurator target");
        assertEq(targets[1], LINEA_ADMIN, "unexpected admin target");
        assertEq(values[0], 0, "destination action sends value");
        assertEq(values[1], 0, "destination action sends value");
        assertEq(signatures[0], "updateAssetPriceFeed(address,address,address)", "unexpected price feed signature");
        assertEq(signatures[1], "deployAndUpgradeTo(address,address)", "unexpected upgrade signature");

        (address comet, address oldPriceFeed, address newPriceFeed) = abi.decode(args[0], (address, address, address));
        assertEq(comet, LINEA_COMET, "unexpected Comet target");
        assertEq(oldPriceFeed, OLD_PRICE_FEED, "unexpected old price feed");
        assertEq(newPriceFeed, NEW_PRICE_FEED, "unexpected new price feed");

        (address configurator, address upgradedComet) = abi.decode(args[1], (address, address));
        assertEq(configurator, LINEA_CONFIGURATOR, "unexpected upgrade configurator");
        assertEq(upgradedComet, LINEA_COMET, "unexpected upgraded Comet");
    }

    function _args(bytes memory callData) internal pure returns (bytes memory out) {
        out = new bytes(callData.length - 4);
        for (uint256 i; i < out.length; ++i) out[i] = callData[i + 4];
    }

    function dirPath() public pure override returns (string memory) {
        return "src/compound/proposals/606-wrseth-linea";
    }
}
