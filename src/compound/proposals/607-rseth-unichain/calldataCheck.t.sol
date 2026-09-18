// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Vm } from "@forge-std/src/Vm.sol";
import { Compound_Governance } from "@compound/compound.t.sol";

interface IUnichainMessageService {
    function sendMessage(address to, bytes calldata data, uint32 gasLimit) external;
}

/// @notice Independent reconstruction of COMP proposal 607 from its specification and live Governor actions.
contract Proposal_COMP_607_Test is Compound_Governance {
    IUnichainMessageService internal constant UNICHAIN_MESSAGE_SERVICE =
        IUnichainMessageService(0x9A3D64E386C18Cb1d6d5179a9596A4B5736e98A6);

    address internal constant UNICHAIN_RECEIVER = 0x4b5DeE60531a72C1264319Ec6A22678a4D0C8118;
    address internal constant CONFIGURATOR = 0x8df378453Ff9dEFFa513367CDF9b3B53726303e9;
    address internal constant COMET_PROXY_ADMIN = 0xaeB318360f27748Acb200CE616E389A6C9409a07;
    address internal constant COMET = 0x6C987dDE50dB1dcDd32Cd4175778C2a291978E2a;
    address internal constant RSETH = 0xc3eACf0612346366Db554C991D7858716db09f58;
    address internal constant DEPRECATED_PRICE_FEED = 0x3fb418B74Ec30bC3e940221F58A04e16afC6378B;

    uint256 internal constant PROPOSAL_ID = 607;
    uint256 internal constant CREATION_BLOCK = 25_991_997;
    uint32 internal constant DESTINATION_GAS_LIMIT = 3_000_000;

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
            "proposal 607 is not executable"
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

    /// @notice Execute the L1 Unichain dispatch as the Compound Timelock and require a messenger event.
    ///         Delivery and execution on Unichain are intentionally outside this mainnet fork.
    function test_l1DispatchExecutesAndEmitsMessage() public {
        PreState memory beforeState = _beforeProposal();
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas,) =
            GOVERNOR.proposalDetails(PROPOSAL_ID);

        vm.recordLogs();
        vm.prank(address(TIMELOCK));
        (bool ok,) = targets[0].call{ value: values[0] }(calldatas[0]);
        assertTrue(ok, "Unichain message dispatch reverted");

        _afterExecution(beforeState, vm.getRecordedLogs());
    }

    function _beforeProposal() internal view returns (PreState memory beforeState) {
        assertGt(address(UNICHAIN_MESSAGE_SERVICE).code.length, 0, "Unichain message service has no code");
        assertGt(UNICHAIN_RECEIVER.code.length, 0, "Unichain receiver has no mainnet code");

        (address[] memory liveTargets, uint256[] memory liveValues, bytes[] memory liveCalldatas,) =
            GOVERNOR.proposalDetails(PROPOSAL_ID);
        assertEq(liveTargets.length, 1, "expected one bridge dispatch");
        assertEq(liveTargets[0], address(UNICHAIN_MESSAGE_SERVICE), "unexpected bridge target");
        assertEq(liveValues[0], 0, "bridge dispatch must not send ETH");
        assertEq(liveCalldatas.length, 1, "expected one bridge calldata");
        _assertInnerPayload(_innerPayloadFromLive(liveCalldatas[0]));

        beforeState.messageServiceCodeHash = address(UNICHAIN_MESSAGE_SERVICE).codehash;
        beforeState.receiverCodeHash = UNICHAIN_RECEIVER.codehash;
    }

    function _afterExecution(PreState memory beforeState, Vm.Log[] memory logs) internal view {
        assertEq(address(UNICHAIN_MESSAGE_SERVICE).codehash, beforeState.messageServiceCodeHash);
        assertEq(UNICHAIN_RECEIVER.codehash, beforeState.receiverCodeHash);

        bool emittedByMessageService;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(UNICHAIN_MESSAGE_SERVICE)) {
                emittedByMessageService = true;
            }
        }
        assertTrue(emittedByMessageService, "Unichain message service emitted no message event");
    }

    function _generateCallData()
        internal
        pure
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        targets[0] = address(UNICHAIN_MESSAGE_SERVICE);
        calldatas[0] = abi.encodeWithSelector(
            IUnichainMessageService.sendMessage.selector,
            UNICHAIN_RECEIVER,
            _destinationPayload(),
            DESTINATION_GAS_LIMIT
        );
    }

    function _destinationPayload() internal pure returns (bytes memory) {
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        string[] memory signatures = new string[](2);
        bytes[] memory args = new bytes[](2);

        targets[0] = CONFIGURATOR;
        targets[1] = COMET_PROXY_ADMIN;
        signatures[0] = "updateAsset(address,(address,address,uint8,uint64,uint64,uint64,uint128))";
        signatures[1] = "deployAndUpgradeTo(address,address)";
        args[0] = abi.encode(COMET, RSETH, DEPRECATED_PRICE_FEED, uint8(18), uint64(0), uint64(0), uint64(0), uint128(0));
        args[1] = abi.encode(CONFIGURATOR, COMET);

        return abi.encode(targets, values, signatures, args);
    }

    function _innerPayloadFromLive(bytes memory callData) internal pure returns (bytes memory) {
        bytes memory args = _args(callData);
        (, bytes memory payload,) = abi.decode(args, (address, bytes, uint32));
        return payload;
    }

    function _assertInnerPayload(bytes memory payload) internal pure {
        (address[] memory targets, uint256[] memory values, string[] memory signatures, bytes[] memory args) =
            abi.decode(payload, (address[], uint256[], string[], bytes[]));
        assertEq(targets.length, 2, "unexpected destination action count");
        assertEq(values.length, targets.length, "destination values length mismatch");
        assertEq(signatures.length, targets.length, "destination signatures length mismatch");
        assertEq(args.length, targets.length, "destination args length mismatch");

        assertEq(targets[0], CONFIGURATOR, "unexpected configurator target");
        assertEq(targets[1], COMET_PROXY_ADMIN, "unexpected proxy admin target");
        assertEq(values[0], 0, "destination action sends value");
        assertEq(values[1], 0, "destination action sends value");
        assertEq(signatures[0], "updateAsset(address,(address,address,uint8,uint64,uint64,uint64,uint128))", "unexpected asset signature");
        assertEq(signatures[1], "deployAndUpgradeTo(address,address)", "unexpected upgrade signature");

        (address comet, address asset, address priceFeed, uint8 decimals, uint64 borrowCollateralFactor,
            uint64 liquidationFactor, uint64 liquidateCollateralFactor, uint128 supplyCap) =
            abi.decode(args[0], (address, address, address, uint8, uint64, uint64, uint64, uint128));
        assertEq(comet, COMET, "unexpected Comet target");
        assertEq(asset, RSETH, "unexpected rsETH asset");
        assertEq(priceFeed, DEPRECATED_PRICE_FEED, "unexpected replacement price feed");
        assertEq(decimals, 18, "unexpected rsETH decimals");
        assertEq(borrowCollateralFactor, 0, "borrow collateral factor not zero");
        assertEq(liquidationFactor, 0, "liquidation factor not zero");
        assertEq(liquidateCollateralFactor, 0, "liquidate collateral factor not zero");
        assertEq(supplyCap, 0, "supply cap not zero");

        (address configurator, address upgradedComet) = abi.decode(args[1], (address, address));
        assertEq(configurator, CONFIGURATOR, "unexpected upgrade configurator");
        assertEq(upgradedComet, COMET, "unexpected upgraded Comet");
    }

    function _args(bytes memory callData) internal pure returns (bytes memory out) {
        out = new bytes(callData.length - 4);
        for (uint256 i; i < out.length; ++i) out[i] = callData[i + 4];
    }

    function dirPath() public pure override returns (string memory) {
        return "src/compound/proposals/607-rseth-unichain";
    }
}
