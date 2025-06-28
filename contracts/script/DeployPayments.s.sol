// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Payments} from "../src/Payments.sol";

contract DeployPaymentsScript is Script {
    function run() public {
        // Set higher gas limit for Filecoin network
        vm.txGasPrice(1000000000); // 1 gwei
        vm.startBroadcast();

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
        ERC1967Proxy proxy = new ERC1967Proxy(address(paymentsImpl), initData);
        console.log("Payments proxy deployed at:", address(proxy));

        // Cast proxy to Payments interface to verify it works
        Payments paymentsContract = Payments(address(proxy));

        // Verify the proxy is working by calling a view function
        address owner = paymentsContract.owner();
        console.log("Payments contract owner (should be deployer):", owner);
        console.log("Deployer address:", msg.sender);

        vm.stopBroadcast();

        // Log final deployment information
        console.log("");
        console.log("=== DEPLOYMENT SUMMARY ===");
        console.log("Implementation address:", address(paymentsImpl));
        console.log("Proxy address:", address(proxy));
        console.log("Use the proxy address for all interactions");
        console.log("Owner:", owner);
    }
}
