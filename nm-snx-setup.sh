#!/bin/bash
# nm-snx-setup.sh - Cria conexões NM para todas as VPNs configuradas
# Detecta dinamicamente todos os *.conf em ~/.config/snx-rs/

set -e

CONFIG_DIR="$HOME/.config/snx-rs"

echo "=== Configurando conexões VPN no NetworkManager ==="

for conf in "$CONFIG_DIR"/vpn*.conf; do
    [ -f "$conf" ] || continue

    # Extrai nome do arquivo (vpnro.conf → vpnro)
    name=$(basename "$conf" .conf)

    # Gera label a partir do config (server-name como fallback)
    server=$(grep "^server-name=" "$conf" | cut -d= -f2)
    label="VPN ${name#vpn} - ${server}"

    # Labels conhecidas
    case "$name" in
        vpnro)   label="VPN RO - Rondônia" ;;
        vpnpr)   label="VPN PR - Paraná" ;;
        vpnam)   label="VPN AM - Amazonas" ;;
        vpnmt)   label="VPN MT - Mato Grosso" ;;
        vpnsc)   label="VPN SC - Santa Catarina" ;;
        vpnto)   label="VPN TO - Tocantins" ;;
        vpnprgp) label="VPN PR GP" ;;
    esac

    # Remove conexão existente e recria
    nmcli connection delete "$label" 2>/dev/null || true
    nmcli connection add \
        type dummy \
        ifname "snx-${name}" \
        con-name "$label" \
        autoconnect no \
        ipv4.method disabled \
        ipv6.method disabled 2>/dev/null

    echo "[✓] $label (${server})"
done

echo "[✓] Conexões NM configuradas."
