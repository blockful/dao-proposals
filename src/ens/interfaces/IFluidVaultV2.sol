// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IFluidVaultV2 {
    error Abdicated();
    error AbsoluteCapExceeded();
    error AbsoluteCapNotDecreasing();
    error AbsoluteCapNotIncreasing();
    error AutomaticallyTimelocked();
    error CannotReceiveAssets();
    error CannotReceiveShares();
    error CannotSendAssets();
    error CannotSendShares();
    error CastOverflow();
    error DataAlreadyPending();
    error DataNotTimelocked();
    error FeeInvariantBroken();
    error FeeTooHigh();
    error InvalidSigner();
    error MaxRateTooHigh();
    error NoCode();
    error NotAdapter();
    error NotInAdapterRegistry();
    error PenaltyTooHigh();
    error PermitDeadlineExpired();
    error RelativeCapAboveOne();
    error RelativeCapExceeded();
    error RelativeCapNotDecreasing();
    error RelativeCapNotIncreasing();
    error TimelockNotDecreasing();
    error TimelockNotExpired();
    error TimelockNotIncreasing();
    error TransferFromReturnedFalse();
    error TransferFromReverted();
    error TransferReturnedFalse();
    error TransferReverted();
    error Unauthorized();
    error ZeroAbsoluteCap();
    error ZeroAddress();
    error ZeroAllocation();

    event Abdicate(bytes4 indexed selector);
    event Accept(bytes4 indexed selector, bytes data);
    event AccrueInterest(
        uint256 previousTotalAssets, uint256 newTotalAssets, uint256 performanceFeeShares, uint256 managementFeeShares
    );
    event AddAdapter(address indexed account);
    event Allocate(address indexed sender, address indexed adapter, uint256 assets, bytes32[] ids, int256 change);
    event AllowanceUpdatedByTransferFrom(address indexed owner, address indexed spender, uint256 shares);
    event Approval(address indexed owner, address indexed spender, uint256 shares);
    event Constructor(address indexed owner, address indexed asset);
    event Deallocate(address indexed sender, address indexed adapter, uint256 assets, bytes32[] ids, int256 change);
    event DecreaseAbsoluteCap(address indexed sender, bytes32 indexed id, bytes idData, uint256 newAbsoluteCap);
    event DecreaseRelativeCap(address indexed sender, bytes32 indexed id, bytes idData, uint256 newRelativeCap);
    event DecreaseTimelock(bytes4 indexed selector, uint256 newDuration);
    event Deposit(address indexed sender, address indexed onBehalf, uint256 assets, uint256 shares);
    event ForceDeallocate(
        address indexed sender,
        address adapter,
        uint256 assets,
        address indexed onBehalf,
        bytes32[] ids,
        uint256 penaltyAssets
    );
    event IncreaseAbsoluteCap(bytes32 indexed id, bytes idData, uint256 newAbsoluteCap);
    event IncreaseRelativeCap(bytes32 indexed id, bytes idData, uint256 newRelativeCap);
    event IncreaseTimelock(bytes4 indexed selector, uint256 newDuration);
    event Permit(address indexed owner, address indexed spender, uint256 shares, uint256 nonce, uint256 deadline);
    event RemoveAdapter(address indexed account);
    event Revoke(address indexed sender, bytes4 indexed selector, bytes data);
    event SetAdapterRegistry(address indexed newAdapterRegistry);
    event SetCurator(address indexed newCurator);
    event SetForceDeallocatePenalty(address indexed adapter, uint256 forceDeallocatePenalty);
    event SetIsAllocator(address indexed account, bool newIsAllocator);
    event SetIsSentinel(address indexed account, bool newIsSentinel);
    event SetLiquidityAdapterAndData(
        address indexed sender, address indexed newLiquidityAdapter, bytes indexed newLiquidityData
    );
    event SetManagementFee(uint256 newManagementFee);
    event SetManagementFeeRecipient(address indexed newManagementFeeRecipient);
    event SetMaxRate(uint256 newMaxRate);
    event SetName(string newName);
    event SetOwner(address indexed newOwner);
    event SetPerformanceFee(uint256 newPerformanceFee);
    event SetPerformanceFeeRecipient(address indexed newPerformanceFeeRecipient);
    event SetReceiveAssetsGate(address indexed newReceiveAssetsGate);
    event SetReceiveSharesGate(address indexed newReceiveSharesGate);
    event SetSendAssetsGate(address indexed newSendAssetsGate);
    event SetSendSharesGate(address indexed newSendSharesGate);
    event SetSymbol(string newSymbol);
    event Submit(bytes4 indexed selector, bytes data, uint256 executableAt);
    event Transfer(address indexed from, address indexed to, uint256 shares);
    event Withdraw(
        address indexed sender, address indexed receiver, address indexed onBehalf, uint256 assets, uint256 shares
    );

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function _totalAssets() external view returns (uint128);
    function abdicate(bytes4 selector) external;
    function abdicated(bytes4 selector) external view returns (bool);
    function absoluteCap(bytes32 id) external view returns (uint256);
    function accrueInterest() external;
    function accrueInterestView() external view returns (uint256, uint256, uint256);
    function adapterRegistry() external view returns (address);
    function adapters(uint256) external view returns (address);
    function adaptersLength() external view returns (uint256);
    function addAdapter(address account) external;
    function allocate(address adapter, bytes memory data, uint256 assets) external;
    function allocation(bytes32 id) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 shares) external returns (bool);
    function asset() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function canReceiveAssets(address account) external view returns (bool);
    function canReceiveShares(address account) external view returns (bool);
    function canSendAssets(address account) external view returns (bool);
    function canSendShares(address account) external view returns (bool);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function convertToShares(uint256 assets) external view returns (uint256);
    function curator() external view returns (address);
    function deallocate(address adapter, bytes memory data, uint256 assets) external;
    function decimals() external view returns (uint8);
    function decreaseAbsoluteCap(bytes memory idData, uint256 newAbsoluteCap) external;
    function decreaseRelativeCap(bytes memory idData, uint256 newRelativeCap) external;
    function decreaseTimelock(bytes4 selector, uint256 newDuration) external;
    function deposit(uint256 assets, address onBehalf) external returns (uint256);
    function executableAt(bytes memory data) external view returns (uint256);
    function firstTotalAssets() external view returns (uint256);
    function forceDeallocate(address adapter, bytes memory data, uint256 assets, address onBehalf)
        external
        returns (uint256);
    function forceDeallocatePenalty(address adapter) external view returns (uint256);
    function increaseAbsoluteCap(bytes memory idData, uint256 newAbsoluteCap) external;
    function increaseRelativeCap(bytes memory idData, uint256 newRelativeCap) external;
    function increaseTimelock(bytes4 selector, uint256 newDuration) external;
    function isAdapter(address account) external view returns (bool);
    function isAllocator(address account) external view returns (bool);
    function isSentinel(address account) external view returns (bool);
    function lastUpdate() external view returns (uint64);
    function liquidityAdapter() external view returns (address);
    function liquidityData() external view returns (bytes memory);
    function managementFee() external view returns (uint96);
    function managementFeeRecipient() external view returns (address);
    function maxDeposit(address) external pure returns (uint256);
    function maxMint(address) external pure returns (uint256);
    function maxRate() external view returns (uint64);
    function maxRedeem(address) external pure returns (uint256);
    function maxWithdraw(address) external pure returns (uint256);
    function mint(uint256 shares, address onBehalf) external returns (uint256);
    function multicall(bytes[] memory data) external;
    function name() external view returns (string memory);
    function nonces(address account) external view returns (uint256);
    function owner() external view returns (address);
    function performanceFee() external view returns (uint96);
    function performanceFeeRecipient() external view returns (address);
    function permit(address _owner, address spender, uint256 shares, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;
    function previewDeposit(uint256 assets) external view returns (uint256);
    function previewMint(uint256 shares) external view returns (uint256);
    function previewRedeem(uint256 shares) external view returns (uint256);
    function previewWithdraw(uint256 assets) external view returns (uint256);
    function receiveAssetsGate() external view returns (address);
    function receiveSharesGate() external view returns (address);
    function redeem(uint256 shares, address receiver, address onBehalf) external returns (uint256);
    function relativeCap(bytes32 id) external view returns (uint256);
    function removeAdapter(address account) external;
    function revoke(bytes memory data) external;
    function sendAssetsGate() external view returns (address);
    function sendSharesGate() external view returns (address);
    function setAdapterRegistry(address newAdapterRegistry) external;
    function setCurator(address newCurator) external;
    function setForceDeallocatePenalty(address adapter, uint256 newForceDeallocatePenalty) external;
    function setIsAllocator(address account, bool newIsAllocator) external;
    function setIsSentinel(address account, bool newIsSentinel) external;
    function setLiquidityAdapterAndData(address newLiquidityAdapter, bytes memory newLiquidityData) external;
    function setManagementFee(uint256 newManagementFee) external;
    function setManagementFeeRecipient(address newManagementFeeRecipient) external;
    function setMaxRate(uint256 newMaxRate) external;
    function setName(string memory newName) external;
    function setOwner(address newOwner) external;
    function setPerformanceFee(uint256 newPerformanceFee) external;
    function setPerformanceFeeRecipient(address newPerformanceFeeRecipient) external;
    function setReceiveAssetsGate(address newReceiveAssetsGate) external;
    function setReceiveSharesGate(address newReceiveSharesGate) external;
    function setSendAssetsGate(address newSendAssetsGate) external;
    function setSendSharesGate(address newSendSharesGate) external;
    function setSymbol(string memory newSymbol) external;
    function submit(bytes memory data) external;
    function symbol() external view returns (string memory);
    function timelock(bytes4 selector) external view returns (uint256);
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function transfer(address to, uint256 shares) external returns (bool);
    function transferFrom(address from, address to, uint256 shares) external returns (bool);
    function virtualShares() external view returns (uint256);
    function withdraw(uint256 assets, address receiver, address onBehalf) external returns (uint256);
}
