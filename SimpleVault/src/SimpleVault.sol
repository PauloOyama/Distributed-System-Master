// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract SimpleVault {
    // Mapping para armazenar o saldo de cada endereço
    mapping(address => uint256) public balances;
    
    // Mapping para armazenar o timestamp do depósito
    mapping(address => uint256) public depositTime;
    
    // Tempo mínimo entre depósito e saque (1 minuto = 60 segundos)
    uint256 public constant WITHDRAWAL_DELAY = 1 minutes;

    // Eventos
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    // Função deposit() que recebe ETH e salva o saldo
    function deposit() public payable {
        require(msg.value > 0, "Deposito deve ser maior que 0");
        
        // Adiciona o valor ao saldo do usuário
        balances[msg.sender] += msg.value;
        
        // Registra o timestamp do depósito
        depositTime[msg.sender] = block.timestamp;
        
        // Emite evento
        emit Deposited(msg.sender, msg.value);
    }

    // Função withdraw() que permite sacar após 1 minuto
    function withdraw() public {
        require(balances[msg.sender] > 0, "Saldo insuficiente");
        require(
            // slither-disable-next-line timestamp
            block.timestamp >= depositTime[msg.sender] + WITHDRAWAL_DELAY,
            "Ainda nao pode sacar (espere 1 minuto apos o deposito)"
        );
        
        // Armazena o valor a ser sacado
        uint256 amount = balances[msg.sender];
        
        // Reseta o saldo
        balances[msg.sender] = 0;
        
        // Reseta o tempo de depósito
        depositTime[msg.sender] = 0;
        
        // Emite evento
        emit Withdrawn(msg.sender, amount);
        
        // Envia os fundos
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Falha ao enviar os fundos");
    }

    // Função auxiliar para consultar saldo de um endereço
    function getBalance(address user) public view returns (uint256) {
        return balances[user];
    }
    
    // Função para consultar quanto tempo falta para sacar
    function getTimeUntilWithdraw(address user) public view returns (uint256) {
        
        uint256 unlockTime = depositTime[user] + WITHDRAWAL_DELAY;
        // slither-disable-next-line timestamp
        if (block.timestamp >= unlockTime) {
            return 0; // Pode sacar agora
        }
        
        return unlockTime - block.timestamp; // Tempo restante em segundos
    }
    
    // Função para receber ETH
    receive() external payable {}
}
