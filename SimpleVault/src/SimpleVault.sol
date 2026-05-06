// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract SimpleVault {
    // Mapping para armazenar o saldo de cada endereço
    mapping(address => uint256) public balances;

    // Evento para registrar depósitos
    event Deposited(address indexed user, uint256 amount);

    // Função deposit() que recebe ETH e salva o saldo
    function deposit() public payable {
        require(msg.value > 0, "Deposito deve ser maior que 0");
        
        // Adiciona o valor ao saldo do usuário
        balances[msg.sender] += msg.value;
        
        // Emite evento
        emit Deposited(msg.sender, msg.value);
    }

    // Função auxiliar para consultar saldo de um endereço
    function getBalance(address user) public view returns (uint256) {
        return balances[user];
    }
}
