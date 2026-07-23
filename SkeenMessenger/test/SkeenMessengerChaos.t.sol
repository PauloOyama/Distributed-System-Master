// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {SkeenMessenger} from "../src/SkeenMessenger.sol";
import {TestMailbox} from "@hyperlane-xyz/core/test/TestMailbox.sol";
import {TestIsm} from "@hyperlane-xyz/core/test/TestIsm.sol";
import {TestPostDispatchHook} from "@hyperlane-xyz/core/test/TestPostDispatchHook.sol";
import {TypeCasts} from "@hyperlane-xyz/core/libs/TypeCasts.sol";

contract SkeenMessengerChaosTest is Test {
    using TypeCasts for address;
    using TypeCasts for bytes32;

    uint32 constant CHAIN_A = 1;
    uint32 constant CHAIN_B = 137;
    address constant SENDER = address(0xAAAA);

    TestMailbox mailboxA;
    TestMailbox mailboxB;
    TestIsm ism;
    TestPostDispatchHook hook;
    SkeenMessenger messengerA;
    SkeenMessenger messengerB;

    function setUp() public {
        ism  = new TestIsm();
        hook = new TestPostDispatchHook();

        mailboxA = new TestMailbox(CHAIN_A);
        mailboxA.initialize(address(this), address(ism), address(hook), address(hook));

        mailboxB = new TestMailbox(CHAIN_B);
        mailboxB.initialize(address(this), address(ism), address(hook), address(hook));

        messengerA = new SkeenMessenger(address(mailboxA));
        messengerB = new SkeenMessenger(address(mailboxB));
    }

    /// Build the formatted Hyperlane message that mailboxB.process() expects.
    function _buildMessage(uint256 nonce, string memory text) internal view returns (bytes memory) {
        bytes memory body = abi.encode(SENDER, nonce, text);
        return mailboxB.buildInboundMessage(
            CHAIN_A,
            address(messengerB).addressToBytes32(),
            address(messengerA).addressToBytes32(),
            body
        );
    }

    /// Deliver a pre-built message through the official mailboxB.process().
    function _deliver(bytes memory message) internal {
        mailboxB.process("", message);
    }

    // ── Chaos Test ───────────────────────────────────────────────────────────

    function test_ChaosOutOfOrderDelivery() public {
        // ── SEND M1, M2, M3 from Chain A ─────────────────────────────────────
        vm.startPrank(SENDER);
        uint256 fee = messengerA.quoteDispatch(CHAIN_B, address(messengerB), "M1");
        vm.deal(SENDER, fee * 3);

        messengerA.sendMessage{value: fee}(CHAIN_B, address(messengerB), "M1");
        messengerA.sendMessage{value: fee}(CHAIN_B, address(messengerB), "M2");
        messengerA.sendMessage{value: fee}(CHAIN_B, address(messengerB), "M3");
        vm.stopPrank();

        console2.log("=== CHAOS: entregando M3, M2, M1 fora de ordem ===");

        // senderKey = originalSender embutido no body (SENDER, não messengerA)
        bytes32 senderKey = bytes32(uint256(uint160(SENDER)));

        // Nonces emitidos: SENDER incrementa nextOutgoingNonce => 1, 2, 3
        bytes memory msgM1 = _buildMessage(1, "M1");
        bytes memory msgM2 = _buildMessage(2, "M2");
        bytes memory msgM3 = _buildMessage(3, "M3");

        // ── Entrega M3 primeiro (deve ir para o buffer) ───────────────────────
        console2.log("Entregando M3 (nonce=3) -> deve ir para o buffer");
        _deliver(msgM3);
        assertEq(messengerB.nextExpectedNonce(CHAIN_A, senderKey), 0, "M3 nao deve avancar o nonce esperado");
        console2.log("Actual Nonce: ",messengerB.nextExpectedNonce(CHAIN_A, senderKey));

        // ── Entrega M2 (deve ir para o buffer) ───────────────────────────────
        console2.log("Entregando M2 (nonce=2) -> deve ir para o buffer");
        _deliver(msgM2);
        assertEq(messengerB.nextExpectedNonce(CHAIN_A, senderKey), 0, "M2 nao deve avancar o nonce esperado");
        console2.log("Actual Nonce: ",messengerB.nextExpectedNonce(CHAIN_A, senderKey));
        // ── Entrega M1 (deve processar M1, M2 e M3 em cascata) ───────────────
        console2.log("Entregando M1 (nonce=1) -> deve processar M1+M2+M3 em cascata");

        vm.expectEmit(true, true, false, true);
        emit SkeenMessenger.MessageReceived(CHAIN_A, address(messengerA).addressToBytes32(), "M1");

        vm.expectEmit(true, true, false, true);
        emit SkeenMessenger.MessageReceived(CHAIN_A, address(messengerA).addressToBytes32(), "M2");

        vm.expectEmit(true, true, false, true);
        emit SkeenMessenger.MessageReceived(CHAIN_A, address(messengerA).addressToBytes32(), "M3");

        _deliver(msgM1);
        console2.log("Actual Nonce: ",messengerB.nextExpectedNonce(CHAIN_A, senderKey));
        // console2.log("Actual Buffer: ",messengerB._buffer(abi.decode(msgM2, (address, uint256, string))));

        // ── Verificações de estado ────────────────────────────────────────────
        assertEq(
            messengerB.nextExpectedNonce(CHAIN_A, senderKey),
            3,
            "nextExpectedNonce deve ser 3 apos processar M1+M2+M3"
        );

        console2.log("SUCESSO: M1, M2 e M3 processadas na ordem correta!");
    }
}
