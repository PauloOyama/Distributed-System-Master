// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {SkeenMessenger} from "../src/SkeenMessenger.sol";
import {
    IMailbox,
    IPostDispatchHook
} from "@hyperlane-xyz/core/interfaces/IMailbox.sol";

// Mock Mailbox - Simulates Hyperlane Mailbox
contract MockMailbox is IMailbox {
    uint32 public localDomain;
    bytes[] public dispatchedMessages;

    event Dispatch(
        uint32 indexed destinationDomain,
        bytes32 indexed sender,
        bytes message,
        bytes32 indexed messageId
    );

    constructor(uint32 _domain) {
        localDomain = _domain;
    }

    function dispatch(
        uint32 _destinationDomain,
        bytes32 _recipientAddress,
        bytes calldata _messageBody
    ) external returns (bytes32) {
        bytes32 messageId = keccak256(
            abi.encode(
                _destinationDomain,
                _recipientAddress,
                _messageBody,
                block.timestamp
            )
        );
        dispatchedMessages.push(_messageBody);
        emit Dispatch(
            _destinationDomain,
            bytes32(uint256(uint160(msg.sender))),
            _messageBody,
            messageId
        );
        return messageId;
    }

    function dispatch(
        uint32 _destinationDomain,
        bytes32 _recipientAddress,
        bytes calldata _messageBody,
        bytes calldata _hookMetadata,
        IPostDispatchHook _hook
    ) external returns (bytes32) {
        return this.dispatch(_destinationDomain, _recipientAddress, _messageBody);
    }

    function process(
        bytes calldata,
        bytes calldata
    ) external pure returns (bytes32) {
        return bytes32(0);
    }

    function count() external pure returns (uint32) {
        return 0;
    }
    function latest() external pure returns (uint32) {
        return 0;
    }
    function safeAccess(bytes32, uint32) external pure returns (bytes memory) {
        return "";
    }
    function recipientIsSmartContract(
        bytes32,
        address
    ) external pure returns (bool) {
        return true;
    }
    function quoteDispatch(
        uint32,
        bytes32,
        bytes calldata
    ) external pure returns (uint256) {
        return 0;
    }
    function quoteDispatch(
        uint32,
        bytes32,
        bytes calldata,
        bytes calldata,
        IPostDispatchHook
    ) external pure returns (uint256) {
        return 0;
    }
}

contract SkeenMessengerTest is Test {
    uint32 constant CHAIN_A = 1;
    uint32 constant CHAIN_B = 137;
    address constant SENDER = address(0x1234);
    address constant RELAYER = address(0xDEAD);

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
        vm.prank(SENDER);
        bytes memory messageData = "Hello from Chain A!";
        bytes32 messageId = messengerOnChainA.sendMessage(SENDER,CHAIN_B, messageData);

        assertGt(uint256(messageId), 0, "Message ID should be valid");
        assertEq(
            mailboxChainA.dispatchedMessages().length,
            1,
            "Should have 1 dispatched message"
        );
        console2.log("Message sent with ID:");
        console2.logBytes32(messageId);
    }

    function test_CrossChainMessageDelivery() public {
        // Step 1: Simulate Chain A sending message
        vm.prank(SENDER);
        bytes memory originalMessage = "Cross-chain delivery test!";
        bytes32 messageId = messengerOnChainA.sendMessage(
            CHAIN_B,
            originalMessage
        );

        bytes memory dispatchedData = mailboxChainA.dispatchedMessages(
            mailboxChainA.dispatchedMessages().length - 1
        );
        console2.log("Step 1: Message dispatched from Chain A");

        // Step 2: Simulate Relayer picking up and delivering to Chain B
        vm.prank(RELAYER);
        messengerOnChainB.handle(
            CHAIN_A,
            addressToBytes32(address(messengerOnChainA)),
            dispatchedData
        );

        // Step 3: Verify message was received
        bytes memory receivedMessage = messengerOnChainB.getLastMessage(
            CHAIN_A
        );
        assertEq(
            keccak256(receivedMessage),
            keccak256(originalMessage),
            "Messages should match"
        );
        console2.log("Step 2: Message delivered to Chain B");
    }

    function test_HandleRequiresMailboxCaller() public {
        bytes memory dispatchedData = abi.encode(SENDER, "Test message");
        vm.expectRevert("Caller must be mailbox");
        messengerOnChainB.handle(
            CHAIN_A,
            addressToBytes32(address(messengerOnChainA)),
            dispatchedData
        );
    }

    function test_MultipleMessagesFromSameOrigin() public {
        for (uint i = 0; i < 3; i++) {
            vm.prank(SENDER);
            bytes memory msg = abi.encode("Message", i);
            messengerOnChainA.sendMessage(CHAIN_B, msg);

            bytes memory lastDispatched = mailboxChainA.dispatchedMessages(
                mailboxChainA.dispatchedMessages().length - 1
            );
            vm.prank(RELAYER);
            messengerOnChainB.handle(
                CHAIN_A,
                addressToBytes32(address(messengerOnChainA)),
                lastDispatched
            );
        }

        bytes memory lastMsg = messengerOnChainB.getLastMessage(CHAIN_A);
        (string memory prefix, uint256 num) = abi.decode(
            lastMsg,
            (string, uint256)
        );
        assertEq(num, 2, "Last message should be #2");
        console2.log("Multiple messages test passed");
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}
