#!/bin/bash
set -e

# vpn-egsys - Instalador e Configurador (RO, PR, AM)
# Suporta: Ubuntu, Debian, Zorin, Arch Linux, CachyOS e derivados.

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SNX_RS_VERSION="5.2.3"
CONFIG_DIR="$HOME/.config/snx-rs"
LOCAL_BIN="$HOME/.local/bin"
APPS_DIR="$HOME/.local/share/applications"
AUTOSTART_DIR="$HOME/.config/autostart"
ICON_DIR="$HOME/.local/share/icons/vpn-egsys"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo -e "${BOLD}"
echo "╔══════════════════════════════════════╗"
echo "║       vpn-egsys - Instalador         ║"
echo "║   VPN Check Point (RO, PR e AM)      ║"
echo "║      Multi-System Support            ║"
echo "╚══════════════════════════════════════╝"
echo -e "${NC}"

# --- 0. Preparação (Fechar processos antigos) ---
warn "Preparando o ambiente..."
killall vpn-tray 2>/dev/null || true
killall snx-rs 2>/dev/null || true
sleep 1
sudo rm -f /run/snx-rs.lock 2>/dev/null || true

# --- 1. Detectar SO ---
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME="$NAME"
        OS_ID="$ID"
        OS_ID_LIKE="$ID_LIKE"
    else
        error "Sistema operacional não identificado (/etc/os-release não encontrado)"
    fi

    ARCH=$(uname -m)
    if [ "$ARCH" != "x86_64" ]; then
        error "Arquitetura $ARCH não suportada. Apenas x86_64."
    fi

    if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" || "$OS_ID" == "zorin" || "$OS_ID_LIKE" == *"ubuntu"* || "$OS_ID_LIKE" == *"debian"* ]]; then
        PKG_MANAGER="apt"
    elif [[ "$OS_ID" == "arch" || "$OS_ID" == "cachyos" || "$OS_ID_LIKE" == *"arch"* ]]; then
        PKG_MANAGER="pacman"
    else
        if command -v apt &>/dev/null; then PKG_MANAGER="apt";
        elif command -v pacman &>/dev/null; then PKG_MANAGER="pacman";
        else error "Gerenciador de pacotes não suportado."; fi
    fi
    info "Sistema: $OS_NAME | Gerenciador: $PKG_MANAGER"
}

detect_os

# --- 2. Instalar snx-rs ---
if command -v snx-rs &>/dev/null; then
    info "snx-rs já instalado."
else
    warn "Instalando snx-rs v${SNX_RS_VERSION}..."
    if [ "$PKG_MANAGER" == "apt" ]; then
        URL="https://github.com/ancwrd1/snx-rs/releases/download/v${SNX_RS_VERSION}/snx-rs_${SNX_RS_VERSION}_amd64.deb"
        TMP_PKG=$(mktemp /tmp/snx-rs-XXXX.deb); curl -L -o "$TMP_PKG" "$URL"
        sudo apt install -y "$TMP_PKG"; rm -f "$TMP_PKG"
    elif [ "$PKG_MANAGER" == "pacman" ]; then
        URL="https://github.com/ancwrd1/snx-rs/releases/download/v${SNX_RS_VERSION}/snx-rs-v${SNX_RS_VERSION}-x86_64-unknown-linux-gnu.tar.gz"
        TMP_PKG=$(mktemp /tmp/snx-rs-XXXX.tar.gz); curl -L -o "$TMP_PKG" "$URL"
        TMP_DIR=$(mktemp -d); tar -xf "$TMP_PKG" -C "$TMP_DIR"
        sudo install -m 755 "$TMP_DIR/snx-rs" /usr/bin/
        [ -f "$TMP_DIR/snxctl" ] && sudo install -m 755 "$TMP_DIR/snxctl" /usr/bin/
        rm -rf "$TMP_DIR" "$TMP_PKG"
    fi
    info "snx-rs instalado."
fi

# --- 3. Instalar dependências ---
warn "Instalando dependências..."
if [ "$PKG_MANAGER" == "apt" ]; then
    sudo apt update
    sudo apt install -y python3-gi python3-requests gir1.2-gtk-3.0 gir1.2-ayatanaappindicator3-0.1 libwebkit2gtk-4.0-37 || sudo apt install -y python3-gi python3-requests gir1.2-gtk-3.0 gir1.2-ayatanaappindicator3-0.1 libwebkit2gtk-4.1-0
elif [ "$PKG_MANAGER" == "pacman" ]; then
    sudo pacman -Sy --noconfirm python-gobject python-requests gtk3 libayatana-appindicator webkit2gtk
fi
info "Dependências instaladas."



# --- 5. Credenciais Unificadas ---
setup_vpn_config() {
    local name=$1; local label=$2; local server=$3; local conf_file="$CONFIG_DIR/$name.conf"
    echo -e "\n${BOLD}$label${NC}"
    if [ -f "$conf_file" ]; then
        read -rp "Já configurada. Deseja redefinir? (s/N): " choice
        [[ "$choice" != "s" && "$choice" != "S" ]] && return
    fi
    read -rp "Usuário $name: " USER_INPUT
    read -rsp "Senha $name: " PASS_INPUT; echo ""
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
}

echo -e "\n${BOLD}=== Configuração de Credenciais ===${NC}"
setup_vpn_config "vpnro" "VPN RO - Rondônia" "131.72.155.42"
setup_vpn_config "vpnpr" "VPN PR - Paraná" "acessoremoto.pr.gov.br"
setup_vpn_config "vpnam" "VPN AM - Amazonas" "sslvpn.prodam.am.gov.br"
info "Configurações de credenciais finalizadas."

# --- 6. vpn-tray e ícones ---
mkdir -p "$LOCAL_BIN" "$ICON_DIR"
cp "$SCRIPT_DIR/vpn-tray" "$LOCAL_BIN/vpn-tray"; chmod +x "$LOCAL_BIN/vpn-tray"
cp "$SCRIPT_DIR/icons/"*.svg "$ICON_DIR/"
info "vpn-tray e ícones instalados."

# --- 7. Desktop entry e autostart ---
mkdir -p "$APPS_DIR" "$AUTOSTART_DIR"
cat > "$APPS_DIR/vpn-egsys.desktop" <<EOF
[Desktop Entry]
Name=VPN Monitor
Comment=Monitor de VPN Check Point (RO/PR/AM)
Exec=${LOCAL_BIN}/vpn-tray
Icon=${ICON_DIR}/vpn-disconnected.svg
Terminal=false
Type=Application
Categories=Network;
EOF
cp "$APPS_DIR/vpn-egsys.desktop" "$AUTOSTART_DIR/vpn-tray.desktop"
update-desktop-database "$APPS_DIR" 2>/dev/null || true
info "Atalhos de menu e autostart configurados."

# --- 8. Aliases ---
setup_aliases() {
    local shell_rc=$1; [ ! -f "$shell_rc" ] && return
    MARKER="# >>> vpn-egsys >>>"; MARKER_END="# <<< vpn-egsys <<<"
    sed -i "/$MARKER/,/$MARKER_END/d" "$shell_rc" 2>/dev/null || true
    cat >> "$shell_rc" <<ALIASES
$MARKER
alias vpnro="vpnoff >/dev/null 2>&1; nohup sudo snx-rs -m standalone -c ~/.config/snx-rs/vpnro.conf -l info > /tmp/snx-rs.log 2>&1 & sleep 3 && tail -n 10 /tmp/snx-rs.log"
alias vpnpr="vpnoff >/dev/null 2>&1; nohup sudo snx-rs -m standalone -c ~/.config/snx-rs/vpnpr.conf -l info > /tmp/snx-rs.log 2>&1 & sleep 3 && tail -n 10 /tmp/snx-rs.log"
alias vpnam="vpnoff >/dev/null 2>&1; nohup sudo snx-rs -m standalone -c ~/.config/snx-rs/vpnam.conf -l info > /tmp/snx-rs.log 2>&1 & sleep 3 && tail -n 10 /tmp/snx-rs.log"
alias vpnoff="killall snx-rs 2>/dev/null; sleep 1; sudo rm -f /run/snx-rs.lock 2>/dev/null; echo 'VPN desconectada'"
alias vpnstatus="tail -n 20 /tmp/snx-rs.log 2>/dev/null; ip addr show snx-xfrm 2>/dev/null || echo 'Interface snx-xfrm não encontrada'"
$MARKER_END
ALIASES
}
setup_aliases "$HOME/.bashrc"; setup_aliases "$HOME/.zshrc"
info "Aliases adicionados."

echo -e "\n${BOLD}${YELLOW}=== Configuração Adicional de Sudo ===${NC}"
echo "Para evitar que o comando 'snx-rs' solicite sua senha do sudo repetidamente,"
echo "é altamente recomendável configurar o 'NOPASSWD' no seu arquivo sudoers."
echo "Execute o seguinte comando para editar o arquivo sudoers com segurança:"
echo "  ${GREEN}sudo visudo${NC}"
echo "Adicione a seguinte linha no final do arquivo, substituindo 'SEU_USUARIO' pelo seu nome de usuário:"
SNX_RS_PATH=$(command -v snx-rs || echo "/usr/bin/snx-rs")
echo "  ${GREEN}SEU_USUARIO ALL=(ALL) NOPASSWD: ${SNX_RS_PATH}${NC}"
echo "Salve e saia do editor. Isso permitirá que o 'snx-rs' seja executado via aliases sem pedir a senha."

# --- 9. Iniciar tray ---
nohup "$LOCAL_BIN/vpn-tray" > /dev/null 2>&1 &
info "Monitor da bandeja iniciado."

echo -e "\n${BOLD}${GREEN}=== Instalação concluída com sucesso! ===${NC}\n"
