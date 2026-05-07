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

    // Testa com múltiplos usuários usando vm.prank
    function testDepositWithMultipleUsers() public {
        address alice = address(0x1);
        address bob = address(0x2);
        
        // Dá 10 ETH para Alice e Bob
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        
        // Alice faz um depósito de 1 ETH
        vm.prank(alice);
        vault.deposit{value: 1 ether}();
        
        // Bob faz um depósito de 2 ETH
        vm.prank(bob);
        vault.deposit{value: 2 ether}();
        
        // Verifica os saldos de cada um
        assertEq(vault.balances(alice), 1 ether);
        assertEq(vault.balances(bob), 2 ether);
    }

    // Testa saque de Alice após 1 minuto
    function testAliceWithdrawAfterDelay() public {
        address alice = address(0x1);
        
        // Dá 10 ETH para Alice
        vm.deal(alice, 10 ether);
        
        // Alice deposita 1 ETH
        vm.prank(alice);
        vault.deposit{value: 1 ether}();
        
        // Verifica tempo até saque
        uint256 timeLeft = vault.getTimeUntilWithdraw(alice);
        assertGt(timeLeft, 0);
        
        // Avança o tempo em 61 segundos
        vm.warp(block.timestamp + 61 seconds);
        
        // Alice agora pode sacar
        vm.prank(alice);
        vault.withdraw();
        
        // Verifica se o saldo foi resetado
        assertEq(vault.balances(alice), 0);
    }

    // Testa que Alice não pode sacar os fundos de Bob
    function testAliceCannotWithdrawBobFunds() public {
        address alice = address(0x1);
        address bob = address(0x2);
        
        // Dá ETH para Bob
        vm.deal(bob, 10 ether);
        
        // Bob deposita 1 ETH
        vm.prank(bob);
        vault.deposit{value: 1 ether}();
        
        // Avança o tempo
        vm.warp(block.timestamp + 61 seconds);
        
        // Alice tenta sacar (mas não tem saldo)
        vm.prank(alice);
        vm.expectRevert("Saldo insuficiente");
        vault.withdraw();
        
        // Bob ainda tem seu saldo
        assertEq(vault.balances(bob), 1 ether);
    }

    // Testa eventos com vm.prank
    function testDepositEventWithPrank() public {
        address alice = address(0x1);
        
        // Dá ETH para Alice
        vm.deal(alice, 10 ether);
        
        // Usa vm.expectEmit para verificar eventos
        vm.expectEmit(true, false, false, true);
        emit SimpleVault.Deposited(alice, 1 ether);
        
        // Alice faz o depósito
        vm.prank(alice);
        vault.deposit{value: 1 ether}();
    }

    // Precisa para receber ETH
    receive() external payable {}
}
