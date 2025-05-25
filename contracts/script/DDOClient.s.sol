// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {DDOClient} from "../src/DDOClient.sol";

contract DDOClientScript is Script {
    DDOClient public ddoClient;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        ddoClient = new DDOClient();

        console.log("DDOClient deployed at:", address(ddoClient));

        vm.stopBroadcast();
    }
}
