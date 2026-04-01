#!/bin/bash
set -e

# vpn-egsys - Setup interativo de VPN Check Point (snx-rs)
# Configura VPN RO (Rondônia) e VPN PR (Paraná)
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
echo "║   VPN Check Point (RO e PR)          ║"
echo "║      Multi-System Support            ║"
echo "╚══════════════════════════════════════╝"
echo -e "${NC}"

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
        # Tenta detectar pelo binário se ID não bater
        if command -v apt &>/dev/null; then
            PKG_MANAGER="apt"
        elif command -v pacman &>/dev/null; then
            PKG_MANAGER="pacman"
        else
            error "Gerenciador de pacotes não suportado. Este script suporta sistemas baseados em Debian/Ubuntu e Arch Linux."
        fi
    fi

    info "Sistema detectado: $OS_NAME ($OS_ID)"
    info "Gerenciador de pacotes: $PKG_MANAGER"
}

detect_os

# --- 2. Instalar snx-rs ---
if command -v snx-rs &>/dev/null; then
    CURRENT=$(snx-rs --version 2>&1 | grep -oP '[\d.]+' | head -1)
    info "snx-rs já instalado (v${CURRENT})"
else
    warn "Instalando snx-rs v${SNX_RS_VERSION}..."
    
    if [ "$PKG_MANAGER" == "apt" ]; then
        URL="https://github.com/ancwrd1/snx-rs/releases/download/v${SNX_RS_VERSION}/snx-rs_${SNX_RS_VERSION}_amd64.deb"
        TMP_PKG=$(mktemp /tmp/snx-rs-XXXX.deb)
        curl -L -o "$TMP_PKG" "$URL"
        sudo apt install -y "$TMP_PKG"
        rm -f "$TMP_PKG"
    elif [ "$PKG_MANAGER" == "pacman" ]; then
        URL="https://github.com/ancwrd1/snx-rs/releases/download/v${SNX_RS_VERSION}/snx-rs-v${SNX_RS_VERSION}-x86_64-unknown-linux-gnu.tar.gz"
        TMP_PKG=$(mktemp /tmp/snx-rs-XXXX.tar.gz)
        curl -L -o "$TMP_PKG" "$URL"
        TMP_DIR=$(mktemp -d)
        tar -xf "$TMP_PKG" -C "$TMP_DIR"
        # O tar.gz contém o binário diretamente
        sudo install -m 755 "$TMP_DIR/snx-rs" /usr/bin/
        # snxctl pode não estar no tar.gz do release binário, mas se estiver instalamos
        [ -f "$TMP_DIR/snxctl" ] && sudo install -m 755 "$TMP_DIR/snxctl" /usr/bin/
        rm -rf "$TMP_DIR" "$TMP_PKG"
    fi
    info "snx-rs v${SNX_RS_VERSION} instalado"
fi

# --- 3. Instalar dependências (snx-rs + tray) ---
warn "Instalando dependências do sistema..."
if [ "$PKG_MANAGER" == "apt" ]; then
    sudo apt update
    sudo apt install -y python3-gi python3-requests gir1.2-gtk-3.0 gir1.2-ayatanaappindicator3-0.1 libwebkit2gtk-4.0-37 || sudo apt install -y python3-gi python3-requests gir1.2-gtk-3.0 gir1.2-ayatanaappindicator3-0.1 libwebkit2gtk-4.1-0
elif [ "$PKG_MANAGER" == "pacman" ]; then
    sudo pacman -Sy --noconfirm python-gobject python-requests gtk3 libayatana-appindicator webkit2gtk
fi
info "Dependências instaladas"

# --- 4. Permissões (SUID) ---
# snx-rs precisa de SUID para gerenciar interfaces de rede sem sudo a cada conexão
for bin in /usr/bin/snx-rs /usr/bin/snxctl; do
    if [ -f "$bin" ]; then
        sudo chown root:root "$bin"
        sudo chmod u+s "$bin"
    fi
done
info "Permissões SUID configuradas para snx-rs"

# --- 5. Credenciais ---
if [ ! -f "$CONFIG_DIR/vpnro.conf" ] || [ ! -f "$CONFIG_DIR/vpnpr.conf" ]; then
    echo ""
    echo -e "${BOLD}=== Configuração de Credenciais ===${NC}"
    echo "Isso será feito apenas uma vez."
    
    echo -e "\n${BOLD}VPN RO (Rondônia)${NC}"
    read -rp "Usuário RO (ex: nome.sobrenome): " RO_USER
    read -rsp "Senha RO: " RO_PASS
    echo ""
    RO_PASS_B64=$(echo -n "$RO_PASS" | base64)

    echo -e "\n${BOLD}VPN PR (Paraná)${NC}"
    read -rp "Usuário PR (ex: nome.sobrenome): " PR_USER
    read -rsp "Senha PR: " PR_PASS
    echo ""
    PR_PASS_B64=$(echo -n "$PR_PASS" | base64)

    mkdir -p "$CONFIG_DIR"
    
    cat > "$CONFIG_DIR/vpnro.conf" <<EOF
server-name=131.72.155.42
user-name=${RO_USER}
password=${RO_PASS_B64}
ignore-server-cert=true
login-type=vpn
EOF

    cat > "$CONFIG_DIR/vpnpr.conf" <<EOF
server-name=acessoremoto.pr.gov.br
user-name=${PR_USER}
password=${PR_PASS_B64}
ignore-server-cert=true
login-type=vpn
EOF
    
    chmod 600 "$CONFIG_DIR"/*.conf
    info "Arquivos de configuração criados em $CONFIG_DIR"
else
    info "Configurações de credenciais já existem."
fi

# --- 6. vpn-tray e ícones ---
mkdir -p "$LOCAL_BIN" "$ICON_DIR"
cp "$SCRIPT_DIR/vpn-tray" "$LOCAL_BIN/vpn-tray"
chmod +x "$LOCAL_BIN/vpn-tray"
cp "$SCRIPT_DIR/icons/"*.svg "$ICON_DIR/"
info "vpn-tray e ícones instalados em $LOCAL_BIN"

# --- 7. Desktop entry e autostart ---
mkdir -p "$APPS_DIR" "$AUTOSTART_DIR"

cat > "$APPS_DIR/vpn-egsys.desktop" <<EOF
[Desktop Entry]
Name=VPN Monitor
Comment=Monitor de VPN Check Point (RO/PR)
Exec=${LOCAL_BIN}/vpn-tray
Icon=${ICON_DIR}/vpn-disconnected.svg
Terminal=false
Type=Application
Categories=Network;
EOF

cat > "$AUTOSTART_DIR/vpn-tray.desktop" <<EOF
[Desktop Entry]
Name=VPN Monitor
Exec=${LOCAL_BIN}/vpn-tray
Type=Application
X-KDE-autostart-phase=2
X-GNOME-Autostart-enabled=true
EOF

update-desktop-database "$APPS_DIR" 2>/dev/null || true
info "Atalhos de menu e inicialização automática configurados"

# --- 8. Aliases no .bashrc / .zshrc ---
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
alias vpnoff="killall snx-rs 2>/dev/null; sleep 1; sudo rm -f /run/snx-rs.lock 2>/dev/null; echo 'VPN desconectada'"
alias vpnstatus="tail -n 20 /tmp/snx-rs.log 2>/dev/null; ip addr show snx-xfrm 2>/dev/null || echo 'Interface snx-xfrm não encontrada'"
$MARKER_END
ALIASES
}

setup_aliases "$HOME/.bashrc"
setup_aliases "$HOME/.zshrc"
info "Aliases adicionados ao .bashrc e .zshrc"

# --- 9. Iniciar tray ---
echo ""
killall vpn-tray 2>/dev/null || true
sleep 1
nohup "$LOCAL_BIN/vpn-tray" > /dev/null 2>&1 &
info "Monitor da bandeja iniciado"

echo ""
echo -e "${BOLD}=== Instalação concluída com sucesso! ===${NC}"
echo ""
echo "Comandos rápidos no terminal:"
echo "  vpnro      - Conecta à VPN Rondônia"
echo "  vpnpr      - Conecta à VPN Paraná"
echo "  vpnoff     - Desconecta qualquer VPN"
echo "  vpnstatus  - Mostra o log e status da conexão"
echo ""
echo "Um ícone foi adicionado à sua bandeja do sistema para controle gráfico."
echo "IMPORTANTE: Reinicie seu terminal ou execute: source ~/.bashrc"
