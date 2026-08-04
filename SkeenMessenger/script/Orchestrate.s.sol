// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {SkeenAMC} from "../src/SkeenAMC.sol";

contract Orchestrate is Script {

    uint32 constant DOMAIN_A = 31337;
    uint32 constant DOMAIN_B = 31338;
    uint32 constant DOMAIN_C = 31339;

    function run() external {
        address amcA        = vm.envAddress("AMC_A");
        address amcB        = vm.envAddress("AMC_B");
        address amcC        = vm.envAddress("AMC_C");

        // Usa PRIVATE_KEY se disponivel; senao usa --private-key passada via CLI
        uint256 deployerKey  = vm.envOr("PRIVATE_KEY", uint256(0));
        address deployerAddr = deployerKey != 0 ? vm.addr(deployerKey) : msg.sender;

        SkeenAMC skeenAMC = SkeenAMC(payable(amcA));

        uint32[] memory destinations = new uint32[](3);
        destinations[0] = DOMAIN_A;
        destinations[1] = DOMAIN_B;
        destinations[2] = DOMAIN_C;

        bytes memory txnData = abi.encode(
            "skeen-txn-v1",
            block.timestamp,
            deployerAddr
        );
        bytes32 txnId = keccak256(txnData);
        vm.writeFile("script/.last_txn_id", Strings.toHexString(uint256(txnId), 32));

        console2.log("=================================================================");
        console2.log("[ORCHESTRATOR] Protocolo de Skeen - Simulacao Local 3-chain");
        console2.log("=================================================================");
        console2.log("[ORCHESTRATOR] Chain A (AMC):  ", amcA);
        console2.log("[ORCHESTRATOR] Chain B (AMC):  ", amcB);
        console2.log("[ORCHESTRATOR] Chain C (AMC):  ", amcC);
        console2.log("[ORCHESTRATOR] Destinations:   [31337, 31338, 31339]");
        console2.log("[ORCHESTRATOR] txnId:");
        console2.logBytes32(txnId);
        console2.log("[ORCHESTRATOR] Block:          ", block.number);
        console2.log("[ORCHESTRATOR] Timestamp:      ", block.timestamp);
        console2.log("");

        console2.log("--- RODADA 1: START ---");
        console2.log("[START] Chamando multicast() na Chain A...");

        if (deployerKey != 0) {
            vm.startBroadcast(deployerKey);
        } else {
            vm.startBroadcast();
        }
        skeenAMC.multicast{value: 0}(txnData, destinations, SkeenAMC.Mode.Cooperative);
        vm.stopBroadcast();

        console2.log("[START] multicast() enviado. Phase:", uint8(skeenAMC.getPhase(txnId)));
        console2.log("[START] Aguardando relayer entregar START para as chains B e C...");
        console2.log("[START] Verifique:");
        console2.log("  cast logs --rpc-url http://localhost:8546 --address", amcB, "--from-block 0");
        console2.log("  cast logs --rpc-url http://localhost:8547 --address", amcC, "--from-block 0");
        console2.log("");

        console2.log("--- RODADA 2: LOCAL_TS + FINAL ---");
        console2.log("[LOCAL_TS] Cada chain atribuira seu globalClock como timestamp local.");
        console2.log("[LOCAL_TS] globalClock Chain A:", skeenAMC.globalClock());
        console2.log("[LOCAL_TS] Aguardando LOCAL_TS de todas as chains...");
        console2.log("[LOCAL_TS] Monitor Chain A: cast logs --rpc-url http://localhost:8545 --address", amcA, "--from-block 0");
        console2.log("[LOCAL_TS] Monitor Chain B: cast logs --rpc-url http://localhost:8546 --address", amcB, "--from-block 0");
        console2.log("[LOCAL_TS] Monitor Chain C: cast logs --rpc-url http://localhost:8547 --address", amcC, "--from-block 0");
        console2.log("");

        console2.log("[FINAL] Quando todos os LOCAL_TS chegarem, FinalTsCalculated sera emitido.");
        console2.log("[FINAL] finalTimestamp atual:", skeenAMC.getFinalTimestamp(txnId));
        console2.log("");

        console2.log("--- RODADA 3: ACK ---");
        console2.log("[ACK] Cada chain enviara ACK apos receber FINAL.");
        console2.log("[ACK] ackCount atual:", skeenAMC.getAckCount(txnId));
        console2.log("[ACK] Quando ackCount == 3, tryDeliver() sera chamado.");
        console2.log("");

        console2.log("--- DELIVER ---");
        console2.log("[DELIVER] isDelivered Chain A:", skeenAMC.isDelivered(txnId));
        console2.log("[DELIVER] Aguardando entrega em todas as chains...");
        console2.log("");

        console2.log("=================================================================");
        console2.log("[ORCHESTRATOR] Para monitorar o protocolo em tempo real:");
        console2.log("");
        console2.log("  # Todos os eventos da Chain A:");
        console2.log("  cast logs --rpc-url http://localhost:8545");
        console2.log("    --address", amcA);
        console2.log("    --from-block 0");
        console2.log("");
        console2.log("  # Todos os eventos da Chain B:");
        console2.log("  cast logs --rpc-url http://localhost:8546");
        console2.log("    --address", amcB);
        console2.log("    --from-block 0");
        console2.log("");
        console2.log("  # Todos os eventos da Chain C:");
        console2.log("  cast logs --rpc-url http://localhost:8547");
        console2.log("    --address", amcC);
        console2.log("    --from-block 0");
        console2.log("");
        console2.log("  # Verificar entrega na Chain A:");
        console2.log("  cast call <AMC_A> \"isDelivered(bytes32)(bool)\" <txnId> --rpc-url http://localhost:8545");
        console2.log("  AMC_A:", amcA);
        console2.log("=================================================================");
    }
}
