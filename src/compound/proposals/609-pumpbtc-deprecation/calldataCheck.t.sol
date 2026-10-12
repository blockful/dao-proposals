// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Compound_Governance } from "@compound/compound.t.sol";

interface IConfigurator609 {
    function setFactory(address comet, address factory) external;
    function setExtensionDelegate(address comet, address extensionDelegate) external;
    function updateAssetBorrowCollateralFactor(address comet, address asset, uint64 newBorrowCollateralFactor) external;
    function updateAssetLiquidateCollateralFactor(address comet, address asset, uint64 newLiquidateCollateralFactor)
        external;
    function updateAssetLiquidationFactor(address comet, address asset, uint64 newLiquidationFactor) external;
    function factory(address comet) external view returns (address);
}

interface ICometAdmin609 {
    function deployAndUpgradeTo(address configurator, address comet) external;
    function getProxyImplementation(address proxy) external view returns (address);
}

interface IComet609 {
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
    function extensionDelegate() external view returns (address);
}

interface IVersionedFactory609 {
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
    function version() external view returns (uint64 major, uint64 minor, uint64 patch, string memory alternative);
}

/// @notice Independent reconstruction of COMP proposal 609 from its description and typed interfaces.
contract Proposal_COMP_609_Test is Compound_Governance {
    IConfigurator609 internal constant CONFIGURATOR =
        IConfigurator609(0x316f9708bB98af7dA9c68C1C3b5e79039cD336E3);
    ICometAdmin609 internal constant COMET_ADMIN = ICometAdmin609(0x1EC63B5883C3481134FD50D5DAebc83Ecd2E8779);
    IVersionedFactory609 internal constant FACTORY = IVersionedFactory609(0x298aC0E463cEAd4aaA73fb91Df7C639A8eFBd9c4);
    IComet609 internal constant COMET = IComet609(0xe85Dc543813B8c2CFEaAc371517b925a166a9293);

    address internal constant PUMP_BTC = 0xF469fBD2abcd6B9de8E169d128226C0Fc90a012e;
    address internal constant OLD_FACTORY = 0x1fA408992e74A42D1787E28b880C451452E8C958;
    address internal constant OLD_EXTENSION_DELEGATE = 0x4f4D5A808E2448cB12df7aC12EFb12888FD9BDd5;
    address internal constant NEW_EXTENSION_DELEGATE = 0xecac24cBadFDF7a8F302fCD75C91Fea9335611C4;

    uint256 internal constant PROPOSAL_ID = 609;
    uint256 internal constant CREATION_BLOCK = 26_024_021;
    uint256 internal constant VOTE_START = 26_037_161;
    uint256 internal constant VOTE_END = 26_056_871;
    address internal constant TEST_VOTER = address(0x609);

    uint64 internal constant BORROW_COLLATERAL_FACTOR_BEFORE = 750_000_000_000_000_000;
    uint64 internal constant LIQUIDATE_COLLATERAL_FACTOR_BEFORE = 780_000_000_000_000_000;
    uint64 internal constant LIQUIDATION_FACTOR_BEFORE = 900_000_000_000_000_000;

    function setUp() public {
        vm.createSelectFork({ blockNumber: CREATION_BLOCK, urlOrAlias: "mainnet" });
    }

    function test_liveProposalExistsOnchain() public view {
        assertEq(GOVERNOR.state(PROPOSAL_ID), 0, "proposal 609 was not pending at creation block");
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

        assertEq(liveTargets.length, 7, "unexpected call count");
        assertEq(liveValues.length, targets.length, "live values length mismatch");
        assertEq(liveCalldatas.length, targets.length, "live calldata length mismatch");
        for (uint256 i; i < targets.length; ++i) {
            assertEq(liveTargets[i], targets[i], "target mismatch");
            assertEq(liveValues[i], values[i], "value mismatch");
            assertEq(liveCalldatas[i], calldatas[i], "calldata mismatch");
        }
    }

    function test_fullLifecycleDelistsPumpBTCAndUpgradesComet() public {
        address implementationBefore = _beforeProposal();

        vm.roll(VOTE_START + 1);
        _executeLiveProposal(PROPOSAL_ID, VOTE_START, VOTE_END, TEST_VOTER);

        _afterExecution(implementationBefore);
    }

    function _beforeProposal() internal view returns (address implementationBefore) {
        IComet609.AssetInfo memory assetInfo = COMET.getAssetInfoByAddress(PUMP_BTC);
        assertEq(assetInfo.borrowCollateralFactor, BORROW_COLLATERAL_FACTOR_BEFORE, "unexpected borrow factor");
        assertEq(assetInfo.liquidateCollateralFactor, LIQUIDATE_COLLATERAL_FACTOR_BEFORE, "unexpected liquidate factor");
        assertEq(assetInfo.liquidationFactor, LIQUIDATION_FACTOR_BEFORE, "unexpected liquidation factor");
        assertEq(CONFIGURATOR.factory(address(COMET)), OLD_FACTORY, "unexpected pre-existing factory");
        assertEq(COMET.extensionDelegate(), OLD_EXTENSION_DELEGATE, "unexpected pre-existing extension delegate");

        (uint64 major, uint64 minor, uint64 patch, string memory alternative) = FACTORY.version();
        assertEq(major, 1, "unexpected factory major version");
        assertEq(minor, 0, "unexpected factory minor version");
        assertEq(patch, 0, "unexpected factory patch version");
        assertEq(bytes(alternative).length, 0, "unexpected factory version alternative");

        implementationBefore = COMET_ADMIN.getProxyImplementation(address(COMET));
        assertNotEq(implementationBefore, address(0), "pre-existing Comet implementation is zero");
        assertGt(implementationBefore.code.length, 0, "pre-existing Comet implementation has no code");
    }

    function _afterExecution(address implementationBefore) internal view {
        IComet609.AssetInfo memory assetInfo = COMET.getAssetInfoByAddress(PUMP_BTC);
        assertEq(assetInfo.borrowCollateralFactor, 0, "borrow collateral factor was not zeroed");
        assertEq(assetInfo.liquidateCollateralFactor, 0, "liquidate collateral factor was not zeroed");
        assertEq(assetInfo.liquidationFactor, 0, "liquidation factor was not zeroed");
        assertEq(CONFIGURATOR.factory(address(COMET)), address(FACTORY), "factory was not updated");
        assertEq(COMET.extensionDelegate(), NEW_EXTENSION_DELEGATE, "extension delegate was not updated");

        (uint64 major, uint64 minor, uint64 patch, string memory alternative) = FACTORY.version();
        assertEq(major, 1, "unexpected upgraded factory major version");
        assertEq(minor, 2, "unexpected upgraded factory minor version");
        assertEq(patch, 1, "unexpected upgraded factory patch version");
        assertEq(bytes(alternative).length, 0, "unexpected upgraded version alternative");

        address implementationAfter = COMET_ADMIN.getProxyImplementation(address(COMET));
        assertNotEq(implementationAfter, address(0), "upgraded Comet implementation is zero");
        assertGt(implementationAfter.code.length, 0, "upgraded Comet implementation has no code");
        assertNotEq(implementationAfter, implementationBefore, "Comet implementation did not change");
    }

    function _generateCallData()
        internal
        pure
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        targets = new address[](7);
        values = new uint256[](7);
        calldatas = new bytes[](7);

        IVersionedFactory609.Version memory version_ = IVersionedFactory609.Version({
            version: IVersionedFactory609.SemanticVersion({ major: 1, minor: 2, patch: 1 }), alternative: ""
        });

        targets[0] = address(FACTORY);
        calldatas[0] = abi.encodeWithSelector(IVersionedFactory609.setVersion.selector, version_);
        targets[1] = address(CONFIGURATOR);
        calldatas[1] = abi.encodeWithSelector(IConfigurator609.setFactory.selector, address(COMET), address(FACTORY));
        targets[2] = address(CONFIGURATOR);
        calldatas[2] = abi.encodeWithSelector(
            IConfigurator609.setExtensionDelegate.selector, address(COMET), NEW_EXTENSION_DELEGATE
        );
        targets[3] = address(CONFIGURATOR);
        calldatas[3] = abi.encodeWithSelector(
            IConfigurator609.updateAssetBorrowCollateralFactor.selector, address(COMET), PUMP_BTC, uint64(0)
        );
        targets[4] = address(CONFIGURATOR);
        calldatas[4] = abi.encodeWithSelector(
            IConfigurator609.updateAssetLiquidateCollateralFactor.selector, address(COMET), PUMP_BTC, uint64(0)
        );
        targets[5] = address(CONFIGURATOR);
        calldatas[5] = abi.encodeWithSelector(
            IConfigurator609.updateAssetLiquidationFactor.selector, address(COMET), PUMP_BTC, uint64(0)
        );
        targets[6] = address(COMET_ADMIN);
        calldatas[6] = abi.encodeWithSelector(
            ICometAdmin609.deployAndUpgradeTo.selector, address(CONFIGURATOR), address(COMET)
        );
    }

    function dirPath() public pure override returns (string memory) {
        return "src/compound/proposals/609-pumpbtc-deprecation";
    }
}
