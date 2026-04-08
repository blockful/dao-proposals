// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "@forge-std/src/console2.sol";

import { ENS_Governance } from "@ens/ens.t.sol";
import { SafeHelper } from "@ens/helpers/SafeHelper.sol";
import { ZodiacRolesHelper } from "@ens/helpers/ZodiacRolesHelper.sol";
import { IZodiacRoles } from "@ens/interfaces/IZodiacRoles.sol";
import { IRolesModifier, ConditionFlat } from "@ens/interfaces/IRolesModifier.sol";
import { IERC20 } from "@forge-std/src/interfaces/IERC20.sol";

import { RegistrarManager } from "./contracts/RegistrarManager.sol";

interface IRegistrarController {
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
    function recoverFunds(address _token, address _to, uint256 _amount) external;
    function withdraw() external;
}

/**
 * @title Proposal_ENS_EP_Registrar_Manager_Endowment_Test
 * @notice Calldata review for ENS EP 6.39 — Registrar Manager + Endowment Roles Updates
 * @dev This proposal:
 *      1) Registers the new registrar controllers in RegistrarManager.
 *      2) Transfers registrar controller ownership to RegistrarManager.
 *      3) Updates Zodiac Roles (MANAGER) to allow:
 *         - USDC.transfer(timelock, amount) with unlimited amount.
 *         - ETH transfers to timelock (empty calldata, send-only).
 */
contract Proposal_ENS_EP_Registrar_Manager_Endowment_Test is ENS_Governance, SafeHelper, ZodiacRolesHelper {
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    IRegistrarController public constant CURRENT_REGISTRAR =
        IRegistrarController(0x253553366Da8546fC250F225fe3d25d0C782303b);
    IRegistrarController public constant NEW_REGISTRAR =
        IRegistrarController(0x59E16fcCd424Cc24e280Be16E11Bcd56fb0CE547);
    IRegistrarController public constant OLD_REGISTRAR =
        IRegistrarController(0x283Af0B28c62C092C9727F1Ee09c02CA627EB7F5);

    IRolesModifier public constant ROLES_MOD = IRolesModifier(0x703806E61847984346d2D7DDd853049627e50A40);

    /// @dev Deployed RegistrarManager contract.
    RegistrarManager public constant manager =
        RegistrarManager(payable(0x62627681D92e36b9aeE1D9A6BF181373ccd42552));

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 24_828_897, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0x1D5460F896521aD685Ea4c3F2c679Ec0b6806359; // coltron.eth
    }

    function _beforeProposal() public override {
        assertEq(CURRENT_REGISTRAR.owner(), address(timelock), "Current registrar owner should be timelock");
        assertEq(NEW_REGISTRAR.owner(), address(timelock), "New registrar owner should be timelock");
        assertEq(OLD_REGISTRAR.owner(), address(timelock), "Old registrar owner should be timelock");

        _expectUSDCTransferNotAllowed();
        _expectEthSendNotAllowed();
    }

    function _generateCallData()
        public
        override
        returns (
            address[] memory,
            uint256[] memory,
            string[] memory,
            bytes[] memory,
            string memory
        )
    {
        uint256 numTransactions = 10;

        targets = new address[](numTransactions);
        values = new uint256[](numTransactions);
        calldatas = new bytes[](numTransactions);
        signatures = new string[](numTransactions);

        // 1) Register current registrar controller (controller.ens.eth)
        targets[0] = address(manager);
        calldatas[0] = abi.encodeWithSelector(RegistrarManager.addRegistrar.selector, address(CURRENT_REGISTRAR));

        // 2) Register new registrar controller
        targets[1] = address(manager);
        calldatas[1] = abi.encodeWithSelector(RegistrarManager.addRegistrar.selector, address(NEW_REGISTRAR));

        // 3) Register old registrar controller
        targets[2] = address(manager);
        calldatas[2] = abi.encodeWithSelector(RegistrarManager.addRegistrar.selector, address(OLD_REGISTRAR));

        // 4) Transfer ownership of current registrar to RegistrarManager
        targets[3] = address(CURRENT_REGISTRAR);
        calldatas[3] = abi.encodeWithSelector(IRegistrarController.transferOwnership.selector, address(manager));

        // 5) Transfer ownership of new registrar to RegistrarManager
        targets[4] = address(NEW_REGISTRAR);
        calldatas[4] = abi.encodeWithSelector(IRegistrarController.transferOwnership.selector, address(manager));

        // 6) Transfer ownership of old registrar to RegistrarManager
        targets[5] = address(OLD_REGISTRAR);
        calldatas[5] = abi.encodeWithSelector(IRegistrarController.transferOwnership.selector, address(manager));

        // 7) Zodiac: scope USDC target
        {
            bytes memory inner = abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, address(USDC));
            (targets[6], calldatas[6]) = _buildSafeExecCalldata(
                address(endowmentSafe), address(ROLES_MOD), inner, address(timelock)
            );
        }

        // 8) Zodiac: allow USDC.transfer(timelock, amount)
        {
            ConditionFlat[] memory conditions = _usdcTransferConditions();
            bytes memory inner = abi.encodeWithSelector(
                IRolesModifier.scopeFunction.selector,
                MANAGER_ROLE, address(USDC), IERC20.transfer.selector, conditions, uint8(0)
            );
            (targets[7], calldatas[7]) = _buildSafeExecCalldata(
                address(endowmentSafe), address(ROLES_MOD), inner, address(timelock)
            );
        }

        // 9) Zodiac: scope timelock target
        {
            bytes memory inner = abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, address(timelock));
            (targets[8], calldatas[8]) = _buildSafeExecCalldata(
                address(endowmentSafe), address(ROLES_MOD), inner, address(timelock)
            );
        }

        // 10) Zodiac: allow ETH sends to timelock (empty calldata, send-only)
        {
            bytes memory inner = abi.encodeWithSelector(
                IRolesModifier.allowFunction.selector, MANAGER_ROLE, address(timelock), bytes4(0), EXEC_SEND
            );
            (targets[9], calldatas[9]) = _buildSafeExecCalldata(
                address(endowmentSafe), address(ROLES_MOD), inner, address(timelock)
            );
        }

        description = vm.readFile("src/ens/proposals/ep-registrar-manager-endowment/proposalDescription.md");

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        // RegistrarManager state
        assertEq(manager.owner(), address(timelock), "RegistrarManager owner should be timelock");
        assertEq(manager.destination(), address(endowmentSafe), "Destination should be endowment safe");
        assertTrue(manager.isRegistrar(address(CURRENT_REGISTRAR)), "Current registrar not registered");
        assertTrue(manager.isRegistrar(address(NEW_REGISTRAR)), "New registrar not registered");
        assertTrue(manager.isRegistrar(address(OLD_REGISTRAR)), "Old registrar not registered");

        // Ownership transferred to manager
        assertEq(CURRENT_REGISTRAR.owner(), address(manager), "Current registrar owner should be manager");
        assertEq(NEW_REGISTRAR.owner(), address(manager), "New registrar owner should be manager");
        assertEq(OLD_REGISTRAR.owner(), address(manager), "Old registrar owner should be manager");

        // WithdrawAll
        uint256 balanceBefore = address(endowmentSafe).balance;
        uint256 registrarBalance =
            address(CURRENT_REGISTRAR).balance + address(NEW_REGISTRAR).balance + address(OLD_REGISTRAR).balance;
        uint256 managerBalance = address(manager).balance;
        manager.withdrawAll();
        uint256 balanceAfter = address(endowmentSafe).balance;

        assertEq(
            balanceAfter,
            balanceBefore + registrarBalance + managerBalance,
            "Endowment balance should increase after withdraw"
        );

        // Zodiac role permissions — positive tests
        _expectUSDCTransferAllowed();
        _expectEthSendAllowed();

        // Zodiac role permissions — negative tests (scoping verification)
        _expectUSDCTransferToNonTimelockBlocked();
        _expectEthSendToNonTimelockBlocked();
    }

    function _expectUSDCTransferNotAllowed() internal {
        uint256 amount = 1000000;

        vm.startPrank(karpatkey);
        bytes memory data = abi.encodeWithSelector(IERC20.transfer.selector, address(timelock), amount);
        vm.expectRevert();
        roles.execTransactionWithRole(address(USDC), 0, data, IZodiacRoles.Operation.Call, MANAGER_ROLE, false);
        vm.stopPrank();
    }

    function _expectUSDCTransferAllowed() internal {
        uint256 amount = 1000000;

        // Ensure endowment safe has USDC to transfer (may be zero at fork block)
        deal(address(USDC), address(endowmentSafe), amount);

        uint256 balanceBefore = USDC.balanceOf(address(timelock));

        vm.startPrank(karpatkey);
        bytes memory data = abi.encodeWithSelector(IERC20.transfer.selector, address(timelock), amount);
        roles.execTransactionWithRole(address(USDC), 0, data, IZodiacRoles.Operation.Call, MANAGER_ROLE, false);
        vm.stopPrank();

        uint256 balanceAfter = USDC.balanceOf(address(timelock));
        assertEq(balanceAfter, balanceBefore + amount, "USDC balance should increase after transfer");
    }

    function _expectEthSendNotAllowed() internal {
        vm.startPrank(karpatkey);
        vm.expectRevert();
        roles.execTransactionWithRole(address(timelock), 1 ether, "", IZodiacRoles.Operation.Call, MANAGER_ROLE, false);
        vm.stopPrank();
    }

    function _expectEthSendAllowed() internal {
        uint256 balanceBefore = address(timelock).balance;
        uint256 amount = 1 ether;
        vm.startPrank(karpatkey);
        roles.execTransactionWithRole(address(timelock), amount, "", IZodiacRoles.Operation.Call, MANAGER_ROLE, false);
        vm.stopPrank();

        uint256 balanceAfter = address(timelock).balance;
        assertEq(balanceAfter, balanceBefore + amount, "ETH balance should increase after transfer");
    }

    function _expectUSDCTransferToNonTimelockBlocked() internal {
        address notTimelock = address(0xdead);
        uint256 amount = 1000000;

        vm.startPrank(karpatkey);
        bytes memory data = abi.encodeWithSelector(IERC20.transfer.selector, notTimelock, amount);
        vm.expectRevert();
        roles.execTransactionWithRole(address(USDC), 0, data, IZodiacRoles.Operation.Call, MANAGER_ROLE, false);
        vm.stopPrank();
    }

    function _expectEthSendToNonTimelockBlocked() internal {
        address notTimelock = address(0xdead);

        vm.startPrank(karpatkey);
        vm.expectRevert();
        roles.execTransactionWithRole(notTimelock, 1 ether, "", IZodiacRoles.Operation.Call, MANAGER_ROLE, false);
        vm.stopPrank();
    }

    function _usdcTransferConditions() internal view returns (ConditionFlat[] memory) {
        ConditionFlat[] memory conditions = new ConditionFlat[](3);
        conditions[0] = ConditionFlat({
            parent: 0,
            paramType: PARAM_TYPE_CALLDATA,
            operator: OP_MATCHES,
            compValue: ""
        });
        conditions[1] = ConditionFlat({
            parent: 0,
            paramType: PARAM_TYPE_STATIC,
            operator: OP_EQUAL_TO,
            compValue: abi.encodePacked(bytes32(uint256(uint160(address(timelock)))))
        });
        conditions[2] = ConditionFlat({
            parent: 0,
            paramType: PARAM_TYPE_STATIC,
            operator: OP_PASS,
            compValue: ""
        });
        return conditions;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-registrar-manager-endowment";
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true;
    }
}
