// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Payments} from "../src/Payments.sol";

contract GetInitDataScript is Script {
    function run() public pure {
        // Generate initialization data for Payments.initialize()
        bytes memory initData = abi.encodeWithSelector(
            Payments.initialize.selector
        );

        console.log("Initialization data:");
        console.logBytes(initData);

        // Also log it as hex string for easier copying
        console.log("Hex string:");
        console.log(vm.toString(initData));
    }
}
