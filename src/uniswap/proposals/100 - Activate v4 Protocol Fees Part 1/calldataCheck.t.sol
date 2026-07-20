// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Vm } from "@forge-std/src/Vm.sol";
import { UNI_Governance } from "@uniswap/uniswap.t.sol";
import { IArbitrumInbox } from "@uniswap/interfaces/IArbitrumInbox.sol";
import {
    ICrossChainAccount,
    ICrossDomainMessenger,
    IFxRoot,
    IUniswapWormholeMessageSender
} from "@uniswap/interfaces/ICrossChainGovernance.sol";
import { IPoolManager } from "@uniswap/interfaces/IPoolManager.sol";

contract Proposal_UNI_100_Activate_V4_Protocol_Fees_Part_1_Test is UNI_Governance {
    IPoolManager public constant ETHEREUM_POOL_MANAGER = IPoolManager(0x000000000004444c5dc75cB358380D2e3dE08A90);
    address public constant ETHEREUM_V4_FEE_ADAPTER = 0x89A5D5bF00a27D55c02951E49078a5C5771051dB;

    IArbitrumInbox public constant ARBITRUM_INBOX = IArbitrumInbox(0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f);
    address public constant ARBITRUM_POOL_MANAGER = 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32;
    address public constant ARBITRUM_V4_FEE_ADAPTER = 0x6b3C04567CC62fc5D6AB8D50f1bc1Dee161eb2Cc;

    ICrossDomainMessenger public constant BASE_MESSENGER =
        ICrossDomainMessenger(0x866E82a600A1414e583f7F13623F1aC5d58b0Afa);
    address public constant BASE_CROSS_CHAIN_ACCOUNT = 0x31FAfd4889FA1269F7a13A66eE0fB458f27D72A9;
    address public constant BASE_POOL_MANAGER = 0x498581fF718922c3f8e6A244956aF099B2652b2b;
    address public constant BASE_V4_FEE_ADAPTER = 0xc53DD825dedBE7814562528A1A30e8e5BCbB4b55;

    IUniswapWormholeMessageSender public constant BNB_WORMHOLE_SENDER =
        IUniswapWormholeMessageSender(0xf5F4496219F31CDCBa6130B5402873624585615a);
    address public constant BNB_POOL_MANAGER = 0x28e2Ea090877bF75740558f6BFB36A5ffeE9e9dF;
    address public constant BNB_V4_FEE_ADAPTER = 0x66276D2e80784180E4B9b859e4327b9C5646B87c;
    address public constant BNB_WORMHOLE_RECEIVER = 0x341c1511141022cf8eE20824Ae0fFA3491F1302b;
    uint16 public constant BNB_WORMHOLE_CHAIN_ID = 4;

    IFxRoot public constant POLYGON_FX_ROOT = IFxRoot(0xfe5e5D361b2ad62c541bAb87C45a0B9B018389a2);
    address public constant POLYGON_EXECUTOR = 0x8a1B966aC46F42275860f905dbC75EfBfDC12374;
    address public constant POLYGON_POOL_MANAGER = 0x67366782805870060151383F4BbFF9daB53e5cD6;
    address public constant POLYGON_V4_FEE_ADAPTER = 0x59e84309Afa65F084F9c03668583d231afB12cc6;

    ICrossDomainMessenger public constant OPTIMISM_MESSENGER =
        ICrossDomainMessenger(0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1);
    address public constant OPTIMISM_CROSS_CHAIN_ACCOUNT = 0xa1dD330d602c32622AA270Ea73d078B803Cb3518;
    address public constant OPTIMISM_POOL_MANAGER = 0x9a13F98Cb987694C9F086b1F5eB990EeA8264Ec3;
    address public constant OPTIMISM_V4_FEE_ADAPTER = 0xd85393784234fB2ee4f077867A8B78E1aD4cE56B;

    IArbitrumInbox public constant ROBINHOOD_INBOX = IArbitrumInbox(0x1A07cc4BD17E0118BdB54D70990D2158AbAD7a2D);
    address public constant ROBINHOOD_POOL_MANAGER = 0x8366a39CC670B4001A1121B8F6A443A643e40951;
    address public constant ROBINHOOD_V4_FEE_ADAPTER = 0x6d0009504D129CF5002Dba61D9Ae8575AA79314c;

    address public constant ALIASED_TIMELOCK = 0x2BAD8182C09F50c8318d769245beA52C32Be46CD;
    uint256 public constant MAX_SUBMISSION_COST = 10_000_000_000_000_000;
    uint256 public constant RETRYABLE_GAS_LIMIT = 200_000;
    uint256 public constant MAX_FEE_PER_GAS = 100_000_000;
    uint256 public constant RETRYABLE_TICKET_VALUE = MAX_SUBMISSION_COST + RETRYABLE_GAS_LIMIT * MAX_FEE_PER_GAS;
    uint32 public constant OP_MIN_GAS_LIMIT = 200_000;

    uint256 private governorBalanceBefore;
    uint256 private timelockBalanceBefore;
    address private ethereumControllerBefore;

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 25_554_834, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0x927c7fD078FC406059957a691c21F6E0fC4A959C;
    }

    function _beforeProposal() public override {
        ethereumControllerBefore = ETHEREUM_POOL_MANAGER.protocolFeeController();
        governorBalanceBefore = address(governor).balance;
        timelockBalanceBefore = address(timelock).balance;

        assertEq(ethereumControllerBefore, address(0), "Ethereum controller must be unset before execution");
        assertGt(ETHEREUM_V4_FEE_ADAPTER.code.length, 0, "Ethereum V4FeeAdapter must be deployed");
        assertGt(address(ARBITRUM_INBOX).code.length, 0, "Arbitrum Inbox must be deployed");
        assertGt(address(BASE_MESSENGER).code.length, 0, "Base messenger must be deployed");
        assertGt(address(BNB_WORMHOLE_SENDER).code.length, 0, "BNB Wormhole sender must be deployed");
        assertGt(address(POLYGON_FX_ROOT).code.length, 0, "Polygon FxRoot must be deployed");
        assertGt(address(OPTIMISM_MESSENGER).code.length, 0, "Optimism messenger must be deployed");
        assertGt(address(ROBINHOOD_INBOX).code.length, 0, "Robinhood Inbox must be deployed");

        vm.deal(address(governor), governorBalanceBefore + RETRYABLE_TICKET_VALUE * 2);
        vm.recordLogs();
    }

    function _generateCallData()
        public
        override
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory, string memory)
    {
        proposalId = 100;
        targets = new address[](7);
        values = new uint256[](7);
        signatures = new string[](7);
        calldatas = new bytes[](7);

        targets[0] = address(ETHEREUM_POOL_MANAGER);
        calldatas[0] = _setControllerCalldata(ETHEREUM_V4_FEE_ADAPTER);

        targets[1] = address(ARBITRUM_INBOX);
        values[1] = RETRYABLE_TICKET_VALUE;
        calldatas[1] = _retryableTicketCalldata(ARBITRUM_POOL_MANAGER, ARBITRUM_V4_FEE_ADAPTER);

        targets[2] = address(BASE_MESSENGER);
        calldatas[2] = _opStackMessageCalldata(BASE_CROSS_CHAIN_ACCOUNT, BASE_POOL_MANAGER, BASE_V4_FEE_ADAPTER);

        targets[3] = address(BNB_WORMHOLE_SENDER);
        calldatas[3] = _wormholeMessageCalldata();

        targets[4] = address(POLYGON_FX_ROOT);
        calldatas[4] = _polygonMessageCalldata();

        targets[5] = address(OPTIMISM_MESSENGER);
        calldatas[5] =
            _opStackMessageCalldata(OPTIMISM_CROSS_CHAIN_ACCOUNT, OPTIMISM_POOL_MANAGER, OPTIMISM_V4_FEE_ADAPTER);

        targets[6] = address(ROBINHOOD_INBOX);
        values[6] = RETRYABLE_TICKET_VALUE;
        calldatas[6] = _retryableTicketCalldata(ROBINHOOD_POOL_MANAGER, ROBINHOOD_V4_FEE_ADAPTER);

        description = getDescriptionFromMarkdown();
        return (targets, values, signatures, calldatas, description);
    }

    function _setControllerCalldata(address adapter) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(IPoolManager.setProtocolFeeController.selector, adapter);
    }

    function _retryableTicketCalldata(address poolManager, address adapter) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            IArbitrumInbox.createRetryableTicket.selector,
            poolManager,
            0,
            MAX_SUBMISSION_COST,
            ALIASED_TIMELOCK,
            ALIASED_TIMELOCK,
            RETRYABLE_GAS_LIMIT,
            MAX_FEE_PER_GAS,
            _setControllerCalldata(adapter)
        );
    }

    function _opStackMessageCalldata(
        address crossChainAccount,
        address poolManager,
        address adapter
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory forwardedCall =
            abi.encodeWithSelector(ICrossChainAccount.forward.selector, poolManager, _setControllerCalldata(adapter));
        return abi.encodeWithSelector(
            ICrossDomainMessenger.sendMessage.selector, crossChainAccount, forwardedCall, OP_MIN_GAS_LIMIT
        );
    }

    function _wormholeMessageCalldata() internal pure returns (bytes memory) {
        address[] memory remoteTargets = new address[](1);
        uint256[] memory remoteValues = new uint256[](1);
        bytes[] memory remoteCalldatas = new bytes[](1);
        remoteTargets[0] = BNB_POOL_MANAGER;
        remoteCalldatas[0] = _setControllerCalldata(BNB_V4_FEE_ADAPTER);

        return abi.encodeWithSelector(
            IUniswapWormholeMessageSender.sendMessage.selector,
            remoteTargets,
            remoteValues,
            remoteCalldatas,
            BNB_WORMHOLE_RECEIVER,
            BNB_WORMHOLE_CHAIN_ID
        );
    }

    function _polygonMessageCalldata() internal pure returns (bytes memory) {
        address[] memory remoteTargets = new address[](1);
        uint256[] memory remoteValues = new uint256[](1);
        bytes[] memory remoteCalldatas = new bytes[](1);
        remoteTargets[0] = POLYGON_POOL_MANAGER;
        remoteCalldatas[0] = _setControllerCalldata(POLYGON_V4_FEE_ADAPTER);

        // Polygon's EthereumProxy decodes (address[], bytes[], uint256[]) in this order.
        return abi.encodeWithSelector(
            IFxRoot.sendMessageToChild.selector,
            POLYGON_EXECUTOR,
            abi.encode(remoteTargets, remoteCalldatas, remoteValues)
        );
    }

    function _afterExecution() public override {
        assertEq(
            ETHEREUM_POOL_MANAGER.protocolFeeController(),
            ETHEREUM_V4_FEE_ADAPTER,
            "Ethereum PoolManager controller mismatch"
        );
        assertNotEq(
            ETHEREUM_POOL_MANAGER.protocolFeeController(), ethereumControllerBefore, "Ethereum controller must change"
        );

        assertEq(address(governor).balance, governorBalanceBefore, "Governor retryable-ticket spend mismatch");
        assertEq(address(timelock).balance, timelockBalanceBefore, "Timelock must not retain ticket ETH");

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 inboxTopic = keccak256("InboxMessageDelivered(uint256,bytes)");
        bytes32 sentMessageTopic = keccak256("SentMessage(address,address,bytes,uint256,uint256)");
        bytes32 wormholeTopic = keccak256("MessageSent(bytes,address)");
        bytes32 stateSyncedTopic = keccak256("StateSynced(uint256,address,bytes)");

        assertEq(_countLogs(logs, address(ARBITRUM_INBOX), inboxTopic), 1, "Arbitrum message not delivered");
        assertEq(_countLogs(logs, address(BASE_MESSENGER), sentMessageTopic), 1, "Base message not sent");
        assertEq(_countLogs(logs, address(BNB_WORMHOLE_SENDER), wormholeTopic), 1, "BNB message not sent");
        assertEq(_countLogsByTopic(logs, stateSyncedTopic), 1, "Polygon state sync not emitted");
        assertEq(_countLogs(logs, address(OPTIMISM_MESSENGER), sentMessageTopic), 1, "Optimism message not sent");
        assertEq(_countLogs(logs, address(ROBINHOOD_INBOX), inboxTopic), 1, "Robinhood message not delivered");
    }

    function _countLogs(Vm.Log[] memory logs, address emitter, bytes32 topic) internal pure returns (uint256 count) {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter == emitter && logs[i].topics.length > 0 && logs[i].topics[0] == topic) count++;
        }
    }

    function _countLogsByTopic(Vm.Log[] memory logs, bytes32 topic) internal pure returns (uint256 count) {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length > 0 && logs[i].topics[0] == topic) count++;
        }
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/uniswap/proposals/100 - Activate v4 Protocol Fees Part 1";
    }
}
