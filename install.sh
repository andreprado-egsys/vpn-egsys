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
SNX_RS_DEB_URL="https://github.com/ancwrd1/snx-rs/releases/download/v${SNX_RS_VERSION}/snx-rs-v${SNX_RS_VERSION}-linux-x86_64.deb"
CONFIG_DIR="$HOME/.config/snx-rs"
LOCAL_BIN="$HOME/.local/bin"
APPS_DIR="$HOME/.local/share/applications"
AUTOSTART_DIR="$HOME/.config/autostart"

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }

echo -e "${BOLD}"
echo "╔══════════════════════════════════════╗"
echo "║       vpn-egsys - Instalador         ║"
echo "║   VPN Check Point (RO e PR)          ║"
echo "╚══════════════════════════════════════╝"
echo -e "${NC}"

# --- 1. Instalar snx-rs ---
if command -v snx-rs &>/dev/null; then
    CURRENT=$(snx-rs --version 2>&1 | grep -oP '[\d.]+' | head -1)
    info "snx-rs já instalado (v${CURRENT})"
else
    warn "Instalando snx-rs v${SNX_RS_VERSION}..."
    TMP_DEB=$(mktemp /tmp/snx-rs-XXXX.deb)
    curl -L -o "$TMP_DEB" "$SNX_RS_DEB_URL"
    sudo dpkg -i "$TMP_DEB"
    rm -f "$TMP_DEB"
    info "snx-rs instalado"
fi

# --- 2. Instalar dependência do tray ---
if ! python3 -c "import gi; gi.require_version('AyatanaAppIndicator3','0.1')" 2>/dev/null; then
    warn "Instalando dependência gir1.2-ayatanaappindicator3-0.1..."
    sudo apt install -y gir1.2-ayatanaappindicator3-0.1
fi
info "Dependências OK"

# --- 3. Permissões (SUID) ---
sudo chmod u+s /usr/bin/snx-rs /usr/bin/snxctl /usr/bin/snx-rs-gui 2>/dev/null
info "Permissões SUID configuradas"

# --- 4. Credenciais ---
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

# --- 5. Configs ---
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

# --- 6. vpn-tray ---
mkdir -p "$LOCAL_BIN"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp "$SCRIPT_DIR/vpn-tray" "$LOCAL_BIN/vpn-tray"
chmod +x "$LOCAL_BIN/vpn-tray"

ICON_DIR="$HOME/.local/share/icons/vpn-egsys"
mkdir -p "$ICON_DIR"
cp "$SCRIPT_DIR/icons/"*.svg "$ICON_DIR/"
info "vpn-tray e ícones instalados"

# --- 7. Desktop entry e autostart ---
mkdir -p "$APPS_DIR" "$AUTOSTART_DIR"

cat > "$APPS_DIR/vpn-egsys.desktop" <<EOF
[Desktop Entry]
Name=VPN Monitor
Comment=Monitor de VPN Check Point (RO/PR)
Exec=${LOCAL_BIN}/vpn-tray
Icon=network-vpn
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
EOF

update-desktop-database "$APPS_DIR" 2>/dev/null
info "Atalho e autostart configurados"

# --- 8. Aliases no .bashrc ---
MARKER="# >>> vpn-egsys >>>"
MARKER_END="# <<< vpn-egsys <<<"

# Remove bloco antigo se existir
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

# --- 9. Testar conectividade ---
echo ""
warn "Testando conectividade com os servidores..."
if timeout 10 snx-rs -m info -c "$CONFIG_DIR/vpnro.conf" >/dev/null 2>&1; then
    info "VPN RO: servidor acessível ✓"
else
    error "VPN RO: servidor inacessível"
fi
if timeout 10 snx-rs -m info -c "$CONFIG_DIR/vpnpr.conf" >/dev/null 2>&1; then
    info "VPN PR: servidor acessível ✓"
else
    error "VPN PR: servidor inacessível"
fi

echo ""
echo -e "${BOLD}=== Instalação concluída! ===${NC}"
echo ""
echo "Uso pelo terminal:"
echo "  vpnro       - Conectar VPN Rondônia"
echo "  vpnpr       - Conectar VPN Paraná"
echo "  vpnoff      - Desconectar"
echo "  vpnstatus   - Ver status"
echo ""
echo "Uso gráfico:"
echo "  Procure 'VPN Monitor' no menu de apps"
echo "  Ícone na bandeja mostra status da conexão"
echo ""
echo "Execute: source ~/.bashrc"
