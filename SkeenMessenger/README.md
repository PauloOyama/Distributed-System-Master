# Como Rodar o SkeenMessenger

## 📖 Entendendo Deploy vs Test (Para Iniciantes)

Antes de começar, é importante entender a diferença:

### **Deploy.s.sol** (Enviar para Blockchain)
- ✅ **Coloca o contrato NA BLOCKCHAIN de verdade**
- Usa sua chave privada real e gasta GAS
- Cria um contrato que qualquer um pode interagir
- Executado com: `forge script`
- **Exemplo:** Deploy em Sepolia, seu contrato fica lá para sempre

### **Test.t.sol** (Testar Localmente)
- ✅ **Testa o contrato SEM gastar GAS**
- Roda em memória, simula situações
- Verifica se o código funciona corretamente antes de fazer deploy
- Executado com: `forge test`
- **Exemplo:** Testar se `sendMessage()` funciona sem enviar nada de verdade

**Analogia simples:**
```
Test = Ensaiar uma apresentação (sem público)
Deploy = Fazer a apresentação de verdade (com público)
```

### Fluxo Correto de Desenvolvimento:
1. Escrever código no contrato
2. Testar localmente com `forge test` (grátis, rápido)
3. Se passou nos testes, fazer Deploy com `forge script` (real, caro)

---

## 0. **Instalar Dependências**

```bash
cd SkeenMessenger

# Adicionar submódulos (Hyperlane e forge-std)
git submodule add https://github.com/hyperlane-xyz/hyperlane-monorepo.git lib/hyperlane-monorepo
git submodule add https://github.com/foundry-rs/forge-std lib/forge-std

# Inicializar os submódulos
git submodule update --init --recursive
```

## 1. **Compilar o contrato**

```bash
forge build
```

## 2. **Deploy Local (Anvil)**

```bash
# Terminal 1: Inicie o Anvil
anvil

# Terminal 2: Faça deploy
export PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb476cadeee4c811dac45ba720b85"
export MAILBOX_ADDRESS="0x0000000000000000000000000000000000000000"

forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

forge script script/Deploy.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
```

## 3. **Deploy em Testnet (ex: Sepolia)**

```bash
export PRIVATE_KEY="sua_chave_privada_aqui"
export MAILBOX_ADDRESS="0x...(mailbox da rede)"
export RPC_URL="https://sepolia.infura.io/v3/sua_chave_infura"

forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast
```

## 4. **Testar Localmente**

```bash
forge test
```

Crie um arquivo `test/SkeenMessenger.t.sol` com testes. **Exemplo básico:**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {SkeenMessenger} from "../src/SkeenMessenger.sol";

contract SkeenMessengerTest is Test {
    SkeenMessenger public messenger;

    function setUp() public {
        // Cria o contrato com um endereço fake de Mailbox
        messenger = new SkeenMessenger(address(0x123));
    }

    function testSendMessage() public {
        // Testa se a função sendMessage não falha
        messenger.sendMessage(1, address(0x456), "Olá!");
    }

    function testHandleMessage() public {
        // Testa o recebimento de mensagens
        bytes memory messageBody = abi.encode("Mensagem recebida");
        messenger.handle(1, bytes32(uint256(1)), messageBody);
    }
}
```

**Diferença prática:**
- ❌ `forge test` = Não custa nada, roda localmente
- ✅ `forge script` = Custa GAS, envia para blockchain real

## Endereços do Mailbox (Hyperlane)

- **Ethereum Sepolia**: `0xc3F23848Ed83e5f75F794f3265d4db833D38EA5d`
- **Polygon Mumbai**: `0xcDb15156cF3e2AcD32E579Dec3053423e4922599`
- Consulte: https://docs.hyperlane.xyz/

## Comandos Úteis

```bash
# Ver saldo
cast balance 0x... --rpc-url $RPC_URL

# Enviar transação
cast send --private-key $PRIVATE_KEY --rpc-url $RPC_URL ...
```
