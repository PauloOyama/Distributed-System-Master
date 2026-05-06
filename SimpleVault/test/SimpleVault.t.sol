// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";

import {SimpleVault} from "../src/SimpleVault.sol";

contract SimpleVaultTest is Test {
    SimpleVault public vault;

    function setUp() public {
        vault = new SimpleVault();
    }

    // Testa se o depósito funciona corretamente
    function testDeposit() public {
        uint256 amount = 1 ether;
        
        // Envia 1 ETH para a função deposit
        vault.deposit{value: amount}();
        
        // Verifica se o saldo foi registrado corretamente
        assertEq(vault.balances(address(this)), amount);
    }

    // Testa múltiplos depósitos
    function testMultipleDeposits() public {
        vault.deposit{value: 1 ether}();
        vault.deposit{value: 2 ether}();
        
        assertEq(vault.balances(address(this)), 3 ether);
    }

    // Testa se rejeita depósito de 0
    function testRejectZeroDeposit() public {
        vm.expectRevert("Deposito deve ser maior que 0");
        vault.deposit{value: 0}();
    }

    // Testa função getBalance
    function testGetBalance() public {
        vault.deposit{value: 5 ether}();
        assertEq(vault.getBalance(address(this)), 5 ether);
    }

    // Precisa para receber ETH
    receive() external payable {}
}
