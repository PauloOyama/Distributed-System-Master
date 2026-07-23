# Deploy Cross-Chain com Hyperlane (duas Anvils locais)

## Visão geral do fluxo

```
anvil (8545, chainId=31337) + anvil (8546, chainId=31338)
        ↓
hyperlane core deploy → Mailbox_A + Mailbox_B
        ↓
forge script Deploy.s.sol → SkeenMessenger_A (conta 0)
forge script Deploy.s.sol → SkeenMessenger_B (conta 1 — endereço distinto)
        ↓
SkeenMessenger_A ↔ SkeenMessenger_B via Hyperlane Relayer
```

O `hyperlane core deploy` instala os contratos de infraestrutura do Hyperlane (Mailbox, ISM, Hook)
em cada chain. Só depois disso o `SkeenMessenger` é deployado passando o endereço do Mailbox gerado.

O `SkeenMessenger` implementa `interchainSecurityModule()` para informar ao relayer qual ISM usar,
eliminando o aviso `Invalid response from provider`.

---

## Passo 1 — Instalar o Hyperlane CLI

```bash
npm install -g @hyperlane-xyz/cli
hyperlane --version  # testado com 35.1.0
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

Chaves privadas padrão do Anvil (mnemônico `test test test ... junk`):

| Conta | Endereço | Chave Privada |
|-------|----------|---------------|
| 0 | `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` | `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80` |
| 1 | `0x70997970C51812dc3A010C7d01b50e0d17dc79C8` | `0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d` |

> A conta 1 é usada para o deploy na chain B, garantindo endereços distintos entre as duas chains.
> Isso acontece porque o endereço do contrato é determinístico: `keccak256(deployer + nonce)`.

---

## Passo 3 — Registrar as chains no Hyperlane

```bash
mkdir -p ~/.hyperlane/chains/anvil1
mkdir -p ~/.hyperlane/chains/anvil2

cat > ~/.hyperlane/chains/anvil1/metadata.yaml << 'EOF'
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
EOF

cat > ~/.hyperlane/chains/anvil2/metadata.yaml << 'EOF'
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
EOF
```

> **CLI 35.x:** o formato correto do `rpcUrls` é `- http: <url>` (string direta).
> O formato com sub-chave `url:` causa erro `Expected string, received object`.

---

## Passo 4 — Criar a config do Core

```bash
hyperlane core init
```

Quando perguntado pelo owner e beneficiary, use `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`.
O comando cria `./configs/core-config.yaml`:

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

> O `trustedRelayerIsm` é o ISM mais simples para ambiente local — aceita mensagens
> entregues pelo relayer configurado sem verificação criptográfica extra.

---

## Passo 5 — Compilar os contratos

```bash
forge build
```

---

## Passo 6 — Deploy do core Hyperlane

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

## Passo 7 — Deploy do SkeenMessenger

Usa **conta 0** na chain A e **conta 1** na chain B para gerar endereços distintos:

```bash
export PRIVATE_KEY_A=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export PRIVATE_KEY_B=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d

export MAILBOX_A=$(grep 'mailbox:' ~/.hyperlane/chains/anvil1/addresses.yaml | awk '{print $2}' | tr -d '"')
export MAILBOX_B=$(grep 'mailbox:' ~/.hyperlane/chains/anvil2/addresses.yaml | awk '{print $2}' | tr -d '"')

# Deploy na chain A (conta 0)
MAILBOX_ADDRESS=$MAILBOX_A forge script script/Deploy.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --private-key $PRIVATE_KEY_A

# Deploy na chain B (conta 1 — endereço diferente)
MAILBOX_ADDRESS=$MAILBOX_B forge script script/Deploy.s.sol \
  --rpc-url http://localhost:8546 \
  --broadcast \
  --private-key $PRIVATE_KEY_B
```

Verifique os endereços deployados:

```bash
echo "=== SkeenMessenger anvil1 ===" && \
  cat broadcast/Deploy.s.sol/31337/run-latest.json | grep contractAddress

echo "=== SkeenMessenger anvil2 ===" && \
  cat broadcast/Deploy.s.sol/31338/run-latest.json | grep contractAddress
```

Os endereços serão distintos porque os deployers (conta 0 vs conta 1) são diferentes.

---

## Passo 8 — Rodar o Relayer

Na versão 35.x use `--chains` com flags separadas:

```bash
hyperlane relayer \
  --chains anvil1 \
  --chains anvil2 \
  --registry ~/.hyperlane \
  --key $HYP_KEY
```

Deixe esse terminal aberto.

> **Sobre `Invalid response from provider`:** O relayer chama `interchainSecurityModule()`
> no contrato destinatário para saber qual ISM usar. O `SkeenMessenger` implementa essa
> função retornando o ISM padrão da Mailbox. Se o aviso persistir, confirme que o contrato
> foi recompilado (`forge build`) e redeployado após a adição da função.

---

## Passo 9 — Testar envio de mensagem

```bash
export SKEEN_A=<endereço do SkeenMessenger na anvil1>
export SKEEN_B=<endereço do SkeenMessenger na anvil2>

# Enviar mensagem da chain A para a chain B
cast send $SKEEN_A \
  "sendMessage(uint32,address,string)" \
  31338 $SKEEN_B "hello from anvil1" \
  --rpc-url http://localhost:8545 \
  --private-key $PRIVATE_KEY_A
```

> **Nota:** Não use `--value` — o `merkleTreeHook` não aceita ETH.

Verifique se a mensagem foi entregue na chain B:

```bash
cast logs \
  --rpc-url http://localhost:8546 \
  --address $SKEEN_B \
  --from-block 0
```

---

## Referência rápida de comandos

| Ação | Comando |
|------|---------|
| Instalar CLI | `npm install -g @hyperlane-xyz/cli` |
| Compilar contratos | `forge build` |
| Gerar config core | `hyperlane core init` |
| Deploy core (por chain) | `hyperlane core deploy --chain anvil1 ...` |
| Deploy SkeenMessenger chain A | `forge script script/Deploy.s.sol --rpc-url http://localhost:8545 ...` |
| Deploy SkeenMessenger chain B | `forge script script/Deploy.s.sol --rpc-url http://localhost:8546 ...` |
| Ver endereços deployados | `cat broadcast/Deploy.s.sol/31337/run-latest.json \| grep contractAddress` |
| Rodar relayer | `hyperlane relayer --chains anvil1 --chains anvil2 ...` |
| Enviar mensagem | `cast send <addr> "sendMessage(uint32,address,string)" ...` |
| Ver mensagens recebidas | `cast logs --rpc-url http://localhost:8546 --address <addr> --from-block 0` |
| Ver saldo da conta | `cast balance 0xf39F... --rpc-url http://localhost:8545 --ether` |

---

## Consultando nextExpectedNonce

O mapping usa `bytes32` como chave. Converta o endereço com padding de 12 bytes de zero à esquerda:

**Formato:** `0x000000000000000000000000` + endereço sem o `0x`

```bash
cast call $SKEEN_B \
  "nextExpectedNonce(uint32,bytes32)(uint256)" \
  31337 \
  0x000000000000000000000000<SKEEN_A_sem_0x> \
  --rpc-url http://localhost:8546
```

O valor retornado é o último nonce processado em ordem. `0` significa que nenhuma mensagem foi entregue ainda.

---

## Decodificando a mensagem recebida (hex → texto)

O `cast logs` retorna o campo `data` em hexadecimal. Estrutura do ABI-encoded event:

| Bloco (32 bytes) | Conteúdo |
|---|---|
| 1º | `sender` — endereço do SkeenMessenger emissor |
| 2º | offset do string (sempre `0x40` = 64) |
| 3º | tamanho do string em bytes |
| 4º | conteúdo da mensagem em ASCII/hex |

Converta o conteúdo com:

```bash
cast --to-ascii <hex_da_mensagem>
# exemplo:
cast --to-ascii 68656c6c6f2066726f6d20616e76696c31
# → hello from anvil1
```

---

## Passo a passo completo de redeploy (após reiniciar o Anvil)

O Anvil **não persiste estado entre reinicializações** por padrão. Se você reiniciou os terminais
ou o computador, o Mailbox e o SkeenMessenger foram perdidos e precisam ser redeployados do zero.

### Opção A — Redeploy completo (mais seguro)

Siga os passos 2, 6 e 7 novamente na ordem:

```bash
# 1. Iniciar as Anvils novamente (terminais separados)
anvil --port 8545 --chain-id 31337
anvil --port 8546 --chain-id 31338

# 2. Variáveis de chave
export HYP_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export PRIVATE_KEY_A=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export PRIVATE_KEY_B=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d

# 3. Redeploy do core Hyperlane (Mailbox) nas duas chains
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

# 4. Ler os novos endereços do Mailbox
export MAILBOX_A=$(grep 'mailbox:' ~/.hyperlane/chains/anvil1/addresses.yaml | awk '{print $2}' | tr -d '"')
export MAILBOX_B=$(grep 'mailbox:' ~/.hyperlane/chains/anvil2/addresses.yaml | awk '{print $2}' | tr -d '"')
echo "Mailbox A: $MAILBOX_A"
echo "Mailbox B: $MAILBOX_B"

# 5. Redeploy do SkeenMessenger nas duas chains
MAILBOX_ADDRESS=$MAILBOX_A forge script script/Deploy.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --private-key $PRIVATE_KEY_A

MAILBOX_ADDRESS=$MAILBOX_B forge script script/Deploy.s.sol \
  --rpc-url http://localhost:8546 \
  --broadcast \
  --private-key $PRIVATE_KEY_B

# 6. Exportar os novos endereços do SkeenMessenger
export SKEEN_A=$(cat broadcast/Deploy.s.sol/31337/run-latest.json | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['transactions'][0]['contractAddress'])")
export SKEEN_B=$(cat broadcast/Deploy.s.sol/31338/run-latest.json | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['transactions'][0]['contractAddress'])")
echo "SKEEN_A: $SKEEN_A"
echo "SKEEN_B: $SKEEN_B"

# 7. Verificar que os contratos existem (deve retornar bytecode, não "0x")
cast code $SKEEN_A --rpc-url http://localhost:8545 | head -c 20
cast code $SKEEN_B --rpc-url http://localhost:8546 | head -c 20
```

### Opção B — Persistir o estado do Anvil (evita redeploy)

Inicie o Anvil com `--dump-state` para salvar o estado ao encerrar e `--load-state` para restaurar:

```bash
# Terminal 1 — Chain A (salva estado ao Ctrl+C)
anvil --port 8545 --chain-id 31337 \
  --dump-state /tmp/anvil-chainA.json \
  --load-state /tmp/anvil-chainA.json

# Terminal 2 — Chain B
anvil --port 8546 --chain-id 31338 \
  --dump-state /tmp/anvil-chainB.json \
  --load-state /tmp/anvil-chainB.json
```

> Na primeira vez os arquivos `/tmp/anvil-chain*.json` não existem — o `--load-state` é ignorado
> e o Anvil inicia limpo. Após o primeiro `Ctrl+C`, o estado é salvo e nas próximas inicializações
> o Mailbox e o SkeenMessenger já estarão presentes.

### Diagnóstico rápido: verificar se o contrato ainda está vivo

```bash
# Retorna bytecode → contrato existe ✅
# Retorna "0x"    → contrato foi perdido, faça redeploy ❌
cast code $SKEEN_B --rpc-url http://localhost:8546
```

---

## Problemas conhecidos e soluções

| Problema | Causa | Solução |
|----------|-------|---------|
| `No chain metadata set` | `--registry` não encontrado | Use caminho absoluto `/home/<user>/.hyperlane` |
| `Expected string, received object` | `rpcUrls` com formato errado | Use `- http: http://localhost:8545` (string direta) |
| `Unknown argument: relayChains` | Flag removida na v35 | Use `--chains anvil1 --chains anvil2` |
| Chave pedida interativamente | `$HYP_KEY` vazia | `export HYP_KEY=0xac09...` antes de rodar |
| Endereços iguais nas duas chains | Mesmo deployer e nonce | Deploy chain B com `PRIVATE_KEY_B` (conta 1) |
| `Invalid response from provider` (aviso) | `interchainSecurityModule()` não implementado | Recompilar e redeployar após adicionar a função |
| `cast logs --address $SKEEN_B` retorna vazio | `$SKEEN_B` não exportado ou Anvil reiniciado | `echo $SKEEN_B` para checar; `cast code $SKEEN_B --rpc-url ...` para confirmar; redeploy se retornar `0x` |
| `cast code $SKEEN_B` retorna `0x` | Anvil foi reiniciado e perdeu o estado | Seguir o "Passo a passo completo de redeploy" acima |

---

## Fase 5 — Teste do Caos (Sliding Window + Buffer FIFO manual)

Esta fase demonstra o comportamento do `WINDOW_SIZE` e do Buffer FIFO **sem depender do Relayer**,
injetando mensagens diretamente na função `handle()` via `cast send`.

> **Pré-requisito:** O contrato deve ter sido redeployado após a adição de `WINDOW_SIZE = 10`
> e do `require` anti-DoS. Execute `forge build` e repita os Passos 6 e 7 antes de continuar.

---

### Fase 5.1 — Parar o Relayer

Vá no terminal do Relayer (Painel 3) e pressione `Ctrl+C`.
A comunicação cross-chain automática está paralisada — as mensagens ficarão presas na chain A.

---

### Fase 5.2 — Enviar três mensagens consecutivas (sem entrega)

Com o Relayer parado, envie três mensagens da chain A. Elas serão despachadas no Mailbox A
mas **não serão entregues** na chain B (nonces 1, 2 e 3 serão gerados).

```bash
export SKEEN_A=<endereço do SkeenMessenger na anvil1>
export SKEEN_B=<endereço do SkeenMessenger na anvil2>
export PRIVATE_KEY_A=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

cast send $SKEEN_A \
  "sendMessage(uint32,address,string)" \
  31338 $SKEEN_B "mensagem-1" \
  --rpc-url http://localhost:8545 \
  --private-key $PRIVATE_KEY_A

cast send $SKEEN_A \
  "sendMessage(uint32,address,string)" \
  31338 $SKEEN_B "mensagem-2" \
  --rpc-url http://localhost:8545 \
  --private-key $PRIVATE_KEY_A

cast send $SKEEN_A \
  "sendMessage(uint32,address,string)" \
  31338 $SKEEN_B "mensagem-3" \
  --rpc-url http://localhost:8545 \
  --private-key $PRIVATE_KEY_A
```

Confirme os nonces gerados:

```bash
cast call $SKEEN_A \
  "nextOutgoingNonce(address)(uint256)" \
  0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  --rpc-url http://localhost:8545
# Resultado esperado: 3
```

---

### Fase 5.3 — Extrair o payload da terceira mensagem (nonce=3)

Cada `sendMessage` emite um evento `MessageSent` e faz um `dispatch` no Mailbox.
O payload ABI-encoded está no campo `input` da transação ou nos logs. O jeito mais direto
é recriar o encoding localmente:

```bash
# O payload do handle() é: abi.encode(address sender, uint256 nonce, string message)
# Para a terceira mensagem (nonce=3):
SENDER_A=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

PAYLOAD_3=$(cast abi-encode "f(address,uint256,string)" $SENDER_A 3 "mensagem-3")
echo $PAYLOAD_3
```

> O `cast abi-encode` com `f(...)` gera exatamente o mesmo encoding que `abi.encode(...)` no Solidity.

---

### Fase 5.4 — Injeção direta da mensagem 3 (fora de ordem)

Chame `handle()` diretamente no SkeenMessenger da chain B **como se fosse o Mailbox**,
passando a mensagem de nonce=3 antes das de nonce=1 e 2.

Para isso, o caller precisa ser o endereço do Mailbox B. Use `vm.prank` não é possível em
produção — então precisamos chamar via `cast send` da conta que **é** o Mailbox, ou usar
um contrato auxiliar.

A forma mais simples é chamar `process()` no Mailbox B diretamente, passando a mensagem
formatada no padrão Hyperlane. Mas o caminho mais rápido para o teste de caos é usar o
`cast send` com `--from` do endereço do Mailbox e `--unlocked` (disponível no Anvil):

```bash
export MAILBOX_B=0x610178dA211FEF7D417bC0e6FeD39F05609AD788
export SENDER_A=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

# Payload da mensagem 3 (nonce=3)
PAYLOAD_3=$(cast abi-encode "f(address,uint256,string)" $SENDER_A 3 "mensagem-3")

# Sender como bytes32 (endereço com padding de 12 bytes de zero à esquerda)
SENDER_BYTES32="0x000000000000000000000000${SENDER_A:2}"

# Injetar handle() impersonando o Mailbox B (Anvil permite --unlocked)
cast send $SKEEN_B \
  "handle(uint32,bytes32,bytes)" \
  31337 $SENDER_BYTES32 $PAYLOAD_3 \
  --rpc-url http://localhost:8546 \
  --from $MAILBOX_B \
  --unlocked
```

**Resultado esperado:** A transação passa (nonce=3 está dentro da janela: `3 <= 0 + 10`).
A mensagem vai para o `_buffer`. O `nextExpectedNonce` deve continuar em `0`:

```bash
SENDER_KEY="0x000000000000000000000000${SENDER_A:2}"

cast call $SKEEN_B \
  "nextExpectedNonce(uint32,bytes32)(uint256)" \
  31337 $SENDER_KEY \
  --rpc-url http://localhost:8546
# Resultado esperado: 0  ← mensagem bufferizada, não processada
```

---

### Fase 5.5 — Teste de Limite: Injeção de nonce fora da janela (anti-DoS)

Injete um pacote forjado com nonce=100 (muito além de `0 + WINDOW_SIZE = 10`):

```bash
PAYLOAD_SPAM=$(cast abi-encode "f(address,uint256,string)" $SENDER_A 100 "spam")

cast send $SKEEN_B \
  "handle(uint32,bytes32,bytes)" \
  31337 $SENDER_BYTES32 $PAYLOAD_SPAM \
  --rpc-url http://localhost:8546 \
  --from $MAILBOX_B \
  --unlocked
```

**Resultado esperado:** A transação **reverte** com:

```
Error: server returned an error response: error code 3: execution reverted:
Nonce muito a frente da janela esperada (Possivel Spam)
```

---

### Fase 5.6 — Entrega em ordem e flush do buffer

Agora entregue as mensagens 1 e 2 na ordem correta. Ao entregar a 1, o buffer deve
automaticamente esvaziar a 2 e a 3 em cascata:

```bash
# Entregar mensagem 1 (nonce=1)
PAYLOAD_1=$(cast abi-encode "f(address,uint256,string)" $SENDER_A 1 "mensagem-1")

cast send $SKEEN_B \
  "handle(uint32,bytes32,bytes)" \
  31337 $SENDER_BYTES32 $PAYLOAD_1 \
  --rpc-url http://localhost:8546 \
  --from $MAILBOX_B \
  --unlocked

# Verificar nextExpectedNonce — deve ser 3 (flush automático 1 → 2 → 3)
cast call $SKEEN_B \
  "nextExpectedNonce(uint32,bytes32)(uint256)" \
  31337 $SENDER_KEY \
  --rpc-url http://localhost:8546
# Resultado esperado: 3
```

**Resultado esperado:** Três eventos `MessageReceived` emitidos na ordem correta:
`mensagem-1` → `mensagem-2` (flush do buffer) → `mensagem-3` (flush do buffer).

Verifique os logs emitidos:

```bash
cast logs \
  --rpc-url http://localhost:8546 \
  --address $SKEEN_B \
  --from-block 0
```

---

### Resumo do comportamento esperado na Fase 5

| Ação | Nonce | `nextExpectedNonce` | Resultado |
|------|-------|---------------------|-----------|
| Injetar mensagem-3 | 3 | 0 → **0** | Bufferizada (dentro da janela) |
| Injetar nonce=100 | 100 | 0 | **Revert** (fora da janela) |
| Injetar mensagem-1 | 1 | 0 → **3** | Processada + flush 2 e 3 |

