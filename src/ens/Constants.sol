// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

/// @title ENS Constants
/// @notice Shared address constants for ENS governance proposal tests.
///         Use these instead of hardcoding addresses in individual proposals.
library ENSConstants {
    // ─── Governance ─────────────────────────────────────────────────────
    address internal constant ENS_TOKEN = 0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72;
    address internal constant GOVERNOR = 0x323A76393544d5ecca80cd6ef2A560C6a395b7E3;
    address internal constant TIMELOCK = 0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7;

    // ─── ENS Infrastructure ─────────────────────────────────────────────
    address internal constant ENS_ROOT = 0xaB528d626EC275E3faD363fF1393A41F581c5897;
    address internal constant ENS_REGISTRY = 0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e;
    address internal constant NAME_WRAPPER = 0xD4416b13d2b3a9aBae7AcD5D6C2BbDBE25686401;

    // ─── Endowment & Zodiac ────────────────────────────────────────────
    address internal constant ENDOWMENT_SAFE = 0x4F2083f5fBede34C2714aFfb3105539775f7FE64;
    address internal constant ZODIAC_ROLES = 0x703806E61847984346d2D7DDd853049627e50A40;
    address internal constant KARPATKEY = 0xb423e0f6E7430fa29500c5cC9bd83D28c8BD8978;
    address internal constant MULTI_SEND = 0x40A2aCCbd92BCA938b02010E17A5b8929b49130D;

    // ─── Multisigs ──────────────────────────────────────────────────────
    address internal constant META_GOV_MULTISIG = 0x91c32893216dE3eA0a55ABb9851f581d4503d39b;
    address internal constant ECOSYSTEM_MULTISIG = 0x2686A8919Df194aA7673244549E68D42C1685d03;
    address internal constant PUBLIC_GOODS_MULTISIG = 0xcD42b4c4D102cc22864e3A1341Bb0529c17fD87d;

    // ─── Tokens ─────────────────────────────────────────────────────────
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant GHO = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;

    // ─── Token Decimals ─────────────────────────────────────────────────
    uint8 internal constant USDC_DECIMALS = 6;
    uint8 internal constant USDT_DECIMALS = 6;
    uint8 internal constant WETH_DECIMALS = 18;
    uint8 internal constant ENS_DECIMALS = 18;

    // ─── Default Actors ─────────────────────────────────────────────────
    address internal constant FIREEYESDAO = 0x5BFCB4BE4d7B43437d5A0c57E908c048a4418390;
}
