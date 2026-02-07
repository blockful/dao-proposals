// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "@forge-std/src/console2.sol";

import { ENS_Governance } from "@ens/ens.t.sol";
import { SafeHelper } from "@ens/helpers/SafeHelper.sol";
import { ZodiacRolesHelper } from "@ens/helpers/ZodiacRolesHelper.sol";
import { IZodiacRoles } from "@ens/interfaces/IZodiacRoles.sol";
import { IERC20 } from "@forge-std/src/interfaces/IERC20.sol";

import { RegistrarManager } from "./contracts/RegistrarManager.sol";

interface IRegistrarController {
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
    function recoverFunds(address _token, address _to, uint256 _amount) external;
    function withdraw() external;
}

interface IRoles {
    function scopeTarget(bytes32 roleKey, address targetAddress) external;

    function allowFunction(
        bytes32 roleKey,
        address targetAddress,
        bytes4 selector,
        uint8 options
    )
        external;

    function scopeFunction(
        bytes32 roleKey,
        address targetAddress,
        bytes4 selector,
        ConditionFlat[] calldata conditions,
        uint8 options
    )
        external;
}

struct ConditionFlat {
    uint8 parent;
    uint8 paramType;
    uint8 operator;
    bytes compValue;
}

/**
 * @title Proposal_ENS_EP_Registrar_Manager_Endowment_Test
 * @notice Calldata review for ENS Draft — Registrar Manager + Endowment Roles Updates
 * @dev This proposal:
 *      1) Registers the new registrar controllers in RegistrarManager.
 *      2) Transfers registrar controller ownership to RegistrarManager.
 *      3) Updates Zodiac Roles (MANAGER) to allow:
 *         - USDC.transfer(timelock, amount) with unlimited amount.
 *         - ETH transfers to timelock (empty calldata, send-only).
 */
contract Proposal_ENS_EP_Registrar_Manager_Endowment_Test is ENS_Governance, SafeHelper, ZodiacRolesHelper {
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    IRegistrarController public constant NEW_REGISTRAR =
        IRegistrarController(0x59E16fcCd424Cc24e280Be16E11Bcd56fb0CE547);
    IRegistrarController public constant OLD_REGISTRAR =
        IRegistrarController(0x283Af0B28c62C092C9727F1Ee09c02CA627EB7F5);

    IRoles public constant ROLES_MOD = IRoles(0x703806E61847984346d2D7DDd853049627e50A40);

    uint8 private constant ABI_TYPE_STATIC = 1;
    uint8 private constant ABI_TYPE_CALLDATA = 5;
    uint8 private constant OP_PASS = 0;
    uint8 private constant OP_MATCHES = 5;
    uint8 private constant OP_EQUAL_TO = 16;
    uint8 private constant EXECUTION_SEND = 1;

    RegistrarManager public manager;

    function setUp() public override {
        super.setUp();
        manager = new RegistrarManager(address(timelock), address(endowmentSafe));
    }

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 24_402_958, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0xb8c2C29ee19D8307cb7255e1Cd9CbDE883A267d5; // nick.eth
    }

    function _beforeProposal() public override {
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
        uint256 numTransactions = 8;

        targets = new address[](numTransactions);
        values = new uint256[](numTransactions);
        calldatas = new bytes[](numTransactions);
        signatures = new string[](numTransactions);

        address managerAddr = address(manager);

        // 1) Register new registrar controller
        targets[0] = managerAddr;
        calldatas[0] = abi.encodeWithSelector(RegistrarManager.addRegistrar.selector, address(NEW_REGISTRAR));

        // 2) Register old registrar controller
        targets[1] = managerAddr;
        calldatas[1] = abi.encodeWithSelector(RegistrarManager.addRegistrar.selector, address(OLD_REGISTRAR));

        // 3) Transfer ownership of new registrar to RegistrarManager
        targets[2] = address(NEW_REGISTRAR);
        calldatas[2] = abi.encodeWithSelector(IRegistrarController.transferOwnership.selector, managerAddr);

        // 4) Transfer ownership of old registrar to RegistrarManager
        targets[3] = address(OLD_REGISTRAR);
        calldatas[3] = abi.encodeWithSelector(IRegistrarController.transferOwnership.selector, managerAddr);

        // 5) Zodiac: scope USDC target
        {
            bytes memory inner = abi.encodeWithSelector(IRoles.scopeTarget.selector, MANAGER_ROLE, address(USDC));
            (targets[4], calldatas[4]) = _buildSafeExecCalldata(
                address(endowmentSafe), address(ROLES_MOD), inner, address(timelock)
            );
        }

        // 6) Zodiac: allow USDC.transfer(timelock, amount)
        {
            ConditionFlat[] memory conditions = _usdcTransferConditions();
            bytes memory inner = abi.encodeWithSelector(
                IRoles.scopeFunction.selector,
                MANAGER_ROLE, address(USDC), IERC20.transfer.selector, conditions, uint8(0)
            );
            (targets[5], calldatas[5]) = _buildSafeExecCalldata(
                address(endowmentSafe), address(ROLES_MOD), inner, address(timelock)
            );
        }

        // 7) Zodiac: scope timelock target
        {
            bytes memory inner = abi.encodeWithSelector(IRoles.scopeTarget.selector, MANAGER_ROLE, address(timelock));
            (targets[6], calldatas[6]) = _buildSafeExecCalldata(
                address(endowmentSafe), address(ROLES_MOD), inner, address(timelock)
            );
        }

        // 8) Zodiac: allow ETH sends to timelock (empty calldata, send-only)
        {
            bytes memory inner = abi.encodeWithSelector(
                IRoles.allowFunction.selector, MANAGER_ROLE, address(timelock), bytes4(0), EXECUTION_SEND
            );
            (targets[7], calldatas[7]) = _buildSafeExecCalldata(
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
        assertTrue(manager.isRegistrar(address(NEW_REGISTRAR)), "New registrar not registered");
        assertTrue(manager.isRegistrar(address(OLD_REGISTRAR)), "Old registrar not registered");

        // Ownership transferred to manager
        address managerAddr = address(manager);
        assertEq(NEW_REGISTRAR.owner(), managerAddr, "New registrar owner should be manager");
        assertEq(OLD_REGISTRAR.owner(), managerAddr, "Old registrar owner should be manager");

        // WithdrawAll
        uint256 balanceBefore = address(endowmentSafe).balance;
        uint256 registrarBalance = address(NEW_REGISTRAR).balance + address(OLD_REGISTRAR).balance;
        uint256 managerBalance = address(manager).balance;
        manager.withdrawAll();
        uint256 balanceAfter = address(endowmentSafe).balance;

        assertEq(
            balanceAfter,
            balanceBefore + registrarBalance + managerBalance,
            "Endowment balance should increase after withdraw"
        );

        // Zodiac role permissions
        _expectUSDCTransferAllowed();
        _expectEthSendAllowed();
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
        uint256 balanceBefore = USDC.balanceOf(address(timelock));
        uint256 amount = 1000000;

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

    function _usdcTransferConditions() internal view returns (ConditionFlat[] memory) {
        ConditionFlat[] memory conditions = new ConditionFlat[](3);
        conditions[0] = ConditionFlat({
            parent: 0,
            paramType: ABI_TYPE_CALLDATA,
            operator: OP_MATCHES,
            compValue: ""
        });
        conditions[1] = ConditionFlat({
            parent: 0,
            paramType: ABI_TYPE_STATIC,
            operator: OP_EQUAL_TO,
            compValue: abi.encodePacked(bytes32(uint256(uint160(address(timelock)))))
        });
        conditions[2] = ConditionFlat({
            parent: 0,
            paramType: ABI_TYPE_STATIC,
            operator: OP_PASS,
            compValue: ""
        });
        return conditions;
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return false;
    }
}
