// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

library IAllowanceTransfer {
    struct PermitDetails {
        address token;
        uint160 amount;
        uint48 expiration;
        uint48 nonce;
    }

    struct PermitSingle {
        PermitDetails details;
        address spender;
        uint256 sigDeadline;
    }
}

interface IFToken {
    error FluidLendingError(uint256 errorId_);
    error FluidLiquidityCalcsError(uint256 errorId_);
    error FluidSafeTransferError(uint256 errorId_);

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event LogRebalance(uint256 assets);
    event LogRescueFunds(address indexed token);
    event LogUpdateRates(uint256 tokenExchangePrice, uint256 liquidityExchangePrice);
    event LogUpdateRebalancer(address indexed rebalancer);
    event LogUpdateRewards(address indexed rewardsRateModel);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Withdraw(
        address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function asset() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function convertToAssets(uint256 shares_) external view returns (uint256);
    function convertToShares(uint256 assets_) external view returns (uint256);
    function decimals() external view returns (uint8);
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);
    function deposit(uint256 assets_, address receiver_) external returns (uint256 shares_);
    function deposit(uint256 assets_, address receiver_, uint256 minAmountOut_) external returns (uint256 shares_);
    function depositWithSignature(
        uint256 assets_,
        address receiver_,
        uint256 minAmountOut_,
        IAllowanceTransfer.PermitSingle memory permit_,
        bytes memory signature_
    ) external returns (uint256 shares_);
    function depositWithSignatureEIP2612(
        uint256 assets_,
        address receiver_,
        uint256 minAmountOut_,
        uint256 deadline_,
        bytes memory signature_
    ) external returns (uint256 shares_);
    function getData()
        external
        view
        returns (
            address liquidity_,
            address lendingFactory_,
            address lendingRewardsRateModel_,
            address permit2_,
            address rebalancer_,
            bool rewardsActive_,
            uint256 liquidityBalance_,
            uint256 liquidityExchangePrice_,
            uint256 tokenExchangePrice_
        );
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);
    function liquidityCallback(address token_, uint256 amount_, bytes memory data_) external;
    function maxDeposit(address) external view returns (uint256);
    function maxMint(address) external view returns (uint256);
    function maxRedeem(address owner_) external view returns (uint256);
    function maxWithdraw(address owner_) external view returns (uint256);
    function minDeposit() external view returns (uint256);
    function mint(uint256 shares_, address receiver_, uint256 maxAssets_) external returns (uint256 assets_);
    function mint(uint256 shares_, address receiver_) external returns (uint256 assets_);
    function mintWithSignature(
        uint256 shares_,
        address receiver_,
        uint256 maxAssets_,
        IAllowanceTransfer.PermitSingle memory permit_,
        bytes memory signature_
    ) external returns (uint256 assets_);
    function mintWithSignatureEIP2612(
        uint256 shares_,
        address receiver_,
        uint256 maxAssets_,
        uint256 deadline_,
        bytes memory signature_
    ) external returns (uint256 assets_);
    function name() external view returns (string memory);
    function nonces(address owner) external view returns (uint256);
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;
    function previewDeposit(uint256 assets_) external view returns (uint256);
    function previewMint(uint256 shares_) external view returns (uint256);
    function previewRedeem(uint256 shares_) external view returns (uint256);
    function previewWithdraw(uint256 assets_) external view returns (uint256);
    function rebalance() external payable returns (uint256 assets_);
    function redeem(uint256 shares_, address receiver_, address owner_, uint256 minAmountOut_)
        external
        returns (uint256 assets_);
    function redeem(uint256 shares_, address receiver_, address owner_) external returns (uint256 assets_);
    function redeemWithSignature(
        uint256 shares_,
        address receiver_,
        address owner_,
        uint256 minAmountOut_,
        uint256 deadline_,
        bytes memory signature_
    ) external returns (uint256 assets_);
    function rescueFunds(address token_) external;
    function symbol() external view returns (string memory);
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function updateRates() external returns (uint256 tokenExchangePrice_, uint256 liquidityExchangePrice_);
    function updateRebalancer(address newRebalancer_) external;
    function updateRewards(address rewardsRateModel_) external;
    function withdraw(uint256 assets_, address receiver_, address owner_, uint256 maxSharesBurn_)
        external
        returns (uint256 shares_);
    function withdraw(uint256 assets_, address receiver_, address owner_) external returns (uint256 shares_);
    function withdrawWithSignature(
        uint256 sharesToPermit_,
        uint256 assets_,
        address receiver_,
        address owner_,
        uint256 maxSharesBurn_,
        uint256 deadline_,
        bytes memory signature_
    ) external returns (uint256 shares_);
}
