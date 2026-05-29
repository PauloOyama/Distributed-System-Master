Semana 2: O Buffer FIFO e Testes de Caos
A internet não é perfeita. Relayers podem travar, e a transação 2 pode chegar na Cadeia B antes da
transação 1. Se isso acontecer no algoritmo de Skeen, a Ordem Total pode falhar em situações bem
específicas.
Nonce no Emissor
• Atualize seu SkeenMessenger.sol.
• Crie um mapping(address => uint256) public nextOutgoingNonce.
• Antes de enviar a mensagem, incremente esse número e “empacote” ele junto com o payload
usando abi.encode(msg.sender, nonce, payload).
Lógica de Reordenação no Destino (O Buffer)
• Crie um mapping para rastrear o que você espera receber: nextExpectedNonce.
• Crie um mapping para guardar mensagens adiantadas (O Buffer).
• ARegra de Ouro no handle():– Desempacote a mensagem para ler o nonce.– Aplique regra para garantir a ordem.