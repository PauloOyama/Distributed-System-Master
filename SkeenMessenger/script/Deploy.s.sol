// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {SkeenMessenger} from "../src/SkeenMessenger.sol";

contract Deploy is Script {
    function run() external {
        address mailboxAddress = vm.envAddress("MAILBOX_ADDRESS");
        vm.startBroadcast();

        new SkeenMessenger(mailboxAddress);

        vm.stopBroadcast();
    }
}
