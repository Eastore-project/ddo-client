// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {FilecoinPayV1} from "filecoin-pay/FilecoinPayV1.sol";

contract DeployPaymentsScript is Script {
    function run() public {
        // Set higher gas limit for Filecoin network
        vm.txGasPrice(1000000000); // 1 gwei
        vm.startBroadcast();

        // Deploy the payments contract directly (no proxy)
        FilecoinPayV1 paymentsContract = new FilecoinPayV1();
        console.log(
            "FilecoinPayV1 deployed at:",
            address(paymentsContract)
        );

        vm.stopBroadcast();

        // Log final deployment information
        console.log("");
        console.log("=== DEPLOYMENT SUMMARY ===");
        console.log("FilecoinPayV1 address:", address(paymentsContract));
        console.log("Deployer:", msg.sender);
    }
}
