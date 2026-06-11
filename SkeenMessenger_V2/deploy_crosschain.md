# Deploy Cross-Chain com Hyperlane (duas Anvils locais)

## Visão geral do fluxo

```
anvil (8545) + anvil (8546)
        ↓
hyperlane core deploy → Mailbox_A + Mailbox_B
        ↓
forge script Deploy.s.sol (chain A, usando Mailbox_A)
forge script Deploy.s.sol (chain B, usando Mailbox_B)
        ↓
SkeenMessenger_A ↔ SkeenMessenger_B via Hyperlane
```

O `hyperlane core deploy` instala os contratos de infraestrutura do Hyperlane (Mailbox, ISM, Hook) em cada chain. Só depois disso o `SkeenMessenger` é deployado passando o endereço do Mailbox gerado.

---

## Passo 1 — Instalar o Hyperlane CLI

```bash
npm install -g @hyperlane-xyz/cli
```

Verifique:
```bash
hyperlane --version
# testado com 35.1.0
```

---

## Passo 2 — Iniciar as duas Anvils

Em dois terminais separados:

```bash
# Terminal 1 — Chain A
anvil --port 8545 --chain-id 31337

# Terminal 2 — Chain B
anvil --port 8546 --chain-id 31338
```

A Anvil imprime as contas e chaves privadas ao iniciar. A chave privada da conta 0 (mnemônico padrão `test test test ... junk`) é:
```
0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```
Endereço correspondente: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`

> **Atenção:** Confirme a chave no output da Anvil — ela pode variar dependendo da versão.

---

## Passo 3 — Registrar as chains no Hyperlane

```bash
mkdir -p ~/.hyperlane/chains/anvil1
mkdir -p ~/.hyperlane/chains/anvil2
```

**`~/.hyperlane/chains/anvil1/metadata.yaml`**:
```yaml
chainId: 31337
domainId: 31337
name: anvil1
protocol: ethereum
rpcUrls:
  - http: http://localhost:8545
nativeToken:
  name: Ether
  symbol: ETH
  decimals: 18
```

**`~/.hyperlane/chains/anvil2/metadata.yaml`**:
```yaml
chainId: 31338
domainId: 31338
name: anvil2
protocol: ethereum
rpcUrls:
  - http: http://localhost:8546
nativeToken:
  name: Ether
  symbol: ETH
  decimals: 18
```

---

## Passo 4 — Criar o arquivo de configuração do Core

Na versão 35.x do CLI, o config é um objeto flat (sem chave de chain). Gere com:

```bash
hyperlane core init
```

Quando perguntado pelo owner, use `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`. O comando cria `./configs/core-config.yaml`:

```yaml
defaultHook:
  type: merkleTreeHook
defaultIsm:
  relayer: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
  type: trustedRelayerIsm
owner: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
proxyAdmin:
  owner: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
requiredHook:
  beneficiary: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
  maxProtocolFee: "100000000000000000"
  owner: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
  protocolFee: "0"
  type: protocolFee
```

> **Nota:** O `trustedRelayerIsm` é o ISM mais simples para ambiente local — aceita mensagens entregues por um relayer de confiança sem verificação criptográfica extra.

---

## Passo 5 — Deploy do core Hyperlane

Na versão 35.x o `--chain` é singular — rode uma vez por chain:

```bash
export HYP_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

hyperlane core deploy \
  --registry ~/.hyperlane \
  --config ./configs/core-config.yaml \
  --key $HYP_KEY \
  --chain anvil1 \
  --yes

hyperlane core deploy \
  --registry ~/.hyperlane \
  --config ./configs/core-config.yaml \
  --key $HYP_KEY \
  --chain anvil2 \
  --yes
```

Ao terminar, os endereços ficam salvos em:
- `~/.hyperlane/chains/anvil1/addresses.yaml`
- `~/.hyperlane/chains/anvil2/addresses.yaml`

O campo relevante em cada arquivo é `mailbox`.

---

## Passo 6 — Deploy do SkeenMessenger

```bash
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Lê os endereços gerados pelo core deploy
MAILBOX_A=$(grep 'mailbox:' ~/.hyperlane/chains/anvil1/addresses.yaml | awk '{print $2}')
MAILBOX_B=$(grep 'mailbox:' ~/.hyperlane/chains/anvil2/addresses.yaml | awk '{print $2}')

# Deploy na chain A
MAILBOX_ADDRESS=$MAILBOX_A forge script script/Deploy.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --private-key $PRIVATE_KEY

# Deploy na chain B
MAILBOX_ADDRESS=$MAILBOX_B forge script script/Deploy.s.sol \
  --rpc-url http://localhost:8546 \
  --broadcast \
  --private-key $PRIVATE_KEY
```

Anote os endereços do `SkeenMessenger` impressos no output do `forge script` — você precisará deles para chamar `sendMessage`.

---

## Passo 7 — Rodar o Relayer

Para que mensagens enviadas na chain A cheguem na chain B:

```bash
hyperlane relayer \
  --relayChains anvil1,anvil2 \
  --registry ~/.hyperlane \
  --defaultSigner.key $HYP_KEY
```

---

## Referência rápida de comandos

| Ação | Comando |
|------|---------|
| Instalar CLI | `npm install -g @hyperlane-xyz/cli` |
| Gerar config | `hyperlane core init` |
| Deploy core (por chain) | `hyperlane core deploy --chain anvil1 ...` |
| Deploy contrato | `forge script script/Deploy.s.sol --broadcast ...` |
| Rodar relayer | `hyperlane relayer --relayChains anvil1,anvil2 ...` |
| Ver endereços deployados | `cat ~/.hyperlane/chains/anvil1/addresses.yaml` |
