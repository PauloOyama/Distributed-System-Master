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

    function test_SendMessageFromChainA() public {
        string memory message = "Hello from Chain A!";

        vm.prank(SENDER);
        messengerOnChainA.sendMessage(CHAIN_B, address(messengerOnChainB), message);

        bytes32 dispatchedId = mailboxChainA.latestDispatchedId();
        assertGt(uint256(dispatchedId), 0, "Message ID should be valid");
        assertEq(mailboxChainA.dispatchedMessages(0).length, abi.encode(message).length, "Message body mismatch");

        console2.log("Message sent with ID:");
        console2.logBytes32(dispatchedId);
    }

    function test_ReceiveMessageOnChainB() public {
        string memory message = "Hello from Chain A!";
        bytes32 senderBytes = bytes32(uint256(uint160(address(messengerOnChainA))));

        vm.expectEmit(true, true, true, true);
        emit SkeenMessenger.MessageReceived(CHAIN_A, senderBytes, message);

        mailboxChainB.deliverMessage(
            address(messengerOnChainB),
            CHAIN_A,
            senderBytes,
            abi.encode(message)
        );
    }

    function test_HandleRevertsIfNotMailbox() public {
        bytes32 senderBytes = bytes32(uint256(uint160(address(messengerOnChainA))));

        vm.prank(address(0xBEEF));
        vm.expectRevert("Only mailbox can call handle");
        messengerOnChainB.handle(CHAIN_A, senderBytes, abi.encode("test"));
    }
}
