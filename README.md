# Distributed-System-Master

Projetos de contratos inteligentes com Solidity, Foundry e Hyperlane para sistemas distribuídos.

## Projetos

- **SimpleVault** - Contrato de cofre com depósitos e saques com delay
- **SkeenMessenger** - Integração com Hyperlane para mensagens cross-chain

---

## Testando Contratos com Anvil

### O que é Anvil?

Anvil é um nó blockchain local que simula a Ethereum. Perfeito para:
- Testar contratos localmente
- Debugar sem gastar ETH real
- Simular múltiplas contas com saldo

### Terminal 1: Inicie o Anvil

```bash
anvil
```

Você verá algo assim:
```
Listening on 127.0.0.1:8545
Account #0: 0x1234... (10000 ETH)
Account #1: 0x5678... (10000 ETH)
...
Private Key #0: 0xac097...
```

### Terminal 2: Execute Testes

**Opção A - Testes em ambiente isolado (SEM Anvil):**
```bash
cd SimpleVault
forge test -v
```

Rápido, não precisa do Anvil. Block number não muda no Anvil.

**Opção B - Testes contra Anvil (EM fork isolado):**
```bash
cd SimpleVault
forge test -v --rpc-url http://localhost:8545
```

Testa contra o estado do Anvil. Block number ainda não muda (testes rodam em fork).

**Opção C - Deploy com transações REAIS (Modifica Anvil):**
```bash
cd SimpleVault
forge script script/Deploy.s.sol \
  --rpc-url http://localhost:8545 
  --broadcast 
  --private-key 0x976EA74026E726554dB657fA54763abd0C3a0aa9
```

Realmente modifica o Anvil. Block number aumenta.

---

## Manipulando Blocos via RPC

### Ver informações do bloco atual

```bash
cast block-number --rpc-url http://localhost:8545
```

```bash
cast block --rpc-url http://localhost:8545
```

### Avançar o bloco (Warp)

**Opção 1 - Enviar uma transação (cria novo bloco):**
```bash
cast send 0x0000000000000000000000000000000000000000 \
  --value 1wei \
  --rpc-url http://localhost:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

**Opção 2 - Usar vm.warp() nos testes (muda timestamp):**
```solidity
function testWarpTime() public {
    console.log("Bloco antes:", block.number);
    console.log("Timestamp antes:", block.timestamp);
    
    // Avança 1 hora
    vm.warp(block.timestamp + 1 hours);
    
    console.log("Bloco depois:", block.number);
    console.log("Timestamp depois:", block.timestamp);
}
```

**Opção 3 - Usar anvil_mine via cast (CLI):**
```bash
# Minera 5 blocos
cast rpc anvil_mine 5 --rpc-url http://localhost:8545

# Avança tempo em 60 segundos
cast rpc evm_increaseTime 60 --rpc-url http://localhost:8545
```

### Resetar estado do Anvil

```bash
# Redefine o fork para o bloco 0
cast rpc hardhat_reset --rpc-url http://localhost:8545
```

---

## Exemplo Prático: Teste com Blocos

```bash
# Terminal 1
anvil

# Terminal 2 - Verificar bloco inicial
cast block-number --rpc-url http://localhost:8545
# Output: 0

# Terminal 2 - Enviar transação (cria bloco 1)
cast send 0x0000000000000000000000000000000000000000 \
  --value 1wei \
  --rpc-url http://localhost:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Terminal 2 - Verificar novo bloco
cast block-number --rpc-url http://localhost:8545
# Output: 1
```

---

## Cheat Codes Úteis (nos testes)

```solidity
// Manipular blocos
vm.warp(timestamp);           // Muda o timestamp
vm.roll(blockNumber);         // Muda o block number
vm.deal(address, amount);     // Dá ETH para um endereço

// Simular outros endereços
vm.prank(address);            // Próxima chamada como outro endereço
vm.startPrank(address);       // Todas as chamadas como outro endereço
vm.stopPrank();               // Para de simular

// Verificar comportamento
vm.expectRevert("mensagem");  // Espera um erro
vm.expectEmit();              // Espera um evento
```

---

## Troubleshooting

| Problema | Solução |
|----------|---------|
| Connection refused | Verifique se Anvil está rodando em Terminal 1 |
| Block number não muda com testes | Isso é esperado! Use forge script --broadcast para mudar |
| Insufficient funds for gas | Use uma das chaves padrão do Anvil com 10000 ETH |
| No files changed, compilation skipped | Delete cache/ e out/ se houver mudanças |

---

## Referências

- [Foundry Book](https://book.getfoundry.sh/)
- [Anvil Docs](https://book.getfoundry.sh/reference/anvil/)
- [Cast Commands](https://book.getfoundry.sh/reference/cast/)
- [Cheat Codes](https://book.getfoundry.sh/cheatcodes/top-level)
