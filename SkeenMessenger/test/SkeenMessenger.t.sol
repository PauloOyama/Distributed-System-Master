// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {SkeenMessenger} from "../src/SkeenMessenger.sol";
import {IMailbox} from "@hyperlane-xyz/core/interfaces/IMailbox.sol";
import {IPostDispatchHook} from "@hyperlane-xyz/core/interfaces/hooks/IPostDispatchHook.sol";
import {IInterchainSecurityModule} from "@hyperlane-xyz/core/interfaces/IInterchainSecurityModule.sol";

// Mock Mailbox - Implementação da interface IMailbox para testes
contract MockMailbox is IMailbox {
    uint32 private _localDomain;
    bytes[] public dispatchedMessages;
    mapping(bytes32 => bool) private _delivered;
    uint32 private _nonce;
    bytes32 private _latestDispatchedId;

    constructor(uint32 domain) {
        _localDomain = domain;
    }

    function localDomain() external view returns (uint32) {
        return _localDomain;
    }

    function delivered(bytes32 messageId) external view returns (bool) {
        return _delivered[messageId];
    }

    function defaultIsm() external pure returns (IInterchainSecurityModule) {
        return IInterchainSecurityModule(address(0));
    }

    function defaultHook() external pure returns (IPostDispatchHook) {
        return IPostDispatchHook(address(0));
    }

    function requiredHook() external pure returns (IPostDispatchHook) {
        return IPostDispatchHook(address(0));
    }

    function latestDispatchedId() external view returns (bytes32) {
        return _latestDispatchedId;
    }

    function nonce() external view returns (uint32) {
        return _nonce;
    }

    function dispatch(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        bytes calldata messageBody
    ) external payable returns (bytes32 messageId) {
        messageId = keccak256(
            abi.encode(destinationDomain, recipientAddress, messageBody, block.timestamp, _nonce)
        );
        dispatchedMessages.push(messageBody);
        _latestDispatchedId = messageId;
        _nonce++;
        emit Dispatch(msg.sender, destinationDomain, recipientAddress, messageBody);
        emit DispatchId(messageId);
    }

    function dispatch(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        bytes calldata messageBody,
        bytes calldata /*defaultHookMetadata*/
    ) external payable returns (bytes32) {
        return this.dispatch(destinationDomain, recipientAddress, messageBody);
    }

    function dispatch(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        bytes calldata messageBody,
        bytes calldata /*customHookMetadata*/,
        IPostDispatchHook /*customHook*/
    ) external payable returns (bytes32) {
        return this.dispatch(destinationDomain, recipientAddress, messageBody);
    }

    function quoteDispatch(uint32, bytes32, bytes calldata) external pure returns (uint256) {
        return 0;
    }

    function quoteDispatch(uint32, bytes32, bytes calldata, bytes calldata) external pure returns (uint256) {
        return 0;
    }

    function quoteDispatch(uint32, bytes32, bytes calldata, bytes calldata, IPostDispatchHook) external pure returns (uint256) {
        return 0;
    }

    function process(bytes calldata, bytes calldata) external payable {}

    function recipientIsm(address) external pure returns (IInterchainSecurityModule) {
        return IInterchainSecurityModule(address(0));
    }

    // Helper para simular entrega de mensagem ao destinatário
    function deliverMessage(
        address recipient,
        uint32 origin,
        bytes32 sender,
        bytes calldata messageBody
    ) external {
        bytes32 messageId = keccak256(abi.encode(origin, sender, messageBody));
        _delivered[messageId] = true;
        IMailbox(recipient);
        (bool success,) = recipient.call(
            abi.encodeWithSignature("handle(uint32,bytes32,bytes)", origin, sender, messageBody)
        );
        require(success, "Delivery failed");
    }
}

contract SkeenMessengerTest is Test {
    uint32 constant CHAIN_A = 1;
    uint32 constant CHAIN_B = 137;
    address constant SENDER = address(0x1234);

    MockMailbox mailboxChainA;
    MockMailbox mailboxChainB;
    SkeenMessenger messengerOnChainA;
    SkeenMessenger messengerOnChainB;

    function setUp() public {
        mailboxChainA = new MockMailbox(CHAIN_A);
        mailboxChainB = new MockMailbox(CHAIN_B);
        messengerOnChainA = new SkeenMessenger(address(mailboxChainA));
        messengerOnChainB = new SkeenMessenger(address(mailboxChainB));
    }

    function test_FullMessageFlowAtoB() public {
        string memory message = "Hello from Chain A!";
        bytes32 senderBytes = bytes32(uint256(uint160(address(messengerOnChainA))));

        // ── ENVIO (Chain A) ──────────────────────────────────────────────
        console2.log("=== ENVIO (Chain A -> Chain B) ===");
        console2.log("Remetente:      ", SENDER);
        console2.log("Messenger A:    ", address(messengerOnChainA));
        console2.log("Mailbox A:      ", address(mailboxChainA));
        console2.log("Destino domain: ", CHAIN_B);
        console2.log("Destinatario:   ", address(messengerOnChainB));
        console2.log("Mensagem:       ", message);

        vm.prank(SENDER);
        messengerOnChainA.sendMessage(CHAIN_B, address(messengerOnChainB), message);

        bytes32 messageId = mailboxChainA.latestDispatchedId();
        console2.log("Message ID gerado:");
        console2.logBytes32(messageId);
        console2.log("Mensagens no mailbox A:", mailboxChainA.nonce());

        assertGt(uint256(messageId), 0, "Message ID invalido");

        // ── ENTREGA (Chain B) ────────────────────────────────────────────
        console2.log("");
        console2.log("=== ENTREGA (Relayer -> Chain B) ===");
        console2.log("Mailbox B:      ", address(mailboxChainB));
        console2.log("Messenger B:    ", address(messengerOnChainB));
        console2.log("Origin domain:  ", CHAIN_A);
        console2.log("Sender bytes32:");
        console2.logBytes32(senderBytes);

        vm.expectEmit(true, true, true, true);
        emit SkeenMessenger.MessageReceived(CHAIN_A, senderBytes, message);

        mailboxChainB.deliverMessage(
            address(messengerOnChainB),
            CHAIN_A,
            senderBytes,
            abi.encode(message)
        );

        console2.log("Mensagem entregue com sucesso na Chain B!");
        console2.log("Evento MessageReceived emitido com a mensagem: ", message);
    }

    function test_HandleRevertsIfNotMailbox() public {
        bytes32 senderBytes = bytes32(uint256(uint160(address(messengerOnChainA))));

        vm.prank(address(0xBEEF));
        vm.expectRevert("Only mailbox can call handle");
        messengerOnChainB.handle(CHAIN_A, senderBytes, abi.encode("test"));
    }
}
