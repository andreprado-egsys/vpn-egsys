#!/bin/bash
# nm-snx-setup.sh - Cria conexões VPN no NetworkManager para snx-rs
# Aparecem na seção VPN do applet (junto com SC e TO)

set -e

CONFIG_DIR="$HOME/.config/snx-rs"

# Detecta qual plugin VPN está disponível para usar como container
detect_vpn_plugin() {
    local vpn_dir="/usr/lib/NetworkManager/VPN"
    [ -d "$vpn_dir" ] || vpn_dir="/usr/lib64/NetworkManager/VPN"

    if [ -f "$vpn_dir/nm-openconnect-service.name" ]; then
        echo "org.freedesktop.NetworkManager.openconnect"
    elif [ -f "$vpn_dir/nm-vpnc-service.name" ]; then
        echo "org.freedesktop.NetworkManager.vpnc"
    elif [ -f "$vpn_dir/nm-pptp-service.name" ]; then
        echo "org.freedesktop.NetworkManager.pptp"
    else
        echo ""
    fi
}

VPN_PLUGIN=$(detect_vpn_plugin)

create_nm_vpn() {
    local name="$1" label="$2"

    # Remove conexão existente se houver
    nmcli connection delete "$label" 2>/dev/null || true

    if [ -n "$VPN_PLUGIN" ]; then
        # Cria como tipo VPN (aparece na seção VPN do applet)
        nmcli connection add \
            type vpn \
            vpn-type "$VPN_PLUGIN" \
            con-name "$label" \
            autoconnect no \
            ifname "*"

        # Marca com vpn.data para o dispatcher identificar
        nmcli connection modify "$label" \
            vpn.data "gateway=snx-${name}"
    else
        # Fallback: dummy (se nenhum plugin VPN disponível)
        nmcli connection add \
            type dummy \
            ifname "snx-${name}" \
            con-name "$label" \
            autoconnect no \
            ipv4.method disabled \
            ipv6.method disabled
    fi

    echo "[✓] Conexão NM criada: $label"
}

echo "=== Configurando conexões VPN no NetworkManager ==="

[ -f "$CONFIG_DIR/vpnro.conf" ] && create_nm_vpn "vpnro" "VPN RO - Rondônia"
[ -f "$CONFIG_DIR/vpnpr.conf" ] && create_nm_vpn "vpnpr" "VPN PR - Paraná"
[ -f "$CONFIG_DIR/vpnam.conf" ] && create_nm_vpn "vpnam" "VPN AM - Amazonas"

echo "[✓] Conexões NM configuradas. Visíveis no applet do NetworkManager."
