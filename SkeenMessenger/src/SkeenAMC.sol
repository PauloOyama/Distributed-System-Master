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

    // =========================================================================
    // Construtor
    // =========================================================================

    constructor(address _messenger, address _mailbox) {
        messenger = SkeenMessenger(payable(_messenger));
        mailbox   = _mailbox;
    }

    //TODO: FAZER TESTES 
    // =========================================================================
    // Funções
    // =========================================================================
    /// @notice Inicia o protocolo de Skeen para uma transação multicast.
    /// @param _txnData   Dados da transação (payload serializado)
    /// @param _destinations Array de domain IDs das chains participantes
    /// @param _mode      Cooperative (sem escrow) ou Adversarisal (com escrow)
    function multicast(
        bytes calldata _txnData,
        uint32[] calldata _destinations,
        Mode _mode
    ) external payable {
        require(_destinations.length >= 2, "Requer ao menos 2 destinations");

        bytes32 txnId = keccak256(_txnData);
        require(!txns[txnId].delivered, "Transacao ja entregue");
        require(txns[txnId].txnId == bytes32(0), "Transacao ja iniciada");

        TxnState storage t = txns[txnId];
        t.txnId       = txnId;
        t.phase       = Phase.START;
        t.destinations = _destinations;

        // Modo Adversarial: puxar ativos para escrow antes de propagar
        if (_mode == Mode.Adversarial) {
            _escrowAssets(_txnData);
        }

        // Envia START para todas as chains de destino
        bytes memory payload = abi.encode(txnId, _txnData, _destinations, uint8(_mode));
        for (uint256 i = 0; i < _destinations.length; i++) {
            _sendProtocolMessage(_destinations[i], Phase.START, payload);
        }

        emit TxnStarted(txnId, _destinations, block.timestamp);
        emit PhaseAdvanced(txnId, Phase.START);
    }


    /// @notice Ponto de entrada de todas as mensagens cross-chain (Hyperlane handle).
    ///         Somente o Mailbox pode chamar esta função (SR-01).
    function handle(
        uint32 _origin,
        bytes32 /*_sender*/,
        bytes calldata _message
    ) external payable {
        require(msg.sender == mailbox, "SkeenAMC: apenas o Mailbox pode chamar handle");

        (Phase phase, bytes32 txnId, bytes memory payload) =
            abi.decode(_message, (Phase, bytes32, bytes));

        if (phase == Phase.START) {
            _onStart(txnId, _origin, payload);
        } else if (phase == Phase.LOCAL_TS) {
            _onLocalTs(txnId, _origin, payload);
        } else if (phase == Phase.FINAL) {
            _onFinal(txnId, _origin, payload);
        } else if (phase == Phase.ACK) {
            _onAck(txnId, _origin, payload);
        }
    }


    
    // =========================================================================
    // Rodadas
    // =========================================================================
    
    /// @dev Rodada 1 — START recebido.
    ///      Incrementa o globalClock, atribui timestamp local e envia LOCAL_TS para todos.
    function _onStart(bytes32 _txnId, uint32 _origin, bytes memory _payload) internal {
        (, , uint32[] memory destinations, ) =
            abi.decode(_payload, (bytes32, bytes, uint32[], uint8));

        TxnState storage t = txns[_txnId];

        // Inicializar estado se ainda não existe (chain destino recebendo START)
        if (t.txnId == bytes32(0)) {
            t.txnId        = _txnId;
            t.destinations = destinations;
        }

        // Rodada 2a: atribuir timestamp local
        globalClock++;
        uint256 localTs = globalClock;

        t.phase = Phase.LOCAL_TS;
        emit PhaseAdvanced(_txnId, Phase.LOCAL_TS);
        emit LocalTsAssigned(_txnId, _origin, localTs, t.responseCount + 1);

        // Propagar LOCAL_TS para todas as chains (incluindo esta)
        bytes memory localTsPayload = abi.encode(_txnId, localTs, destinations);
        for (uint256 i = 0; i < destinations.length; i++) {
            _sendProtocolMessage(destinations[i], Phase.LOCAL_TS, localTsPayload);
        }
    }

/// @dev Rodada 2a/2b — LOCAL_TS recebido de uma chain.
    ///      Coleta timestamps. Quando todos chegarem, calcula max() e envia FINAL.
    function _onLocalTs(bytes32 _txnId, uint32 _origin, bytes memory _payload) internal {
        (, uint256 localTs, uint32[] memory destinations) =
            abi.decode(_payload, (bytes32, uint256, uint32[]));

        TxnState storage t = txns[_txnId];

        // SR-05: evitar LOCAL_TS duplicado da mesma chain
        require(!t.hasResponded[_origin], "Chain ja respondeu com LOCAL_TS");
        t.hasResponded[_origin] = true;

        t.localTimestamps.push(localTs);
        t.responseCount++;

        emit LocalTsAssigned(_txnId, _origin, localTs, t.responseCount);

        // Quando todos os LOCAL_TS chegaram: calcular FINAL
        if (t.responseCount == destinations.length) {
            uint256 finalTs = _max(t.localTimestamps);
            t.finalTimestamp = finalTs;
            t.phase = Phase.FINAL;

            emit FinalTsCalculated(_txnId, finalTs, destinations.length);
            emit PhaseAdvanced(_txnId, Phase.FINAL);

            // Distribuir FINAL para todas as chains
            bytes memory finalPayload = abi.encode(_txnId, finalTs, destinations);
            for (uint256 i = 0; i < destinations.length; i++) {
                _sendProtocolMessage(destinations[i], Phase.FINAL, finalPayload);
            }
        }
    }

/// @dev Rodada 3a — FINAL recebido.
    ///      Registra o timestamp final e envia ACK para todas as chains.
    function _onFinal(bytes32 _txnId, uint32 /*_origin*/, bytes memory _payload) internal {
        (, uint256 finalTs, uint32[] memory destinations) =
            abi.decode(_payload, (bytes32, uint256, uint32[]));

        TxnState storage t = txns[_txnId];
        t.finalTimestamp = finalTs;
        t.phase = Phase.ACK;

        // Obter o domain ID desta chain a partir do messenger
        uint32 localDomain = messenger.mailbox().localDomain();

        emit AckSent(_txnId, localDomain);
        emit PhaseAdvanced(_txnId, Phase.ACK);

        // Enviar ACK para todas as chains
        bytes memory ackPayload = abi.encode(_txnId, localDomain, destinations);
        for (uint256 i = 0; i < destinations.length; i++) {
            _sendProtocolMessage(destinations[i], Phase.ACK, ackPayload);
        }
    }

    /// @dev Rodada 3b — ACK recebido de uma chain.
    ///      Incrementa ackCount. Quando todos chegarem, entrega a transação.
    function _onAck(bytes32 _txnId, uint32 /*_origin*/, bytes memory _payload) internal {
        (, uint32 fromChain, uint32[] memory destinations) =
            abi.decode(_payload, (bytes32, uint32, uint32[]));

        TxnState storage t = txns[_txnId];

        // Evitar ACK duplicado da mesma chain
        require(!t.hasAcked[fromChain], "Chain ja enviou ACK");
        t.hasAcked[fromChain] = true;
        t.ackCount++;

        emit AckReceived(_txnId, fromChain, t.ackCount);

        // Quando todos os ACKs chegaram: entregar
        if (t.ackCount == destinations.length) {
            tryDeliver(_txnId);
        }
    }

        /// @dev Entrega a transação se todas as condições forem satisfeitas (SR-06).
    function tryDeliver(bytes32 _txnId) internal {
        TxnState storage t = txns[_txnId];

        require(!t.delivered,           "Transacao ja entregue");
        require(t.finalTimestamp > 0,   "Timestamp final nao definido");
        require(t.ackCount == t.destinations.length, "ACKs insuficientes");

        t.delivered = true;
        t.phase     = Phase.DELIVER;

        emit PhaseAdvanced(_txnId, Phase.DELIVER);
        emit TxnDelivered(_txnId, t.finalTimestamp);
    }

    // =========================================================================
    // Utils
    // =========================================================================

    /// @notice Retorna o timestamp final de uma transação
    function getFinalTimestamp(bytes32 _txnId) external view returns (uint256) {
        return txns[_txnId].finalTimestamp;
    }

    /// @dev Envia uma mensagem de protocolo via SkeenMessenger.
    function _sendProtocolMessage(
        uint32 _dest,
        Phase _phase,
        bytes memory _payload
    ) internal {
        bytes memory message = abi.encode(_phase, _payload);
        uint256 fee = messenger.mailbox().quoteDispatch(
            _dest,
            bytes32(uint256(uint160(address(this)))),
            message
        );
        messenger.sendMessage{value: fee}(
            _dest,
            address(this),
            string(message)
        );
    }
    
    /// @dev Calcula o máximo de um array de uint256.
    function _max(uint256[] storage arr) internal view returns (uint256 maxVal) {
        require(arr.length > 0, "Array vazio");
        maxVal = arr[0];
        for (uint256 i = 1; i < arr.length; i++) {
            if (arr[i] > maxVal) {
                maxVal = arr[i];
            }
        }
    }


    /// @dev Custódia de ativos no modo Adversarial (stub para extensão futura).
    function _escrowAssets(bytes calldata /*_txnData*/) internal {
        // Decodificar operações e chamar transferFrom
        // Implementação específica do caso de uso (ex: ERC-20 lockup)
    }

    /// @notice Retorna a fase atual de uma transação
    function getPhase(bytes32 _txnId) external view returns (Phase) {
        return txns[_txnId].phase;
    }


    /// @notice Retorna o número de ACKs recebidos para uma transação
    function getAckCount(bytes32 _txnId) external view returns (uint256) {
        return txns[_txnId].ackCount;
    }
    
    /// @notice Retorna se uma transação foi entregue
    function isDelivered(bytes32 _txnId) external view returns (bool) {
        return txns[_txnId].delivered;
    }

}