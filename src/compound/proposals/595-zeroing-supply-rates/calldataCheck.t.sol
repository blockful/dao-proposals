// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";
import { CalldataComparison } from "@contracts/base/CalldataComparison.sol";

interface IERC20Like {
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

/// @notice Compound migrated to an OpenZeppelin-style Governor at the Bravo address; actions are read
///         through proposalDetails, not getActions.
interface IGovernor {
    function state(uint256 proposalId) external view returns (uint8);
    function proposalDetails(uint256 proposalId)
        external
        view
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash);
}

interface ILineaMessageService {
    function sendMessage(address to, uint256 fee, bytes calldata data) external payable;
}

interface IMantleMessenger {
    function sendMessage(address target, bytes calldata message, uint32 gasLimit) external;
}

interface IScrollMessenger {
    function sendMessage(address target, uint256 value, bytes calldata message, uint256 gasLimit) external payable;
}

interface ICCIPRouter {
    struct EVMTokenAmount {
        address token;
        uint256 amount;
    }

    struct EVM2AnyMessage {
        bytes receiver;
        bytes data;
        EVMTokenAmount[] tokenAmounts;
        address feeToken;
        bytes extraArgs;
    }
    function ccipSend(uint64 destinationChainSelector, EVM2AnyMessage calldata message) external returns (bytes32);
    function getFee(uint64 destinationChainSelector, EVM2AnyMessage memory message) external view returns (uint256);
}

/// @notice Independent reconstruction of COMP proposal 595 from the published specification and typed interfaces.
contract Proposal_COMP_595_Test is CalldataComparison {
    IGovernor constant GOVERNOR = IGovernor(0x309a862bbC1A00e45506cB8A802D1ff10004c8C0);
    address constant TIMELOCK = 0x6d903f6003cca6255D85CcA4D3B5E5146dC33925;
    IERC20Like constant GHO = IERC20Like(0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f);

    address constant LINEA_MESSAGE_SERVICE = 0xd19d4B5d358258f05D7B411E21A1460D11B0876F;
    address constant MANTLE_MESSENGER = 0x676A795fe6E43C17c668de16730c3F690FEB7120;
    address constant CCIP_ROUTER = 0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D;
    address constant SCROLL_MESSENGER = 0x6774Bcbd5ceCeF1336b5300fb5186a12DDD8b367;

    address constant LINEA_RECEIVER = 0x1F71901daf98d70B4BAF40DE080321e5C2676856;
    address constant LINEA_CONFIGURATOR = 0x970FfD8E335B8fa4cd5c869c7caC3a90671d5Dc3;
    address constant LINEA_ADMIN = 0x4b5DeE60531a72C1264319Ec6A22678a4D0C8118;
    address constant LINEA_USDC = 0x8D38A3d6B3c3B7d96D6536DA7Eef94A9d7dbC991;
    address constant LINEA_WETH = 0x60F2058379716A64a7A5d29219397e79bC552194;

    address constant MANTLE_RECEIVER = 0xc91EcA15747E73d6dd7f616C49dAFF37b9F1B604;
    address constant MANTLE_CONFIGURATOR = 0xb77Cd4cD000957283D8BAf53cD782ECf029cF7DB;
    address constant MANTLE_ADMIN = 0xe268B436E75648aa0639e2088fa803feA517a0c7;
    address constant MANTLE_USDE = 0x606174f62cd968d8e684c645080fa694c1D7786E;

    uint64 constant RONIN_SELECTOR = 6_916_147_374_840_168_594;
    address constant RONIN_RECEIVER = 0x2c7EfA766338D33B9192dB1fB5D170Bdc03ef3F9;
    address constant RONIN_CONFIGURATOR = 0x966c72F456FC248D458784EF3E0b6d042be115F2;
    address constant RONIN_ADMIN = 0xfa64A82a3d13D4c05d5133E53b2EbB8A0FA9c3F6;
    address constant RONIN_WETH = 0x4006eD4097Ee51c09A04c3B0951D28CCf19e6DFE;
    address constant RONIN_WRON = 0xc0Afdbd1cEB621Ef576BA969ce9D4ceF78Dbc0c0;

    address constant SCROLL_RECEIVER = 0xC6bf5A64896D679Cf89843DbeC6c0f5d3C9b610D;
    address constant SCROLL_CONFIGURATOR = 0xECAB0bEEa3e5DEa0c35d3E69468EAC20098032D7;
    address constant SCROLL_ADMIN = 0x87A27b91f4130a25E9634d23A5B8E05e342bac50;
    address constant SCROLL_USDC = 0xB2f97c1Bd3bf02f5e74d13f02E3e26F93D77CE44;

    uint64 constant SUPPLY_KINK = 900_000_000_000_000_000;
    // Twice the CCIP fee quoted when the proposal was constructed; half is consumed by ccipSend.
    uint256 constant RONIN_APPROVAL = 1_008_963_950_898_564_450;
    uint256 constant PROPOSAL_ID = 595;
    uint256 constant CREATION_BLOCK = 25_734_186;

    function setUp() public {
        // Pinned to the proposal creation block from proposalCalldata.json, via the mainnet
        // alias so MAINNET_RPC_URL (an archive endpoint) serves the historical state.
        // Forking at the tip would make every pre-state assertion depend on when this runs.
        vm.createSelectFork({ blockNumber: CREATION_BLOCK, urlOrAlias: "mainnet" });
    }

    function test_liveProposalIsPending() public view {
        uint8 s = GOVERNOR.state(PROPOSAL_ID);
        // Canceled(2), Defeated(3) and Expired(6) would make the calldata unexecutable.
        assertTrue(s == 0 || s == 1 || s == 4 || s == 5 || s == 7, "proposal 595 is not executable");
    }

    /// @notice The committed fixture must be exactly what the Governor stores, otherwise every other
    ///         comparison in this file is anchored to author-supplied data.
    function test_fixtureMatchesOnchainProposal() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas,) =
            GOVERNOR.proposalDetails(PROPOSAL_ID);
        string memory json = vm.readFile(string.concat(dirPath(), "/proposalCalldata.json"));
        assertEq(vm.parseJsonUint(json, ".proposalId"), PROPOSAL_ID);
        _compareLiveCalldata(json, targets, values, calldatas);
    }

    function test_manuallyDerivedCalldataMatchesOnchainProposal() public view {
        (address[] memory onchainTargets, uint256[] memory onchainValues, bytes[] memory onchainCalldatas,) =
            GOVERNOR.proposalDetails(PROPOSAL_ID);
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = _generateCallData();

        assertEq(onchainTargets.length, targets.length, "call count mismatch");
        for (uint256 i; i < targets.length; i++) {
            assertEq(onchainTargets[i], targets[i], "target mismatch");
            assertEq(onchainValues[i], values[i], "value mismatch");
            assertEq(onchainCalldatas[i], calldatas[i], "calldata mismatch");
        }

        // Decode the inner cross-chain payloads out of the live bytes, not out of our own encoder.
        (,, bytes memory lineaPayload) = abi.decode(_args(onchainCalldatas[0]), (address, uint256, bytes));
        _assertInnerPayload(lineaPayload, _two(LINEA_USDC, LINEA_WETH), LINEA_CONFIGURATOR, LINEA_ADMIN);
        (, bytes memory mantlePayload,) = abi.decode(_args(onchainCalldatas[1]), (address, bytes, uint32));
        _assertInnerPayload(mantlePayload, _one(MANTLE_USDE), MANTLE_CONFIGURATOR, MANTLE_ADMIN);
        (, ICCIPRouter.EVM2AnyMessage memory roninMessage) =
            abi.decode(_args(onchainCalldatas[3]), (uint64, ICCIPRouter.EVM2AnyMessage));
        _assertInnerPayload(roninMessage.data, _two(RONIN_WETH, RONIN_WRON), RONIN_CONFIGURATOR, RONIN_ADMIN);
        (,, bytes memory scrollPayload,) = abi.decode(_args(onchainCalldatas[4]), (address, uint256, bytes, uint256));
        _assertInnerPayload(scrollPayload, _one(SCROLL_USDC), SCROLL_CONFIGURATOR, SCROLL_ADMIN);
    }

    /// @notice The GHO approval is a magic number in the proposal; check it actually covers the CCIP fee.
    function test_roninApprovalCoversCcipFee() public view {
        (,, bytes[] memory calldatas,) = GOVERNOR.proposalDetails(PROPOSAL_ID);
        (uint64 selector, ICCIPRouter.EVM2AnyMessage memory message) =
            abi.decode(_args(calldatas[3]), (uint64, ICCIPRouter.EVM2AnyMessage));
        assertEq(selector, RONIN_SELECTOR, "unexpected destination chain");
        assertEq(message.feeToken, address(GHO), "unexpected fee token");
        uint256 fee = ICCIPRouter(CCIP_ROUTER).getFee(selector, message);
        assertGe(RONIN_APPROVAL, fee, "approval does not cover the CCIP fee");
        // The proposal approves ~2x the fee; the surplus stays approved to the router after execution.
        assertLe(RONIN_APPROVAL, fee * 3, "approval is far above the quoted fee");
    }

    /// @notice Execute the five L1 calls as the Timelock and assert the mainnet-side state they produce.
    ///         Delivery and final state on Linea, Mantle, Ronin and Scroll are out of reach from a mainnet fork.
    function test_l1ExecutionEffects() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = _generateCallData();

        uint256 ghoBefore = GHO.balanceOf(TIMELOCK);
        assertGt(ghoBefore, 0, "timelock must hold GHO for the CCIP fee");
        // The Timelock already carries a non-zero router allowance: the surplus of an earlier proposal that
        // used the same "approve twice the fee" pattern. `approve` overwrites it, so this is not a blocker.
        uint256 staleAllowance = GHO.allowance(TIMELOCK, CCIP_ROUTER);
        emit log_named_uint("stale GHO allowance to CCIP router", staleAllowance);
        vm.deal(TIMELOCK, values[4]);

        for (uint256 i; i < targets.length; i++) {
            vm.prank(TIMELOCK);
            (bool ok,) = targets[i].call{ value: values[i] }(calldatas[i]);
            assertTrue(ok, string.concat("L1 call reverted at index ", vm.toString(i)));

            if (i == 2) assertEq(GHO.allowance(TIMELOCK, CCIP_ROUTER), RONIN_APPROVAL, "approval not set");
        }

        uint256 feePaid = ghoBefore - GHO.balanceOf(TIMELOCK);
        assertGt(feePaid, 0, "ccipSend did not charge the GHO fee");
        assertEq(
            GHO.allowance(TIMELOCK, CCIP_ROUTER), RONIN_APPROVAL - feePaid, "leftover allowance is not the surplus"
        );
        // Scroll charges the actual message fee and refunds the surplus to the sender, so the Timelock keeps
        // almost all of the 0.2 ETH attached to the fifth action.
        uint256 scrollFee = values[4] - TIMELOCK.balance;
        assertGt(scrollFee, 0, "scroll message charged no fee");
        assertLt(scrollFee, 0.01 ether, "scroll message consumed more ETH than expected");
    }

    function _generateCallData()
        internal
        pure
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        targets = new address[](5);
        values = new uint256[](5);
        calldatas = new bytes[](5);
        targets[0] = LINEA_MESSAGE_SERVICE;
        calldatas[0] = abi.encodeWithSelector(
            ILineaMessageService.sendMessage.selector,
            LINEA_RECEIVER,
            0,
            _proposalData(_two(LINEA_USDC, LINEA_WETH), LINEA_CONFIGURATOR, LINEA_ADMIN)
        );
        targets[1] = MANTLE_MESSENGER;
        calldatas[1] = abi.encodeWithSelector(
            IMantleMessenger.sendMessage.selector,
            MANTLE_RECEIVER,
            _proposalData(_one(MANTLE_USDE), MANTLE_CONFIGURATOR, MANTLE_ADMIN),
            uint32(2_500_000)
        );
        targets[2] = address(GHO);
        calldatas[2] = abi.encodeWithSelector(IERC20Like.approve.selector, CCIP_ROUTER, RONIN_APPROVAL);
        targets[3] = CCIP_ROUTER;
        ICCIPRouter.EVMTokenAmount[] memory noTokens = new ICCIPRouter.EVMTokenAmount[](0);
        ICCIPRouter.EVM2AnyMessage memory message = ICCIPRouter.EVM2AnyMessage({
            receiver: abi.encode(RONIN_RECEIVER),
            data: _proposalData(_two(RONIN_WETH, RONIN_WRON), RONIN_CONFIGURATOR, RONIN_ADMIN),
            tokenAmounts: noTokens,
            feeToken: address(GHO),
            extraArgs: bytes("")
        });
        calldatas[3] = abi.encodeWithSelector(ICCIPRouter.ccipSend.selector, RONIN_SELECTOR, message);
        targets[4] = SCROLL_MESSENGER;
        values[4] = 0.2 ether;
        calldatas[4] = abi.encodeWithSelector(
            IScrollMessenger.sendMessage.selector,
            SCROLL_RECEIVER,
            0,
            _proposalData(_one(SCROLL_USDC), SCROLL_CONFIGURATOR, SCROLL_ADMIN),
            2_500_000
        );
    }

    function _proposalData(
        address[] memory comets,
        address configurator,
        address admin
    )
        internal
        pure
        returns (bytes memory)
    {
        uint256 n = comets.length * 5;
        address[] memory targets = new address[](n);
        uint256[] memory values = new uint256[](n);
        string[] memory signatures = new string[](n);
        bytes[] memory args = new bytes[](n);
        for (uint256 c; c < comets.length; c++) {
            uint256 i = c * 5;
            targets[i] = configurator;
            targets[i + 1] = configurator;
            targets[i + 2] = configurator;
            targets[i + 3] = configurator;
            targets[i + 4] = admin;
            signatures[i] = "setSupplyPerYearInterestRateBase(address,uint64)";
            signatures[i + 1] = "setSupplyPerYearInterestRateSlopeLow(address,uint64)";
            signatures[i + 2] = "setSupplyKink(address,uint64)";
            signatures[i + 3] = "setSupplyPerYearInterestRateSlopeHigh(address,uint64)";
            signatures[i + 4] = "deployAndUpgradeTo(address,address)";
            args[i] = abi.encode(comets[c], uint64(0));
            args[i + 1] = abi.encode(comets[c], uint64(0));
            args[i + 2] = abi.encode(comets[c], SUPPLY_KINK);
            args[i + 3] = abi.encode(comets[c], uint64(0));
            args[i + 4] = abi.encode(configurator, comets[c]);
        }
        return abi.encode(targets, values, signatures, args);
    }

    function _assertInnerPayload(
        bytes memory payload,
        address[] memory expectedComets,
        address configurator,
        address admin
    )
        internal
        pure
    {
        (address[] memory targets, uint256[] memory values, string[] memory signatures, bytes[] memory args) =
            abi.decode(payload, (address[], uint256[], string[], bytes[]));
        assertEq(targets.length, expectedComets.length * 5, "inner action count");
        assertEq(values.length, targets.length);
        assertEq(signatures.length, targets.length);
        assertEq(args.length, targets.length);

        string[5] memory expectedSignatures = [
            "setSupplyPerYearInterestRateBase(address,uint64)",
            "setSupplyPerYearInterestRateSlopeLow(address,uint64)",
            "setSupplyKink(address,uint64)",
            "setSupplyPerYearInterestRateSlopeHigh(address,uint64)",
            "deployAndUpgradeTo(address,address)"
        ];

        for (uint256 c; c < expectedComets.length; c++) {
            uint256 i = c * 5;
            for (uint256 k; k < 5; k++) {
                assertEq(values[i + k], 0, "inner action must not send value");
                assertEq(signatures[i + k], expectedSignatures[k], "inner signature mismatch");
                assertEq(targets[i + k], k == 4 ? admin : configurator, "inner target mismatch");
            }
            // Zero supply rate base, zero low slope, 90% kink, zero high slope.
            _assertParam(args[i], expectedComets[c], 0);
            _assertParam(args[i + 1], expectedComets[c], 0);
            _assertParam(args[i + 2], expectedComets[c], SUPPLY_KINK);
            _assertParam(args[i + 3], expectedComets[c], 0);
            (address cfg, address comet) = abi.decode(args[i + 4], (address, address));
            assertEq(cfg, configurator, "deployAndUpgradeTo configurator mismatch");
            assertEq(comet, expectedComets[c], "deployAndUpgradeTo comet mismatch");
        }
    }

    function _assertParam(bytes memory arg, address expectedComet, uint64 expectedValue) internal pure {
        (address comet, uint64 value) = abi.decode(arg, (address, uint64));
        assertEq(comet, expectedComet, "comet mismatch");
        assertEq(value, expectedValue, "parameter mismatch");
    }

    /// @notice Strip the 4-byte selector so the remaining ABI-encoded arguments can be decoded.
    function _args(bytes memory callData) internal pure returns (bytes memory out) {
        out = new bytes(callData.length - 4);
        for (uint256 i; i < out.length; i++) {
            out[i] = callData[i + 4];
        }
    }

    function _one(address a) internal pure returns (address[] memory x) {
        x = new address[](1);
        x[0] = a;
    }

    function _two(address a, address b) internal pure returns (address[] memory x) {
        x = new address[](2);
        x[0] = a;
        x[1] = b;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/compound/proposals/595-zeroing-supply-rates";
    }
}
