#!/bin/bash
# nm-snx-setup.sh - Cria conexões NM dummy para VPNs snx-rs
# Essas conexões aparecem no applet do NM e disparam o snxctl via dispatcher

set -e

CONFIG_DIR="$HOME/.config/snx-rs"

create_nm_vpn() {
    local name="$1" label="$2"

    # Remove conexão existente se houver
    nmcli connection delete "$label" 2>/dev/null || true

    # Cria conexão dummy (interface snx-NOME dispara o dispatcher)
    nmcli connection add \
        type dummy \
        ifname "snx-${name}" \
        con-name "$label" \
        autoconnect no \
        ipv4.method disabled \
        ipv6.method disabled

    echo "[✓] Conexão NM criada: $label (interface: snx-${name})"
}

echo "=== Configurando conexões VPN no NetworkManager ==="

[ -f "$CONFIG_DIR/vpnro.conf" ] && create_nm_vpn "vpnro" "VPN RO - Rondônia"
[ -f "$CONFIG_DIR/vpnpr.conf" ] && create_nm_vpn "vpnpr" "VPN PR - Paraná"
[ -f "$CONFIG_DIR/vpnam.conf" ] && create_nm_vpn "vpnam" "VPN AM - Amazonas"

echo "[✓] Conexões NM configuradas. Visíveis no applet do NetworkManager."
