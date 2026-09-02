// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Compound_Governance } from "@compound/compound.t.sol";
import { ICompToken } from "@compound/interfaces/ICompToken.sol";

interface ILegacyFranchiserFactory {
    function recallMany(address[] calldata delegatees, address[] calldata tos) external;
    function getFranchiser(address owner, address delegatee) external view returns (address);
}

interface IFranchiserPoolFactory {
    function createPoolAndFund(
        address coordinator,
        address guardian,
        uint256 maxDelegatees,
        uint256 freezePeriod,
        uint256 totalAmount,
        address[] calldata delegatees,
        uint256[] calldata amounts
    )
        external
        returns (address pool);
    function getAllPools() external view returns (address[] memory);
    function governance() external view returns (address);
    function votingToken() external view returns (address);
    function isKnownPool(address pool) external view returns (bool);
}

interface IFranchiserPool {
    function activeDelegatees() external view returns (address[] memory);
    function coordinator() external view returns (address);
    function guardian() external view returns (address);
    function maxDelegatees() external view returns (uint256);
    function freezePeriod() external view returns (uint256);
    function frozenUntil() external view returns (uint256);
    function factory() external view returns (address);
    function votingToken() external view returns (address);
    function getFranchiser(address delegatee) external view returns (address);
    function delegate(address delegatee, uint256 amount) external;
}

/// @notice Independent reconstruction of COMP proposal 601 from its specification and typed interfaces.
contract Proposal_COMP_601_Test is Compound_Governance {
    ILegacyFranchiserFactory constant LEGACY_FACTORY =
        ILegacyFranchiserFactory(0xE696d89f4F378772f437F01FaaD70240abdf1854);
    IFranchiserPoolFactory constant POOL_FACTORY = IFranchiserPoolFactory(0x8421c35b1235741e00d2475f365A434d4b476A19);

    uint256 constant PROPOSAL_ID = 601;
    uint256 constant VOTE_START = 25_855_886;
    uint256 constant VOTE_END = 25_875_596;
    uint256 constant TOTAL_AMOUNT = 610_000 ether;
    uint256 constant MAX_DELEGATEES = 30;
    uint256 constant FREEZE_PERIOD = 10 days;

    address constant COORDINATOR = 0xfd947c72f09703210eeCbcab9c9206fE5e1Bb6e2;
    address constant GUARDIAN = 0xbbf3f1421D886E9b2c5D716B5192aC998af2012c;
    address constant TEST_VOTER = address(0x601);

    function setUp() public {
        vm.createSelectFork({ blockNumber: VOTE_START + 1, urlOrAlias: "mainnet" });
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

        assertEq(liveTargets.length, 3, "unexpected call count");
        for (uint256 i; i < targets.length; ++i) {
            assertEq(liveTargets[i], targets[i], "target mismatch");
            assertEq(liveValues[i], values[i], "value mismatch");
            assertEq(liveCalldatas[i], calldatas[i], "calldata mismatch");
        }
    }

    function test_fullLifecycleMigratesAllCompIntoConfiguredPool() public {
        address[] memory legacyDelegatees = _legacyDelegatees();
        address[] memory newDelegatees = _newDelegatees();
        uint256[] memory newAmounts = _newAmounts();
        uint256 timelockBalanceBefore = COMP.balanceOf(address(TIMELOCK));

        _beforeProposal(legacyDelegatees);

        _executeLiveProposal(PROPOSAL_ID, VOTE_START, VOTE_END, TEST_VOTER);

        _afterExecution(legacyDelegatees, newDelegatees, newAmounts, timelockBalanceBefore);
    }

    function _beforeProposal(address[] memory legacyDelegatees) internal view {
        assertEq(POOL_FACTORY.getAllPools().length, 0, "pool already exists at review fork");
        assertEq(COMP.allowance(address(TIMELOCK), address(POOL_FACTORY)), 0, "unexpected pre-existing allowance");

        uint256 legacyBalance;
        for (uint256 i; i < legacyDelegatees.length; ++i) {
            address franchiser = LEGACY_FACTORY.getFranchiser(address(TIMELOCK), legacyDelegatees[i]);
            uint256 balance = COMP.balanceOf(franchiser);
            assertGt(balance, 0, "legacy franchiser must be funded");
            assertEq(COMP.delegates(franchiser), legacyDelegatees[i], "legacy voting power delegated incorrectly");
            legacyBalance += balance;
        }
        assertEq(legacyBalance, TOTAL_AMOUNT, "legacy program total must be 610,000 COMP");
    }

    function _afterExecution(
        address[] memory legacyDelegatees,
        address[] memory newDelegatees,
        uint256[] memory newAmounts,
        uint256 timelockBalanceBefore
    )
        internal
    {
        for (uint256 i; i < legacyDelegatees.length; ++i) {
            address oldFranchiser = LEGACY_FACTORY.getFranchiser(address(TIMELOCK), legacyDelegatees[i]);
            assertEq(COMP.balanceOf(oldFranchiser), 0, "legacy franchiser retained COMP");
        }

        address[] memory pools = POOL_FACTORY.getAllPools();
        assertEq(pools.length, 1, "exactly one pool must be created");
        address poolAddress = pools[0];
        IFranchiserPool pool = IFranchiserPool(poolAddress);

        assertTrue(POOL_FACTORY.isKnownPool(poolAddress), "factory does not recognize pool");
        assertEq(POOL_FACTORY.governance(), address(TIMELOCK), "factory governance mismatch");
        assertEq(POOL_FACTORY.votingToken(), address(COMP), "factory voting token mismatch");
        assertEq(pool.factory(), address(POOL_FACTORY), "pool factory mismatch");
        assertEq(pool.votingToken(), address(COMP), "pool voting token mismatch");
        assertEq(pool.coordinator(), COORDINATOR, "coordinator mismatch");
        assertEq(pool.guardian(), GUARDIAN, "guardian mismatch");
        assertEq(pool.maxDelegatees(), MAX_DELEGATEES, "delegate cap mismatch");
        assertEq(pool.freezePeriod(), FREEZE_PERIOD, "freeze period mismatch");
        assertEq(pool.frozenUntil(), 0, "pool unexpectedly frozen");
        assertEq(pool.activeDelegatees().length, newDelegatees.length, "active delegate count mismatch");

        uint256 delegatedBalance;
        for (uint256 i; i < newDelegatees.length; ++i) {
            address franchiser = pool.getFranchiser(newDelegatees[i]);
            assertEq(COMP.balanceOf(franchiser), newAmounts[i], "new delegation amount mismatch");
            assertEq(COMP.delegates(franchiser), newDelegatees[i], "new voting power delegated incorrectly");
            delegatedBalance += COMP.balanceOf(franchiser);
        }
        assertEq(delegatedBalance, TOTAL_AMOUNT, "new program total must remain 610,000 COMP");
        assertEq(COMP.balanceOf(poolAddress), 0, "pool should have no idle COMP after initial allocation");
        assertEq(COMP.allowance(address(TIMELOCK), address(POOL_FACTORY)), 0, "factory allowance should be consumed");
        assertEq(COMP.balanceOf(address(TIMELOCK)), timelockBalanceBefore, "migration changed timelock COMP balance");

        vm.expectRevert();
        pool.delegate(address(0xBEEF), 1 ether);
    }

    function _generateCallData()
        internal
        pure
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        address[] memory legacyDelegatees = _legacyDelegatees();
        address[] memory recipients = new address[](legacyDelegatees.length);
        for (uint256 i; i < recipients.length; ++i) {
            recipients[i] = address(TIMELOCK);
        }

        targets = new address[](3);
        values = new uint256[](3);
        calldatas = new bytes[](3);

        targets[0] = address(LEGACY_FACTORY);
        calldatas[0] =
            abi.encodeWithSelector(ILegacyFranchiserFactory.recallMany.selector, legacyDelegatees, recipients);

        targets[1] = address(COMP);
        calldatas[1] = abi.encodeWithSelector(ICompToken.approve.selector, address(POOL_FACTORY), TOTAL_AMOUNT);

        targets[2] = address(POOL_FACTORY);
        calldatas[2] = abi.encodeWithSelector(
            IFranchiserPoolFactory.createPoolAndFund.selector,
            COORDINATOR,
            GUARDIAN,
            MAX_DELEGATEES,
            FREEZE_PERIOD,
            TOTAL_AMOUNT,
            _newDelegatees(),
            _newAmounts()
        );
    }

    function _legacyDelegatees() internal pure returns (address[] memory x) {
        x = new address[](13);
        x[0] = 0xd2A79F263eC55DBC7B724eCc20FC7448D4795a0C;
        x[1] = 0x17296956b4E07Ff8931E4ff4eA06709FaB70b879;
        x[2] = 0xB933AEe47C438f22DE0747D57fc239FE37878Dd1;
        x[3] = 0xB79294D00848a3A4C00c22D9367F19B4280689D7;
        x[4] = 0x3FB19771947072629C8EEE7995a2eF23B72d4C8A;
        x[5] = 0x070341aA5Ed571f0FB2c4a5641409B1A46b4961b;
        x[6] = 0x0579A616689f7ed748dC07692A3F150D44b0CA09;
        x[7] = 0x13BDaE8c5F0fC40231F0E6A4ad70196F59138548;
        x[8] = 0x66cD62c6F8A4BB0Cd8720488BCBd1A6221B765F9;
        x[9] = 0xB49f8b8613bE240213C1827e2E576044fFEC7948;
        x[10] = 0xb35659cbac913D5E4119F2Af47fD490A45e2c826;
        x[11] = 0x72C58877ef744b86F6ef416a3bE26Ec19d587708;
        x[12] = 0x4f894Bfc9481110278C356adE1473eBe2127Fd3C;
    }

    function _newDelegatees() internal pure returns (address[] memory x) {
        x = new address[](12);
        x[0] = 0xd2A79F263eC55DBC7B724eCc20FC7448D4795a0C;
        x[1] = 0x17296956b4E07Ff8931E4ff4eA06709FaB70b879;
        x[2] = 0xB933AEe47C438f22DE0747D57fc239FE37878Dd1;
        x[3] = 0xB79294D00848a3A4C00c22D9367F19B4280689D7;
        x[4] = 0x3FB19771947072629C8EEE7995a2eF23B72d4C8A;
        x[5] = 0x070341aA5Ed571f0FB2c4a5641409B1A46b4961b;
        x[6] = 0x0579A616689f7ed748dC07692A3F150D44b0CA09;
        x[7] = 0x66cD62c6F8A4BB0Cd8720488BCBd1A6221B765F9;
        x[8] = 0xB49f8b8613bE240213C1827e2E576044fFEC7948;
        x[9] = 0xb35659cbac913D5E4119F2Af47fD490A45e2c826;
        x[10] = 0xc5547B4907418C2EC0C2A95beC6fEE8354657759;
        x[11] = 0x1F3D3A7A9c548bE39539b39D7400302753E20591;
    }

    function _newAmounts() internal pure returns (uint256[] memory x) {
        x = new uint256[](12);
        x[0] = 59_998.98 ether;
        x[1] = 59_999 ether;
        x[2] = 59_317.1 ether;
        x[3] = 59_999.99 ether;
        x[4] = 34_450 ether;
        x[5] = 39_998.25 ether;
        x[6] = 59_999 ether;
        x[7] = 44_371.81 ether;
        x[8] = 59_999.99 ether;
        x[9] = 58_949.76 ether;
        x[10] = 40_000 ether;
        x[11] = 32_916.12 ether;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/compound/proposals/601-franchiser-upgrade-rebalance";
    }
}
