// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

/// @title V3FeeAdapter Interface
/// @notice Interface for the V3 Fee Adapter that manages Uniswap V3 protocol fees
interface IV3FeeAdapter {
    struct CollectParams {
        address pool;
        uint128 amount0Requested;
        uint128 amount1Requested;
    }

    struct Collected {
        uint128 amount0Collected;
        uint128 amount1Collected;
    }

    struct Pair {
        address token0;
        address token1;
    }

    error InvalidFeeTier();
    error InvalidFeeValue();
    error InvalidProof();
    error MerkleProofInvalidMultiproof();
    error TierAlreadyStored();
    error Unauthorized();

    event OwnershipTransferred(address indexed user, address indexed newOwner);

    function FACTORY() external view returns (address);
    function TOKEN_JAR() external view returns (address);
    function batchTriggerFeeUpdate(Pair[] memory pairs, bytes32[] memory proof, bool[] memory proofFlags) external;
    function collect(CollectParams[] memory collectParams)
        external
        returns (Collected[] memory amountsCollected);
    function defaultFees(uint24 feeTier) external view returns (uint8 defaultFeeValue);
    function enableFeeAmount(uint24 fee, int24 tickSpacing) external;
    function feeSetter() external view returns (address);
    function feeTiers(uint256) external view returns (uint24);
    function merkleRoot() external view returns (bytes32);
    function owner() external view returns (address);
    function setDefaultFeeByFeeTier(uint24 feeTier, uint8 defaultFeeValue) external;
    function setFactoryOwner(address newOwner) external;
    function setFeeSetter(address newFeeSetter) external;
    function setMerkleRoot(bytes32 _merkleRoot) external;
    function storeFeeTier(uint24 feeTier) external;
    function transferOwnership(address newOwner) external;
    function triggerFeeUpdate(address pool, bytes32[] memory proof) external;
    function triggerFeeUpdate(address token0, address token1, bytes32[] memory proof) external;
}

