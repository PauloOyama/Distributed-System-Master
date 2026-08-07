// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelloRelayer} from "../src/HelloRelayer.sol";

contract HelloRelayerTest is Test {
    HelloRelayer public relayer;

    function setUp() public {
        relayer = new HelloRelayer(address(this));
    }

    function testHandleStoresMessage() public {
        bytes memory payload = abi.encode("hello from hyperlane");

        relayer.handle(1, bytes32(uint256(7)), payload);

        assertEq(relayer.lastMessage(), "hello from hyperlane");
    }
}
