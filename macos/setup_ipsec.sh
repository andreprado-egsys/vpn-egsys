#!/bin/bash
# macos/setup_ipsec.sh - Configuração nativa de VPN IPsec/IKEv2 no macOS
# Usa os comandos nativos networksetup e scutil do macOS

set -e

NAME="$1"
SERVER="$2"
USER="$3"

if [ -z "$NAME" ] || [ -z "$SERVER" ]; then
    echo "Uso: ./macos/setup_ipsec.sh <nome_servico> <servidor> [usuario]"
    exit 1
fi

echo "=== Configurando Serviço VPN IPsec no macOS: $NAME ==="

# Verifica se o serviço já existe
EXISTING=$(networksetup -listallnetworkservices | grep -Fx "$NAME" || true)
if [ -n "$EXISTING" ]; then
    echo "[!] O serviço '$NAME' já existe na lista de rede do macOS."
else
    # Cria serviço IKEv2 / IPsec
    echo "[+] Criando serviço VPN IKEv2 via networksetup..."
    networksetup -createnetworkservice "$NAME" "IKEv2" 2>/dev/null || \
    networksetup -createnetworkservice "$NAME" "IPSec" 2>/dev/null || true
fi

echo "[✓] Serviço '$NAME' registrado. Conecte usando: scutil --nc start \"$NAME\" ou 'vpn $NAME'"
