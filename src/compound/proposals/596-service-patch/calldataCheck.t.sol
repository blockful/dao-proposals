// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";
import { CalldataComparison } from "@contracts/base/CalldataComparison.sol";

interface IERC20Like {
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

interface IArbitrumInbox {
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

interface ICrossDomainMessenger {
    function sendMessage(address target, bytes calldata message, uint32 gasLimit) external;
}

interface IFxRoot {
    function sendMessageToChild(address receiver, bytes calldata data) external;
}

interface IConfigurator {
    function setFactory(address comet, address factory) external;
    function setExtensionDelegate(address comet, address extensionDelegate) external;
}

interface ICometAdmin {
    function deployAndUpgradeTo(address configurator, address comet) external;
}

interface IVersionedFactory {
    struct SemanticVersion {
        uint64 major;
        uint64 minor;
        uint64 patch;
    }

    struct Version {
        SemanticVersion version;
        string alternative;
    }
    function setVersion(Version calldata version_) external;
}

/// @notice Independent reconstruction of COMP proposal 596 from the published migration and typed interfaces.
contract Proposal_COMP_596_Test is CalldataComparison {
    IGovernorBravo constant GOVERNOR = IGovernorBravo(0x309a862bbC1A00e45506cB8A802D1ff10004c8C0);
    address constant TIMELOCK = 0x6d903f6003cca6255D85CcA4D3B5E5146dC33925;
    IERC20Like constant COMP = IERC20Like(0xc00e94Cb662C3520282E6f5717214004A7f26888);
    uint256 constant PROPOSAL_ID = 596;
    // Proposal creation block, from proposalCalldata.json. Pinned so the pre-state
    // this test asserts is the state the proposal was created against.
    uint256 constant CREATION_BLOCK = 25_747_373;

    address constant FACTORY = 0x30beAd17D2641bCc900dc1ABC5d55c88059D176F;
    address constant ARB_INBOX = 0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f;
    address constant BASE_MESSENGER = 0x866E82a600A1414e583f7F13623F1aC5d58b0Afa;
    address constant OP_MESSENGER = 0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1;
    address constant POLYGON_ROOT = 0xfe5e5D361b2ad62c541bAb87C45a0B9B018389a2;
    address constant MANTLE_MESSENGER = 0x676A795fe6E43C17c668de16730c3F690FEB7120;
    address constant UNI_MESSENGER = 0x9A3D64E386C18Cb1d6d5179a9596A4B5736e98A6;

    address constant ARB_RECEIVER = 0x42480C37B249e33aABaf4c22B20235656bd38068;
    address constant ARB_REFUND = 0x3fB4d38ea7EC20D91917c09591490Eeda38Cf88A;
    address constant BASE_RECEIVER = 0x18281dfC4d00905DA1aaA6731414EABa843c468A;
    address constant OP_RECEIVER = 0xC3a73A70d1577CD5B02da0bA91C0Afc8fA434DAF;
    address constant MANTLE_RECEIVER = 0xc91EcA15747E73d6dd7f616C49dAFF37b9F1B604;
    address constant UNI_RECEIVER = 0x4b5DeE60531a72C1264319Ec6A22678a4D0C8118;

    address constant ARB_CFG = 0xb21b06D71c75973babdE35b49fFDAc3F82Ad3775;
    address constant ARB_ADMIN = 0xD10b40fF1D92e2267D099Da3509253D9Da4D715e;
    address constant BASE_CFG = 0x45939657d1CA34A8FA39A924B71D28Fe8431e581;
    address constant BASE_ADMIN = 0xbdE8F31D2DdDA895264e27DD990faB3DC87b372d;
    address constant OP_CFG = 0x84E93EC6170ED630f5ebD89A1AAE72d4F63f2713;
    address constant OP_ADMIN = 0x24D86Da09C4Dd64e50dB7501b0f695d030f397aF;
    address constant POLYGON_CFG = 0x83E0F742cAcBE66349E3701B171eE2487a26e738;
    address constant POLYGON_ADMIN = 0xd712ACe4ca490D4F3E92992Ecf3DE12251b975F9;
    address constant MANTLE_CFG = 0xb77Cd4cD000957283D8BAf53cD782ECf029cF7DB;
    address constant MANTLE_ADMIN = 0xe268B436E75648aa0639e2088fa803feA517a0c7;
    address constant UNI_CFG = 0x8df378453Ff9dEFFa513367CDF9b3B53726303e9;
    address constant UNI_ADMIN = 0xaeB318360f27748Acb200CE616E389A6C9409a07;

    address constant EXT_USDC = 0x0d4Bd55A755134950027cE1F43190A354e648e20;
    address constant EXT_USDT = 0x5F5406b32ca3Da65e40978190C88B9809A95c6Ba;
    address constant EXT_WETH = 0xF3BBe5807feA997d540939Cbf138c134b11e3CF1;

    function setUp() public {
        vm.createSelectFork({ blockNumber: CREATION_BLOCK, urlOrAlias: "mainnet" });
    }

    function test_liveProposalExistsOnchain() public {
        vm.createSelectFork({ blockNumber: CREATION_BLOCK, urlOrAlias: "mainnet" });
        assertLe(GOVERNOR.state(PROPOSAL_ID), 7, "proposal 596 must resolve on Governor Bravo");
    }

    function test_manuallyDerivedCalldataMatchesLiveProposal() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = _generateCallData();
        _compareLiveCalldata(
            vm.readFile(string.concat(dirPath(), "/proposalCalldata.json")), targets, values, calldatas
        );
        for (uint256 i; i < calldatas.length; i++) {
            _assertOuterAction(i, calldatas[i]);
        }
    }

    function test_payloadStructureAndL1Effects() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = _generateCallData();
        uint256 totalValue;
        for (uint256 i; i < values.length; i++) {
            if (i < 2) assertEq(targets[i], ARB_INBOX, "ETH funds only Arbitrum retryable tickets");
            else assertEq(values[i], 0, "non-Arbitrum action must not transfer ETH");
            totalValue += values[i];
            _assertOuterAction(i, calldatas[i]);
        }
        assertEq(totalValue, 17_028_045_000_000_000, "exact aggregate Arbitrum retryable-ticket funding");
        assertEq(values[0], 9_256_758_000_000_000, "first Arbitrum action funding");
        assertEq(values[1], 7_771_287_000_000_000, "second Arbitrum action funding");
    }

    function _generateCallData() internal pure returns (address[] memory t, uint256[] memory v, bytes[] memory c) {
        t = new address[](8);
        v = new uint256[](8);
        c = new bytes[](8);
        t[0] = ARB_INBOX;
        v[0] = 9_256_758_000_000_000;
        c[0] = abi.encodeWithSelector(
            IArbitrumInbox.createRetryableTicket.selector,
            ARB_RECEIVER,
            0,
            3_352_010_000_000_000,
            ARB_REFUND,
            ARB_REFUND,
            2_552_738,
            1_000_000_000,
            _payload(
                ARB_CFG,
                ARB_ADMIN,
                _arr2(0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf, 0xA5EDBDD9646f8dFF606d7448e414884C7d905dCA),
                _arr2(EXT_USDC, 0xb971973b595C43cb59492dd0ec9b56c648daea33),
                true
            )
        );
        t[1] = ARB_INBOX;
        v[1] = 7_771_287_000_000_000;
        c[1] = abi.encodeWithSelector(
            IArbitrumInbox.createRetryableTicket.selector,
            ARB_RECEIVER,
            0,
            2_814_410_000_000_000,
            ARB_REFUND,
            ARB_REFUND,
            2_142_467,
            1_000_000_000,
            _payload(
                ARB_CFG,
                ARB_ADMIN,
                _arr2(0xd98Be00b5D27fc98112BdE293e487f8D4cA57d07, 0x6f7D514bbD4aFf3BcD1140B7344b32f063dEe486),
                _arr2(EXT_USDT, EXT_WETH),
                false
            )
        );
        t[2] = BASE_MESSENGER;
        c[2] = abi.encodeWithSelector(
            ICrossDomainMessenger.sendMessage.selector,
            BASE_RECEIVER,
            _payload(
                BASE_CFG,
                BASE_ADMIN,
                _arr3(
                    0xb125E6687d4313864e53df431d5425969c15Eb2F,
                    0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf,
                    0x2c776041CCFe903071AF44aa147368a9c8EEA518
                ),
                _arr3(EXT_USDC, 0xD149132Db93C44e0B306493dC3021966167B1b02, 0xeCB8e46FcEa6339D68fdA37cC3FfBBC6838759Ff),
                true
            ),
            uint32(3_000_000)
        );
        t[3] = BASE_MESSENGER;
        c[3] = abi.encodeWithSelector(
            ICrossDomainMessenger.sendMessage.selector,
            BASE_RECEIVER,
            _payload(
                BASE_CFG,
                BASE_ADMIN,
                _arr2(0x784efeB622244d2348d4F2522f8860B96fbEcE89, 0x46e6b214b524310239732D51387075E0e70970bf),
                _arr2(0x7E5873DD6a92802b280D8d59DEc2aa6Ce0EEB13A, EXT_WETH),
                false
            ),
            uint32(3_000_000)
        );
        t[4] = OP_MESSENGER;
        c[4] = abi.encodeWithSelector(
            ICrossDomainMessenger.sendMessage.selector,
            OP_RECEIVER,
            _payload(
                OP_CFG,
                OP_ADMIN,
                _arr3(
                    0x2e44e174f7D53F0212823acC11C01A11d58c5bCB,
                    0x995E394b8B2437aC8Ce61Ee0bC610D617962B214,
                    0xE36A30D249f7761327fd973001A32010b521b6Fd
                ),
                _arr3(EXT_USDC, EXT_USDT, EXT_WETH),
                true
            ),
            uint32(2_500_000)
        );
        t[5] = POLYGON_ROOT;
        c[5] = abi.encodeWithSelector(
            IFxRoot.sendMessageToChild.selector,
            BASE_RECEIVER,
            _payload(
                POLYGON_CFG,
                POLYGON_ADMIN,
                _arr2(0xF25212E676D1F7F89Cd72fFEe66158f541246445, 0xaeB318360f27748Acb200CE616E389A6C9409a07),
                _arr2(EXT_USDC, EXT_USDT),
                true
            )
        );
        t[6] = MANTLE_MESSENGER;
        c[6] = abi.encodeWithSelector(
            ICrossDomainMessenger.sendMessage.selector,
            MANTLE_RECEIVER,
            _payload(
                MANTLE_CFG,
                MANTLE_ADMIN,
                _arr1(0x606174f62cd968d8e684c645080fa694c1D7786E),
                _arr1(0x63fB5e296B9e7423B9281Df31bcdB0282BbeeE25),
                true
            ),
            uint32(1_500_000)
        );
        t[7] = UNI_MESSENGER;
        c[7] = abi.encodeWithSelector(
            ICrossDomainMessenger.sendMessage.selector,
            UNI_RECEIVER,
            _payload(
                UNI_CFG,
                UNI_ADMIN,
                _arr2(0x2c7118c4C88B9841FCF839074c26Ae8f035f2921, 0x6C987dDE50dB1dcDd32Cd4175778C2a291978E2a),
                _arr2(EXT_USDC, EXT_WETH),
                true
            ),
            uint32(2_000_000)
        );
    }

    function _payload(
        address cfg,
        address admin,
        address[] memory comets,
        address[] memory exts,
        bool version
    )
        internal
        pure
        returns (bytes memory)
    {
        uint256 offset = version ? 1 : 0;
        uint256 n = comets.length * 3 + offset;
        address[] memory targets = new address[](n);
        uint256[] memory values = new uint256[](n);
        string[] memory signatures = new string[](n);
        bytes[] memory args = new bytes[](n);
        if (version) {
            targets[0] = FACTORY;
            signatures[0] = "setVersion(((uint64,uint64,uint64),string))";
            args[0] = abi.encode(IVersionedFactory.Version(IVersionedFactory.SemanticVersion(1, 2, 1), ""));
        }
        for (uint256 j; j < comets.length; j++) {
            uint256 i = offset + j * 3;
            targets[i] = cfg;
            targets[i + 1] = cfg;
            targets[i + 2] = admin;
            signatures[i] = "setFactory(address,address)";
            signatures[i + 1] = "setExtensionDelegate(address,address)";
            signatures[i + 2] = "deployAndUpgradeTo(address,address)";
            args[i] = abi.encode(comets[j], FACTORY);
            args[i + 1] = abi.encode(comets[j], exts[j]);
            args[i + 2] = abi.encode(cfg, comets[j]);
        }
        return abi.encode(targets, values, signatures, args);
    }

    function _assertOuterAction(uint256 index, bytes memory callData) internal pure {
        bytes4 selector;
        assembly { selector := mload(add(callData, 32)) }
        if (index < 2) assertEq(selector, IArbitrumInbox.createRetryableTicket.selector);
        else if (index == 5) assertEq(selector, IFxRoot.sendMessageToChild.selector);
        else assertEq(selector, ICrossDomainMessenger.sendMessage.selector);
    }

    function _arr1(address a) internal pure returns (address[] memory x) {
        x = new address[](1);
        x[0] = a;
    }

    function _arr2(address a, address b) internal pure returns (address[] memory x) {
        x = new address[](2);
        x[0] = a;
        x[1] = b;
    }

    function _arr3(address a, address b, address c) internal pure returns (address[] memory x) {
        x = new address[](3);
        x[0] = a;
        x[1] = b;
        x[2] = c;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/compound/proposals/596-service-patch";
    }
}
