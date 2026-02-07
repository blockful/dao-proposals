 # [Executable] Registrar Manager + Endowment Roles Update (Draft)
 
 ## Abstract
 
This proposal introduces a RegistrarManager that can permissionlessly withdraw ETH from ENS registrar controllers and forward funds to a configurable destination (initially the Endowment Safe). It also updates the Endowment Zodiac Roles permissions so the Endowment Manager can transfer ETH and USDC to the ENS Timelock only.
 
 ## Motivation
 
Registrar income currently flows to the Timelock and requires a proposal to move funds into the Endowment. The RegistrarManager removes this bottleneck by allowing permissionless withdrawals from registrars and routing proceeds directly to the Endowment. Separately, limited treasury transfers (ETH/USDC) to the Timelock are required for operational funding; these are scoped to the Timelock only.
 
 ## Specification
 
 ### Description
 
This proposal:
 
1. Deploys `RegistrarManager` via the EIP-2470 singleton factory (CREATE2).
2. Registers the current and legacy registrar controllers in the manager.
3. Transfers registrar controller ownership to the manager.
4. Updates Zodiac Roles for the Endowment Manager (MANAGER role) to allow:
   - `USDC.transfer(timelock, amount)` with no amount cap.
   - ETH sends to the Timelock only (empty calldata, send-only).
 
 ### Transactions Summary
 
This proposal contains **9** transaction(s) to be executed by the ENS DAO Timelock.
 
| # | Contract | Function | Description |
| - | -------- | -------- | ----------- |
| 1 | EIP-2470 Singleton Factory | `deploy(bytes,bytes32)` | Deploy `RegistrarManager` with Timelock owner and Endowment destination |
| 2 | RegistrarManager | `addRegistrar` | Register new ETH Registrar Controller |
| 3 | RegistrarManager | `addRegistrar` | Register legacy ETH Registrar Controller |
| 4 | ETH Registrar Controller 2 | `transferOwnership` | Transfer ownership to RegistrarManager |
| 5 | Old ETH Registrar Controller | `transferOwnership` | Transfer ownership to RegistrarManager |
| 6 | Endowment Safe | `execTransaction` | Zodiac `scopeTarget` for USDC |
| 7 | Endowment Safe | `execTransaction` | Zodiac `scopeFunction` for `USDC.transfer(timelock, amount)` |
| 8 | Endowment Safe | `execTransaction` | Zodiac `scopeTarget` for Timelock |
| 9 | Endowment Safe | `execTransaction` | Zodiac `allowFunction` for ETH sends to Timelock |
 
 ---
 
 ## Detailed Transaction Information
 
 ### Transaction 1: Deploy RegistrarManager
 
**Target:** EIP-2470 Singleton Factory  
**Address:** `0x4e59b44847b379578588920ca78fbf26c0b4956c`  
**Function:** `deploy(bytes _initCode, bytes32 _salt)`
 
**Parameters:**
* `_initCode`: `RegistrarManager` creation code + constructor args `(timelock, endowmentSafe)` → `TBD`
* `_salt`: `keccak256("ENS_REGISTRAR_MANAGER_V1")`
 
**Encoded Calldata:** `TBD`
 
 ---
 
 ### Transaction 2: Register new ETH Registrar Controller
 
**Target:** RegistrarManager  
**Address:** `TBD_REGISTRAR_MANAGER`  
**Function:** `addRegistrar`
 
**Parameters:**
* `registrar`: `0x59E16fcCd424Cc24e280Be16E11Bcd56fb0CE547`
 
**Encoded Calldata:** `TBD`
 
 ---
 
 ### Transaction 3: Register legacy ETH Registrar Controller
 
**Target:** RegistrarManager  
**Address:** `TBD_REGISTRAR_MANAGER`  
**Function:** `addRegistrar`
 
**Parameters:**
* `registrar`: `0x283Af0B28c62C092C9727F1Ee09c02CA627EB7F5`
 
**Encoded Calldata:** `TBD`
 
 ---
 
 ### Transaction 4: Transfer ownership of ETH Registrar Controller 2
 
**Target:** ENS: ETH Registrar Controller 2  
**Address:** `0x59E16fcCd424Cc24e280Be16E11Bcd56fb0CE547`  
**Function:** `transferOwnership`
 
**Parameters:**
* `newOwner`: `TBD_REGISTRAR_MANAGER`
 
**Encoded Calldata:** `TBD`
 
 ---
 
 ### Transaction 5: Transfer ownership of Old ETH Registrar Controller
 
**Target:** ENS: Old ETH Registrar Controller  
**Address:** `0x283Af0B28c62C092C9727F1Ee09c02CA627EB7F5`  
**Function:** `transferOwnership`
 
**Parameters:**
* `newOwner`: `TBD_REGISTRAR_MANAGER`
 
**Encoded Calldata:** `TBD`
 
 ---
 
 ### Transaction 6: Zodiac scopeTarget for USDC
 
**Target:** ENS Endowment Safe  
**Address:** `0x4F2083f5fBede34C2714aFfb3105539775f7FE64`  
**Function:** `execTransaction`
 
**Inner Call:** `Roles.scopeTarget(MANAGER_ROLE, USDC)`
 
**Encoded Calldata:** `TBD`
 
 ---
 
 ### Transaction 7: Zodiac scopeFunction for USDC transfer
 
**Target:** ENS Endowment Safe  
**Address:** `0x4F2083f5fBede34C2714aFfb3105539775f7FE64`  
**Function:** `execTransaction`
 
**Inner Call:** `Roles.scopeFunction(MANAGER_ROLE, USDC, transfer, conditions, options=0)`
 
**Conditions:** `USDC.transfer(timelock, amount)`  
**Encoded Calldata:** `TBD`
 
 ---
 
 ### Transaction 8: Zodiac scopeTarget for Timelock
 
**Target:** ENS Endowment Safe  
**Address:** `0x4F2083f5fBede34C2714aFfb3105539775f7FE64`  
**Function:** `execTransaction`
 
**Inner Call:** `Roles.scopeTarget(MANAGER_ROLE, timelock)`
 
**Encoded Calldata:** `TBD`
 
 ---
 
 ### Transaction 9: Zodiac allowFunction for ETH sends to Timelock
 
**Target:** ENS Endowment Safe  
**Address:** `0x4F2083f5fBede34C2714aFfb3105539775f7FE64`  
**Function:** `execTransaction`
 
**Inner Call:** `Roles.allowFunction(MANAGER_ROLE, timelock, 0x00000000, options=Send)`
 
**Encoded Calldata:** `TBD`
 
 ---
 
 ## Notes / Assumptions
 
* `TBD_REGISTRAR_MANAGER` will be the deterministic address derived from EIP-2470 + salt + init code.
* The Endowment Safe is the owner of the Roles modifier, so Zodiac updates are executed via Safe `execTransaction`.
 
 ## References
 
* EIP-2470 Singleton Factory: https://eips.ethereum.org/EIPS/eip-2470
* ENS Endowment Safe: `0x4F2083f5fBede34C2714aFfb3105539775f7FE64`
* ENS Timelock: `0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7`
