// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelloRelayer} from "../src/HelloRelayer.sol";

contract MockMailbox {
    bytes32 public lastRecipient;
    bytes public lastBody;
    uint32 public lastDestination;

    function dispatch(uint32 destinationDomain, bytes32 recipient, bytes calldata messageBody)
        external
        payable
        returns (bytes32)
    {
        lastDestination = destinationDomain;
        lastRecipient = recipient;
        lastBody = messageBody;
        return bytes32(uint256(1));
    }
}

contract HelloRelayerTest is Test {
    HelloRelayer public relayer;
    MockMailbox public mailbox;

    function setUp() public {
        mailbox = new MockMailbox();
        relayer = new HelloRelayer(address(mailbox));
    }

    function testSendHelloCallsMailbox() public {
        relayer.sendHello(1, address(0xBEEF), "hello from hyperlane");

        assertEq(mailbox.lastDestination(), 1);
        assertEq(mailbox.lastRecipient(), bytes32(uint256(uint160(0xBEEF))));
        assertEq(abi.decode(mailbox.lastBody(), (string)), "hello from hyperlane");
    }

    function testHandleStoresMessage() public {
        bytes memory payload = abi.encode("hello from hyperlane");

        vm.prank(address(mailbox));
        relayer.handle(1, bytes32(uint256(7)), payload);

        assertEq(relayer.lastMessage(), "hello from hyperlane");
        assertEq(relayer.lastNonce(), 1);
    }
}
