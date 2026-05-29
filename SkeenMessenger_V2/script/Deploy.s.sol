// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {SkeenMessenger} from "../src/SkeenMessenger.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Substitua pelo endereço do Mailbox da rede desejada
        address mailboxAddress = vm.envAddress("MAILBOX_ADDRESS");

        SkeenMessenger messenger = new SkeenMessenger(mailboxAddress);

        vm.stopBroadcast();
    }
}
