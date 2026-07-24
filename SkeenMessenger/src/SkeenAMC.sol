// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IMessageRecipient} from "@hyperlane-xyz/core/interfaces/IMessageRecipient.sol";
import {SkeenMessenger} from "./SkeenMessenger.sol";

contract SkeenAMC is IMessageRecipient {

    enum Mode { Cooperative, Adversarial }

    enum Phase { START, LOCAL_TS, FINAL, ACK, DELIVER }


    struct TxnState {
        bytes32   txnId;
        uint32[]  destinations;        // chains participantes (domain IDs)
        uint256[] localTimestamps;     // um por chain, indexado por posição em destinations
        uint256   finalTimestamp;      // max(localTimestamps) — mesmo em todas as chains
        Phase     phase;
        uint256   responseCount;       // quantas chains responderam com LOCAL_TS
        uint256   ackCount;            // quantas chains enviaram ACK
        bool      delivered;
        mapping(uint32 => bool) hasResponded;  // evita LOCAL_TS duplicado por chain
        mapping(uint32 => bool) hasAcked;      // evita ACK duplicado por chain
    }

    /// @notice Relógio lógico  desta chain (incrementado a cada START recebido)
    uint256 public globalClock;

    /// @notice Endereço do SkeenMessenger usado como transporte cross-chain
    SkeenMessenger public immutable messenger;

    /// @notice Endereço do Mailbox Hyperlane (para verificação de origem)
    address public immutable mailbox;

    /// @notice Mapeamento de txnId para estado da transação
    mapping(bytes32 => TxnState) private txns;

    //=====
    //Emissões
    //=====
    
     /// @notice Emitido quando multicast() é chamado (início do protocolo)
    event TxnStarted(bytes32 indexed txnId, uint32[] destinations, uint256 timestamp);

    /// @notice Emitido a cada transição de fase
    event PhaseAdvanced(bytes32 indexed txnId, Phase phase);

    /// @notice Emitido quando esta chain atribui seu timestamp local (Rodada 2a)
    event LocalTsAssigned(bytes32 indexed txnId, uint32 indexed origin, uint256 localTs, uint256 responseCount);

    /// @notice Emitido quando todos os LOCAL_TS chegaram e o FINAL foi calculado (Rodada 2b)
    event FinalTsCalculated(bytes32 indexed txnId, uint256 finalTs, uint256 participantCount);

    /// @notice Emitido quando esta chain envia ACK (Rodada 3)
    event AckSent(bytes32 indexed txnId, uint32 indexed fromChain);

    /// @notice Emitido a cada ACK recebido
    event AckReceived(bytes32 indexed txnId, uint32 indexed fromChain, uint256 ackCount);

    /// @notice Emitido quando a transação é entregue (após todos os ACKs)
    event TxnDelivered(bytes32 indexed txnId, uint256 finalTs);
}