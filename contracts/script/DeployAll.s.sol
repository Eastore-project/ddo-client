// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Payments} from "../src/Payments.sol";
import {DDOClient} from "../src/DDOClient.sol";

contract DeployAllScript is Script {
    function run() public {
        vm.startBroadcast();

        console.log("=== STARTING DEPLOYMENT ===");
        console.log("Deployer address:", msg.sender);
        console.log("");

        // 1. Deploy Payments Contract (with UUPS proxy)
        console.log("1. Deploying Payments Contract...");

        // Deploy the implementation contract
        Payments paymentsImpl = new Payments();
        console.log(
            "Payments implementation deployed at:",
            address(paymentsImpl)
        );

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            Payments.initialize.selector
        );

        // Deploy the ERC1967 proxy with the implementation and initialization data
        ERC1967Proxy paymentsProxy = new ERC1967Proxy(
            address(paymentsImpl),
            initData
        );
        console.log("Payments proxy deployed at:", address(paymentsProxy));

        // Cast proxy to Payments interface
        Payments paymentsContract = Payments(address(paymentsProxy));

        // Verify the proxy is working
        address paymentsOwner = paymentsContract.owner();
        console.log("Payments contract owner:", paymentsOwner);
        console.log("");

        // 2. Deploy DDOClient Contract
        console.log("2. Deploying DDOClient Contract...");
        DDOClient ddoClient = new DDOClient();
        console.log("DDOClient deployed at:", address(ddoClient));
        console.log("");

        // 3. Connect DDOClient to Payments Contract
        console.log("3. Connecting DDOClient to Payments Contract...");
        ddoClient.setPaymentsContract(address(paymentsProxy));
        console.log("DDOClient successfully connected to Payments contract");
        console.log("");

        vm.stopBroadcast();

        // 4. Final Summary
        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("Payments Implementation:", address(paymentsImpl));
        console.log("Payments Proxy (USE THIS):", address(paymentsProxy));
        console.log("DDOClient:", address(ddoClient));
        console.log("Deployer/Owner:", msg.sender);
        console.log("");
        console.log("All contracts deployed and connected successfully!");
        console.log("Use the Payments PROXY address for all interactions:");
        console.log("Proxy Address:", address(paymentsProxy));
    }
}
