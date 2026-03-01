// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {FilecoinPayV1} from "filecoin-pay/FilecoinPayV1.sol";
import {DDOClient} from "../src/DDOClient.sol";

contract DeployAllScript is Script {
    function run() public {
        vm.startBroadcast();

        console.log("=== STARTING DEPLOYMENT ===");
        console.log("Deployer address:", msg.sender);
        console.log("");

        // 1. Deploy Payments Contract (direct, no proxy)
        console.log("1. Deploying FilecoinPayV1 Contract...");

        FilecoinPayV1 paymentsContract = new FilecoinPayV1();
        console.log(
            "FilecoinPayV1 deployed at:",
            address(paymentsContract)
        );
        console.log("");

        // 2. Deploy DDOClient Contract
        console.log("2. Deploying DDOClient Contract...");
        DDOClient ddoClient = new DDOClient();
        console.log("DDOClient deployed at:", address(ddoClient));
        console.log("");

        // 3. Connect DDOClient to Payments Contract
        console.log("3. Connecting DDOClient to Payments Contract...");
        ddoClient.setPaymentsContract(address(paymentsContract));
        console.log("DDOClient successfully connected to Payments contract");
        console.log("");

        vm.stopBroadcast();

        // 4. Final Summary
        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("FilecoinPayV1:", address(paymentsContract));
        console.log("DDOClient:", address(ddoClient));
        console.log("Deployer/Owner:", msg.sender);
        console.log("");
        console.log("All contracts deployed and connected successfully!");
    }
}
