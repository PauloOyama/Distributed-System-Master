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
forge test -v
```

---

## Como Funciona o Mock do Mailbox

### Por que mockar?

O `SkeenMessenger` depende do `IMailbox` do Hyperlane para enviar e receber mensagens cross-chain. Em testes, não há uma rede real nem um relayer rodando — então criamos um **contrato falso (mock)** que imita o comportamento do Mailbox real.

```
Teste real (sem mock):          Teste com mock:
SkeenMessenger → Mailbox real   SkeenMessenger → MockMailbox
                 ↓                               ↓
           Rede Hyperlane              Armazena mensagem em memória
           (não existe em teste)       (controlado pelo teste)
```

### O que o MockMailbox faz

O `MockMailbox` implementa a interface `IMailbox` com comportamento simplificado:

| Função real                  | Comportamento no mock                          |
|------------------------------|------------------------------------------------|
| `dispatch(...)`              | Salva a mensagem em `dispatchedMessages[]` e retorna um `messageId` calculado localmente |
| `latestDispatchedId()`       | Retorna o ID da última mensagem despachada     |
| `delivered(bytes32)`         | Retorna se um messageId foi marcado como entregue |
| `quoteDispatch(...)`         | Retorna `0` (sem custo em testes)              |
| `process(...)`               | Não faz nada (entrega é simulada manualmente)  |

### Como o mock é criado

```solidity
// 1. Declare o mock implementando a interface IMailbox
contract MockMailbox is IMailbox {
    uint32 private _localDomain;
    bytes[] public dispatchedMessages;   // guarda mensagens enviadas
    bytes32 private _latestDispatchedId;

    constructor(uint32 domain) {
        _localDomain = domain;
    }

    // dispatch() simula o envio: salva a mensagem e gera um ID
    function dispatch(uint32 dest, bytes32 recipient, bytes calldata body)
        external payable returns (bytes32 messageId)
    {
        messageId = keccak256(abi.encode(dest, recipient, body, block.timestamp, _nonce));
        dispatchedMessages.push(body);
        _latestDispatchedId = messageId;
        _nonce++;
    }

    // ... demais funções da interface retornam valores neutros
}
```

### Como o mock é usado nos testes

```solidity
contract SkeenMessengerTest is Test {
    MockMailbox mailboxChainA;
    MockMailbox mailboxChainB;
    SkeenMessenger messengerOnChainA;
    SkeenMessenger messengerOnChainB;

    function setUp() public {
        // 2. Cria um mailbox mock para cada "chain"
        mailboxChainA = new MockMailbox(1);    // simula Ethereum (domain 1)
        mailboxChainB = new MockMailbox(137);  // simula Polygon (domain 137)

        // 3. Injeta o mock no contrato (no lugar do Mailbox real)
        messengerOnChainA = new SkeenMessenger(address(mailboxChainA));
        messengerOnChainB = new SkeenMessenger(address(mailboxChainB));
    }
}
```

### Fluxo de um teste de envio

```
test_SendMessageFromChainA()
        │
        ▼
messengerOnChainA.sendMessage(CHAIN_B, recipient, "Hello!")
        │
        ▼  chama internamente:
mailboxChainA.dispatch(137, recipient, encodedMessage)
        │
        ▼  MockMailbox salva em memória:
dispatchedMessages[0] = encodedMessage
_latestDispatchedId   = keccak256(...)
        │
        ▼  teste verifica:
assertGt(uint256(mailboxChainA.latestDispatchedId()), 0)  ✅
```

### Fluxo de um teste de recebimento (entrega simulada)

Como não há relayer real, o mock expõe `deliverMessage()` para simular a entrega:

```
test_ReceiveMessageOnChainB()
        │
        ▼
mailboxChainB.deliverMessage(address(messengerOnChainB), origin, sender, body)
        │
        ▼  MockMailbox chama diretamente:
messengerOnChainB.handle(origin, sender, body)
        │
        ▼  SkeenMessenger emite:
emit MessageReceived(origin, sender, message)  ✅
```

```solidity
// No teste, verificamos o evento emitido com vm.expectEmit:
vm.expectEmit(true, true, true, true);
emit SkeenMessenger.MessageReceived(CHAIN_A, senderBytes, "Hello!");

mailboxChainB.deliverMessage(address(messengerOnChainB), CHAIN_A, senderBytes, abi.encode("Hello!"));
```

### Resumo do padrão

```
1. Criar MockMailbox implementando IMailbox
2. Injetar o mock no construtor do SkeenMessenger
3. Chamar funções do SkeenMessenger normalmente
4. Inspecionar o estado do mock para verificar o que foi enviado
5. Usar deliverMessage() para simular o relayer entregando a mensagem
```

---

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
