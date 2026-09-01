// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Compound_Governance } from "@compound/compound.t.sol";

interface IConfigurator {
    function setBaseTrackingBorrowSpeed(address cometProxy, uint64 newBaseTrackingBorrowSpeed) external;
    function setBaseTrackingSupplySpeed(address cometProxy, uint64 newBaseTrackingSupplySpeed) external;
}

interface ICometProxyAdmin {
    function deployAndUpgradeTo(address configuratorProxy, address cometProxy) external;
}

interface ICometRewardsConfiguration {
    function baseTrackingBorrowSpeed() external view returns (uint64);
    function baseTrackingSupplySpeed() external view returns (uint64);
}

/// @notice Independent reconstruction of COMP proposal 602 from its specification and typed interfaces.
contract Proposal_COMP_602_Test is Compound_Governance {
    IConfigurator internal constant CONFIGURATOR = IConfigurator(0x316f9708bB98af7dA9c68C1C3b5e79039cD336E3);
    ICometProxyAdmin internal constant COMET_PROXY_ADMIN = ICometProxyAdmin(0x1EC63B5883C3481134FD50D5DAebc83Ecd2E8779);

    ICometRewardsConfiguration internal constant USDC_COMET =
        ICometRewardsConfiguration(0xc3d688B66703497DAA19211EEdff47f25384cdc3);
    ICometRewardsConfiguration internal constant USDT_COMET =
        ICometRewardsConfiguration(0x3Afdc9BCA9213A35503b077a6072F3D0d5AB0840);
    ICometRewardsConfiguration internal constant WETH_COMET =
        ICometRewardsConfiguration(0xA17581A9E3356d9A858b789D68B4d866e593aE94);

    uint256 internal constant PROPOSAL_ID = 602;
    uint256 internal constant VOTE_START = 25_867_715;
    uint256 internal constant VOTE_END = 25_887_425;
    address internal constant TEST_VOTER = address(0x602);

    uint64 internal constant USDC_BORROW_SPEED_BEFORE = 636_574_074_074;
    uint64 internal constant USDC_SUPPLY_SPEED_BEFORE = 636_574_074_074;
    uint64 internal constant USDT_BORROW_SPEED_BEFORE = 347_222_222_222;
    uint64 internal constant USDT_SUPPLY_SPEED_BEFORE = 347_222_222_222;
    uint64 internal constant WETH_BORROW_SPEED_BEFORE = 231_481_481_481;
    uint64 internal constant WETH_SUPPLY_SPEED_BEFORE = 115_740_740_740;

    bytes32 internal constant EIP1967_IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    struct Implementations {
        address usdc;
        address usdt;
        address weth;
    }

    function setUp() public {
        vm.createSelectFork("https://eth-mainnet.public.blastapi.io", VOTE_START + 1);
    }

    function test_liveProposalExistsOnchain() public view {
        uint8 proposalState = GOVERNOR.state(PROPOSAL_ID);
        assertTrue(
            proposalState == 0 || proposalState == 1 || proposalState == 4 || proposalState == 5 || proposalState == 7
        );
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

        assertEq(liveTargets.length, 9, "unexpected call count");
        assertEq(liveValues.length, targets.length, "live values length mismatch");
        assertEq(liveCalldatas.length, targets.length, "live calldata length mismatch");
        assertEq(values.length, targets.length, "derived values length mismatch");
        assertEq(calldatas.length, targets.length, "derived calldata length mismatch");
        for (uint256 i; i < targets.length; ++i) {
            assertEq(liveTargets[i], targets[i], "target mismatch");
            assertEq(liveValues[i], values[i], "value mismatch");
            assertEq(liveCalldatas[i], calldatas[i], "calldata mismatch");
        }
    }

    function test_fullLifecycleStopsLegacyRewardAccrualAndUpgradesMarkets() public {
        Implementations memory implementationsBefore = _beforeProposal();

        _executeLiveProposal(PROPOSAL_ID, VOTE_START, VOTE_END, TEST_VOTER);

        _afterExecution(implementationsBefore);
    }

    function _beforeProposal() internal view returns (Implementations memory implementations) {
        assertEq(USDC_COMET.baseTrackingBorrowSpeed(), USDC_BORROW_SPEED_BEFORE, "unexpected USDC borrow speed");
        assertEq(USDC_COMET.baseTrackingSupplySpeed(), USDC_SUPPLY_SPEED_BEFORE, "unexpected USDC supply speed");
        assertEq(USDT_COMET.baseTrackingBorrowSpeed(), USDT_BORROW_SPEED_BEFORE, "unexpected USDT borrow speed");
        assertEq(USDT_COMET.baseTrackingSupplySpeed(), USDT_SUPPLY_SPEED_BEFORE, "unexpected USDT supply speed");
        assertEq(WETH_COMET.baseTrackingBorrowSpeed(), WETH_BORROW_SPEED_BEFORE, "unexpected WETH borrow speed");
        assertEq(WETH_COMET.baseTrackingSupplySpeed(), WETH_SUPPLY_SPEED_BEFORE, "unexpected WETH supply speed");

        implementations.usdc = _implementationOf(address(USDC_COMET));
        implementations.usdt = _implementationOf(address(USDT_COMET));
        implementations.weth = _implementationOf(address(WETH_COMET));
        assertNotEq(implementations.usdc, address(0), "USDC implementation is zero");
        assertNotEq(implementations.usdt, address(0), "USDT implementation is zero");
        assertNotEq(implementations.weth, address(0), "WETH implementation is zero");
    }

    function _afterExecution(Implementations memory implementationsBefore) internal view {
        assertEq(USDC_COMET.baseTrackingBorrowSpeed(), 0, "USDC borrow rewards still accrue");
        assertEq(USDC_COMET.baseTrackingSupplySpeed(), 0, "USDC supply rewards still accrue");
        assertEq(USDT_COMET.baseTrackingBorrowSpeed(), 0, "USDT borrow rewards still accrue");
        assertEq(USDT_COMET.baseTrackingSupplySpeed(), 0, "USDT supply rewards still accrue");
        assertEq(WETH_COMET.baseTrackingBorrowSpeed(), 0, "WETH borrow rewards still accrue");
        assertEq(WETH_COMET.baseTrackingSupplySpeed(), 0, "WETH supply rewards still accrue");

        address usdcImplementationAfter = _implementationOf(address(USDC_COMET));
        address usdtImplementationAfter = _implementationOf(address(USDT_COMET));
        address wethImplementationAfter = _implementationOf(address(WETH_COMET));
        assertNotEq(usdcImplementationAfter, address(0), "upgraded USDC implementation is zero");
        assertNotEq(usdtImplementationAfter, address(0), "upgraded USDT implementation is zero");
        assertNotEq(wethImplementationAfter, address(0), "upgraded WETH implementation is zero");
        assertGt(usdcImplementationAfter.code.length, 0, "upgraded USDC implementation has no code");
        assertGt(usdtImplementationAfter.code.length, 0, "upgraded USDT implementation has no code");
        assertGt(wethImplementationAfter.code.length, 0, "upgraded WETH implementation has no code");
        assertNotEq(usdcImplementationAfter, implementationsBefore.usdc, "USDC implementation did not change");
        assertNotEq(usdtImplementationAfter, implementationsBefore.usdt, "USDT implementation did not change");
        assertNotEq(wethImplementationAfter, implementationsBefore.weth, "WETH implementation did not change");
    }

    function _generateCallData()
        internal
        pure
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        address[3] memory markets = [address(USDC_COMET), address(USDT_COMET), address(WETH_COMET)];
        targets = new address[](9);
        values = new uint256[](9);
        calldatas = new bytes[](9);

        for (uint256 i; i < markets.length; ++i) {
            uint256 setterIndex = i * 2;
            targets[setterIndex] = address(CONFIGURATOR);
            calldatas[setterIndex] =
                abi.encodeWithSelector(IConfigurator.setBaseTrackingBorrowSpeed.selector, markets[i], uint64(0));

            targets[setterIndex + 1] = address(CONFIGURATOR);
            calldatas[setterIndex + 1] =
                abi.encodeWithSelector(IConfigurator.setBaseTrackingSupplySpeed.selector, markets[i], uint64(0));

            targets[6 + i] = address(COMET_PROXY_ADMIN);
            calldatas[6 + i] = abi.encodeWithSelector(
                ICometProxyAdmin.deployAndUpgradeTo.selector, address(CONFIGURATOR), markets[i]
            );
        }
    }

    function _implementationOf(address proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, EIP1967_IMPLEMENTATION_SLOT))));
    }

    function dirPath() public pure override returns (string memory) {
        return "src/compound/proposals/602-stop-legacy-rewards";
    }
}
