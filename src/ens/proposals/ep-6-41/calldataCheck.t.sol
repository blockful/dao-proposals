// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { ENS_Governance } from "@ens/ens.t.sol";
import { SafeHelper } from "@ens/helpers/SafeHelper.sol";
import { ZodiacRolesHelper } from "@ens/helpers/ZodiacRolesHelper.sol";
import { IZodiacRoles } from "@ens/interfaces/IZodiacRoles.sol";
import { IRolesModifier, ConditionFlat } from "@ens/interfaces/IRolesModifier.sol";
import { IMultiSend } from "@ens/interfaces/IMultiSend.sol";
import { ICowSwapOrderSigner } from "@ens/interfaces/ICowSwapOrderSigner.sol";
import { IAnnotationRegistry } from "@ens/interfaces/IAnnotationRegistry.sol";
import { IMetaMorphoV1 } from "@ens/interfaces/IMetaMorphoV1.sol";
import { IERC20 } from "@forge-std/src/interfaces/IERC20.sol";

// ─── Minimal interfaces for new targets scoped by this proposal ─────────

interface IStaderUserWithdrawalManager {
    function requestWithdraw(uint256 _ethXAmount, address _owner, string calldata _referralId) external;
}

interface IWeETH {
    function wrap(uint256 _eETHAmount) external returns (uint256);
    function unwrap(uint256 _weETHAmount) external returns (uint256);
}

interface IEtherFiLiquidityPool {
    function requestWithdraw(address recipient, uint256 amount) external returns (uint256);
}

interface IEtherFiWithdrawRequestNFT {
    function claimWithdraw(uint256 tokenId) external;
}

interface IEtherFiRedemptionManager {
    struct PermitInput {
        uint256 value;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function redeemEEth(uint256 eEthAmount, address receiver, address owner) external;
    function redeemEEthWithPermit(
        uint256 eEthAmount,
        address receiver,
        PermitInput calldata permit,
        address owner
    )
        external;
    function redeemWeEth(uint256 weEthAmount, address receiver, address owner) external;
    function redeemWeEthWithPermit(
        uint256 weEthAmount,
        address receiver,
        PermitInput calldata permit,
        address owner
    )
        external;
}

interface IEtherFiDepositAdapter {
    struct PermitInput {
        uint256 value;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function depositETHForWeETH(address referral) external payable returns (uint256);
    function depositWETHForWeETH(uint256 amount, address referral) external returns (uint256);
    function depositStETHForWeETHWithPermit(
        uint256 amount,
        address referral,
        PermitInput calldata permit
    )
        external
        returns (uint256);
    function depositWstETHForWeETHWithPermit(
        uint256 amount,
        address referral,
        PermitInput calldata permit
    )
        external
        returns (uint256);
}

interface IEtherFiWeEthWithdrawAdapter {
    function requestWithdraw(uint256 weEthAmount, address recipient) external returns (uint256);
}

interface IEtherFiLRT2Claim {
    function claim(
        address account,
        uint256 cumulativeAmount,
        bytes32 expectedMerkleRoot,
        bytes32[] calldata merkleProof
    )
        external;
}

/**
 * @title EP 6.41 — Endowment permissions to karpatkey — Update #9
 * @notice Live calldata review for
 *     https://www.tally.xyz/gov/ens/proposal/39893466662181856279242827854933926689925858494049650894234231038376231891860
 *
 * Summary of operations (40 transactions packed into a MultiSend delegatecall on
 * the Endowment Safe):
 *
 *   TX  0: annotationRegistry.post        -- remove old CowSwap swap annotation
 *   TX  1: scopeFunction CowSwapOrderSigner.signOrder  -- add eETH + weETH
 *   TX  2: scopeFunction wstETH.approve        -- extend spender list (+DepositAdapter)
 *   TX  3: scopeFunction Stader.UserWithdrawalManager.requestWithdraw
 *   TX  4: scopeFunction stETH.approve         -- extend spender list (+DepositAdapter)
 *   TX  5: scopeFunction WETH.approve          -- extend spender list (+DepositAdapter)
 *   TX  6: scopeFunction USDT.approve          -- extend spender list (+MorphoVaults)
 *   TX  7: scopeTarget   eETH
 *   TX  8: scopeFunction eETH.approve
 *   TX  9: scopeTarget   weETH
 *   TX 10: scopeFunction weETH.approve
 *   TX 11: allowFunction weETH.wrap
 *   TX 12: allowFunction weETH.unwrap
 *   TX 13: scopeTarget   Morpho kpk USDT Prime v1
 *   TX 14: scopeFunction Morpho v1.deposit (receiver=Avatar)
 *   TX 15: scopeFunction Morpho v1.withdraw (receiver=owner=Avatar)
 *   TX 16: scopeFunction Morpho v1.redeem   (receiver=owner=Avatar)
 *   TX 17: scopeTarget   Morpho kpk USDT Prime v2
 *   TX 18: scopeFunction Morpho v2.deposit (receiver=Avatar)
 *   TX 19: scopeFunction Morpho v2.withdraw (receiver=owner=Avatar)
 *   TX 20: scopeFunction Morpho v2.redeem   (receiver=owner=Avatar)
 *   TX 21: scopeTarget   Ether.fi DepositAdapter
 *   TX 22: allowFunction DepositAdapter.depositETHForWeETH (options=1 send)
 *   TX 23: scopeFunction DepositAdapter.depositWETHForWeETH (referral=Avatar)
 *   TX 24: scopeFunction DepositAdapter.depositStETHForWeETHWithPermit (referral=Avatar)
 *   TX 25: scopeFunction DepositAdapter.depositWstETHForWeETHWithPermit (referral=Avatar)
 *   TX 26: scopeTarget   Ether.fi LiquidityPool
 *   TX 27: scopeFunction LiquidityPool.requestWithdraw (recipient=Avatar)
 *   TX 28: scopeTarget   Ether.fi WeETHWithdrawAdapter
 *   TX 29: scopeFunction WeETHWithdrawAdapter.requestWithdraw (recipient=Avatar)
 *   TX 30: scopeTarget   Ether.fi WithdrawRequestNFT
 *   TX 31: allowFunction WithdrawRequestNFT.claimWithdraw
 *   TX 32: scopeTarget   Ether.fi RedemptionManager
 *   TX 33: scopeFunction RedemptionManager.redeemEEth (receiver=Avatar, owner=ETH_MAGIC)
 *   TX 34: scopeFunction RedemptionManager.redeemEEthWithPermit
 *   TX 35: scopeFunction RedemptionManager.redeemWeEth
 *   TX 36: scopeFunction RedemptionManager.redeemWeEthWithPermit
 *   TX 37: scopeTarget   Ether.fi LRT2 Claim (CumulativeMerkleDrop)
 *   TX 38: scopeFunction LRT2Claim.claim (account=Avatar)
 *   TX 39: annotationRegistry.post        -- add new CowSwap + Morpho annotations
 */
contract Proposal_ENS_EP_KPK_Update_9_Test is ENS_Governance, SafeHelper, ZodiacRolesHelper {
    // ─── Infrastructure
    // ───────────────────────────────────────

    address private constant MULTISEND = 0x40A2aCCbd92BCA938b02010E17A5b8929b49130D;
    address private constant ANNOTATION_REGISTRY = 0x000000000000cd17345801aa8147b8D3950260FF;

    // ─── CowSwap
    // ──────────────────────────────────────────────

    address private constant COWSWAP_ORDER_SIGNER = 0x23dA9AdE38E4477b23770DeD512fD37b12381FAB;
    address private constant GPV2_VAULT_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;

    // ─── Staking & Restaking Protocols (NEW) ──────────────────

    // Stader
    address private constant STADER_USER_WITHDRAWAL_MANAGER = 0x9F0491B32DBce587c50c4C43AB303b06478193A7;

    // Ether.fi
    address private constant EETH = 0x35fA164735182de50811E8e2E824cFb9B6118ac2;
    address private constant WEETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address private constant ETHERFI_LIQUIDITY_POOL = 0x308861A430be4cce5502d0A12724771Fc6DaF216;
    address private constant ETHERFI_WITHDRAW_REQUEST_NFT = 0x7d5706f6ef3F89B3951E23e557CDFBC3239D4E2c;
    address private constant ETHERFI_REDEMPTION_MANAGER = 0xDadEf1fFBFeaAB4f68A9fD181395F68b4e4E7Ae0;
    address private constant ETHERFI_DEPOSIT_ADAPTER = 0xcfC6d9Bd7411962Bfe7145451A7EF71A24b6A7A2;
    address private constant ETHERFI_WEETH_WITHDRAW_ADAPTER = 0xFbfe6b9cEe0E555Bad7e2E7309EFFC75200cBE38;
    address private constant ETHERFI_LRT2_CLAIM = 0x6Db24Ee656843E3fE03eb8762a54D86186bA6B64;

    // ─── Morpho Vaults (NEW)
    // ──────────────────────────────────

    address private constant KPK_USDT_PRIME_V1 = 0xdaD4e51d64c3B65A9d27aD9F3185B09449712065;
    address private constant KPK_USDT_PRIME_V2 = 0x870F0BF29A25A40E7CC087cD5C53e70C11F2C8A8;

    // ─── Token Addresses
    // ──────────────────────────────────────

    address private constant GHO = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;
    address private constant SWISE = 0x48C3399719B582dD63eB5AADf12A40B4C3f52FA2;
    address private constant CVX = 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B;
    address private constant MORPHO_TOKEN = 0x58D97B57BB95320F9a05dC918Aef65434969c2B2;
    address private constant LDO = 0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32;
    address private constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address private constant FLUID = 0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb;
    address private constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address private constant OETH = 0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3;
    address private constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private constant ETHX = 0xA35b1B31Ce002FBF2058D22F30f95D405200A15b;
    address private constant SUSDS = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    address private constant RETH = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address private constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address private constant BAL = 0xba100000625a3754423978a60c9317c58a424e3D;
    address private constant COMP = 0xc00e94Cb662C3520282E6f5717214004A7f26888;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant AURA = 0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF;
    address private constant SPK = 0xc20059e0317DE91738d13af027DfC4a50781b066;
    address private constant RPL = 0xD33526068D116cE69F19A9ee46F0bd304F21A51f;
    address private constant CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;
    address private constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address private constant USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
    address private constant ANKRETH = 0xE95A203B1a91a908F9B9CE46459d101078c2c3cb;
    address private constant OSETH = 0xf1C9acDc66974dFB6dEcB12aA385b9cD01190E38;

    address private constant NATIVE_ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // ─── Additional spenders seen in approve() scoping ────────

    // wstETH approve spenders
    address private constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address private constant UNISWAP_V3_ROUTER = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address private constant AAVE_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address private constant BALANCER_V2_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address private constant LIDO_WITHDRAWAL_QUEUE = 0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1;

    // ─── Fork / Metadata
    // ──────────────────────────────────────

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 24_988_364, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0x1D5460F896521aD685Ea4c3F2c679Ec0b6806359; // coltron.eth (expected karpatkey sponsor)
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-6-41";
    }

    // ─── Before: verify new targets are NOT yet permitted ─────

    function _beforeProposal() public override {
        // Stader UserWithdrawalManager is already scoped as a target; only requestWithdraw
        // is being newly permissioned. Expect FunctionNotAllowed rather than TargetAddressNotAllowed.
        _assertFunctionNotAllowed(
            STADER_USER_WITHDRAWAL_MANAGER,
            abi.encodeWithSelector(
                IStaderUserWithdrawalManager.requestWithdraw.selector, uint256(1), address(endowmentSafe), ""
            )
        );
        _assertTargetNotAllowed(
            EETH, abi.encodeWithSelector(IERC20.approve.selector, ETHERFI_LIQUIDITY_POOL, uint256(1))
        );
        _assertTargetNotAllowed(WEETH, abi.encodeWithSelector(IWeETH.wrap.selector, uint256(1)));
        _assertTargetNotAllowed(
            KPK_USDT_PRIME_V1,
            abi.encodeWithSelector(IMetaMorphoV1.deposit.selector, uint256(1), address(endowmentSafe))
        );
        _assertTargetNotAllowed(
            KPK_USDT_PRIME_V2,
            abi.encodeWithSelector(IMetaMorphoV1.deposit.selector, uint256(1), address(endowmentSafe))
        );
        _assertTargetNotAllowed(
            ETHERFI_LIQUIDITY_POOL,
            abi.encodeWithSelector(IEtherFiLiquidityPool.requestWithdraw.selector, address(endowmentSafe), uint256(1))
        );
        _assertTargetNotAllowed(
            ETHERFI_WITHDRAW_REQUEST_NFT,
            abi.encodeWithSelector(IEtherFiWithdrawRequestNFT.claimWithdraw.selector, uint256(1))
        );
        _assertTargetNotAllowed(
            ETHERFI_REDEMPTION_MANAGER,
            abi.encodeWithSelector(
                IEtherFiRedemptionManager.redeemEEth.selector, uint256(1), address(endowmentSafe), NATIVE_ETH
            )
        );
        _assertTargetNotAllowed(
            ETHERFI_WEETH_WITHDRAW_ADAPTER,
            abi.encodeWithSelector(
                IEtherFiWeEthWithdrawAdapter.requestWithdraw.selector, uint256(1), address(endowmentSafe)
            )
        );
        _assertTargetNotAllowed(
            ETHERFI_DEPOSIT_ADAPTER,
            abi.encodeWithSelector(IEtherFiDepositAdapter.depositETHForWeETH.selector, address(endowmentSafe))
        );
        _assertTargetNotAllowed(
            ETHERFI_LRT2_CLAIM,
            abi.encodeWithSelector(
                IEtherFiLRT2Claim.claim.selector, address(endowmentSafe), uint256(0), bytes32(0), new bytes32[](0)
            )
        );

        // Sanity: existing wstETH.approve to GPv2VaultRelayer already allowed
        vm.startPrank(karpatkey);
        _safeExecuteTransaction(
            WSTETH, abi.encodeWithSelector(IERC20.approve.selector, GPV2_VAULT_RELAYER, uint256(1e18))
        );
        vm.stopPrank();

        // CowSwap signOrder: old scope exists (WSTETH/WETH works), new tokens not yet allowed
        ICowSwapOrderSigner.Data memory preOrder = _buildCowSwapOrder(WSTETH, WETH, address(endowmentSafe));
        vm.startPrank(karpatkey);
        uint256 snap = vm.snapshot();
        roles.execTransactionWithRole(
            COWSWAP_ORDER_SIGNER,
            0,
            abi.encodeWithSelector(ICowSwapOrderSigner.signOrder.selector, preOrder, uint32(0), uint256(0)),
            IZodiacRoles.Operation.DelegateCall,
            MANAGER_ROLE,
            false
        );
        vm.revertTo(snap);
        vm.stopPrank();
        _assertCowSwapBlocked(_buildCowSwapOrder(EETH, WETH, address(endowmentSafe)), IZodiacRoles.Status.OrViolation);
        _assertCowSwapBlocked(
            _buildCowSwapOrder(WSTETH, WEETH, address(endowmentSafe)), IZodiacRoles.Status.OrViolation
        );
    }

    function _assertTargetNotAllowed(address target, bytes memory data) internal {
        vm.startPrank(karpatkey);
        _expectConditionViolation(IZodiacRoles.Status.TargetAddressNotAllowed);
        roles.execTransactionWithRole(target, 0, data, IZodiacRoles.Operation.Call, MANAGER_ROLE, false);
        vm.stopPrank();
    }

    function _assertFunctionNotAllowed(address target, bytes memory data) internal {
        // Target is already scoped but this specific function is not yet permissioned.
        // The revert includes the function selector in the `info` field; we only check Status.
        vm.startPrank(karpatkey);
        bytes4 sel = bytes4(data);
        vm.expectRevert(
            abi.encodeWithSelector(
                IZodiacRoles.ConditionViolation.selector, IZodiacRoles.Status.FunctionNotAllowed, bytes32(sel)
            )
        );
        roles.execTransactionWithRole(target, 0, data, IZodiacRoles.Operation.Call, MANAGER_ROLE, false);
        vm.stopPrank();
    }

    function _assertBlocked(address target, bytes memory data, IZodiacRoles.Status status) internal {
        vm.startPrank(karpatkey);
        _expectConditionViolation(status);
        roles.execTransactionWithRole(target, 0, data, IZodiacRoles.Operation.Call, MANAGER_ROLE, false);
        vm.stopPrank();
    }

    function _assertAllowed(address target, bytes memory data) internal {
        vm.startPrank(karpatkey);
        _safeExecuteTransaction(target, data);
        vm.stopPrank();
    }

    // ─── After: verify new permissions work + negative tests ──

    function _afterExecution() public override {
        _assertStaderPermissions();
        _assertEEthAndWeEthPermissions();
        _assertMorphoPermissions();
        _assertEtherFiLPAndNftPermissions();
        _assertEtherFiRedemptionPermissions();
        _assertDepositETHForWeETHPermissions();
        _assertEtherFiDepositAdapterPermissions();
        _assertEtherFiLRT2Permissions();
        _assertCowSwapPermissions();
        _assertTokenApproveRescopes();
    }

    function _assertStaderPermissions() internal {
        // Stader requestWithdraw with recipient=Safe WORKS
        _assertAllowed(
            STADER_USER_WITHDRAWAL_MANAGER,
            abi.encodeWithSelector(
                IStaderUserWithdrawalManager.requestWithdraw.selector, uint256(1), address(endowmentSafe), ""
            )
        );
        // Stader requestWithdraw with wrong recipient BLOCKED
        _assertBlocked(
            STADER_USER_WITHDRAWAL_MANAGER,
            abi.encodeWithSelector(
                IStaderUserWithdrawalManager.requestWithdraw.selector, uint256(1), address(0xdead), ""
            ),
            IZodiacRoles.Status.ParameterNotAllowed
        );
    }

    function _assertEEthAndWeEthPermissions() internal {
        // eETH.approve to Ether.fi LP allowed
        _assertAllowed(EETH, abi.encodeWithSelector(IERC20.approve.selector, ETHERFI_LIQUIDITY_POOL, uint256(1e18)));
        // eETH.approve to random address BLOCKED (OR group fails)
        _assertBlocked(
            EETH,
            abi.encodeWithSelector(IERC20.approve.selector, address(0xdead), uint256(1e18)),
            IZodiacRoles.Status.OrViolation
        );
        // weETH.approve to GPv2VaultRelayer allowed
        _assertAllowed(WEETH, abi.encodeWithSelector(IERC20.approve.selector, GPV2_VAULT_RELAYER, uint256(1e18)));
        // weETH.approve to random address BLOCKED
        _assertBlocked(
            WEETH,
            abi.encodeWithSelector(IERC20.approve.selector, address(0xdead), uint256(1e18)),
            IZodiacRoles.Status.OrViolation
        );
        // weETH.wrap and unwrap allowed (allowFunction, no arg checks)
        _assertAllowed(WEETH, abi.encodeWithSelector(IWeETH.wrap.selector, uint256(1e18)));
        _assertAllowed(WEETH, abi.encodeWithSelector(IWeETH.unwrap.selector, uint256(1e18)));
    }

    function _assertMorphoPermissions() internal {
        _assertMorphoVaultPermissions(KPK_USDT_PRIME_V1);
        _assertMorphoVaultPermissions(KPK_USDT_PRIME_V2);
    }

    function _assertMorphoVaultPermissions(address vault) internal {
        // Negative tests first — no snapshot overhead
        _assertBlocked(
            vault,
            abi.encodeWithSelector(IMetaMorphoV1.deposit.selector, uint256(1e6), address(0xdead)),
            IZodiacRoles.Status.ParameterNotAllowed
        );
        // withdraw: bad receiver
        _assertBlocked(
            vault,
            abi.encodeWithSelector(
                IMetaMorphoV1.withdraw.selector, uint256(1), address(0xdead), address(endowmentSafe)
            ),
            IZodiacRoles.Status.ParameterNotAllowed
        );
        // withdraw: bad owner
        _assertBlocked(
            vault,
            abi.encodeWithSelector(
                IMetaMorphoV1.withdraw.selector, uint256(1), address(endowmentSafe), address(0xdead)
            ),
            IZodiacRoles.Status.ParameterNotAllowed
        );
        // redeem: bad receiver
        _assertBlocked(
            vault,
            abi.encodeWithSelector(IMetaMorphoV1.redeem.selector, uint256(1), address(0xdead), address(endowmentSafe)),
            IZodiacRoles.Status.ParameterNotAllowed
        );
        // redeem: bad owner
        _assertBlocked(
            vault,
            abi.encodeWithSelector(IMetaMorphoV1.redeem.selector, uint256(1), address(endowmentSafe), address(0xdead)),
            IZodiacRoles.Status.ParameterNotAllowed
        );
        // Positive tests (use snapshot/revert to avoid side effects)
        _assertAllowed(
            vault, abi.encodeWithSelector(IMetaMorphoV1.deposit.selector, uint256(1e6), address(endowmentSafe))
        );
        _assertAllowed(
            vault,
            abi.encodeWithSelector(
                IMetaMorphoV1.withdraw.selector, uint256(1), address(endowmentSafe), address(endowmentSafe)
            )
        );
        _assertAllowed(
            vault,
            abi.encodeWithSelector(
                IMetaMorphoV1.redeem.selector, uint256(1), address(endowmentSafe), address(endowmentSafe)
            )
        );
    }

    function _assertEtherFiLPAndNftPermissions() internal {
        _assertAllowed(
            ETHERFI_LIQUIDITY_POOL,
            abi.encodeWithSelector(IEtherFiLiquidityPool.requestWithdraw.selector, address(endowmentSafe), uint256(1))
        );
        _assertBlocked(
            ETHERFI_LIQUIDITY_POOL,
            abi.encodeWithSelector(IEtherFiLiquidityPool.requestWithdraw.selector, address(0xdead), uint256(1)),
            IZodiacRoles.Status.ParameterNotAllowed
        );
        _assertAllowed(
            ETHERFI_WITHDRAW_REQUEST_NFT,
            abi.encodeWithSelector(IEtherFiWithdrawRequestNFT.claimWithdraw.selector, uint256(1))
        );
    }

    function _assertEtherFiRedemptionPermissions() internal {
        IEtherFiRedemptionManager.PermitInput memory permit =
            IEtherFiRedemptionManager.PermitInput({ value: 0, deadline: 0, v: 0, r: bytes32(0), s: bytes32(0) });

        // redeemEEth
        _assertAllowed(
            ETHERFI_REDEMPTION_MANAGER,
            abi.encodeWithSelector(
                IEtherFiRedemptionManager.redeemEEth.selector, uint256(1), address(endowmentSafe), NATIVE_ETH
            )
        );
        _assertBlocked(
            ETHERFI_REDEMPTION_MANAGER,
            abi.encodeWithSelector(
                IEtherFiRedemptionManager.redeemEEth.selector, uint256(1), address(0xdead), NATIVE_ETH
            ),
            IZodiacRoles.Status.ParameterNotAllowed
        );
        // redeemEEth: bad owner (outputToken)
        _assertBlocked(
            ETHERFI_REDEMPTION_MANAGER,
            abi.encodeWithSelector(
                IEtherFiRedemptionManager.redeemEEth.selector, uint256(1), address(endowmentSafe), address(0xdead)
            ),
            IZodiacRoles.Status.ParameterNotAllowed
        );

        // redeemWeEth
        _assertAllowed(
            ETHERFI_REDEMPTION_MANAGER,
            abi.encodeWithSelector(
                IEtherFiRedemptionManager.redeemWeEth.selector, uint256(1), address(endowmentSafe), NATIVE_ETH
            )
        );
        _assertBlocked(
            ETHERFI_REDEMPTION_MANAGER,
            abi.encodeWithSelector(
                IEtherFiRedemptionManager.redeemWeEth.selector, uint256(1), address(0xdead), NATIVE_ETH
            ),
            IZodiacRoles.Status.ParameterNotAllowed
        );
        // redeemWeEth: bad owner (outputToken)
        _assertBlocked(
            ETHERFI_REDEMPTION_MANAGER,
            abi.encodeWithSelector(
                IEtherFiRedemptionManager.redeemWeEth.selector, uint256(1), address(endowmentSafe), address(0xdead)
            ),
            IZodiacRoles.Status.ParameterNotAllowed
        );

        // redeemEEthWithPermit
        _assertAllowed(
            ETHERFI_REDEMPTION_MANAGER,
            abi.encodeWithSelector(
                IEtherFiRedemptionManager.redeemEEthWithPermit.selector,
                uint256(1),
                address(endowmentSafe),
                permit,
                NATIVE_ETH
            )
        );
        _assertBlocked(
            ETHERFI_REDEMPTION_MANAGER,
            abi.encodeWithSelector(
                IEtherFiRedemptionManager.redeemEEthWithPermit.selector, uint256(1), address(0xdead), permit, NATIVE_ETH
            ),
            IZodiacRoles.Status.ParameterNotAllowed
        );
        // redeemEEthWithPermit: bad owner (outputToken)
        _assertBlocked(
            ETHERFI_REDEMPTION_MANAGER,
            abi.encodeWithSelector(
                IEtherFiRedemptionManager.redeemEEthWithPermit.selector,
                uint256(1),
                address(endowmentSafe),
                permit,
                address(0xdead)
            ),
            IZodiacRoles.Status.ParameterNotAllowed
        );

        // redeemWeEthWithPermit
        _assertAllowed(
            ETHERFI_REDEMPTION_MANAGER,
            abi.encodeWithSelector(
                IEtherFiRedemptionManager.redeemWeEthWithPermit.selector,
                uint256(1),
                address(endowmentSafe),
                permit,
                NATIVE_ETH
            )
        );
        _assertBlocked(
            ETHERFI_REDEMPTION_MANAGER,
            abi.encodeWithSelector(
                IEtherFiRedemptionManager.redeemWeEthWithPermit.selector,
                uint256(1),
                address(0xdead),
                permit,
                NATIVE_ETH
            ),
            IZodiacRoles.Status.ParameterNotAllowed
        );
        // redeemWeEthWithPermit: bad owner (outputToken)
        _assertBlocked(
            ETHERFI_REDEMPTION_MANAGER,
            abi.encodeWithSelector(
                IEtherFiRedemptionManager.redeemWeEthWithPermit.selector,
                uint256(1),
                address(endowmentSafe),
                permit,
                address(0xdead)
            ),
            IZodiacRoles.Status.ParameterNotAllowed
        );
    }

    function _assertDepositETHForWeETHPermissions() internal {
        vm.startPrank(karpatkey);
        uint256 snap = vm.snapshot();
        roles.execTransactionWithRole(
            ETHERFI_DEPOSIT_ADAPTER,
            0,
            abi.encodeWithSelector(IEtherFiDepositAdapter.depositETHForWeETH.selector, address(endowmentSafe)),
            IZodiacRoles.Operation.Call,
            MANAGER_ROLE,
            false
        );
        vm.revertTo(snap);
        vm.stopPrank();
    }

    function _assertEtherFiDepositAdapterPermissions() internal {
        IEtherFiDepositAdapter.PermitInput memory permit =
            IEtherFiDepositAdapter.PermitInput({ value: 0, deadline: 0, v: 0, r: bytes32(0), s: bytes32(0) });

        // depositWETHForWeETH
        _assertAllowed(
            ETHERFI_DEPOSIT_ADAPTER,
            abi.encodeWithSelector(
                IEtherFiDepositAdapter.depositWETHForWeETH.selector, uint256(1), address(endowmentSafe)
            )
        );
        _assertBlocked(
            ETHERFI_DEPOSIT_ADAPTER,
            abi.encodeWithSelector(IEtherFiDepositAdapter.depositWETHForWeETH.selector, uint256(1), address(0xdead)),
            IZodiacRoles.Status.ParameterNotAllowed
        );

        // depositStETHForWeETHWithPermit
        _assertAllowed(
            ETHERFI_DEPOSIT_ADAPTER,
            abi.encodeWithSelector(
                IEtherFiDepositAdapter.depositStETHForWeETHWithPermit.selector,
                uint256(1),
                address(endowmentSafe),
                permit
            )
        );
        _assertBlocked(
            ETHERFI_DEPOSIT_ADAPTER,
            abi.encodeWithSelector(
                IEtherFiDepositAdapter.depositStETHForWeETHWithPermit.selector, uint256(1), address(0xdead), permit
            ),
            IZodiacRoles.Status.ParameterNotAllowed
        );

        // depositWstETHForWeETHWithPermit
        _assertAllowed(
            ETHERFI_DEPOSIT_ADAPTER,
            abi.encodeWithSelector(
                IEtherFiDepositAdapter.depositWstETHForWeETHWithPermit.selector,
                uint256(1),
                address(endowmentSafe),
                permit
            )
        );
        _assertBlocked(
            ETHERFI_DEPOSIT_ADAPTER,
            abi.encodeWithSelector(
                IEtherFiDepositAdapter.depositWstETHForWeETHWithPermit.selector, uint256(1), address(0xdead), permit
            ),
            IZodiacRoles.Status.ParameterNotAllowed
        );

        // WeETHWithdrawAdapter.requestWithdraw
        _assertAllowed(
            ETHERFI_WEETH_WITHDRAW_ADAPTER,
            abi.encodeWithSelector(
                IEtherFiWeEthWithdrawAdapter.requestWithdraw.selector, uint256(1), address(endowmentSafe)
            )
        );
        _assertBlocked(
            ETHERFI_WEETH_WITHDRAW_ADAPTER,
            abi.encodeWithSelector(IEtherFiWeEthWithdrawAdapter.requestWithdraw.selector, uint256(1), address(0xdead)),
            IZodiacRoles.Status.ParameterNotAllowed
        );
    }

    function _assertEtherFiLRT2Permissions() internal {
        _assertAllowed(
            ETHERFI_LRT2_CLAIM,
            abi.encodeWithSelector(
                IEtherFiLRT2Claim.claim.selector, address(endowmentSafe), uint256(0), bytes32(0), new bytes32[](0)
            )
        );
        _assertBlocked(
            ETHERFI_LRT2_CLAIM,
            abi.encodeWithSelector(
                IEtherFiLRT2Claim.claim.selector, address(0xdead), uint256(0), bytes32(0), new bytes32[](0)
            ),
            IZodiacRoles.Status.ParameterNotAllowed
        );
    }

    function _assertCowSwapPermissions() internal {
        // Positive: valid sellToken + buyToken + receiver=Safe. The roles check passes; the
        // underlying delegatecall fails (signOrder touches GPv2Settlement state not present in
        // the test fork), but with shouldRevert=false, that returns false instead of reverting.
        // No revert = permission check passed.
        ICowSwapOrderSigner.Data memory goodOrder = _buildCowSwapOrder(EETH, WEETH, address(endowmentSafe));
        vm.startPrank(karpatkey);
        uint256 snapshot = vm.snapshot();
        roles.execTransactionWithRole(
            COWSWAP_ORDER_SIGNER,
            0,
            abi.encodeWithSelector(ICowSwapOrderSigner.signOrder.selector, goodOrder, uint32(0), uint256(0)),
            IZodiacRoles.Operation.DelegateCall,
            MANAGER_ROLE,
            false
        );
        vm.revertTo(snapshot);
        vm.stopPrank();

        // Negative: non-whitelisted sellToken (OR group → OrViolation)
        _assertCowSwapBlocked(
            _buildCowSwapOrder(address(0xdead), WETH, address(endowmentSafe)), IZodiacRoles.Status.OrViolation
        );
        // Negative: non-whitelisted buyToken (OR group → OrViolation)
        _assertCowSwapBlocked(
            _buildCowSwapOrder(WSTETH, address(0xdead), address(endowmentSafe)), IZodiacRoles.Status.OrViolation
        );
        // Negative: wrong receiver (EqualToAvatar → ParameterNotAllowed)
        _assertCowSwapBlocked(
            _buildCowSwapOrder(WSTETH, WETH, address(0xdead)), IZodiacRoles.Status.ParameterNotAllowed
        );
    }

    function _assertCowSwapBlocked(ICowSwapOrderSigner.Data memory order, IZodiacRoles.Status status) internal {
        vm.startPrank(karpatkey);
        _expectConditionViolation(status);
        roles.execTransactionWithRole(
            COWSWAP_ORDER_SIGNER,
            0,
            abi.encodeWithSelector(ICowSwapOrderSigner.signOrder.selector, order, uint32(0), uint256(0)),
            IZodiacRoles.Operation.DelegateCall,
            MANAGER_ROLE,
            false
        );
        vm.stopPrank();
    }

    function _assertTokenApproveRescopes() internal {
        // wstETH.approve: new spender DepositAdapter allowed
        _assertAllowed(WSTETH, abi.encodeWithSelector(IERC20.approve.selector, ETHERFI_DEPOSIT_ADAPTER, uint256(1e18)));
        _assertBlocked(
            WSTETH,
            abi.encodeWithSelector(IERC20.approve.selector, address(0xdead), uint256(1e18)),
            IZodiacRoles.Status.OrViolation
        );
        // stETH.approve: new spender DepositAdapter allowed
        _assertAllowed(STETH, abi.encodeWithSelector(IERC20.approve.selector, ETHERFI_DEPOSIT_ADAPTER, uint256(1e18)));
        _assertBlocked(
            STETH,
            abi.encodeWithSelector(IERC20.approve.selector, address(0xdead), uint256(1e18)),
            IZodiacRoles.Status.OrViolation
        );
        // WETH.approve: new spender DepositAdapter allowed
        _assertAllowed(WETH, abi.encodeWithSelector(IERC20.approve.selector, ETHERFI_DEPOSIT_ADAPTER, uint256(1e18)));
        _assertBlocked(
            WETH,
            abi.encodeWithSelector(IERC20.approve.selector, address(0xdead), uint256(1e18)),
            IZodiacRoles.Status.OrViolation
        );
        // USDT.approve: new spenders Morpho v1 and v2 allowed
        _assertAllowed(USDT, abi.encodeWithSelector(IERC20.approve.selector, KPK_USDT_PRIME_V1, uint256(1e6)));
        _assertAllowed(USDT, abi.encodeWithSelector(IERC20.approve.selector, KPK_USDT_PRIME_V2, uint256(1e6)));
        _assertBlocked(
            USDT,
            abi.encodeWithSelector(IERC20.approve.selector, address(0xdead), uint256(1e6)),
            IZodiacRoles.Status.OrViolation
        );
    }

    function _buildCowSwapOrder(
        address sell,
        address buy,
        address receiver
    )
        internal
        pure
        returns (ICowSwapOrderSigner.Data memory)
    {
        return ICowSwapOrderSigner.Data({
            sellToken: IERC20(sell),
            buyToken: IERC20(buy),
            receiver: receiver,
            sellAmount: 0,
            buyAmount: 0,
            validTo: 0,
            appData: bytes32(0),
            feeAmount: 0,
            kind: bytes32(0),
            partiallyFillable: false,
            sellTokenBalance: bytes32(0),
            buyTokenBalance: bytes32(0)
        });
    }

    // ─── Generated Calldata
    // ───────────────────────────────────

    function _generateCallData()
        public
        override
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory, string memory)
    {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        signatures = new string[](1);

        bytes memory multiSendData =
            abi.encodeWithSelector(IMultiSend.multiSend.selector, _buildMultiSendTransactions());

        (targets[0], calldatas[0]) =
            _buildSafeExecDelegateCalldata(address(endowmentSafe), MULTISEND, multiSendData, address(timelock));
        values[0] = 0;
        signatures[0] = "";
        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    // ─── MultiSend Bundle Assembly
    // ────────────────────────────

    function _buildMultiSendTransactions() internal view returns (bytes memory) {
        bytes memory part1 = bytes.concat(
            _buildAnnotationRemoval(),
            _buildCowSwapSignOrderScope(),
            _buildTokenApproveRescopes(),
            _buildEEthScope(),
            _buildWeEthScope()
        );
        bytes memory part2 = bytes.concat(
            _buildMorphoV1Scope(),
            _buildMorphoV2Scope(),
            _buildEtherFiDepositAdapterScope(),
            _buildEtherFiLiquidityPoolScope(),
            _buildEtherFiWeEthWithdrawAdapterScope()
        );
        bytes memory part3 = bytes.concat(
            _buildEtherFiWithdrawRequestNftScope(),
            _buildEtherFiRedemptionManagerScope(),
            _buildEtherFiLRT2ClaimScope(),
            _buildAnnotationAddition()
        );
        return bytes.concat(part1, part2, part3);
    }

    // TX 0
    function _buildAnnotationRemoval() internal view returns (bytes memory) {
        string memory payload = vm.readFile("src/ens/proposals/ep-6-41/annotationRemoval.json");
        return _packTx(
            ANNOTATION_REGISTRY,
            abi.encodeWithSelector(IAnnotationRegistry.post.selector, payload, "ROLES_PERMISSION_ANNOTATION")
        );
    }

    // TX 39
    function _buildAnnotationAddition() internal view returns (bytes memory) {
        string memory payload = vm.readFile("src/ens/proposals/ep-6-41/annotationAddition.json");
        return _packTx(
            ANNOTATION_REGISTRY,
            abi.encodeWithSelector(IAnnotationRegistry.post.selector, payload, "ROLES_PERMISSION_ANNOTATION")
        );
    }

    // TX 1: CowSwap signOrder (EXEC_DELEGATE_CALL)
    function _buildCowSwapSignOrderScope() internal pure returns (bytes memory) {
        return _packTx(
            address(roles),
            abi.encodeWithSelector(
                IRolesModifier.scopeFunction.selector,
                MANAGER_ROLE,
                COWSWAP_ORDER_SIGNER,
                ICowSwapOrderSigner.signOrder.selector,
                _buildCowSwapSignOrderConditions(),
                EXEC_DELEGATE_CALL
            )
        );
    }

    // TX 2-6: Token approve rescopes (updates existing approve spender lists)
    function _buildTokenApproveRescopes() internal pure returns (bytes memory) {
        return bytes.concat(
            // TX 2: wstETH.approve — 8 spenders
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    WSTETH,
                    IERC20.approve.selector,
                    _buildSingleParamOrConditions(_wstethApproveSpenders()),
                    EXEC_NONE
                )
            ),
            // TX 3: Stader UserWithdrawalManager.requestWithdraw(uint256 amount, address recipient, string referral)
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    STADER_USER_WITHDRAWAL_MANAGER,
                    IStaderUserWithdrawalManager.requestWithdraw.selector,
                    _buildPassAvatarConditions(),
                    EXEC_NONE
                )
            ),
            // TX 4: stETH.approve — 8 spenders
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    STETH,
                    IERC20.approve.selector,
                    _buildSingleParamOrConditions(_stethApproveSpenders()),
                    EXEC_NONE
                )
            ),
            // TX 5: WETH.approve — 14 spenders
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    WETH,
                    IERC20.approve.selector,
                    _buildSingleParamOrConditions(_wethApproveSpenders()),
                    EXEC_NONE
                )
            ),
            // TX 6: USDT.approve — 11 spenders
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    USDT,
                    IERC20.approve.selector,
                    _buildSingleParamOrConditions(_usdtApproveSpenders()),
                    EXEC_NONE
                )
            )
        );
    }

    // TX 7-8: eETH scope
    function _buildEEthScope() internal pure returns (bytes memory) {
        return bytes.concat(
            _packTx(address(roles), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, EETH)),
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    EETH,
                    IERC20.approve.selector,
                    _buildSingleParamOrConditions(_eethApproveSpenders()),
                    EXEC_NONE
                )
            )
        );
    }

    // TX 9-12: weETH scope
    function _buildWeEthScope() internal pure returns (bytes memory) {
        return bytes.concat(
            _packTx(address(roles), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, WEETH)),
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    WEETH,
                    IERC20.approve.selector,
                    _buildSingleParamOrConditions(_weethApproveSpenders()),
                    EXEC_NONE
                )
            ),
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector, MANAGER_ROLE, WEETH, IWeETH.wrap.selector, EXEC_NONE
                )
            ),
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector, MANAGER_ROLE, WEETH, IWeETH.unwrap.selector, EXEC_NONE
                )
            )
        );
    }

    // TX 13-16: Morpho kpk USDT Prime v1
    function _buildMorphoV1Scope() internal pure returns (bytes memory) {
        return _buildMorphoVaultScope(KPK_USDT_PRIME_V1);
    }

    // TX 17-20: Morpho kpk USDT Prime v2
    function _buildMorphoV2Scope() internal pure returns (bytes memory) {
        return _buildMorphoVaultScope(KPK_USDT_PRIME_V2);
    }

    function _buildMorphoVaultScope(address vault) internal pure returns (bytes memory) {
        return bytes.concat(
            _packTx(address(roles), abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, vault)),
            // deposit(uint256,address): pass, EqualToAvatar
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    vault,
                    IMetaMorphoV1.deposit.selector,
                    _buildPassAvatarConditions(),
                    EXEC_NONE
                )
            ),
            // withdraw(uint256,address,address): pass, EqualToAvatar, EqualToAvatar
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    vault,
                    IMetaMorphoV1.withdraw.selector,
                    _buildPassAvatarAvatarConditions(),
                    EXEC_NONE
                )
            ),
            // redeem(uint256,address,address): pass, EqualToAvatar, EqualToAvatar
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    vault,
                    IMetaMorphoV1.redeem.selector,
                    _buildPassAvatarAvatarConditions(),
                    EXEC_NONE
                )
            )
        );
    }

    // TX 21-25: Ether.fi DepositAdapter
    function _buildEtherFiDepositAdapterScope() internal pure returns (bytes memory) {
        return bytes.concat(
            _packTx(
                address(roles),
                abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, ETHERFI_DEPOSIT_ADAPTER)
            ),
            // depositETHForWeETH(address) — allowFunction with options=1 (EXEC_SEND)
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector,
                    MANAGER_ROLE,
                    ETHERFI_DEPOSIT_ADAPTER,
                    IEtherFiDepositAdapter.depositETHForWeETH.selector,
                    EXEC_SEND
                )
            ),
            // depositWETHForWeETH(uint256,address): pass, EqualToAvatar
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    ETHERFI_DEPOSIT_ADAPTER,
                    IEtherFiDepositAdapter.depositWETHForWeETH.selector,
                    _buildPassAvatarConditions(),
                    EXEC_NONE
                )
            ),
            // depositStETHForWeETHWithPermit(uint256,address,PermitInput): pass, EqualToAvatar (permit unscoped)
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    ETHERFI_DEPOSIT_ADAPTER,
                    IEtherFiDepositAdapter.depositStETHForWeETHWithPermit.selector,
                    _buildPassAvatarConditions(),
                    EXEC_NONE
                )
            ),
            // depositWstETHForWeETHWithPermit: same structure
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    ETHERFI_DEPOSIT_ADAPTER,
                    IEtherFiDepositAdapter.depositWstETHForWeETHWithPermit.selector,
                    _buildPassAvatarConditions(),
                    EXEC_NONE
                )
            )
        );
    }

    // TX 26-27: Ether.fi LiquidityPool
    function _buildEtherFiLiquidityPoolScope() internal pure returns (bytes memory) {
        return bytes.concat(
            _packTx(
                address(roles),
                abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, ETHERFI_LIQUIDITY_POOL)
            ),
            // requestWithdraw(address recipient, uint256 amount): EqualToAvatar (amount PASS implicit)
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    ETHERFI_LIQUIDITY_POOL,
                    IEtherFiLiquidityPool.requestWithdraw.selector,
                    _buildAvatarOnlyConditions(),
                    EXEC_NONE
                )
            )
        );
    }

    // TX 28-29: Ether.fi WeETHWithdrawAdapter
    function _buildEtherFiWeEthWithdrawAdapterScope() internal pure returns (bytes memory) {
        return bytes.concat(
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeTarget.selector, MANAGER_ROLE, ETHERFI_WEETH_WITHDRAW_ADAPTER
                )
            ),
            // requestWithdraw(uint256 weEthAmount, address recipient): pass, EqualToAvatar
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    ETHERFI_WEETH_WITHDRAW_ADAPTER,
                    IEtherFiWeEthWithdrawAdapter.requestWithdraw.selector,
                    _buildPassAvatarConditions(),
                    EXEC_NONE
                )
            )
        );
    }

    // TX 30-31: Ether.fi WithdrawRequestNFT
    function _buildEtherFiWithdrawRequestNftScope() internal pure returns (bytes memory) {
        return bytes.concat(
            _packTx(
                address(roles),
                abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, ETHERFI_WITHDRAW_REQUEST_NFT)
            ),
            // claimWithdraw(uint256) — allowFunction, no arg scoping
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.allowFunction.selector,
                    MANAGER_ROLE,
                    ETHERFI_WITHDRAW_REQUEST_NFT,
                    IEtherFiWithdrawRequestNFT.claimWithdraw.selector,
                    EXEC_NONE
                )
            )
        );
    }

    // TX 32-36: Ether.fi RedemptionManager
    function _buildEtherFiRedemptionManagerScope() internal pure returns (bytes memory) {
        return bytes.concat(
            _packTx(
                address(roles),
                abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, ETHERFI_REDEMPTION_MANAGER)
            ),
            // TX 33: redeemEEth(uint256,address receiver,address owner): pass, EqualToAvatar, EqualTo(NATIVE_ETH)
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    ETHERFI_REDEMPTION_MANAGER,
                    IEtherFiRedemptionManager.redeemEEth.selector,
                    _buildRedeemNoPermitConditions(),
                    EXEC_NONE
                )
            ),
            // TX 34: redeemEEthWithPermit: pass, EqualToAvatar, tuple pass, EqualTo(NATIVE_ETH)
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    ETHERFI_REDEMPTION_MANAGER,
                    IEtherFiRedemptionManager.redeemEEthWithPermit.selector,
                    _buildRedeemWithPermitConditions(),
                    EXEC_NONE
                )
            ),
            // TX 35: redeemWeEth: same shape as redeemEEth
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    ETHERFI_REDEMPTION_MANAGER,
                    IEtherFiRedemptionManager.redeemWeEth.selector,
                    _buildRedeemNoPermitConditions(),
                    EXEC_NONE
                )
            ),
            // TX 36: redeemWeEthWithPermit: same shape as redeemEEthWithPermit
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    ETHERFI_REDEMPTION_MANAGER,
                    IEtherFiRedemptionManager.redeemWeEthWithPermit.selector,
                    _buildRedeemWithPermitConditions(),
                    EXEC_NONE
                )
            )
        );
    }

    // TX 37-38: LRT2 Claim
    function _buildEtherFiLRT2ClaimScope() internal pure returns (bytes memory) {
        return bytes.concat(
            _packTx(
                address(roles),
                abi.encodeWithSelector(IRolesModifier.scopeTarget.selector, MANAGER_ROLE, ETHERFI_LRT2_CLAIM)
            ),
            // claim(address account, uint256, bytes32, bytes32[]): EqualToAvatar (others implicit)
            _packTx(
                address(roles),
                abi.encodeWithSelector(
                    IRolesModifier.scopeFunction.selector,
                    MANAGER_ROLE,
                    ETHERFI_LRT2_CLAIM,
                    IEtherFiLRT2Claim.claim.selector,
                    _buildAvatarOnlyConditions(),
                    EXEC_NONE
                )
            )
        );
    }

    // ─── Condition Helpers
    // ────────────────────────────────────

    /// @dev Root matches, single param is an OR over an address whitelist
    function _buildSingleParamOrConditions(address[] memory whitelist) internal pure returns (ConditionFlat[] memory) {
        ConditionFlat[] memory c = new ConditionFlat[](2 + whitelist.length);
        c[0] = ConditionFlat(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = ConditionFlat(0, PARAM_TYPE_NONE, OP_OR, "");
        for (uint256 i = 0; i < whitelist.length; i++) {
            c[2 + i] = ConditionFlat(1, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(whitelist[i]));
        }
        return c;
    }

    /// @dev 3 conditions: root matches, param 0 = PASS (uint256), param 1 = EqualToAvatar (address)
    function _buildPassAvatarConditions() internal pure returns (ConditionFlat[] memory) {
        ConditionFlat[] memory c = new ConditionFlat[](3);
        c[0] = ConditionFlat(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[2] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        return c;
    }

    /// @dev 4 conditions: root matches, param 0 = PASS, param 1 = EqualToAvatar, param 2 = EqualToAvatar
    function _buildPassAvatarAvatarConditions() internal pure returns (ConditionFlat[] memory) {
        ConditionFlat[] memory c = new ConditionFlat[](4);
        c[0] = ConditionFlat(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[2] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[3] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        return c;
    }

    /// @dev 2 conditions: root matches, param 0 = EqualToAvatar (other params implicit)
    function _buildAvatarOnlyConditions() internal pure returns (ConditionFlat[] memory) {
        ConditionFlat[] memory c = new ConditionFlat[](2);
        c[0] = ConditionFlat(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        return c;
    }

    /// @dev For redeemEEth / redeemWeEth: amount, receiver=Avatar, owner=NATIVE_ETH magic
    function _buildRedeemNoPermitConditions() internal pure returns (ConditionFlat[] memory) {
        ConditionFlat[] memory c = new ConditionFlat[](4);
        c[0] = ConditionFlat(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[2] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[3] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(NATIVE_ETH));
        return c;
    }

    /// @dev For redeemEEthWithPermit / redeemWeEthWithPermit:
    ///      amount, receiver=Avatar, permit(tuple pass), owner=NATIVE_ETH
    ///      5-field tuple produces 5 child conditions under the tuple
    function _buildRedeemWithPermitConditions() internal pure returns (ConditionFlat[] memory) {
        ConditionFlat[] memory c = new ConditionFlat[](10);
        c[0] = ConditionFlat(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        c[1] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_PASS, "");
        c[2] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        c[3] = ConditionFlat(0, PARAM_TYPE_TUPLE, OP_PASS, "");
        c[4] = ConditionFlat(0, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(NATIVE_ETH));
        // 5 children of tuple (parent=3) for (value, deadline, v, r, s) — all PASS
        for (uint256 i = 5; i < 10; i++) {
            c[i] = ConditionFlat(3, PARAM_TYPE_STATIC, OP_PASS, "");
        }
        return c;
    }

    /// @dev CowSwap signOrder conditions: 58 entries
    /// Tree: root MATCHES -> Data tuple MATCHES -> [sellToken OR, buyToken OR, receiver=Avatar,
    ///       sellAmount..buyTokenBalance PASS x 9] -> sell whitelist (27) -> buy whitelist (17)
    function _buildCowSwapSignOrderConditions() internal pure returns (ConditionFlat[] memory) {
        address[] memory sell = _cowSwapSellTokens();
        address[] memory buy = _cowSwapBuyTokens();
        uint256 n = 14 + sell.length + buy.length;
        ConditionFlat[] memory c = new ConditionFlat[](n);
        uint256 i = 0;
        // [0] root CALLDATA MATCHES
        c[i++] = ConditionFlat(0, PARAM_TYPE_CALLDATA, OP_MATCHES, "");
        // [1] param 0 (Data struct) TUPLE MATCHES parent=0
        c[i++] = ConditionFlat(0, PARAM_TYPE_TUPLE, OP_MATCHES, "");
        // [2] sellToken OR group parent=1 (child of tuple)
        c[i++] = ConditionFlat(1, PARAM_TYPE_NONE, OP_OR, "");
        // [3] buyToken OR group parent=1
        c[i++] = ConditionFlat(1, PARAM_TYPE_NONE, OP_OR, "");
        // [4] receiver = Avatar
        c[i++] = ConditionFlat(1, PARAM_TYPE_STATIC, OP_EQUAL_TO_AVATAR, "");
        // [5-13] 9 x PASS for sellAmount, buyAmount, validTo, appData, feeAmount, kind,
        //         partiallyFillable, sellTokenBalance, buyTokenBalance (parent=1)
        for (uint256 j = 0; j < 9; j++) {
            c[i++] = ConditionFlat(1, PARAM_TYPE_STATIC, OP_PASS, "");
        }
        // Sell token whitelist (parent=2)
        for (uint256 j = 0; j < sell.length; j++) {
            c[i++] = ConditionFlat(2, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(sell[j]));
        }
        // Buy token whitelist (parent=3)
        for (uint256 j = 0; j < buy.length; j++) {
            c[i++] = ConditionFlat(3, PARAM_TYPE_STATIC, OP_EQUAL_TO, abi.encode(buy[j]));
        }
        return c;
    }

    // ─── Token Lists
    // ──────────────────────────────────────────

    /// @dev 27 sell tokens, sorted by address ascending
    function _cowSwapSellTokens() internal pure returns (address[] memory) {
        address[] memory t = new address[](27);
        t[0] = EETH; // 0x35fA164735182de50811E8e2E824cFb9B6118ac2
        t[1] = GHO; // 0x40D16FC0...
        t[2] = SWISE; // 0x48C33997...
        t[3] = CVX; // 0x4e3FBD56...
        t[4] = MORPHO_TOKEN; // 0x58D97B57...
        t[5] = LDO; // 0x5A98FcBE...
        t[6] = DAI; // 0x6B175474...
        t[7] = FLUID; // 0x6f40d4A6...
        t[8] = WSTETH; // 0x7f39C581...
        t[9] = OETH; // 0x856c4Efb...
        t[10] = USDC; // 0xA0b86991...
        t[11] = ETHX; // 0xA35b1B31...
        t[12] = SUSDS; // 0xa3931d71...
        t[13] = RETH; // 0xae78736C...
        t[14] = STETH; // 0xae7ab965...
        t[15] = BAL; // 0xba100000...
        t[16] = COMP; // 0xc00e94Cb...
        t[17] = WETH; // 0xC02aaA39...
        t[18] = AURA; // 0xC0c293ce...
        t[19] = SPK; // 0xc20059e0...
        t[20] = WEETH; // 0xCd5fE23C...
        t[21] = RPL; // 0xD3352606...
        t[22] = CRV; // 0xD533a949...
        t[23] = USDT; // 0xdAC17F95...
        t[24] = USDS; // 0xdC035D45...
        t[25] = ANKRETH; // 0xE95A203B...
        t[26] = OSETH; // 0xf1C9acDc...
        return t;
    }

    /// @dev 17 buy tokens, sorted by address ascending
    function _cowSwapBuyTokens() internal pure returns (address[] memory) {
        address[] memory t = new address[](17);
        t[0] = EETH;
        t[1] = GHO;
        t[2] = DAI;
        t[3] = WSTETH;
        t[4] = OETH;
        t[5] = USDC;
        t[6] = ETHX;
        t[7] = SUSDS;
        t[8] = RETH;
        t[9] = STETH;
        t[10] = WETH;
        t[11] = WEETH;
        t[12] = USDT;
        t[13] = USDS;
        t[14] = ANKRETH;
        t[15] = NATIVE_ETH;
        t[16] = OSETH;
        return t;
    }

    // wstETH approve spenders (8) — sorted ascending
    function _wstethApproveSpenders() internal pure returns (address[] memory) {
        address[] memory s = new address[](8);
        s[0] = PERMIT2;
        s[1] = UNISWAP_V3_ROUTER;
        s[2] = LIDO_WITHDRAWAL_QUEUE;
        s[3] = 0xB188b1CB84Fb0bA13cb9ee1292769F903A9feC59; // Aura RewardPoolDepositWrapper
        s[4] = BALANCER_V2_VAULT;
        s[5] = 0xC13e21B648A5Ee794902342038FF3aDAB66BE987; // Aave V3 pool (L1 bridge)
        s[6] = GPV2_VAULT_RELAYER;
        s[7] = ETHERFI_DEPOSIT_ADAPTER;
        return s;
    }

    // stETH approve spenders (8) — sorted ascending
    function _stethApproveSpenders() internal pure returns (address[] memory) {
        address[] memory s = new address[](8);
        s[0] = 0x21E27a5E5513D6e65C4f830167390997aA84843a; // (kept from prior scope)
        s[1] = 0x56C526b0159a258887e0d79ec3a80dfb940d0cD7;
        s[2] = UNISWAP_V3_ROUTER;
        s[3] = WSTETH;
        s[4] = LIDO_WITHDRAWAL_QUEUE;
        s[5] = GPV2_VAULT_RELAYER;
        s[6] = ETHERFI_DEPOSIT_ADAPTER;
        s[7] = 0xDC24316b9AE028F1497c275EB9192a3Ea0f67022; // Curve stETH/ETH pool
        return s;
    }

    // WETH approve spenders (14) — sorted ascending
    function _wethApproveSpenders() internal pure returns (address[] memory) {
        address[] memory s = new address[](14);
        s[0] = PERMIT2;
        s[1] = 0x13f4EA83D0bd40E75C8222255bc855a974568Dd4;
        s[2] = 0x56C526b0159a258887e0d79ec3a80dfb940d0cD7;
        s[3] = UNISWAP_V3_ROUTER;
        s[4] = AAVE_POOL;
        s[5] = 0xB188b1CB84Fb0bA13cb9ee1292769F903A9feC59; // Aura RewardPoolDepositWrapper
        s[6] = BALANCER_V2_VAULT;
        s[7] = 0xBb50A5341368751024ddf33385BA8cf61fE65FF9;
        s[8] = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb; // Morpho Blue
        s[9] = 0xC13e21B648A5Ee794902342038FF3aDAB66BE987;
        s[10] = GPV2_VAULT_RELAYER;
        s[11] = 0xcc7d5785AD5755B6164e21495E07aDb0Ff11C2A8;
        s[12] = ETHERFI_DEPOSIT_ADAPTER;
        s[13] = 0xd564F765F9aD3E7d2d6cA782100795a885e8e7C8;
        return s;
    }

    // USDT approve spenders (11) — sorted ascending
    function _usdtApproveSpenders() internal pure returns (address[] memory) {
        address[] memory s = new address[](11);
        s[0] = 0x3Afdc9BCA9213A35503b077a6072F3D0d5AB0840;
        s[1] = 0x56C526b0159a258887e0d79ec3a80dfb940d0cD7;
        s[2] = 0x5C20B550819128074FD538Edf79791733ccEdd18;
        s[3] = UNISWAP_V3_ROUTER;
        s[4] = KPK_USDT_PRIME_V2;
        s[5] = AAVE_POOL;
        s[6] = BALANCER_V2_VAULT;
        s[7] = 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7; // Curve 3pool
        s[8] = 0xC13e21B648A5Ee794902342038FF3aDAB66BE987;
        s[9] = GPV2_VAULT_RELAYER;
        s[10] = KPK_USDT_PRIME_V1;
        return s;
    }

    // eETH approve spenders (4) — sorted ascending
    function _eethApproveSpenders() internal pure returns (address[] memory) {
        address[] memory s = new address[](4);
        s[0] = ETHERFI_LIQUIDITY_POOL; // 0x308861A4...
        s[1] = GPV2_VAULT_RELAYER; // 0xC92E8bdf...
        s[2] = WEETH; // 0xCd5fE23C...
        s[3] = ETHERFI_REDEMPTION_MANAGER; // 0xdadef1ff...
        return s;
    }

    // weETH approve spenders (3) — sorted ascending
    function _weethApproveSpenders() internal pure returns (address[] memory) {
        address[] memory s = new address[](3);
        s[0] = GPV2_VAULT_RELAYER;
        s[1] = ETHERFI_REDEMPTION_MANAGER;
        s[2] = ETHERFI_WEETH_WITHDRAW_ADAPTER;
        return s;
    }
}
