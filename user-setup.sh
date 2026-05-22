#!/bin/bash
# vpn-egsys - Configuração por usuário (não requer sudo)
# Rode este script para cada usuário que precisa usar a VPN

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[96m'
NC='\033[0m'

CONFIG_DIR="$HOME/.config/snx-rs"
LOCAL_BIN="$HOME/.local/bin"
ICON_DIR="$HOME/.local/share/icons/vpn-egsys"
AUTOSTART_DIR="$HOME/.config/autostart"
APPS_DIR="$HOME/.local/share/applications"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo -e "${BOLD}=== vpn-egsys: Configuração do usuário $(whoami) ===${NC}\n"

# Verifica se a parte admin já foi feita
if ! command -v snxctl &>/dev/null; then
    error "snx-rs/snxctl não instalado. Peça ao administrador (suporte) para rodar: sudo ./install.sh"
fi
if ! systemctl is-active --quiet snx-rs.service 2>/dev/null; then
    warn "Serviço snx-rs não está ativo. Peça ao administrador verificar."
fi

# --- 1. vpn-tray e ícones ---
mkdir -p "$LOCAL_BIN" "$ICON_DIR"
cp "$SCRIPT_DIR/vpn-tray" "$LOCAL_BIN/vpn-tray"
chmod +x "$LOCAL_BIN/vpn-tray"
cp "$SCRIPT_DIR/icons/"*.svg "$ICON_DIR/"
info "vpn-tray instalado."

# --- 2. Autostart e desktop entry ---
mkdir -p "$AUTOSTART_DIR" "$APPS_DIR"
cat > "$APPS_DIR/vpn-egsys.desktop" <<EOF
[Desktop Entry]
Name=VPN Monitor
Comment=Monitor de VPN Check Point
Exec=${LOCAL_BIN}/vpn-tray
Icon=${ICON_DIR}/vpn-disconnected.svg
Terminal=false
Type=Application
Categories=Network;
EOF
cp "$APPS_DIR/vpn-egsys.desktop" "$AUTOSTART_DIR/vpn-tray.desktop"
info "Autostart configurado."

# --- 3. Credenciais ---
setup_vpn_config() {
    local name=$1 label=$2 server=$3
    local conf_file="$CONFIG_DIR/$name.conf"

    echo -e "\n${BOLD}$label${NC}"
    if [ -f "$conf_file" ]; then
        read -rp "Já configurada. Deseja redefinir? (s/N): " choice
        [[ "$choice" != "s" && "$choice" != "S" ]] && return
    fi
    read -rp "Usuário: " USER_INPUT
    [ -z "$USER_INPUT" ] && warn "Pulando $label." && return
    read -rsp "Senha: " PASS_INPUT; echo ""
    [ -z "$PASS_INPUT" ] && warn "Pulando $label." && return
    PASS_B64=$(echo -n "$PASS_INPUT" | base64)
    mkdir -p "$CONFIG_DIR"
    cat > "$conf_file" <<EOF
server-name=$server
user-name=${USER_INPUT}
password=${PASS_B64}
ignore-server-cert=true
login-type=vpn
EOF
    chmod 600 "$conf_file"
    info "$label configurada."
}

EXISTING_VPNS=$(ls "$CONFIG_DIR"/vpn*.conf 2>/dev/null | wc -l)

if [ "$EXISTING_VPNS" -gt 0 ]; then
    info "VPNs já configuradas:"
    for conf in "$CONFIG_DIR"/vpn*.conf; do
        local_name=$(basename "$conf" .conf)
        local_server=$(grep "^server-name=" "$conf" | cut -d= -f2)
        local_user=$(grep "^user-name=" "$conf" | cut -d= -f2)
        echo -e "  • ${CYAN}${local_name}${NC} → ${local_server} (${local_user})"
    done
    echo ""
    read -rp "Deseja modificar alguma credencial? (s/N): " MODIFY
    if [[ "$MODIFY" == "s" || "$MODIFY" == "S" ]]; then
        setup_vpn_config "vpnro" "VPN RO - Rondônia" "131.72.155.42"
        setup_vpn_config "vpnpr" "VPN PR - Paraná" "acessoremoto.pr.gov.br"
        setup_vpn_config "vpnam" "VPN AM - Amazonas" "sslvpn.prodam.am.gov.br"
    fi
else
    setup_vpn_config "vpnro" "VPN RO - Rondônia" "131.72.155.42"
    setup_vpn_config "vpnpr" "VPN PR - Paraná" "acessoremoto.pr.gov.br"
    setup_vpn_config "vpnam" "VPN AM - Amazonas" "sslvpn.prodam.am.gov.br"
fi

while true; do
    echo ""
    read -rp "Deseja adicionar outra VPN? (s/N): " ADD_MORE
    [[ "$ADD_MORE" != "s" && "$ADD_MORE" != "S" ]] && break
    read -rp "Identificador (ex: vpnsc, vpnto): " VPN_ID
    [ -z "$VPN_ID" ] && continue
    read -rp "Servidor (IP ou hostname): " VPN_SERVER
    [ -n "$VPN_SERVER" ] && setup_vpn_config "$VPN_ID" "VPN ${VPN_ID#vpn}" "$VPN_SERVER"
done

# --- 4. Aliases ---
setup_aliases() {
    local shell_rc=$1
    [ ! -f "$shell_rc" ] && return
    MARKER="# >>> vpn-egsys >>>"
    MARKER_END="# <<< vpn-egsys <<<"
    sed -i "/$MARKER/,/$MARKER_END/d" "$shell_rc" 2>/dev/null || true
    {
        echo "$MARKER"
        for conf in "$CONFIG_DIR"/vpn*.conf; do
            [ -f "$conf" ] || continue
            local name=$(basename "$conf" .conf)
            echo "${name}() { snxctl disconnect 2>/dev/null; sleep 1; cp ~/.config/snx-rs/${name}.conf ~/.config/snx-rs/snx-rs.conf; snxctl connect 2>&1; for i in \$(seq 1 20); do snxctl status 2>/dev/null | grep -qiE \"conectado desde|connected since\" && echo \"✓ ${name} conectada\" && return 0; sleep 1; done; echo \"✗ Timeout\"; }"
        done
        echo 'vpnoff() { snxctl disconnect 2>/dev/null; echo "VPN desconectada"; }'
        echo 'vpnstatus() { snxctl status; }'
        echo "$MARKER_END"
    } >> "$shell_rc"
}
setup_aliases "$HOME/.bashrc"
setup_aliases "$HOME/.zshrc"
info "Aliases configurados."

# --- 5. PATH ---
if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        [ -f "$rc" ] && ! grep -q '.local/bin' "$rc" && echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
    done
fi

echo -e "\n${GREEN}${BOLD}✓ Configuração concluída para $(whoami)!${NC}"
echo -e "Faça logout/login para o VPN Tray aparecer na bandeja."
echo -e "Ou inicie agora: ${CYAN}~/.local/bin/vpn-tray &${NC}\n"
