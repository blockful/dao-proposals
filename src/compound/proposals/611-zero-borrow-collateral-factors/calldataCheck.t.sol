// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";
import { CalldataComparison } from "@contracts/base/CalldataComparison.sol";
import { ICompoundGovernor } from "@compound/interfaces/ICompoundGovernor.sol";

interface ILineaMessageService {
    function sendMessage(address to, uint256 fee, bytes calldata data) external payable;
}

interface IMantleMessenger {
    function sendMessage(address target, bytes calldata message, uint32 gasLimit) external;
}

/// @notice Independent reconstruction of COMP proposal 611 from its published specification and
///         typed bridge interfaces. Destination-chain execution is intentionally outside this test's scope.
contract Proposal_COMP_611_Test is Test, CalldataComparison {
    ICompoundGovernor internal constant GOVERNOR = ICompoundGovernor(0x309a862bbC1A00e45506cB8A802D1ff10004c8C0);
    address internal constant TIMELOCK = 0x6d903f6003cca6255D85CcA4D3B5E5146dC33925;

    address internal constant LINEA_MESSAGE_SERVICE = 0xd19d4B5d358258f05D7B411E21A1460D11B0876F;
    address internal constant MANTLE_MESSENGER = 0x676A795fe6E43C17c668de16730c3F690FEB7120;

    address internal constant LINEA_RECEIVER = 0x1F71901daf98d70B4BAF40DE080321e5C2676856;
    address internal constant LINEA_CONFIGURATOR = 0x970FfD8E335B8fa4cd5c869c7caC3a90671d5Dc3;
    address internal constant LINEA_ADMIN = 0x4b5DeE60531a72C1264319Ec6A22678a4D0C8118;
    address internal constant LINEA_CUSDCV3 = 0x8D38A3d6B3c3B7d96D6536DA7Eef94A9d7dbC991;
    address internal constant LINEA_CWETHV3 = 0x60F2058379716A64a7A5d29219397e79bC552194;

    address internal constant LINEA_WETH = 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f;
    address internal constant LINEA_WSTETH = 0xB5beDd42000b71FddE22D3eE8a79Bd49A568fC8F;
    address internal constant LINEA_WBTC = 0x3aAB2285ddcDdaD8edf438C1bAB47e1a9D05a9b4;
    address internal constant LINEA_EZETH = 0x2416092f143378750bb29b79eD961ab195CcEea5;
    address internal constant LINEA_WEETH = 0x1Bf74C010E6320bab11e2e5A532b5AC15e0b8aA6;

    address internal constant MANTLE_RECEIVER = 0xc91EcA15747E73d6dd7f616C49dAFF37b9F1B604;
    address internal constant MANTLE_CONFIGURATOR = 0xb77Cd4cD000957283D8BAf53cD782ECf029cF7DB;
    address internal constant MANTLE_ADMIN = 0xe268B436E75648aa0639e2088fa803feA517a0c7;
    address internal constant MANTLE_CUSDE_V3 = 0x606174f62cd968d8e684c645080fa694c1D7786E;

    address internal constant MANTLE_METH = 0xcDA86A272531e8640cD7F1a92c01839911B90bb0;
    address internal constant MANTLE_WETH = 0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111;
    address internal constant MANTLE_FBTC = 0xC96dE26018A54D51c097160568752c4E3BD6C364;

    uint256 internal constant PROPOSAL_ID = 611;
    uint256 internal constant CREATION_BLOCK = 26_079_429;
    uint256 internal constant VOTING_START = 26_092_569;
    uint256 internal constant VOTING_END = 26_112_279;
    uint32 internal constant MANTLE_GAS_LIMIT = 2_500_000;

    bool internal lineaDispatched;
    bool internal mantleDispatched;
    uint8 internal beforeState;
    uint256 internal beforeActionCount;

    struct InnerPayload {
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] args;
    }

    function setUp() public {
        vm.createSelectFork({ blockNumber: CREATION_BLOCK, urlOrAlias: "mainnet" });
    }

    function _beforeProposal() internal {
        beforeState = GOVERNOR.state(PROPOSAL_ID);
        beforeActionCount = 2;
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas,) =
            GOVERNOR.proposalDetails(PROPOSAL_ID);
        assertEq(beforeState, 0, "proposal must be pending at its creation block");
        assertEq(targets.length, beforeActionCount, "unexpected live action count");
        assertEq(values.length, beforeActionCount, "live values length mismatch");
        assertEq(calldatas.length, beforeActionCount, "live calldata length mismatch");
        assertEq(values[0], 0, "Linea dispatch must not attach ETH");
        assertEq(values[1], 0, "Mantle dispatch must not attach ETH");
    }

    function _afterExecution() internal view {
        assertTrue(lineaDispatched, "Linea bridge dispatch did not succeed");
        assertTrue(mantleDispatched, "Mantle bridge dispatch did not succeed");
        assertEq(GOVERNOR.state(PROPOSAL_ID), beforeState, "direct L1 dispatch changed proposal state");
        assertEq(beforeActionCount, 2, "unexpected action baseline");
    }

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

        _assertLineaDispatch(onchainCalldatas[0]);
        _assertMantleDispatch(onchainCalldatas[1]);
    }

    function test_l1DispatchesExecuteAsTimelock() public {
        _beforeProposal();
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas,) =
            GOVERNOR.proposalDetails(PROPOSAL_ID);

        vm.prank(TIMELOCK);
        (bool lineaOk,) = targets[0].call{ value: values[0] }(calldatas[0]);
        assertTrue(lineaOk, "Linea bridge rejected the live dispatch");
        lineaDispatched = true;

        vm.prank(TIMELOCK);
        (bool mantleOk,) = targets[1].call{ value: values[1] }(calldatas[1]);
        assertTrue(mantleOk, "Mantle bridge rejected the live dispatch");
        mantleDispatched = true;

        _afterExecution();
    }

    function _generateCallData()
        internal
        pure
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        targets = new address[](2);
        values = new uint256[](2);
        calldatas = new bytes[](2);

        targets[0] = LINEA_MESSAGE_SERVICE;
        calldatas[0] = abi.encodeWithSelector(
            ILineaMessageService.sendMessage.selector,
            LINEA_RECEIVER,
            0,
            _proposalData(
                _arr2(LINEA_CUSDCV3, LINEA_CWETHV3),
                _arr7(LINEA_WETH, LINEA_WSTETH, LINEA_WBTC, LINEA_EZETH, LINEA_WSTETH, LINEA_WBTC, LINEA_WEETH),
                LINEA_CONFIGURATOR,
                LINEA_ADMIN
            )
        );

        targets[1] = MANTLE_MESSENGER;
        calldatas[1] = abi.encodeWithSelector(
            IMantleMessenger.sendMessage.selector,
            MANTLE_RECEIVER,
            _proposalData(
                _arr1(MANTLE_CUSDE_V3), _arr3(MANTLE_METH, MANTLE_WETH, MANTLE_FBTC), MANTLE_CONFIGURATOR, MANTLE_ADMIN
            ),
            MANTLE_GAS_LIMIT
        );
    }

    function _proposalData(
        address[] memory comets,
        address[] memory assets,
        address configurator,
        address admin
    )
        internal
        pure
        returns (bytes memory)
    {
        uint256 updates;
        for (uint256 i; i < comets.length; i++) {
            updates += i == 0 ? 3 : i == 1 ? 4 : 3;
        }
        assertEq(updates, assets.length, "asset/comet grouping mismatch");

        uint256 n = assets.length + comets.length;
        address[] memory targets = new address[](n);
        uint256[] memory values = new uint256[](n);
        string[] memory signatures = new string[](n);
        bytes[] memory args = new bytes[](n);
        uint256 assetIndex;
        for (uint256 c; c < comets.length; c++) {
            uint256 assetCount = c == 0 ? 3 : c == 1 ? 4 : 3;
            for (uint256 a; a < assetCount; a++) {
                uint256 i = assetIndex + c;
                targets[i] = configurator;
                signatures[i] = "updateAssetBorrowCollateralFactor(address,address,uint64)";
                args[i] = abi.encode(comets[c], assets[assetIndex], uint64(0));
                assetIndex++;
            }
            uint256 upgradeIndex = assetIndex + c;
            targets[upgradeIndex] = admin;
            signatures[upgradeIndex] = "deployAndUpgradeTo(address,address)";
            args[upgradeIndex] = abi.encode(configurator, comets[c]);
        }
        return abi.encode(targets, values, signatures, args);
    }

    function _assertLineaDispatch(bytes memory callData) internal pure {
        assertEq(_selector(callData), ILineaMessageService.sendMessage.selector, "Linea selector mismatch");
        (address receiver, uint256 fee, bytes memory payload) = abi.decode(_args(callData), (address, uint256, bytes));
        assertEq(receiver, LINEA_RECEIVER, "Linea receiver mismatch");
        assertEq(fee, 0, "Linea fee must be zero");
        _assertLineaPayload(payload);
    }

    function _assertMantleDispatch(bytes memory callData) internal pure {
        assertEq(_selector(callData), IMantleMessenger.sendMessage.selector, "Mantle selector mismatch");
        (address receiver, bytes memory payload, uint32 gasLimit) =
            abi.decode(_args(callData), (address, bytes, uint32));
        assertEq(receiver, MANTLE_RECEIVER, "Mantle receiver mismatch");
        assertEq(gasLimit, MANTLE_GAS_LIMIT, "Mantle gas limit mismatch");
        _assertMantlePayload(payload);
    }

    function _assertLineaPayload(bytes memory payload) internal pure {
        InnerPayload memory p = _decodeInnerPayload(payload);
        assertEq(p.targets.length, 9, "Linea inner action count mismatch");
        assertEq(p.values.length, p.targets.length, "Linea inner values length mismatch");
        assertEq(p.signatures.length, p.targets.length, "Linea inner signatures length mismatch");
        assertEq(p.args.length, p.targets.length, "Linea inner args length mismatch");
        address[] memory assets =
            _arr7(LINEA_WETH, LINEA_WSTETH, LINEA_WBTC, LINEA_EZETH, LINEA_WSTETH, LINEA_WBTC, LINEA_WEETH);
        _assertCometActions(p, 0, 0, 3, LINEA_CUSDCV3, assets, LINEA_CONFIGURATOR, LINEA_ADMIN);
        _assertCometActions(p, 4, 3, 4, LINEA_CWETHV3, assets, LINEA_CONFIGURATOR, LINEA_ADMIN);
    }

    function _assertMantlePayload(bytes memory payload) internal pure {
        InnerPayload memory p = _decodeInnerPayload(payload);
        assertEq(p.targets.length, 4, "Mantle inner action count mismatch");
        assertEq(p.values.length, p.targets.length, "Mantle inner values length mismatch");
        assertEq(p.signatures.length, p.targets.length, "Mantle inner signatures length mismatch");
        assertEq(p.args.length, p.targets.length, "Mantle inner args length mismatch");
        _assertCometActions(
            p, 0, 0, 3, MANTLE_CUSDE_V3, _arr3(MANTLE_METH, MANTLE_WETH, MANTLE_FBTC), MANTLE_CONFIGURATOR, MANTLE_ADMIN
        );
    }

    function _decodeInnerPayload(bytes memory payload) internal pure returns (InnerPayload memory p) {
        (p.targets, p.values, p.signatures, p.args) = abi.decode(payload, (address[], uint256[], string[], bytes[]));
    }

    function _assertCometActions(
        InnerPayload memory p,
        uint256 actionStart,
        uint256 assetStart,
        uint256 assetCount,
        address comet,
        address[] memory assets,
        address configurator,
        address admin
    )
        internal
        pure
    {
        for (uint256 a; a < assetCount; a++) {
            uint256 i = actionStart + a;
            _assertUpdateAction(p, i, configurator, comet, assets[assetStart + a]);
        }
        uint256 upgradeIndex = actionStart + assetCount;
        _assertUpgradeAction(p, upgradeIndex, admin, configurator, comet);
    }

    function _assertUpdateAction(
        InnerPayload memory p,
        uint256 index,
        address configurator,
        address expectedComet,
        address expectedAsset
    )
        internal
        pure
    {
        assertEq(p.targets[index], configurator, "update target mismatch");
        assertEq(p.values[index], 0, "inner action must not send value");
        assertEq(
            p.signatures[index],
            "updateAssetBorrowCollateralFactor(address,address,uint64)",
            "update signature mismatch"
        );
        (address comet, address asset, uint64 factor) = abi.decode(p.args[index], (address, address, uint64));
        assertEq(comet, expectedComet, "comet mismatch");
        assertEq(asset, expectedAsset, "asset mismatch");
        assertEq(factor, 0, "borrow collateral factor must be zero");
    }

    function _assertUpgradeAction(
        InnerPayload memory p,
        uint256 index,
        address admin,
        address configurator,
        address expectedComet
    )
        internal
        pure
    {
        assertEq(p.targets[index], admin, "upgrade target mismatch");
        assertEq(p.values[index], 0, "upgrade must not send value");
        assertEq(p.signatures[index], "deployAndUpgradeTo(address,address)", "upgrade signature mismatch");
        (address cfg, address comet) = abi.decode(p.args[index], (address, address));
        assertEq(cfg, configurator, "upgrade configurator mismatch");
        assertEq(comet, expectedComet, "upgrade comet mismatch");
    }

    function _selector(bytes memory callData) internal pure returns (bytes4 selector) {
        assembly {
            selector := mload(add(callData, 32))
        }
    }

    function _args(bytes memory callData) internal pure returns (bytes memory out) {
        out = new bytes(callData.length - 4);
        for (uint256 i; i < out.length; i++) {
            out[i] = callData[i + 4];
        }
    }

    function _arr1(address a) internal pure returns (address[] memory result) {
        result = new address[](1);
        result[0] = a;
    }

    function _arr2(address a, address b) internal pure returns (address[] memory result) {
        result = new address[](2);
        result[0] = a;
        result[1] = b;
    }

    function _arr3(address a, address b, address c) internal pure returns (address[] memory result) {
        result = new address[](3);
        result[0] = a;
        result[1] = b;
        result[2] = c;
    }

    function _arr7(
        address a,
        address b,
        address c,
        address d,
        address e,
        address f,
        address g
    )
        internal
        pure
        returns (address[] memory result)
    {
        result = new address[](7);
        result[0] = a;
        result[1] = b;
        result[2] = c;
        result[3] = d;
        result[4] = e;
        result[5] = f;
        result[6] = g;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/compound/proposals/611-zero-borrow-collateral-factors";
    }
}
