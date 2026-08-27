// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";
import { CalldataComparison } from "@contracts/base/CalldataComparison.sol";

interface ICompGovernor {
    function state(uint256 proposalId) external view returns (uint8);
    function proposalDetails(uint256 proposalId)
        external
        view
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash);
    function castVote(uint256 proposalId, uint8 support) external returns (uint256);
    function queue(uint256 proposalId) external;
    function execute(uint256 proposalId) external payable;
}

interface ICompToken {
    function getPriorVotes(address account, uint256 blockNumber) external view returns (uint96);
}

interface ICompoundTimelock {
    function delay() external view returns (uint256);
}

interface IConfigurator {
    function updateAssetSupplyCap(address comet, address asset, uint128 newSupplyCap) external;
}

interface ICometAdmin {
    function deployAndUpgradeTo(address configurator, address comet) external;
    function getProxyImplementation(address proxy) external view returns (address);
}

interface IComet {
    struct AssetInfo {
        uint8 offset;
        address asset;
        address priceFeed;
        uint64 scale;
        uint64 borrowCollateralFactor;
        uint64 liquidateCollateralFactor;
        uint64 liquidationFactor;
        uint128 supplyCap;
    }

    function getAssetInfoByAddress(address asset) external view returns (AssetInfo memory);
}

/// @notice Independent reconstruction of COMP proposal 599 from its specification and typed Compound interfaces.
contract Proposal_COMP_599_Test is Test, CalldataComparison {
    ICompGovernor constant GOVERNOR = ICompGovernor(0x309a862bbC1A00e45506cB8A802D1ff10004c8C0);
    ICompToken constant COMP = ICompToken(0xc00e94Cb662C3520282E6f5717214004A7f26888);
    ICompoundTimelock constant TIMELOCK = ICompoundTimelock(0x6d903f6003cca6255D85CcA4D3B5E5146dC33925);
    IConfigurator constant CONFIGURATOR = IConfigurator(0x316f9708bB98af7dA9c68C1C3b5e79039cD336E3);
    ICometAdmin constant COMET_ADMIN = ICometAdmin(0x1EC63B5883C3481134FD50D5DAebc83Ecd2E8779);

    IComet constant WETH_COMET = IComet(0xA17581A9E3356d9A858b789D68B4d866e593aE94);
    IComet constant WSTETH_COMET = IComet(0x3D0bb1ccaB520A66e607822fC55BC921738fAFE3);
    address constant PUFETH = 0xD9A442856C234a39a81a089C06451EBAa4306a72;
    address constant EZETH = 0xbf5495Efe5DB9ce00f80364C8B423567e58d2110;
    address constant TETH = 0xD11c452fc99cF405034ee446803b6F6c1F6d5ED8;

    uint256 constant PROPOSAL_ID = 599;
    uint256 constant VOTE_START = 25_846_925;
    uint256 constant VOTE_END = 25_866_635;
    address constant TEST_VOTER = address(0x599);

    function setUp() public {
        vm.createSelectFork({ blockNumber: VOTE_START + 1, urlOrAlias: "mainnet" });
    }

    function test_liveProposalIsExecutable() public view {
        uint8 s = GOVERNOR.state(PROPOSAL_ID);
        assertTrue(s == 0 || s == 1 || s == 4 || s == 5 || s == 7, "proposal 599 is not executable");
    }

    function test_fixtureMatchesOnchainProposal() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas,) =
            GOVERNOR.proposalDetails(PROPOSAL_ID);
        string memory json = vm.readFile(string.concat(dirPath(), "/proposalCalldata.json"));
        assertEq(vm.parseJsonUint(json, ".proposalId"), PROPOSAL_ID);
        _compareLiveCalldata(json, targets, values, calldatas);
    }

    function test_manuallyDerivedCalldataMatchesOnchainProposal() public view {
        (address[] memory liveTargets, uint256[] memory liveValues, bytes[] memory liveCalldatas,) =
            GOVERNOR.proposalDetails(PROPOSAL_ID);
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = _generateCallData();

        assertEq(liveTargets.length, 5, "unexpected call count");
        for (uint256 i; i < targets.length; i++) {
            assertEq(liveTargets[i], targets[i], "target mismatch");
            assertEq(liveValues[i], values[i], "value mismatch");
            assertEq(liveCalldatas[i], calldatas[i], "calldata mismatch");
        }
    }

    function test_fullLifecycleAppliesZeroCapsAndUpgradesBothComets() public {
        _assertPreState();
        address wethImplementationBefore = COMET_ADMIN.getProxyImplementation(address(WETH_COMET));
        address wstethImplementationBefore = COMET_ADMIN.getProxyImplementation(address(WSTETH_COMET));

        // Proposal 599 is active on the latest fork. Mock only this voter's snapshot voting power,
        // then exercise the real Governor -> Timelock queue and execution path.
        vm.mockCall(
            address(COMP),
            abi.encodeWithSelector(ICompToken.getPriorVotes.selector, TEST_VOTER, VOTE_START),
            abi.encode(uint96(1_000_000 ether))
        );
        vm.prank(TEST_VOTER);
        GOVERNOR.castVote(PROPOSAL_ID, 1);
        vm.roll(VOTE_END + 1);
        vm.warp(block.timestamp + 4 days);
        assertEq(GOVERNOR.state(PROPOSAL_ID), 4, "proposal did not succeed");

        GOVERNOR.queue(PROPOSAL_ID);
        vm.warp(block.timestamp + TIMELOCK.delay() + 1);
        GOVERNOR.execute(PROPOSAL_ID);
        assertEq(GOVERNOR.state(PROPOSAL_ID), 7, "proposal was not executed");

        _assertPostState();
        address wethImplementationAfter = COMET_ADMIN.getProxyImplementation(address(WETH_COMET));
        address wstethImplementationAfter = COMET_ADMIN.getProxyImplementation(address(WSTETH_COMET));
        assertNotEq(wethImplementationAfter, address(0), "WETH implementation is zero");
        assertNotEq(wstethImplementationAfter, address(0), "wstETH implementation is zero");
        assertNotEq(wethImplementationAfter, wethImplementationBefore, "WETH Comet was not upgraded");
        assertNotEq(wstethImplementationAfter, wstethImplementationBefore, "wstETH Comet was not upgraded");
    }

    function _assertPreState() internal view {
        assertEq(WETH_COMET.getAssetInfoByAddress(PUFETH).supplyCap, 105 ether, "unexpected pufETH cap");
        assertEq(WETH_COMET.getAssetInfoByAddress(EZETH).supplyCap, 500 ether, "unexpected ezETH cap");
        assertEq(WSTETH_COMET.getAssetInfoByAddress(TETH).supplyCap, 44 ether, "unexpected tETH cap");
    }

    function _assertPostState() internal view {
        assertEq(WETH_COMET.getAssetInfoByAddress(PUFETH).supplyCap, 0, "pufETH cap not zero");
        assertEq(WETH_COMET.getAssetInfoByAddress(EZETH).supplyCap, 0, "ezETH cap not zero");
        assertEq(WSTETH_COMET.getAssetInfoByAddress(TETH).supplyCap, 0, "tETH cap not zero");
    }

    function _generateCallData()
        internal
        pure
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        targets = new address[](5);
        values = new uint256[](5);
        calldatas = new bytes[](5);

        targets[0] = address(CONFIGURATOR);
        calldatas[0] = abi.encodeWithSelector(
            IConfigurator.updateAssetSupplyCap.selector, address(WETH_COMET), PUFETH, uint128(0)
        );
        targets[1] = address(CONFIGURATOR);
        calldatas[1] = abi.encodeWithSelector(
            IConfigurator.updateAssetSupplyCap.selector, address(WETH_COMET), EZETH, uint128(0)
        );
        targets[2] = address(COMET_ADMIN);
        calldatas[2] = abi.encodeWithSelector(
            ICometAdmin.deployAndUpgradeTo.selector, address(CONFIGURATOR), address(WETH_COMET)
        );
        targets[3] = address(CONFIGURATOR);
        calldatas[3] = abi.encodeWithSelector(
            IConfigurator.updateAssetSupplyCap.selector, address(WSTETH_COMET), TETH, uint128(0)
        );
        targets[4] = address(COMET_ADMIN);
        calldatas[4] = abi.encodeWithSelector(
            ICometAdmin.deployAndUpgradeTo.selector, address(CONFIGURATOR), address(WSTETH_COMET)
        );
    }

    function dirPath() public pure override returns (string memory) {
        return "src/compound/proposals/599-zero-supply-caps";
    }
}
