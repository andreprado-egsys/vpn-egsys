#!/bin/bash
# nm-snx-setup.sh - Cria conexões NM para VPNs snx-rs
# Tipo dummy com interface snx-NOME → dispatcher intercepta up/down

set -e

CONFIG_DIR="$HOME/.config/snx-rs"

create_nm_vpn() {
    local name="$1" label="$2"

    # Remove conexão existente se houver
    nmcli connection delete "$label" 2>/dev/null || true

    # Cria conexão dummy (dispatcher intercepta pela interface snx-vpn*)
    nmcli connection add \
        type dummy \
        ifname "snx-${name}" \
        con-name "$label" \
        autoconnect no \
        ipv4.method disabled \
        ipv6.method disabled

    echo "[✓] Conexão NM criada: $label"
}

echo "=== Configurando conexões VPN no NetworkManager ==="

[ -f "$CONFIG_DIR/vpnro.conf" ] && create_nm_vpn "vpnro" "VPN RO - Rondônia"
[ -f "$CONFIG_DIR/vpnpr.conf" ] && create_nm_vpn "vpnpr" "VPN PR - Paraná"
[ -f "$CONFIG_DIR/vpnam.conf" ] && create_nm_vpn "vpnam" "VPN AM - Amazonas"

echo "[✓] Conexões NM configuradas."
