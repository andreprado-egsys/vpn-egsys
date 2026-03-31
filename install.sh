#!/bin/bash
set -e

# vpn-egsys - Setup interativo de VPN Check Point (snx-rs)
# Configura VPN RO (Rondônia) e VPN PR (Paraná)

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
echo "╚══════════════════════════════════════╝"
echo -e "${NC}"

# --- 1. Detectar SO ---
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME="$NAME"
        OS_VERSION="$VERSION_ID"
        OS_ID="$ID"
        OS_ID_LIKE="$ID_LIKE"
    else
        error "Sistema operacional não identificado (/etc/os-release não encontrado)"
    fi

    ARCH=$(uname -m)
    if [ "$ARCH" != "x86_64" ]; then
        error "Arquitetura $ARCH não suportada. Apenas x86_64."
    fi

    # Detectar gerenciador de pacotes
    if command -v apt &>/dev/null; then
        PKG_MANAGER="apt"
        PKG_EXT="deb"
    elif command -v dnf &>/dev/null; then
        PKG_MANAGER="dnf"
        PKG_EXT="rpm"
    elif command -v yum &>/dev/null; then
        PKG_MANAGER="yum"
        PKG_EXT="rpm"
    elif command -v pacman &>/dev/null; then
        PKG_MANAGER="pacman"
        PKG_EXT="tar.xz"
    else
        error "Gerenciador de pacotes não suportado"
    fi

    # Detectar desktop environment
    DESKTOP="${XDG_CURRENT_DESKTOP:-desconhecido}"

    info "Sistema: $OS_NAME $OS_VERSION ($ARCH)"
    info "Gerenciador de pacotes: $PKG_MANAGER"
    info "Desktop: $DESKTOP"
}

detect_os

# --- 2. Instalar snx-rs ---
SNX_RS_URL="https://github.com/ancwrd1/snx-rs/releases/download/v${SNX_RS_VERSION}/snx-rs-v${SNX_RS_VERSION}-linux-x86_64.${PKG_EXT}"

if command -v snx-rs &>/dev/null; then
    CURRENT=$(snx-rs --version 2>&1 | grep -oP '[\d.]+' | head -1)
    info "snx-rs já instalado (v${CURRENT})"
else
    warn "Instalando snx-rs v${SNX_RS_VERSION}..."
    TMP_PKG=$(mktemp /tmp/snx-rs-XXXX.${PKG_EXT})
    curl -L -o "$TMP_PKG" "$SNX_RS_URL"

    case "$PKG_MANAGER" in
        apt)     sudo dpkg -i "$TMP_PKG" ;;
        dnf|yum) sudo $PKG_MANAGER install -y "$TMP_PKG" ;;
        pacman)
            TMP_DIR=$(mktemp -d)
            tar -xf "$TMP_PKG" -C "$TMP_DIR"
            sudo cp "$TMP_DIR"/usr/bin/snx-rs* /usr/bin/
            sudo cp "$TMP_DIR"/usr/bin/snxctl /usr/bin/ 2>/dev/null || true
            rm -rf "$TMP_DIR"
            ;;
    esac

    rm -f "$TMP_PKG"
    info "snx-rs v${SNX_RS_VERSION} instalado"
fi

# --- 3. Instalar dependência do tray ---
install_tray_deps() {
    if python3 -c "import gi; gi.require_version('AyatanaAppIndicator3','0.1')" 2>/dev/null; then
        info "Dependências do tray OK"
        return
    fi

    warn "Instalando dependências do tray..."
    case "$PKG_MANAGER" in
        apt)     sudo apt install -y gir1.2-ayatanaappindicator3-0.1 ;;
        dnf|yum) sudo $PKG_MANAGER install -y libayatana-appindicator-gtk3 ;;
        pacman)  sudo pacman -S --noconfirm libayatana-appindicator ;;
    esac

    if ! python3 -c "import gi; gi.require_version('AyatanaAppIndicator3','0.1')" 2>/dev/null; then
        warn "Tray icon pode não funcionar. Instale manualmente o pacote appindicator do seu sistema."
    fi
}

install_tray_deps

# --- 4. Permissões (SUID) ---
for bin in /usr/bin/snx-rs /usr/bin/snxctl /usr/bin/snx-rs-gui; do
    [ -f "$bin" ] && sudo chmod u+s "$bin"
done
info "Permissões SUID configuradas"

# --- 5. Credenciais ---
echo ""
echo -e "${BOLD}=== Credenciais VPN RO (Rondônia) ===${NC}"
echo "Servidor: 131.72.155.42"
read -rp "Usuário RO: " RO_USER
read -rsp "Senha RO: " RO_PASS
echo ""
RO_PASS_B64=$(echo -n "$RO_PASS" | base64)

echo ""
echo -e "${BOLD}=== Credenciais VPN PR (Paraná) ===${NC}"
echo "Servidor: acessoremoto.pr.gov.br"
read -rp "Usuário PR: " PR_USER
read -rsp "Senha PR: " PR_PASS
echo ""
PR_PASS_B64=$(echo -n "$PR_PASS" | base64)

# --- 6. Configs ---
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

cp "$CONFIG_DIR/vpnro.conf" "$CONFIG_DIR/snx-rs.conf"
chmod 600 "$CONFIG_DIR"/*.conf
info "Configs criados em $CONFIG_DIR"

# --- 7. vpn-tray e ícones ---
mkdir -p "$LOCAL_BIN" "$ICON_DIR"
cp "$SCRIPT_DIR/vpn-tray" "$LOCAL_BIN/vpn-tray"
chmod +x "$LOCAL_BIN/vpn-tray"
cp "$SCRIPT_DIR/icons/"*.svg "$ICON_DIR/"
info "vpn-tray e ícones instalados"

# --- 8. Desktop entry e autostart ---
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
info "Atalho e autostart configurados"

# --- 9. Aliases no .bashrc ---
MARKER="# >>> vpn-egsys >>>"
MARKER_END="# <<< vpn-egsys <<<"

if grep -q "$MARKER" ~/.bashrc 2>/dev/null; then
    sed -i "/$MARKER/,/$MARKER_END/d" ~/.bashrc
fi

cat >> ~/.bashrc <<'ALIASES'
# >>> vpn-egsys >>>
alias vpnro="vpnoff >/dev/null 2>&1; nohup snx-rs -m standalone -c ~/.config/snx-rs/vpnro.conf -l info > /tmp/snx-rs.log 2>&1 & sleep 4 && tail -20 /tmp/snx-rs.log"
alias vpnpr="vpnoff >/dev/null 2>&1; nohup snx-rs -m standalone -c ~/.config/snx-rs/vpnpr.conf -l info > /tmp/snx-rs.log 2>&1 & sleep 4 && tail -20 /tmp/snx-rs.log"
alias vpnoff="killall snx-rs 2>/dev/null; sleep 1; rm -f /run/snx-rs.lock 2>/dev/null; echo 'VPN desconectada'"
alias vpnstatus="tail -20 /tmp/snx-rs.log 2>/dev/null; ip addr show snx-xfrm 2>/dev/null || echo 'Desconectado'"
# <<< vpn-egsys <<<
ALIASES
info "Aliases adicionados ao .bashrc"

# --- 10. Testar conectividade ---
echo ""
warn "Testando conectividade com os servidores..."
if timeout 10 snx-rs -m info -c "$CONFIG_DIR/vpnro.conf" >/dev/null 2>&1; then
    info "VPN RO: servidor acessível ✓"
else
    error_msg="VPN RO: servidor inacessível"
    echo -e "${RED}[✗]${NC} $error_msg"
fi
if timeout 10 snx-rs -m info -c "$CONFIG_DIR/vpnpr.conf" >/dev/null 2>&1; then
    info "VPN PR: servidor acessível ✓"
else
    error_msg="VPN PR: servidor inacessível"
    echo -e "${RED}[✗]${NC} $error_msg"
fi

# --- 11. Iniciar tray ---
echo ""
killall vpn-tray 2>/dev/null || true
sleep 1
nohup "$LOCAL_BIN/vpn-tray" > /dev/null 2>&1 &
info "VPN Monitor iniciado na bandeja do sistema"

echo ""
echo -e "${BOLD}=== Instalação concluída! ===${NC}"
echo ""
echo "Terminal:  vpnro | vpnpr | vpnoff | vpnstatus"
echo "Gráfico:   Ícone na bandeja do sistema (ao lado do relógio)"
echo ""
echo "Execute: source ~/.bashrc"
