// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {SkeenAMC} from "../src/SkeenAMC.sol";

/// @notice Deploy do SkeenAMC nas chains Anvil locais.
contract DeployAMC is Script {
    function run() external {
        address mailboxAddress = vm.envAddress("MAILBOX_ADDRESS");

        console2.log("[DEPLOY] Iniciando deploy do SkeenAMC");
        console2.log("[DEPLOY] Mailbox:            ", mailboxAddress);
        console2.log("[DEPLOY] Chain ID:           ", block.chainid);
        console2.log("[DEPLOY] RPC block:          ", block.number);

        vm.startBroadcast();

        SkeenAMC amc = new SkeenAMC(mailboxAddress);

        vm.stopBroadcast();

        console2.log("[DEPLOY] SkeenAMC deployado: ", address(amc));
        console2.log("[DEPLOY] globalClock inicial: ", amc.globalClock());
        console2.log("[DEPLOY] OK - contrato pronto para receber multicast()");
    }
}
