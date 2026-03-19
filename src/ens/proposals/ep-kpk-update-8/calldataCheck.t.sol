// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ENS_Governance } from "@ens/ens.t.sol";
import { SafeHelper } from "@ens/helpers/SafeHelper.sol";
import { ZodiacRolesHelper } from "@ens/helpers/ZodiacRolesHelper.sol";
import { IZodiacRoles } from "@ens/interfaces/IZodiacRoles.sol";
import { IRolesModifier, ConditionFlat } from "@ens/interfaces/IRolesModifier.sol";
import { IMultiSend } from "@ens/interfaces/IMultiSend.sol";
import { ICowSwapOrderSigner } from "@ens/interfaces/ICowSwapOrderSigner.sol";
import { ISparkRewards } from "@ens/interfaces/ISparkRewards.sol";
import { IAnnotationRegistry } from "@ens/interfaces/IAnnotationRegistry.sol";
import { IFluidMerkleDistributor } from "@ens/interfaces/IFluidMerkleDistributor.sol";
import { IWETH } from "@ens/interfaces/IWETH.sol";
import { IERC20 } from "@forge-std/src/interfaces/IERC20.sol";

/**
 * @title EP 6.38 — Endowment permissions to karpatkey — Update #8
 * @notice Calldata review for the draft proposal on Tally
 * @dev Draft: https://www.tally.xyz/gov/ens/draft/2810671389726475399
 *
 * Summary of operations (18 transactions in MultiSend):
 *
 *   1. disableModule: Remove Roles V1 (0xf20325cf...) from Endowment Safe
 *   2. setTransactionUnwrapper: Update unwrapper for multiSend adapter on Roles V2
 *   3. revokeTarget(MANAGER, RocketPoolDepositV3): Revoke old RocketPool deposit pool
 *   4. revokeFunction(MANAGER, RocketPoolDepositV3, deposit()): Revoke deposit
 *   5. revokeFunction(MANAGER, SPK, transfer()): Remove SPK transfer permission
 *   6. revokeTarget(MANAGER, SparkRewards): Revoke SparkRewards contract
 *   7. revokeFunction(MANAGER, SparkRewards, claim()): Revoke SparkRewards claim
 *   8. post(): Remove old annotations from annotation registry
 *   9. scopeFunction(MANAGER, CowSwapOrderSigner, signOrder()): CowSwap swap permissions with GHO+FLUID
 *  10. scopeFunction(MANAGER, GHO, approve()): GHO approval scoped to fGHO + GPv2VaultRelayer
 *  11. scopeTarget(MANAGER, FLUID): Scope FLUID token target
 *  12. scopeFunction(MANAGER, FLUID, approve()): FLUID approval scoped to GPv2VaultRelayer
 *  13. scopeTarget(MANAGER, RocketPoolDepositV4): Scope new RocketPool deposit pool
 *  14. allowFunction(MANAGER, RocketPoolDepositV4, deposit()): Allow deposit with ETH
 *  15. scopeTarget(MANAGER, FluidMerkle): Scope Fluid Merkle Distributor
 *  16. scopeFunction(MANAGER, FluidMerkle, claim()): Claim scoped to recipient=Safe
 *  17. post(): Add new annotations to annotation registry
 *  18. setTransactionUnwrapper: Re-apply unwrapper for multiSend adapter
 */
contract Proposal_ENS_EP_KPK_Update_8_Draft_Test is ENS_Governance, SafeHelper, ZodiacRolesHelper {
    // ─── Protocol Addresses ──────────────────────────────────────────────

    address private constant MULTISEND = 0xA83c336B20401Af773B6219BA5027174338D1836;
    address private constant MULTISEND_HANDLER = 0xA238CBeb142c10Ef7Ad8442C6D1f9E89e07e7761;
    address private constant MULTISEND_ADAPTER = 0xB4Cd4bb764C089f20DA18700CE8bc5e49F369efD;
    address private constant ANNOTATION_REGISTRY = 0x000000000000cd17345801aa8147b8D3950260FF;

    // ─── Roles V1 (being disabled) ───────────────────────────────────────

    address private constant ROLES_V1 = 0xf20325cf84b72e8BBF8D8984B8f0059B984B390B;
    address private constant PREV_MODULE = 0xCFbFaC74C26F8647cBDb8c5caf80BB5b32E43134;

    // ─── Revoked Targets ─────────────────────────────────────────────────

    address private constant ROCKET_POOL_DEPOSIT_V3 = 0xDD3f50F8A6CafbE9b31a427582963f465E745AF8;
    address private constant SPARK_REWARDS = 0x7ac96180C4d6b2A328D3a19ac059D0E7Fc3C6d41;
    address private constant SPK = 0xc20059e0317DE91738d13af027DfC4a50781b066;

    // ─── New Targets ─────────────────────────────────────────────────────

    address private constant ROCKET_POOL_DEPOSIT_V4 = 0xCE15294273CFb9D9b628F4D61636623decDF4fdC;
    address private constant FLUID_MERKLE = 0xF398E66B1273a34558AeBbEC550DccaF4AcC7714;
    address private constant COWSWAP_ORDER_SIGNER = 0x23dA9AdE38E4477b23770DeD512fD37b12381FAB;

    // ─── CowSwap Sell Tokens (25, sorted by address ascending) ───────────

    address private constant GHO     = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;
    address private constant SWISE   = 0x48C3399719B582dD63eB5AADf12A40B4C3f52FA2;
    address private constant CVX     = 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B;
    address private constant MORPHO  = 0x58D97B57BB95320F9a05dC918Aef65434969c2B2;
    address private constant LDO     = 0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32;
    address private constant DAI     = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address private constant FLUID   = 0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb;
    address private constant WSTETH  = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address private constant LUSD    = 0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3;
    address private constant USDC    = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private constant USR     = 0xA35b1B31Ce002FBF2058D22F30f95D405200A15b;
    address private constant SDAI    = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    address private constant RETH    = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address private constant STETH   = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address private constant BAL     = 0xba100000625a3754423978a60c9317c58a424e3D;
    address private constant COMP    = 0xc00e94Cb662C3520282E6f5717214004A7f26888;
    address private constant WETH    = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant AURA    = 0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF;
    // SPK already declared above in Revoked Targets
    address private constant RPL     = 0xD33526068D116cE69F19A9ee46F0bd304F21A51f;
    address private constant CRV     = 0xD533a949740bb3306d119CC777fa900bA034cd52;
    address private constant USDT    = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address private constant USDS    = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
    address private constant SUSDE   = 0xE95A203B1a91a908F9B9CE46459d101078c2c3cb;
    address private constant SFRXETH = 0xf1C9acDc66974dFB6dEcB12aA385b9cD01190E38;

    // ─── CowSwap Buy-only Tokens (not in sell list) ──────────────────────

    address private constant NATIVE_ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // ─── Approved Spenders ───────────────────────────────────────────────

    address private constant F_GHO = 0x6A29A46E21C730DcA1d8b23d637c101cec605C5B;
    address private constant GPV2_VAULT_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;

    // ─── Function Selectors ──────────────────────────────────────────────

    bytes4 private constant DEPOSIT_SELECTOR = IWETH.deposit.selector;
    bytes4 private constant TRANSFER_SELECTOR = IERC20.transfer.selector;
    bytes4 private constant APPROVE_SELECTOR = IERC20.approve.selector;
    bytes4 private constant SIGN_ORDER_SELECTOR = ICowSwapOrderSigner.signOrder.selector;
    bytes4 private constant SPARK_CLAIM_SELECTOR = ISparkRewards.claim.selector;
    bytes4 private constant FLUID_CLAIM_SELECTOR = IFluidMerkleDistributor.claim.selector;
    bytes4 private constant MULTISEND_SELECTOR = IMultiSend.multiSend.selector;

    // ─── Zodiac Condition Constants ──────────────────────────────────────

    // ─── Framework Overrides ─────────────────────────────────────────────

    function _selectFork() public override {
        vm.createSelectFork({ urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0x1D5460F896521aD685Ea4c3F2c679Ec0b6806359; // coltron.eth
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return false; // Draft -- not yet on-chain
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-kpk-update-8";
    }

    // ─── Before/After Permission Assertions ──────────────────────────────

    function _beforeProposal() public override {
        // Roles V1 should still be enabled as a module on the Safe
        (bool ok, bytes memory ret) = address(endowmentSafe).staticcall(
            abi.encodeWithSignature("isModuleEnabled(address)", ROLES_V1)
        );
        assertTrue(ok && abi.decode(ret, (bool)), "Roles V1 should be enabled before execution");

        // --- Permissions that SHOULD WORK before execution (will be revoked) ---

        // RocketPool v3 deposit currently works
        vm.startPrank(karpatkey);
        _safeExecuteTransaction(
            ROCKET_POOL_DEPOSIT_V3,
            abi.encodeWithSelector(DEPOSIT_SELECTOR)
        );
        vm.stopPrank();

        // SPK transfer currently works
        vm.startPrank(karpatkey);
        _safeExecuteTransaction(
            SPK,
            abi.encodeWithSelector(TRANSFER_SELECTOR, address(timelock), uint256(1))
        );
        vm.stopPrank();

        // SparkRewards claim currently works
        vm.startPrank(karpatkey);
        _safeExecuteTransaction(
            SPARK_REWARDS,
            abi.encodeWithSelector(
                SPARK_CLAIM_SELECTOR, uint256(0), address(endowmentSafe), SPK, uint256(0), bytes32(0), new bytes32[](0)
            )
        );
        vm.stopPrank();

        // --- Permissions that should NOT WORK before execution (will be added) ---

        // FLUID token target should not be scoped yet
        vm.startPrank(karpatkey);
        _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
        roles.execTransactionWithRole(
            FLUID,
            0,
            abi.encodeWithSelector(APPROVE_SELECTOR, GPV2_VAULT_RELAYER, uint256(1)),
            IZodiacRoles.Operation.Call,
            MANAGER_ROLE,
            false
        );
        vm.stopPrank();

        // FluidMerkle target should not be scoped yet
        vm.startPrank(karpatkey);
        _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
        roles.execTransactionWithRole(
            FLUID_MERKLE,
            0,
            abi.encodeWithSelector(
                FLUID_CLAIM_SELECTOR,
                address(endowmentSafe),
                uint256(0),
                uint8(0),
                bytes32(0),
                uint256(0),
                new bytes32[](0),
                ""
            ),
            IZodiacRoles.Operation.Call,
            MANAGER_ROLE,
            false
        );
        vm.stopPrank();

        // RocketPool v4 target should not be scoped yet
        vm.startPrank(karpatkey);
        _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
        roles.execTransactionWithRole(
            ROCKET_POOL_DEPOSIT_V4,
            0,
            abi.encodeWithSelector(DEPOSIT_SELECTOR),
            IZodiacRoles.Operation.Call,
            MANAGER_ROLE,
            false
        );
        vm.stopPrank();
    }

    function _afterExecution() public override {
        // --- Roles V1 should be disabled ---
        (bool ok, bytes memory ret) = address(endowmentSafe).staticcall(
            abi.encodeWithSignature("isModuleEnabled(address)", ROLES_V1)
        );
        assertTrue(ok, "isModuleEnabled call should succeed");
        assertFalse(abi.decode(ret, (bool)), "Roles V1 should be disabled after execution");

        // --- Revoked permissions should NO LONGER work ---

        // RocketPool v3 deposit revoked
        vm.startPrank(karpatkey);
        _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
        roles.execTransactionWithRole(
            ROCKET_POOL_DEPOSIT_V3,
            0,
            abi.encodeWithSelector(DEPOSIT_SELECTOR),
            IZodiacRoles.Operation.Call,
            MANAGER_ROLE,
            false
        );
        vm.stopPrank();

        // SPK transfer revoked
        vm.startPrank(karpatkey);
        vm.expectRevert(
            abi.encodeWithSelector(
                IZodiacRoles.ConditionViolation.selector,
                IZodiacRoles.Status.FunctionNotAllowed,
                bytes32(TRANSFER_SELECTOR)
            )
        );
        roles.execTransactionWithRole(
            SPK,
            0,
            abi.encodeWithSelector(TRANSFER_SELECTOR, address(timelock), uint256(1)),
            IZodiacRoles.Operation.Call,
            MANAGER_ROLE,
            false
        );
        vm.stopPrank();

        // SparkRewards claim revoked
        vm.startPrank(karpatkey);
        _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
        roles.execTransactionWithRole(
            SPARK_REWARDS,
            0,
            abi.encodeWithSelector(
                SPARK_CLAIM_SELECTOR, uint256(0), address(endowmentSafe), SPK, uint256(0), bytes32(0), new bytes32[](0)
            ),
            IZodiacRoles.Operation.Call,
            MANAGER_ROLE,
            false
        );
        vm.stopPrank();

        // --- New permissions should WORK ---

        // GHO approve to fGHO should be allowed
        vm.startPrank(karpatkey);
        _safeExecuteTransaction(
            GHO,
            abi.encodeWithSelector(APPROVE_SELECTOR, F_GHO, uint256(1e18))
        );
        vm.stopPrank();

        // GHO approve to GPv2VaultRelayer should be allowed
        vm.startPrank(karpatkey);
        _safeExecuteTransaction(
            GHO,
            abi.encodeWithSelector(APPROVE_SELECTOR, GPV2_VAULT_RELAYER, uint256(1e18))
        );
        vm.stopPrank();

        // GHO approve to a random address should be BLOCKED (OR group fails -> OrViolation)
        vm.startPrank(karpatkey);
        _expectConditionViolation(IZodiacRoles.Status.OrViolation);
        roles.execTransactionWithRole(
            GHO,
            0,
            abi.encodeWithSelector(APPROVE_SELECTOR, address(0xdead), uint256(1e18)),
            IZodiacRoles.Operation.Call,
            MANAGER_ROLE,
            false
        );
        vm.stopPrank();

        // FLUID approve to GPv2VaultRelayer should be allowed
        vm.startPrank(karpatkey);
        _safeExecuteTransaction(
            FLUID,
            abi.encodeWithSelector(APPROVE_SELECTOR, GPV2_VAULT_RELAYER, uint256(1e18))
        );
        vm.stopPrank();

        // FLUID approve to random address should be BLOCKED
        vm.startPrank(karpatkey);
        _expectConditionViolation(IZodiacRoles.Status.ParameterNotAllowed);
        roles.execTransactionWithRole(
            FLUID,
            0,
            abi.encodeWithSelector(APPROVE_SELECTOR, address(0xdead), uint256(1e18)),
            IZodiacRoles.Operation.Call,
            MANAGER_ROLE,
            false
        );
        vm.stopPrank();

        // RocketPool v4 deposit should be allowed (with ETH)
        vm.startPrank(karpatkey);
        _safeExecuteTransaction(
            ROCKET_POOL_DEPOSIT_V4,
            abi.encodeWithSelector(DEPOSIT_SELECTOR)
        );
        vm.stopPrank();

        // FluidMerkle claim with recipient=Safe should be allowed
        vm.startPrank(karpatkey);
        _safeExecuteTransaction(
            FLUID_MERKLE,
            abi.encodeWithSelector(
                FLUID_CLAIM_SELECTOR,
                address(endowmentSafe), // recipient must be the Safe
                uint256(0),
                uint8(0),
                bytes32(0),
                uint256(0),
                new bytes32[](0),
                ""
            )
        );
        vm.stopPrank();

        // FluidMerkle claim with recipient=attacker should be BLOCKED
        vm.startPrank(karpatkey);
        _expectConditionViolation(IZodiacRoles.Status.ParameterNotAllowed);
        roles.execTransactionWithRole(
            FLUID_MERKLE,
            0,
            abi.encodeWithSelector(
                FLUID_CLAIM_SELECTOR,
                address(0xdead), // wrong recipient
                uint256(0),
                uint8(0),
                bytes32(0),
                uint256(0),
                new bytes32[](0),
                ""
            ),
            IZodiacRoles.Operation.Call,
            MANAGER_ROLE,
            false
        );
        vm.stopPrank();
    }

    // ─── Calldata Generation ─────────────────────────────────────────────

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
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        signatures = new string[](1);

        bytes memory multiSendData = abi.encodeWithSelector(
            IMultiSend.multiSend.selector,
            _buildMultiSendTransactions()
        );

        (targets[0], calldatas[0]) = _buildSafeExecDelegateCalldata(
            address(endowmentSafe),
            MULTISEND,
            multiSendData,
            address(timelock)
        );
        values[0] = 0;
        signatures[0] = "";
        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    // ─── MultiSend Packing ───────────────────────────────────────────────

    function _buildMultiSendTransactions() internal view returns (bytes memory) {
        return bytes.concat(
            _buildRevocationTransactions(),
            _buildAnnotationRemoval(),
            _buildScopingTransactions(),
            _buildAnnotationAddition(),
            _buildFinalUnwrapper()
        );
    }

    // ─── TX 1-7: Module removal, unwrapper setup, and revocations ────────

    function _buildRevocationTransactions() internal view returns (bytes memory) {
        return bytes.concat(
            // TX 1: Safe.disableModule -- remove Roles V1
            _packTx(
                address(endowmentSafe),
                abi.encodeWithSignature("disableModule(address,address)", PREV_MODULE, ROLES_V1)
            ),
            // TX 2: roles.setTransactionUnwrapper -- configure multiSend adapter
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.setTransactionUnwrapper.selector,
                    MULTISEND_HANDLER,
                    MULTISEND_SELECTOR,
                    MULTISEND_ADAPTER
                )
            ),
            // TX 3: roles.revokeTarget -- RocketPool Deposit V3
            _packTx(
                address(roles),
                abi.encodeWithSelector(IRolesModifier.revokeTarget.selector, MANAGER_ROLE, ROCKET_POOL_DEPOSIT_V3)
            ),
            // TX 4: roles.revokeFunction -- RocketPool Deposit V3 deposit()
            _packTx(
                address(roles),
                abi.encodeWithSelector(IRolesModifier.revokeFunction.selector, MANAGER_ROLE, ROCKET_POOL_DEPOSIT_V3, DEPOSIT_SELECTOR)
            ),
            // TX 5: roles.revokeFunction -- SPK transfer()
            _packTx(
                address(roles),
                abi.encodeWithSelector(IRolesModifier.revokeFunction.selector, MANAGER_ROLE, SPK, TRANSFER_SELECTOR)
            ),
            // TX 6: roles.revokeTarget -- SparkRewards
            _packTx(
                address(roles),
                abi.encodeWithSelector(IRolesModifier.revokeTarget.selector, MANAGER_ROLE, SPARK_REWARDS)
            ),
            // TX 7: roles.revokeFunction -- SparkRewards claim()
            _packTx(
                address(roles),
                abi.encodeWithSelector(IRolesModifier.revokeFunction.selector, MANAGER_ROLE, SPARK_REWARDS, SPARK_CLAIM_SELECTOR)
            )
        );
    }

    // ─── TX 8: Remove old annotations ────────────────────────────────────

    function _buildAnnotationRemoval() internal view returns (bytes memory) {
        // See annotationRemoval.json — removes old annotation URIs for:
        //   - spark/deposit?targets=SKY_USDS
        //   - cowswap/swap with old sell/buy token lists (without GHO/FLUID)
        string memory jsonPayload = vm.readFile("src/ens/proposals/ep-kpk-update-8/annotationRemoval.json");

        return _packTx(
            ANNOTATION_REGISTRY,
            abi.encodeWithSelector(
                IAnnotationRegistry.post.selector,
                jsonPayload,
                "ROLES_PERMISSION_ANNOTATION"
            )
        );
    }

    // ─── TX 9-16: Scoping transactions ───────────────────────────────────

    function _buildScopingTransactions() internal view returns (bytes memory) {
        return bytes.concat(
            // TX 9: CowSwap signOrder scoping
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE, COWSWAP_ORDER_SIGNER, SIGN_ORDER_SELECTOR,
                    _buildCowSwapSignOrderConditions(), EXEC_DELEGATE_CALL
                )
            ),
            // TX 10: GHO approve scoping
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE, GHO, APPROVE_SELECTOR,
                    _buildGhoApproveConditions(), EXEC_NONE
                )
            ),
            // TX 11: scopeTarget FLUID
            _packTx(
                address(roles),
                abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, FLUID)
            ),
            // TX 12: FLUID approve scoping
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE, FLUID, APPROVE_SELECTOR,
                    _buildFluidApproveConditions(), EXEC_NONE
                )
            ),
            // TX 13: scopeTarget RocketPool Deposit V4
            _packTx(
                address(roles),
                abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, ROCKET_POOL_DEPOSIT_V4)
            ),
            // TX 14: allowFunction RocketPool Deposit V4 deposit() with ETH
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector, MANAGER_ROLE, ROCKET_POOL_DEPOSIT_V4, DEPOSIT_SELECTOR, EXEC_SEND
                )
            ),
            // TX 15: scopeTarget FluidMerkle
            _packTx(
                address(roles),
                abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, FLUID_MERKLE)
            ),
            // TX 16: FluidMerkle claim scoping
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE, FLUID_MERKLE, FLUID_CLAIM_SELECTOR,
                    _buildFluidMerkleClaimConditions(), EXEC_NONE
                )
            )
        );
    }

    // ─── TX 17: Add new annotations ──────────────────────────────────────

    function _buildAnnotationAddition() internal view returns (bytes memory) {
        // See annotationAddition.json — adds new annotation URIs for:
        //   - cowswap/swap with updated sell/buy token lists (GHO + FLUID added)
        //   - spark/deposit?targets=SKY_sUSDS
        string memory jsonPayload = vm.readFile("src/ens/proposals/ep-kpk-update-8/annotationAddition.json");

        return _packTx(
            ANNOTATION_REGISTRY,
            abi.encodeWithSelector(
                IAnnotationRegistry.post.selector,
                jsonPayload,
                "ROLES_PERMISSION_ANNOTATION"
            )
        );
    }

    // ─── TX 18: Re-apply unwrapper ───────────────────────────────────────

    function _buildFinalUnwrapper() internal view returns (bytes memory) {
        // TX 18: roles.setTransactionUnwrapper -- same as TX 2
        return _packTx(
            address(roles),
            abi.encodeWithSelector(
                IRolesModifier.setTransactionUnwrapper.selector,
                MULTISEND_HANDLER,
                MULTISEND_SELECTOR,
                MULTISEND_ADAPTER
            )
        );
    }

    // ─── Condition Builders ──────────────────────────────────────────────

    /// @dev TX 9: CowSwap signOrder -- 54 conditions total
    ///      Struct: (sellToken, buyToken, receiver, sellAmount, buyAmount, validTo, appData,
    ///               feeAmount, kind, partiallyFillable, sellTokenBalance, buyTokenBalance)
    function _buildCowSwapSignOrderConditions() internal pure returns (ConditionFlat[] memory) {
        address[] memory sellTokens = _cowSwapSellTokens();
        address[] memory buyTokens = _cowSwapBuyTokens();

        // Total: 1 root + 1 tuple + 2 OR groups + 1 avatar + 9 pass + 25 sell + 15 buy = 54
        uint256 numConditions = 14 + sellTokens.length + buyTokens.length;
        ConditionFlat[] memory c = new ConditionFlat[](numConditions);

        uint256 i = 0;

        // [0] Root: Calldata Matches
        c[i++] = ConditionFlat(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        // [1] Param 0 (order struct): Tuple Matches
        c[i++] = ConditionFlat(0, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        // [2] sellToken: OR group (children will be sell tokens)
        c[i++] = ConditionFlat(1, PARAM_TYPE_NONE, OP_OR, "");
        // [3] buyToken: OR group (children will be buy tokens)
        c[i++] = ConditionFlat(1, PARAM_TYPE_NONE, OP_OR, "");
        // [4] receiver: must equal Avatar (the Safe)
        c[i++] = ConditionFlat(1, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        // [5-13] sellAmount, buyAmount, validTo, appData, feeAmount, kind,
        //        partiallyFillable, sellTokenBalance, buyTokenBalance: Pass
        for (uint256 j = 0; j < 9; j++) {
            c[i++] = ConditionFlat(1, PARAM_TYPE_STATIC, OP_PASS, "");
        }

        // [14-38] Sell token whitelist (parent=2, the sellToken OR group)
        for (uint256 j = 0; j < sellTokens.length; j++) {
            c[i++] = ConditionFlat(2, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(sellTokens[j]));
        }

        // [39-53] Buy token whitelist (parent=3, the buyToken OR group)
        for (uint256 j = 0; j < buyTokens.length; j++) {
            c[i++] = ConditionFlat(3, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(buyTokens[j]));
        }

        return c;
    }

    /// @dev TX 10: GHO approve() -- spender must be fGHO OR GPv2VaultRelayer
    function _buildGhoApproveConditions() internal pure returns (ConditionFlat[] memory) {
        ConditionFlat[] memory c = new ConditionFlat[](4);
        // [0] Root: Calldata Matches
        c[0] = ConditionFlat(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        // [1] Param 0 (spender): OR group
        c[1] = ConditionFlat(0, PARAM_TYPE_NONE, OP_OR, "");
        // [2] spender == fGHO
        c[2] = ConditionFlat(1, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(F_GHO));
        // [3] spender == GPv2VaultRelayer
        c[3] = ConditionFlat(1, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(GPV2_VAULT_RELAYER));
        return c;
    }

    /// @dev TX 12: FLUID approve() -- spender must be GPv2VaultRelayer only
    function _buildFluidApproveConditions() internal pure returns (ConditionFlat[] memory) {
        ConditionFlat[] memory c = new ConditionFlat[](2);
        // [0] Root: Calldata Matches
        c[0] = ConditionFlat(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        // [1] Param 0 (spender): must equal GPv2VaultRelayer
        c[1] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(GPV2_VAULT_RELAYER));
        return c;
    }

    /// @dev TX 16: FluidMerkle claim() -- recipient (param 0) must equal the Safe (EqualToAvatar)
    function _buildFluidMerkleClaimConditions() internal pure returns (ConditionFlat[] memory) {
        ConditionFlat[] memory c = new ConditionFlat[](2);
        // [0] Root: Calldata Matches
        c[0] = ConditionFlat(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        // [1] Param 0 (recipient): must equal Avatar (the Safe)
        c[1] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        return c;
    }

    // ─── Token List Helpers ──────────────────────────────────────────────

    /// @dev 25 sell tokens, sorted by address ascending (matching on-chain condition order)
    function _cowSwapSellTokens() internal pure returns (address[] memory) {
        address[] memory t = new address[](25);
        t[0]  = GHO;      // 0x40D16FC0...
        t[1]  = SWISE;    // 0x48C33997...
        t[2]  = CVX;      // 0x4e3FBD56...
        t[3]  = MORPHO;   // 0x58D97B57...
        t[4]  = LDO;      // 0x5A98FcBE...
        t[5]  = DAI;      // 0x6B175474...
        t[6]  = FLUID;    // 0x6f40d4A6...
        t[7]  = WSTETH;   // 0x7f39C581...
        t[8]  = LUSD;     // 0x856c4Efb...
        t[9]  = USDC;     // 0xA0b86991...
        t[10] = USR;      // 0xA35b1B31...
        t[11] = SDAI;     // 0xa3931d71...
        t[12] = RETH;     // 0xae78736C...
        t[13] = STETH;    // 0xae7ab965...
        t[14] = BAL;      // 0xba100000...
        t[15] = COMP;     // 0xc00e94Cb...
        t[16] = WETH;     // 0xC02aaA39...
        t[17] = AURA;     // 0xC0c293ce...
        t[18] = SPK;      // 0xc20059e0...
        t[19] = RPL;      // 0xD3352606...
        t[20] = CRV;      // 0xD533a949...
        t[21] = USDT;     // 0xdAC17F95...
        t[22] = USDS;     // 0xdC035D45...
        t[23] = SUSDE;    // 0xE95A203B...
        t[24] = SFRXETH;  // 0xf1C9acDc...
        return t;
    }

    /// @dev 15 buy tokens, sorted by address ascending (matching on-chain condition order)
    function _cowSwapBuyTokens() internal pure returns (address[] memory) {
        address[] memory t = new address[](15);
        t[0]  = GHO;        // 0x40D16FC0...
        t[1]  = DAI;        // 0x6B175474...
        t[2]  = WSTETH;     // 0x7f39C581...
        t[3]  = LUSD;       // 0x856c4Efb...
        t[4]  = USDC;       // 0xA0b86991...
        t[5]  = USR;        // 0xA35b1B31...
        t[6]  = SDAI;       // 0xa3931d71...
        t[7]  = RETH;       // 0xae78736C...
        t[8]  = STETH;      // 0xae7ab965...
        t[9]  = WETH;       // 0xC02aaA39...
        t[10] = USDT;       // 0xdAC17F95...
        t[11] = USDS;       // 0xdC035D45...
        t[12] = SUSDE;      // 0xE95A203B...
        t[13] = NATIVE_ETH; // 0xEeeeeeEe...
        t[14] = SFRXETH;    // 0xf1C9acDc...
        return t;
    }
}
