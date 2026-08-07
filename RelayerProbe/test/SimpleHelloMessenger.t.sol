// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {SimpleHelloMessenger} from "../src/SimpleHelloMessenger.sol";

contract MockMailbox {
    function dispatch(uint32, bytes32, bytes calldata) external payable returns (bytes32) {
        return bytes32(uint256(1));
    }
}

contract SimpleHelloMessengerTest is Test {
    SimpleHelloMessenger public messenger;
    MockMailbox public mailbox;

    function setUp() public {
        mailbox = new MockMailbox();
        messenger = new SimpleHelloMessenger(address(mailbox));
    }

    function testSendHelloEmitsMessage() public {
        messenger.sendHello(31338, address(0xBEEF));

        assertEq(messenger.lastMessage(), "");
    }

    function testHandleStoresHelloMessage() public {
        vm.prank(address(mailbox));
        messenger.handle(31337, bytes32(uint256(7)), abi.encode("OLA DA REDE A"));

        assertEq(messenger.lastMessage(), "OLA DA REDE A");
    }
}
