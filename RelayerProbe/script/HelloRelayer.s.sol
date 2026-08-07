// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {HelloRelayer} from "../src/HelloRelayer.sol";
import {HelloRecipient} from "../src/HelloRecipient.sol";

contract HelloRelayerScript is Script {
    HelloRelayer public sender;
    HelloRecipient public recipient;

    function run() public {
        vm.startBroadcast();

        recipient = new HelloRecipient();
        sender = new HelloRelayer(address(recipient));

        vm.stopBroadcast();
    }
}
