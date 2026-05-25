# Como Rodar o SkeenMessenger

## 1. **Compilar o contrato**

```bash
cd SkeenMessenger
forge build
```

## 2. **Instalar dependências Hyperlane**

Você precisa adicionar as dependências do Hyperlane. Crie um arquivo `foundry.toml` com:

```toml
remappings = [
    "@hyperlane-xyz/core/=lib/hyperlane-monorepo/solidity/core/"
]
```

E adicione o submódulo:
```bash
git submodule add https://github.com/hyperlane-xyz/hyperlane-monorepo.git lib/hyperlane-monorepo
```

## 3. **Deploy Local (Anvil)**

```bash
# Terminal 1: Inicie o Anvil
anvil

# Terminal 2: Faça deploy
export PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb476cadeee4c811dac45ba720b85"
export MAILBOX_ADDRESS="0x0000000000000000000000000000000000000000"

forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

## 4. **Deploy em Testnet (ex: Sepolia)**

```bash
export PRIVATE_KEY="sua_chave_privada_aqui"
export MAILBOX_ADDRESS="0x...(mailbox da rede)"
export RPC_URL="https://sepolia.infura.io/v3/sua_chave_infura"

forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast
```

## 5. **Testar Localmente**

```bash
forge test
```

Crie um arquivo `test/SkeenMessenger.t.sol` com testes.

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
