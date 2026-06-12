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

Quando perguntado pelo owner e beneficiary, use `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`. O comando cria `./configs/core-config.yaml`:

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

# Lê os endereços gerados pelo core deploy (remove aspas extras do yaml)
export MAILBOX_A=$(grep 'mailbox:' ~/.hyperlane/chains/anvil1/addresses.yaml | awk '{print $2}' | tr -d '"')
export MAILBOX_B=$(grep 'mailbox:' ~/.hyperlane/chains/anvil2/addresses.yaml | awk '{print $2}' | tr -d '"')

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

Verifique os endereços deployados:
```bash
# Chain A (chainId 31337)
cat broadcast/Deploy.s.sol/31337/run-latest.json | grep contractAddress

# Chain B (chainId 31338)
cat broadcast/Deploy.s.sol/31338/run-latest.json | grep contractAddress
```

---

## Passo 7 — Rodar o Relayer

Para que mensagens enviadas na chain A cheguem na chain B, passe as chains separadas:

```bash
hyperlane relayer \
  --chains anvil1 \
  --chains anvil2 \
  --registry ~/.hyperlane \
  --key $HYP_KEY
```

Deixe esse terminal aberto.

---

## Passo 8 — Testar envio de mensagem

Envie uma mensagem de anvil1 para anvil2 (substitua os endereços pelos do seu deploy):

```bash
cast send <SKEEN_MESSENGER_ANVIL1> \
  "sendMessage(uint32,address,string)" \
  31338 \
  <SKEEN_MESSENGER_ANVIL2> \
  "hello from anvil1" \
  --rpc-url http://localhost:8545 \
  --private-key $PRIVATE_KEY
```

> **Nota:** Não use `--value` — o `merkleTreeHook` não aceita ETH.

Verifique se a mensagem foi entregue na chain B:

```bash
cast logs \
  --rpc-url http://localhost:8546 \
  --address <SKEEN_MESSENGER_ANVIL2> \
  --from-block 0
```

O log deve conter o texto da mensagem codificado em hex no campo `data`. Por exemplo, `"hello from anvil1"` aparece como `68656c6c6f2066726f6d20616e76696c31`.

---

## Referência rápida de comandos

| Ação | Comando |
|------|---------|
| Instalar CLI | `npm install -g @hyperlane-xyz/cli` |
| Gerar config | `hyperlane core init` |
| Deploy core (por chain) | `hyperlane core deploy --chain anvil1 ...` |
| Deploy contrato | `forge script script/Deploy.s.sol --broadcast ...` |
| Rodar relayer | `hyperlane relayer --chains anvil1 --chains anvil2 ...` |
| Enviar mensagem | `cast send <addr> "sendMessage(uint32,address,string)" ...` |
| Ver mensagens recebidas | `cast logs --rpc-url http://localhost:8546 --address <addr> --from-block 0` |
| Ver endereços deployados | `cat ~/.hyperlane/chains/anvil1/addresses.yaml` |
| Ver timestamp do bloco atual | `cast block latest --field timestamp --rpc-url http://localhost:8546` |
| Ver nextExpectedNonce | `cast call <SKEEN_B> "nextExpectedNonce(uint32,bytes32)(uint256)" <DOMAIN_A> 0x000000000000000000000000<SKEEN_A_sem_0x> --rpc-url http://localhost:8546` |
| Ver nextExpectedNonce (exemplo real) | ver seção abaixo |

---

## Consultando nextExpectedNonce

O mapping usa `bytes32` como chave (não `address`), então o endereço deve ser convertido para `bytes32` com padding de 12 bytes de zero à esquerda.

**Formato:** `0x000000000000000000000000` + endereço sem o `0x`

Exemplo com os endereços locais (ambas as chains deployadas em `0xe7f1725e7734ce288f8367e1bb143e90bb3f0512`):

```bash
# Consulta na rede B (8546): quantas mensagens da rede A (domain 31337) já foram processadas em ordem
cast call 0xe7f1725e7734ce288f8367e1bb143e90bb3f0512 \
  "nextExpectedNonce(uint32,bytes32)(uint256)" \
  31337 \
  0x000000000000000000000000e7f1725e7734ce288f8367e1bb143e90bb3f0512 \
  --rpc-url http://localhost:8546
```

> O valor retornado é o último nonce processado em ordem. `0` significa que nenhuma mensagem foi entregue ainda.

---

## Decodificando a mensagem recebida (hex → texto)

O `cast logs` retorna o campo `data` em hexadecimal. A mensagem de texto fica no **último bloco de 32 bytes** do `data`.

Exemplo de `data` real:

```
000000000000000000000000c6e7df5e7b4f2a278906862b61205850344d4e7d  ← sender (address)
0000000000000000000000000000000000000000000000000000000000000040  ← offset do string
0000000000000000000000000000000000000000000000000000000000000010  ← tamanho em bytes (0x10 = 16)
68656c6c6f2066726f6d205041554c4f00000000000000000000000000000000  ← conteúdo da mensagem ← esse
```

**Como extrair o texto:**

1. Leia o tamanho (`0x10` = 16 bytes → 32 caracteres hex)
2. Pegue os primeiros `tamanho * 2` caracteres do último bloco
3. Converta com `cast --to-ascii`:

```bash
cast --to-ascii 68656c6c6f2066726f6d205041554c4f
# hello from PAULO
```

**Tabela de referência rápida:**

| Bloco no `data` | Conteúdo |
|---|---|
| 1º (32 bytes) | `sender` — endereço do SkeenMessenger emissor |
| 2º (32 bytes) | offset do string (sempre `0x40` = 64) |
| 3º (32 bytes) | tamanho do string em bytes |
| 4º (32 bytes) | conteúdo da mensagem em ASCII/hex |

> **Atenção ao erro RPC na Chain A:** O Relayer tenta chamar `recipientIsm()` no contrato para descobrir qual ISM usar. Como o `SkeenMessenger` não implementa essa função, a call reverte com `execution reverted`. Isso é **inofensivo** — o Relayer usa o ISM padrão da Mailbox e entrega a mensagem normalmente.
