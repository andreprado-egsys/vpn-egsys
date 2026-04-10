#!/bin/bash
set -e

# vpn-egsys - Script de Atualização e Configuração
# Garante compatibilidade Ubuntu/Arch e unifica credenciais.

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

CONFIG_DIR="$HOME/.config/snx-rs"
LOCAL_BIN="$HOME/.local/bin"
ICON_DIR="$HOME/.local/share/icons/vpn-egsys"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo -e "${BOLD}=== vpn-egsys: Iniciando Atualização ===${NC}\n"

# --- 1. Fechar processos ativos para evitar conflitos ---
warn "Encerrando instâncias ativas do vpn-tray e snx-rs..."
killall vpn-tray 2>/dev/null || true
killall snx-rs 2>/dev/null || true
sleep 1
sudo rm -f /run/snx-rs.lock 2>/dev/null || true
info "Processos encerrados e travas removidas."

# --- 2. Detectar SO e instalar dependências faltantes ---
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID="$ID"
        OS_ID_LIKE="$ID_LIKE"
    fi

    if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" || "$OS_ID_LIKE" == *"ubuntu"* || "$OS_ID_LIKE" == *"debian"* ]]; then
        PKG_MANAGER="apt"
    elif [[ "$OS_ID" == "arch" || "$OS_ID" == "cachyos" || "$OS_ID_LIKE" == *"arch"* ]]; then
        PKG_MANAGER="pacman"
    else
        command -v apt &>/dev/null && PKG_MANAGER="apt"
        command -v pacman &>/dev/null && PKG_MANAGER="pacman"
    fi
}

detect_os
warn "Verificando dependências para $PKG_MANAGER..."

if [ "$PKG_MANAGER" == "apt" ]; then
    sudo apt update
    sudo apt install -y python3-gi python3-requests gir1.2-gtk-3.0 gir1.2-ayatanaappindicator3-0.1 libwebkit2gtk-4.0-37 || sudo apt install -y python3-gi python3-requests gir1.2-gtk-3.0 gir1.2-ayatanaappindicator3-0.1 libwebkit2gtk-4.1-0
elif [ "$PKG_MANAGER" == "pacman" ]; then
    sudo pacman -Sy --noconfirm python-gobject python-requests gtk3 libayatana-appindicator webkit2gtk
fi
info "Dependências verificadas."

# --- 3. Unificar Configuração de Credenciais ---
setup_vpn_config() {
    local name=$1
    local label=$2
    local server=$3
    local conf_file="$CONFIG_DIR/$name.conf"

    echo -e "\n${BOLD}Configuração: $label${NC}"
    if [ -f "$conf_file" ]; then
        read -rp "Deseja atualizar as credenciais de $label? (s/N): " choice
        [[ "$choice" != "s" && "$choice" != "S" ]] && return
    fi

    read -rp "Usuário $name (ex: nome.sobrenome): " USER_INPUT
    read -rsp "Senha $name: " PASS_INPUT
    echo ""
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
    info "Configuração para $label salva."
}

setup_vpn_config "vpnro" "VPN RO - Rondônia" "131.72.155.42"
setup_vpn_config "vpnpr" "VPN PR - Paraná" "acessoremoto.pr.gov.br"
setup_vpn_config "vpnam" "VPN AM - Amazonas" "sslvpn.prodam.am.gov.br"

# --- 4. Atualizar binários e ícones ---
mkdir -p "$LOCAL_BIN" "$ICON_DIR"
cp "$SCRIPT_DIR/vpn-tray" "$LOCAL_BIN/vpn-tray"
chmod +x "$LOCAL_BIN/vpn-tray"
cp "$SCRIPT_DIR/icons/"*.svg "$ICON_DIR/"
info "Binários e ícones atualizados."

# --- 5. Atualizar Aliases ---
setup_aliases() {
    local shell_rc=$1
    [ ! -f "$shell_rc" ] && return

    MARKER="# >>> vpn-egsys >>>"
    MARKER_END="# <<< vpn-egsys <<<"

    sed -i "/$MARKER/,/$MARKER_END/d" "$shell_rc" 2>/dev/null || true

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
info "Aliases atualizados no .bashrc e .zshrc."

# --- 6. Reiniciar Monitor ---
nohup "$LOCAL_BIN/vpn-tray" > /dev/null 2>&1 &
info "Monitor da bandeja reiniciado."

echo -e "\n${GREEN}${BOLD}✓ Atualização concluída com sucesso!${NC}"
