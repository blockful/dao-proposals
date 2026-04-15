# Review Reference

Shared reference data for all proposal calldata reviews.

## ENS Key Addresses

| Contract                         | Address                                      |
| -------------------------------- | -------------------------------------------- |
| ENS Token                        | `0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72` |
| ENS Governor                     | `0x323A76393544d5ecca80cd6ef2A560C6a395b7E3` |
| ENS Timelock (wallet.ensdao.eth) | `0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7` |
| ENS Endowment Safe               | `0x4F2083f5fBede34C2714aFfb3105539775f7FE64` |
| ENS Root                         | `0xaB528d626EC275E3faD363fF1393A41F581c5897` |
| ENS Registry                     | `0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e` |
| Zodiac Roles V2                  | `0x703806E61847984346d2D7DDd853049627e50A40` |
| USDC                             | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` |
| Meta-Gov Multisig                | `0x91c32893216dE3eA0a55ABb9851f581d4503d39b` |
| Ecosystem Multisig               | `0x2686A8919Df194aA7673244549E68D42C1685d03` |
| Public Goods Multisig            | `0xcD42b4c4D102cc22864e3A1341Bb0529c17fD87d` |

For the full list, see `src/ens/Constants.sol` (ENSConstants library):

```solidity
import { ENSConstants } from "@ens/Constants.sol";
// Use: ENSConstants.USDC, ENSConstants.TIMELOCK, ENSConstants.META_GOV_MULTISIG, etc.
```

For other DAOs, see `src/dao-registry.json`.

## Available Helpers

| Helper              | Import                               | When to Use                                                                                                                                            |
| ------------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `SafeHelper`        | `@ens/helpers/SafeHelper.sol`        | Proposal calls the Endowment Safe (`execTransaction`). Provides `endowmentSafe`, `_buildSafeExecCalldata()`, `_buildSafeExecDelegateCalldata()`.       |
| `ZodiacRolesHelper` | `@ens/helpers/ZodiacRolesHelper.sol` | Proposal modifies Zodiac Roles permissions. Provides `roles`, `karpatkey`, `MANAGER_ROLE`, `_safeExecuteTransaction()`, `_expectConditionViolation()`. |
| `MultiSendHelper`   | `@ens/helpers/MultiSendHelper.sol`   | Proposal batches multiple Safe transactions via MultiSend. Provides `_packCall()`, `_buildSafeMultiSendCalldata()`. Extends SafeHelper.                |

### When to use which helper

- **Proposal calls the Endowment Safe**: inherit `SafeHelper`
- **Proposal modifies Zodiac Roles permissions**: inherit `ZodiacRolesHelper`
- **Proposal does both**: inherit both
- **Proposal batches Safe calls via MultiSend**: inherit `MultiSendHelper` (extends SafeHelper)
- **Simple governance proposal** (token transfers, ENS registry ops): no helpers needed

## Decimal Reference

| Token    | Decimals | Example                       |
| -------- | -------- | ----------------------------- |
| USDC     | 6        | `900_000 * 10**6` = 900K USDC |
| USDT     | 6        | `100_000 * 10**6` = 100K USDT |
| ETH/WETH | 18       | `1 ether` = 1 ETH             |
| ENS      | 18       | `100_000 * 10**18` = 100K ENS |

## Common Function Selectors

Always derive from interfaces: `IERC20.transfer.selector`, `IWETH.deposit.selector`, etc. Never hardcode hex bytes4
values.

| Selector     | Function                                                                                     |
| ------------ | -------------------------------------------------------------------------------------------- |
| `0xa9059cbb` | `transfer(address,uint256)`                                                                  |
| `0x095ea7b3` | `approve(address,uint256)`                                                                   |
| `0x23b872dd` | `transferFrom(address,address,uint256)`                                                      |
| `0x6a761202` | `execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes)` |
