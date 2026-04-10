#!/bin/bash
set -e

# vpn-egsys - Script de Atualização
# Adiciona VPN AM (Amazonas) e atualiza os binários

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

CONFIG_DIR="$HOME/.config/snx-rs"
LOCAL_BIN="$HOME/.local/bin"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo -e "${BOLD}=== Atualização vpn-egsys ===${NC}\n"

# 1. Configurar VPN AM se não existir
if [ ! -f "$CONFIG_DIR/vpnam.conf" ]; then
    echo -e "${BOLD}Configurando VPN AM (Amazonas)${NC}"
    read -rp "Usuário AM (ex: nome.sobrenome): " AM_USER
    read -rsp "Senha AM: " AM_PASS
    echo ""
    AM_PASS_B64=$(echo -n "$AM_PASS" | base64)

    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_DIR/vpnam.conf" <<EOF
server-name=sslvpn.prodam.am.gov.br
user-name=${AM_USER}
password=${AM_PASS_B64}
ignore-server-cert=true
login-type=vpn
EOF
    chmod 600 "$CONFIG_DIR/vpnam.conf"
    info "Configuração VPN AM criada."
else
    info "Configuração VPN AM já existe."
fi

# 2. Atualizar vpn-tray
mkdir -p "$LOCAL_BIN"
cp "$SCRIPT_DIR/vpn-tray" "$LOCAL_BIN/vpn-tray"
chmod +x "$LOCAL_BIN/vpn-tray"
info "vpn-tray atualizado em $LOCAL_BIN"

# 3. Atualizar Aliases
setup_aliases() {
    local shell_rc=$1
    [ ! -f "$shell_rc" ] && return

    MARKER="# >>> vpn-egsys >>>"
    MARKER_END="# <<< vpn-egsys <<<"

    if grep -q "$MARKER" "$shell_rc" 2>/dev/null; then
        sed -i "/$MARKER/,/$MARKER_END/d" "$shell_rc"
    fi

    cat >> "$shell_rc" <<ALIASES
$MARKER
alias vpnro="vpnoff >/dev/null 2>&1; nohup snx-rs -m standalone -c ~/.config/snx-rs/vpnro.conf -l info > /tmp/snx-rs.log 2>&1 & sleep 3 && tail -n 10 /tmp/snx-rs.log"
alias vpnpr="vpnoff >/dev/null 2>&1; nohup snx-rs -m standalone -c ~/.config/snx-rs/vpnpr.conf -l info > /tmp/snx-rs.log 2>&1 & sleep 3 && tail -n 10 /tmp/snx-rs.log"
alias vpnam="vpnoff >/dev/null 2>&1; nohup snx-rs -m standalone -c ~/.config/snx-rs/vpnam.conf -l info > /tmp/snx-rs.log 2>&1 & sleep 3 && tail -n 10 /tmp/snx-rs.log"
alias vpnoff="killall snx-rs 2>/dev/null; sleep 1; sudo rm -f /run/snx-rs.lock 2>/dev/null; echo 'VPN desconectada'"
alias vpnstatus="tail -n 20 /tmp/snx-rs.log 2>/dev/null; ip addr show snx-xfrm 2>/dev/null || echo 'Interface snx-xfrm não encontrada'"
$MARKER_END
ALIASES
}

setup_aliases "$HOME/.bashrc"
setup_aliases "$HOME/.zshrc"
info "Aliases atualizados"

# 4. Reiniciar Tray
killall vpn-tray 2>/dev/null || true
sleep 1
nohup "$LOCAL_BIN/vpn-tray" > /dev/null 2>&1 &
info "Monitor da bandeja reiniciado"

echo -e "\n${GREEN}${BOLD}Atualização concluída!${NC}"
echo "Novo comando disponível: vpnam"
