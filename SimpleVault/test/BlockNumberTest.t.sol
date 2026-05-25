// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SimpleVault} from "../src/SimpleVault.sol";

contract BlockNumberTest is Test {
    SimpleVault public vault;

    function setUp() public {
        vault = new SimpleVault();
        console.log(" setUp() - Block number:", block.number);
    }

    function testBlockNumber1() public {
        console.log(" testBlockNumber1() - Block number:", block.number);
    }

    function testBlockNumber2() public {
        console.log(" testBlockNumber2() - Block number:", block.number);
    }

    function testBlockNumber3() public {
        console.log(" testBlockNumber3() - Block number:", block.number);
    }

    receive() external payable {}
}
