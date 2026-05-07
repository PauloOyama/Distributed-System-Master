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

    // Testa se rejeita saque antes de 1 minuto
    function testRejectWithdrawBeforeDelay() public {
        vault.deposit{value: 1 ether}();
        
        // Tenta sacar imediatamente
        vm.expectRevert("Ainda nao pode sacar (espere 1 minuto apos o deposito)");
        vault.withdraw();
    }

    // Testa saque após 1 minuto
    function testWithdrawAfterDelay() public {
        uint256 amount = 1 ether;
        vault.deposit{value: amount}();
        
        // Avança o tempo em 61 segundos (mais de 1 minuto)
        vm.warp(block.timestamp + 61 seconds);
        
        // Agora pode sacar
        vault.withdraw();
        
        // Verifica se o saldo foi resetado
        assertEq(vault.balances(address(this)), 0);
    }

    // Testa se rejeita saque sem saldo
    function testRejectWithdrawNoBalance() public {
        vm.expectRevert("Saldo insuficiente");
        vault.withdraw();
    }

    // Testa função getTimeUntilWithdraw
    function testGetTimeUntilWithdraw() public {
        vault.deposit{value: 1 ether}();
        
        // Imediatamente após depósito, deve retornar ~60 segundos
        uint256 timeLeft = vault.getTimeUntilWithdraw(address(this));
        assertGt(timeLeft, 0);
        assertLe(timeLeft, 60);
        
        // Avança 30 segundos
        vm.warp(block.timestamp + 30 seconds);
        uint256 timeLeftAfter30 = vault.getTimeUntilWithdraw(address(this));
        assertGt(timeLeftAfter30, 0);
        assertLe(timeLeftAfter30, 30);
        
        // Avança mais 40 segundos (total 70)
        vm.warp(block.timestamp + 40 seconds);
        assertEq(vault.getTimeUntilWithdraw(address(this)), 0); // Pode sacar
    }

    // Testa saque múltiplo (depois de depositar novamente)
    function testMultipleWithdrawals() public {
        // Primeiro depósito e saque
        vault.deposit{value: 1 ether}();
        vm.warp(block.timestamp + 61 seconds);
        vault.withdraw();
        assertEq(vault.balances(address(this)), 0);
        
        // Segundo depósito e saque
        vault.deposit{value: 2 ether}();
        vm.warp(block.timestamp + 61 seconds);
        vault.withdraw();
        assertEq(vault.balances(address(this)), 0);
    }

    // Precisa para receber ETH
    receive() external payable {}
}
