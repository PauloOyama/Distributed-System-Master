# SimpleHelloMessenger — Guia de execução local

Este manual mostra como rodar o contrato simples [RelayerProbe/src/SimpleHelloMessenger.sol](RelayerProbe/src/SimpleHelloMessenger.sol) em dois Anvils diferentes, registrar as duas chains no Hyperlane e subir o relayer em um terceiro terminal.

## Pré-requisitos

- Foundry instalado (`forge`, `cast`, `anvil`)
- Hyperlane CLI instalado
- WSL ou terminal Linux com acesso ao `~/.foundry/bin`

## 1. Terminal 1 — iniciar a chain A

```bash
anvil --port 8545 --chain-id 31337
```

## 2. Terminal 2 — iniciar a chain B

```bash
anvil --port 8546 --chain-id 31338
```

## 3. Verificar se os dois nós responderam

Em outro terminal, rode:

```bash
cast block-number --rpc-url http://127.0.0.1:8545
cast block-number --rpc-url http://127.0.0.1:8546
```

## 4. Criar os metadados das chains no Hyperlane

Crie os diretórios:

```bash
mkdir -p ~/.hyperlane/chains/anvil1 ~/.hyperlane/chains/anvil2
```

Crie o arquivo `~/.hyperlane/chains/anvil1/metadata.yaml` com:

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

Crie o arquivo `~/.hyperlane/chains/anvil2/metadata.yaml` com:

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

## 5. Gerar a configuração do Hyperlane core

```bash
hyperlane core init
```

Use um owner/beneficiary simples, por exemplo o endereço da conta 0 do Anvil.

## 6. Deployar o core Hyperlane nas duas chains

```bash
export HYP_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

hyperlane core deploy \
  --registry ~/.hyperlane \
  --config ./configs/core-config.yaml \
  --key "$HYP_KEY" \
  --chain anvil1 \
  --yes

hyperlane core deploy \
  --registry ~/.hyperlane \
  --config ./configs/core-config.yaml \
  --key "$HYP_KEY" \
  --chain anvil2 \
  --yes
```

Os endereços da Mailbox ficam em:

```bash
cat ~/.hyperlane/chains/anvil1/addresses.yaml
cat ~/.hyperlane/chains/anvil2/addresses.yaml
```

## 7. Terminal 3 — compilar e deployar o SimpleHelloMessenger

Em um terceiro terminal, rode:

```bash
cd /mnt/c/Users/papal/MasterDegree/Distributed-System-Master/RelayerProbe
~/.foundry/bin/forge build
~/.foundry/bin/forge test
```

Depois, para deployar na chain A:

```bash
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export MAILBOX_A=$(grep 'mailbox:' ~/.hyperlane/chains/anvil1/addresses.yaml | awk '{print $2}' | tr -d '"')

MAILBOX_ADDRESS="$MAILBOX_A" ~/.foundry/bin/forge script script/HelloRelayer.s.sol \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast \
  --private-key "$PRIVATE_KEY"
```

E na chain B:

```bash
export MAILBOX_B=$(grep 'mailbox:' ~/.hyperlane/chains/anvil2/addresses.yaml | awk '{print $2}' | tr -d '"')

MAILBOX_ADDRESS="$MAILBOX_B" ~/.foundry/bin/forge script script/HelloRelayer.s.sol \
  --rpc-url http://127.0.0.1:8546 \
  --broadcast \
  --private-key "$PRIVATE_KEY"
```

> O script atual de deploy do projeto cria um contrato simples e usa o mailbox da chain correspondente.

## 8. Iniciar o relayer em um terceiro terminal

Em um terminal separado, mantenha o relayer rodando:

```bash
hyperlane relayer \
  --chains anvil1 \
  --chains anvil2 \
  --registry ~/.hyperlane \
  --key "$HYP_KEY"
```

## 9. Enviar a mensagem

Depois que o relayer estiver rodando, você pode enviar a mensagem da cadeia A para a cadeia B. O contrato simples usa a mensagem fixa `OLA DA REDE A`.

Exemplo no WSL:

```bash
cast send <ADDRESS_DO_CONTRATO_DA_CHAIN_A> \
  "sendHello(uint32,address)" \
  31338 \
  <ADDRESS_DO_CONTRATO_DA_CHAIN_B> \
  --rpc-url http://127.0.0.1:8545 \
  --private-key "$PRIVATE_KEY"
```

## 10. Verificar a chegada na chain B

```bash
cast call <ADDRESS_DO_CONTRATO_DA_CHAIN_B> \
  "lastMessage()(string)" \
  --rpc-url http://127.0.0.1:8546
```

Se tudo estiver correto, o retorno será:

```text
OLA DA REDE A
```
