// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {SkeenAMC} from "../src/SkeenAMC.sol";
import {SkeenMessenger} from "../src/SkeenMessenger.sol";
import {IMailbox} from "@hyperlane-xyz/core/interfaces/IMailbox.sol";
import {IPostDispatchHook} from "@hyperlane-xyz/core/interfaces/hooks/IPostDispatchHook.sol";
import {IInterchainSecurityModule} from "@hyperlane-xyz/core/interfaces/IInterchainSecurityModule.sol";

// ─────────────────────────────────────────────────────────────────────────────
// Mock Mailbox para testes do SkeenAMC
// ─────────────────────────────────────────────────────────────────────────────
contract MockMailboxAMC is IMailbox {
    uint32 private _localDomain;
    uint32 private _nonce;
    bytes32 private _latestId;
    bytes[] public dispatchedMessages;

    constructor(uint32 domain) { _localDomain = domain; }

    function localDomain() external view returns (uint32) { return _localDomain; }
    function delivered(bytes32) external pure returns (bool) { return false; }
    function defaultIsm() external pure returns (IInterchainSecurityModule) {
        return IInterchainSecurityModule(address(0));
    }
    function defaultHook() external pure returns (IPostDispatchHook) {
        return IPostDispatchHook(address(0));
    }
    function requiredHook() external pure returns (IPostDispatchHook) {
        return IPostDispatchHook(address(0));
    }
    function latestDispatchedId() external view returns (bytes32) { return _latestId; }
    function nonce() external view returns (uint32) { return _nonce; }

    function dispatch(uint32 dest, bytes32 recipient, bytes calldata body)
        external payable returns (bytes32 messageId)
    {
        messageId = keccak256(abi.encode(dest, recipient, body, _nonce++));
        dispatchedMessages.push(body);
        _latestId = messageId;
        emit Dispatch(msg.sender, dest, recipient, body);
        emit DispatchId(messageId);
    }
    function dispatch(uint32 d, bytes32 r, bytes calldata b, bytes calldata)
        external payable returns (bytes32) { return this.dispatch(d, r, b); }
    function dispatch(uint32 d, bytes32 r, bytes calldata b, bytes calldata, IPostDispatchHook)
        external payable returns (bytes32) { return this.dispatch(d, r, b); }

    function quoteDispatch(uint32, bytes32, bytes calldata) external pure returns (uint256) { return 0; }
    function quoteDispatch(uint32, bytes32, bytes calldata, bytes calldata) external pure returns (uint256) { return 0; }
    function quoteDispatch(uint32, bytes32, bytes calldata, bytes calldata, IPostDispatchHook) external pure returns (uint256) { return 0; }

    function process(bytes calldata, bytes calldata) external payable {}
    function recipientIsm(address) external pure returns (IInterchainSecurityModule) {
        return IInterchainSecurityModule(address(0));
    }

    /// @dev Simula o relayer entregando uma mensagem a um destinatário.
    function deliverTo(address recipient, uint32 origin, bytes32 sender, bytes calldata body) external {
        (bool ok,) = recipient.call(
            abi.encodeWithSignature("handle(uint32,bytes32,bytes)", origin, sender, body)
        );
        require(ok, "MockMailboxAMC: delivery failed");
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// Suite de testes do SkeenAMC
// ─────────────────────────────────────────────────────────────────────────────
contract SkeenAMCTest is Test {

    uint32 constant CHAIN_A = 31337;
    uint32 constant CHAIN_B = 31338;
    address constant CALLER = address(0xCAFE);

    MockMailboxAMC mailboxA;
    MockMailboxAMC mailboxB;
    SkeenMessenger messengerA;
    SkeenMessenger messengerB;
    SkeenAMC amcA;
    SkeenAMC amcB;

    uint32[] destinations;
    bytes txnData;
    bytes32 txnId;

    function setUp() public {
        // Criar mailboxes mock
        mailboxA = new MockMailboxAMC(CHAIN_A);
        mailboxB = new MockMailboxAMC(CHAIN_B);

        // Criar messengers
        messengerA = new SkeenMessenger(address(mailboxA));
        messengerB = new SkeenMessenger(address(mailboxB));

        // Criar AMCs — mailbox é quem chama handle()
        amcA = new SkeenAMC(address(mailboxA));
        amcB = new SkeenAMC(address(mailboxB));

        // Dados padrão de teste
        destinations = new uint32[](2);
        destinations[0] = CHAIN_A;
        destinations[1] = CHAIN_B;

        txnData = abi.encode("test-transaction", uint256(42));
        txnId   =  keccak256(txnData);
        
    }

// =========================================================================
    // RODADA 1: START
    // =========================================================================

    function test_StartPhase_MulticastEmitsEvents() public {
        console2.log("=== test_StartPhase_MulticastEmitsEvents ===");

        vm.expectEmit(true, false, false, true);
        emit SkeenAMC.TxnStarted(txnId, destinations, block.timestamp);

        vm.expectEmit(true, false, false, true);
        emit SkeenAMC.PhaseAdvanced(txnId, SkeenAMC.Phase.START);

        vm.prank(CALLER);
        amcA.multicast(txnData, destinations, SkeenAMC.Mode.Cooperative);

        // console2.log("[txnId] ---> ", txnId);
        assertEq(uint8(amcA.getPhase(txnId)), uint8(SkeenAMC.Phase.START));
        console2.log("[START] txnId phase:", uint8(amcA.getPhase(txnId)));
        // console2.log("[START] txnId phase:", amcA.getPhase(txnId));
        console2.log("[START] Mensagens dispatch no Mailbox A:", mailboxA.nonce());
    }


    function test_StartPhase_DispatchesMsgToAllDestinations() public {
        console2.log("=== test_StartPhase_DispatchesMsgToAllDestinations ===");

        vm.prank(CALLER);
        amcA.multicast(txnData, destinations, SkeenAMC.Mode.Cooperative);

        // Cada destino recebe uma mensagem START
        assertEq(mailboxA.nonce(), uint32(destinations.length),
            "Mailbox deve ter dispatch para cada destino");
        console2.log("[START] Dispatches realizados:", mailboxA.nonce());
    }

    function test_StartPhase_RevertOnDuplicate() public {
        console2.log("=== test_StartPhase_RevertOnDuplicate ===");

        vm.prank(CALLER);
        amcA.multicast(txnData, destinations, SkeenAMC.Mode.Cooperative);

        vm.prank(CALLER);
        vm.expectRevert("Transacao ja iniciada");
        amcA.multicast(txnData, destinations, SkeenAMC.Mode.Cooperative);
        console2.log("[START] Revert em duplicata: OK");
    }

    function test_StartPhase_RevertOnSingleDestination() public {
        uint32[] memory single = new uint32[](1);
        single[0] = CHAIN_A;

        vm.expectRevert("Requer ao menos 2 destinations");
        vm.prank(CALLER);
        amcA.multicast(txnData, single, SkeenAMC.Mode.Cooperative);
    }

        // =========================================================================
    // RODADA 2: LOCAL_TS + FINAL
    // =========================================================================

    function test_OnStart_IncrementsGlobalClock() public {
        console2.log("=== test_OnStart_IncrementsGlobalClock ===");

        uint256 clockBefore = amcA.globalClock();

        // Simular o Mailbox entregando START para o AMC A
        bytes memory payload = abi.encode(txnId, txnData, destinations, uint8(SkeenAMC.Mode.Cooperative));
        bytes memory message  = abi.encode(SkeenAMC.Phase.START, txnId, payload);

        vm.prank(address(mailboxA));
        amcA.handle(CHAIN_B, bytes32(uint256(uint160(address(amcB)))), message);

        assertEq(amcA.globalClock(), clockBefore + 1, "globalClock deve incrementar");
        console2.log("[LOCAL_TS] globalClock antes:", clockBefore);
        console2.log("[LOCAL_TS] globalClock depois:", amcA.globalClock());
    }

    function test_LocalTs_FinalIsMaxOfTwo() public {
        console2.log("=== test_LocalTs_FinalIsMaxOfTwo ===");

        // Inicializar a txn no AMC A
        vm.prank(CALLER);
        amcA.multicast(txnData, destinations, SkeenAMC.Mode.Cooperative);

        // Simular recebimento do START (Rodada 1 → Rodada 2a)
        bytes memory startPayload = abi.encode(txnId, txnData, destinations, uint8(SkeenAMC.Mode.Cooperative));
        bytes memory startMsg     = abi.encode(SkeenAMC.Phase.START, txnId, startPayload);

        vm.prank(address(mailboxA));
        amcA.handle(CHAIN_A, bytes32(uint256(uint160(address(amcA)))), startMsg);
        uint256 ts1 = amcA.globalClock(); // timestamp atribuído pela chain A

        vm.prank(address(mailboxA));
        amcA.handle(CHAIN_B, bytes32(uint256(uint160(address(amcB)))), startMsg);
        // A segunda chamada de _onStart incrementa novamente o clock — simula chain B

        // Simular recebimento de LOCAL_TS da chain A (ts1) e da chain B (ts1+1)
        uint256 ts2 = ts1 + 5; // chain B tem clock maior
        // Receber LOCAL_TS da chain A
        vm.prank(address(mailboxA));
        amcA.handle(CHAIN_A, bytes32(uint256(uint160(address(amcA)))),
            abi.encode(SkeenAMC.Phase.LOCAL_TS, txnId, abi.encode(txnId, ts1, destinations)));

        // Receber LOCAL_TS da chain B (dispara cálculo do FINAL)
        vm.prank(address(mailboxA));
        amcA.handle(CHAIN_B, bytes32(uint256(uint160(address(amcB)))),
            abi.encode(SkeenAMC.Phase.LOCAL_TS, txnId, abi.encode(txnId, ts2, destinations)));

        assertEq(amcA.getFinalTimestamp(txnId), ts2,
            "finalTimestamp deve ser max(ts1, ts2)");
        console2.log("[FINAL] ts1:", ts1, " ts2:", ts2);
        console2.log("[FINAL] finalTimestamp:", amcA.getFinalTimestamp(txnId));
        assertEq(uint8(amcA.getPhase(txnId)), uint8(SkeenAMC.Phase.FINAL));
    }

        function test_LocalTs_NoDuplicateResponseAllowed() public {
        console2.log("=== test_LocalTs_NoDuplicateResponseAllowed ===");

        bytes memory payload = abi.encode(txnId, uint256(10), destinations);

        // Primeiro LOCAL_TS da chain A — OK
        vm.prank(address(mailboxA));
        amcA.handle(CHAIN_A, bytes32(0),
            abi.encode(SkeenAMC.Phase.LOCAL_TS, txnId, payload));

        // Segundo LOCAL_TS da mesma chain A — deve reverter (SR-05)
        vm.prank(address(mailboxA));
        vm.expectRevert("Chain ja respondeu com LOCAL_TS");
        amcA.handle(CHAIN_A, bytes32(0),
            abi.encode(SkeenAMC.Phase.LOCAL_TS, txnId, payload));
        console2.log("[LOCAL_TS] Revert em duplicata: OK");
    }

   // =========================================================================
    // RODADA 3: ACK + DELIVER
    // =========================================================================

    function test_FullProtocolFlow_TxnDelivered() public {
        console2.log("=== test_FullProtocolFlow_TxnDelivered ===");
        console2.log("[FLOW] Simulando protocolo completo em 2 chains...");

        uint256 finalTs = 42;

        // Simular FINAL recebido pela chain A
        bytes memory finalPayload = abi.encode(txnId, finalTs, destinations);
        vm.prank(address(mailboxA));
        amcA.handle(CHAIN_B, bytes32(0),
            abi.encode(SkeenAMC.Phase.FINAL, txnId, finalPayload));
        console2.log("[ACK] AckSent emitido pela chain A. Phase:", uint8(amcA.getPhase(txnId)));

        // Simular ACK da chain A chegando
        bytes memory ackFromA = abi.encode(txnId, CHAIN_A, destinations);
        vm.prank(address(mailboxA));
        amcA.handle(CHAIN_A, bytes32(0),
            abi.encode(SkeenAMC.Phase.ACK, txnId, ackFromA));
        console2.log("[ACK] ACK de Chain A recebido. ackCount:", amcA.getAckCount(txnId));

        // Simular ACK da chain B chegando — dispara tryDeliver()
        bytes memory ackFromB = abi.encode(txnId, CHAIN_B, destinations);

        vm.expectEmit(true, false, false, true);
        emit SkeenAMC.TxnDelivered(txnId, finalTs);

        vm.prank(address(mailboxA));
        amcA.handle(CHAIN_B, bytes32(0),
            abi.encode(SkeenAMC.Phase.ACK, txnId, ackFromB));
        console2.log("[ACK] ACK de Chain B recebido. ackCount:", amcA.getAckCount(txnId));

        // Verificações finais
        assertTrue(amcA.isDelivered(txnId), "Txn deve estar entregue");
        assertEq(amcA.getFinalTimestamp(txnId), finalTs, "finalTimestamp incorreto");
        assertEq(uint8(amcA.getPhase(txnId)), uint8(SkeenAMC.Phase.DELIVER));

        console2.log("[DELIVER] isDelivered:", amcA.isDelivered(txnId));
        console2.log("[DELIVER] finalTimestamp:", amcA.getFinalTimestamp(txnId));
        console2.log("[DELIVER] SUCESSO: protocolo de Skeen completo em 2 chains!");
    }

      function test_NoDuplicateDelivery() public {
        console2.log("=== test_NoDuplicateDelivery ===");

        uint256 finalTs = 10;
        bytes memory finalPayload = abi.encode(txnId, finalTs, destinations);

        vm.prank(address(mailboxA));
        amcA.handle(CHAIN_B, bytes32(0),
            abi.encode(SkeenAMC.Phase.FINAL, txnId, finalPayload));

        // Entregar os dois ACKs normalmente
        vm.prank(address(mailboxA));
        amcA.handle(CHAIN_A, bytes32(0),
            abi.encode(SkeenAMC.Phase.ACK, txnId, abi.encode(txnId, CHAIN_A, destinations)));

        vm.prank(address(mailboxA));
        amcA.handle(CHAIN_B, bytes32(0),
            abi.encode(SkeenAMC.Phase.ACK, txnId, abi.encode(txnId, CHAIN_B, destinations)));

        assertTrue(amcA.isDelivered(txnId));

        // Tentar ACK duplicado da chain B — deve reverter (SR-06 implícito)
        vm.prank(address(mailboxA));
        vm.expectRevert("Chain ja enviou ACK");
        amcA.handle(CHAIN_B, bytes32(0),
            abi.encode(SkeenAMC.Phase.ACK, txnId, abi.encode(txnId, CHAIN_B, destinations)));

        console2.log("[DELIVER] Nenhum segundo TxnDelivered emitido: OK");
    }
}