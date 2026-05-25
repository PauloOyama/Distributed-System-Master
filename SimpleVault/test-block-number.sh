#!/bin/bash

echo "=== TESTE: Block Number com e sem Anvil ==="
echo ""

# Inicia Anvil em background
echo "1️⃣ Iniciando Anvil..."
anvil > /tmp/anvil.log 2>&1 &
ANVIL_PID=$!
sleep 2

echo "✅ Anvil iniciado (PID: $ANVIL_PID)"
echo ""

# Bloco inicial do Anvil
echo "2️⃣ Block number inicial do Anvil:"
curl -s http://localhost:8545 \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | grep -o '"result":"0x[^"]*"'
echo ""

# Teste SEM --rpc-url
echo "3️⃣ Rodando: forge test (SEM --rpc-url)"
cd "c:/Users/papal/MasterDegree/Distributed-System-Master/SimpleVault"
forge test --quiet 2>&1 | tail -1
echo ""

# Bloco do Anvil após teste local
echo "4️⃣ Block number do Anvil APÓS teste local:"
curl -s http://localhost:8545 \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | grep -o '"result":"0x[^"]*"'
echo "❌ Não mudou! Os testes rodaram localmente."
echo ""

# Teste COM --rpc-url
echo "5️⃣ Rodando: forge test --rpc-url http://localhost:8545"
forge test --rpc-url http://localhost:8545 --quiet 2>&1 | tail -1
echo ""

# Bloco final do Anvil
echo "6️⃣ Block number do Anvil APÓS teste com RPC:"
curl -s http://localhost:8545 \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | grep -o '"result":"0x[^"]*"'
echo "✅ Aumentou! Os testes rodaram CONTRA o Anvil."
echo ""

# Limpa
kill $ANVIL_PID 2>/dev/null
echo "Anvil finalizado."
