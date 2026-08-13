// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";
import { CalldataComparison } from "@contracts/base/CalldataComparison.sol";

interface IERC20Like {
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function delegate(address delegatee) external;
}

interface IGovernorBravo {
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    )
        external
        returns (uint256);
    function castVote(uint256 proposalId, uint8 support) external;
    function queue(uint256 proposalId) external;
    function execute(uint256 proposalId) external payable;
    function state(uint256 proposalId) external view returns (uint8);
    function votingDelay() external view returns (uint256);
    function votingPeriod() external view returns (uint256);
    function proposalThreshold() external view returns (uint256);
}

interface ITimelockLike {
    function delay() external view returns (uint256);
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
}

/// @notice Independent reconstruction of COMP proposal 595 from the published specification and typed interfaces.
contract Proposal_COMP_595_Test is CalldataComparison {
    IGovernorBravo constant GOVERNOR = IGovernorBravo(0x309a862bbC1A00e45506cB8A802D1ff10004c8C0);
    address constant TIMELOCK = 0x6d903f6003cca6255D85CcA4D3B5E5146dC33925;
    IERC20Like constant COMP = IERC20Like(0xc00e94Cb662C3520282E6f5717214004A7f26888);
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
    uint256 constant CREATION_BLOCK = 25_734_186;
    uint256 constant PROPOSAL_ID = 595;

    function setUp() public {
        // Free public RPCs prune the proposal-creation state; latest state is sufficient for
        // deterministic calldata comparison and for an independent lifecycle simulation.
        vm.createSelectFork("https://ethereum-rpc.publicnode.com");
    }

    function test_liveProposalExistsOnchain() public view {
        uint8 proposalState = GOVERNOR.state(PROPOSAL_ID);
        assertTrue(proposalState <= 7, "proposal 595 must resolve on Governor Bravo");
    }

    function test_manuallyDerivedCalldataMatchesLiveProposal() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = _generateCallData();
        string memory json = vm.readFile(string.concat(dirPath(), "/proposalCalldata.json"));
        _compareLiveCalldata(json, targets, values, calldatas);
        _assertInnerPayload(
            _proposalData(_two(LINEA_USDC, LINEA_WETH), LINEA_CONFIGURATOR, LINEA_ADMIN), _two(LINEA_USDC, LINEA_WETH)
        );
        _assertInnerPayload(_proposalData(_one(MANTLE_USDE), MANTLE_CONFIGURATOR, MANTLE_ADMIN), _one(MANTLE_USDE));
        _assertInnerPayload(
            _proposalData(_two(RONIN_WETH, RONIN_WRON), RONIN_CONFIGURATOR, RONIN_ADMIN), _two(RONIN_WETH, RONIN_WRON)
        );
        _assertInnerPayload(_proposalData(_one(SCROLL_USDC), SCROLL_CONFIGURATOR, SCROLL_ADMIN), _one(SCROLL_USDC));
    }

    function test_l1ExecutionPreconditions() public view {
        // The live proposal is cross-chain. A mainnet-only fork cannot prove downstream L2 execution,
        // but these preconditions ensure the fee assets required by the two payable actions exist.
        assertGe(address(TIMELOCK).balance, 0.2 ether, "timelock must fund the Scroll message");
        assertGe(GHO.balanceOf(TIMELOCK), RONIN_APPROVAL / 2, "timelock must fund the CCIP fee");
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

    function _assertInnerPayload(bytes memory payload, address[] memory expectedComets) internal pure {
        (address[] memory targets, uint256[] memory values, string[] memory signatures, bytes[] memory args) =
            abi.decode(payload, (address[], uint256[], string[], bytes[]));
        assertEq(targets.length, expectedComets.length * 5);
        for (uint256 c; c < expectedComets.length; c++) {
            uint256 i = c * 5;
            assertEq(values[i], 0);
            assertEq(values[i + 4], 0);
            assertEq(
                keccak256(bytes(signatures[i])), keccak256(bytes("setSupplyPerYearInterestRateBase(address,uint64)"))
            );
            assertEq(keccak256(bytes(signatures[i + 2])), keccak256(bytes("setSupplyKink(address,uint64)")));
            (address comet, uint64 kink) = abi.decode(args[i + 2], (address, uint64));
            assertEq(comet, expectedComets[c]);
            assertEq(kink, SUPPLY_KINK);
            (address cometBase, uint64 base) = abi.decode(args[i], (address, uint64));
            assertEq(cometBase, expectedComets[c]);
            assertEq(base, 0);
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
