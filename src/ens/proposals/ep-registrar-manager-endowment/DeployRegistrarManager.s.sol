// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Script, console2 } from "@forge-std/src/Script.sol";

import { ENSConstants } from "@ens/Constants.sol";
import { RegistrarManager } from
    "@ens/proposals/ep-registrar-manager-endowment/contracts/RegistrarManager.sol";

/// @title DeployRegistrarManager
/// @notice Deploys the RegistrarManager contract with the ENS Timelock as owner and
///         the Endowment Safe as the ETH destination.
/// @dev Usage:
///   forge script script/DeployRegistrarManager.s.sol \
///     --rpc-url $MAINNET_RPC_URL \
///     --broadcast \
///     --verify \
///     --etherscan-api-key $API_KEY_ETHERSCAN
contract DeployRegistrarManager is Script {
    function run() external returns (RegistrarManager manager) {
        vm.startBroadcast();
        manager = new RegistrarManager(ENSConstants.TIMELOCK, ENSConstants.ENDOWMENT_SAFE);
        vm.stopBroadcast();

        console2.log("RegistrarManager deployed at:", address(manager));
        console2.log("  owner:       ", ENSConstants.TIMELOCK);
        console2.log("  destination: ", ENSConstants.ENDOWMENT_SAFE);
    }
}
