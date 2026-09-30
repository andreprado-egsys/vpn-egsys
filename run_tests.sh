#!/bin/bash
# run_tests.sh - Runner do Quality Gate para o vpn-egsys
set -e

BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BOLD}=== Executando Quality Gate do vpn-egsys ===${NC}\n"

echo "[1/3] Verificando sintaxe dos scripts Bash..."
bash -n install.sh update.sh uninstall.sh user-setup.sh nm-snx-setup.sh 99-snx-vpn.sh macos/*.sh
echo -e "${GREEN}✓ Scripts Bash válidos.${NC}\n"

echo "[2/3] Compilando arquivos Python..."
python3 -m py_compile vpn-tray vpn core/*.py tests/*.py
echo -e "${GREEN}✓ Compilação Python sem erros de sintaxe.${NC}\n"

echo "[3/3] Executando suíte de testes unitários..."
python3 -m unittest discover -s tests -v
echo -e "${GREEN}✓ Bateria de testes concluída com 100% de sucesso!${NC}\n"

echo -e "${BOLD}${GREEN}=== QUALITY GATE APROVADO ===${NC}"
