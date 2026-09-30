#!/bin/bash
# macos/install_macos.sh - Instalador dedicado para macOS (Darwin)
# Suporta macOS Monterey, Ventura, Sonoma, Sequoia (Intel & Apple Silicon)

set -e

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[96m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL_BIN="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config/snx-rs"
MACOS_SUPPORT_DIR="$HOME/Library/Application Support/vpn-egsys"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo -e "${BOLD}"
echo "╔══════════════════════════════════════════╗"
echo "║     vpn-egsys - Instalador macOS        ║"
echo "║    Suporte SNX & IPsec Cross-Platform   ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# --- 1. Verificar Homebrew e Python 3 ---
if ! command -v brew &>/dev/null; then
    warn "Homebrew não encontrado. Recomendamos instalar o Homebrew:"
    echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
fi

if ! command -v python3 &>/dev/null; then
    if command -v brew &>/dev/null; then
        warn "Instalando Python 3 via Homebrew..."
        brew install python3
    else
        error "Python 3 é obrigatório. Instale Python 3 antes de continuar."
    fi
fi
info "Python 3 detectado: $(python3 --version)"

# --- 2. Instalar dependências Python opcionais (para Tray nativo no macOS) ---
warn "Instalando dependências para a barra de menus do macOS (pystray, Pillow)..."
pip3 install --user pystray Pillow 2>/dev/null || true
info "Módulos de interface gráfica verificados."

# --- 3. Criar diretórios de sistema ---
mkdir -p "$LOCAL_BIN" "$CONFIG_DIR" "$MACOS_SUPPORT_DIR/icons" "$LAUNCH_AGENTS_DIR"

# --- 4. Copiar executáveis e módulos ---
warn "Instalando binários e módulos em $LOCAL_BIN..."
cp "$SCRIPT_DIR/vpn" "$LOCAL_BIN/vpn"
chmod +x "$LOCAL_BIN/vpn"

cp "$SCRIPT_DIR/vpn-tray" "$LOCAL_BIN/vpn-tray"
chmod +x "$LOCAL_BIN/vpn-tray"

cp -r "$SCRIPT_DIR/core" "$LOCAL_BIN/"
cp "$SCRIPT_DIR/icons/"*.svg "$MACOS_SUPPORT_DIR/icons/" 2>/dev/null || true
info "Binários 'vpn' e 'vpn-tray' instalados com sucesso."

# --- 5. Configurar LaunchAgent do macOS ---
PLIST_FILE="$LAUNCH_AGENTS_DIR/com.egsys.vpn-tray.plist"
cat > "$PLIST_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.egsys.vpn-tray</string>
    <key>ProgramArguments</key>
    <array>
        <string>$(which python3)</string>
        <string>$LOCAL_BIN/vpn-tray</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>StandardOutPath</key>
    <string>/tmp/vpn-tray.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/vpn-tray.err</string>
</dict>
</plist>
EOF

launchctl unload "$PLIST_FILE" 2>/dev/null || true
launchctl load "$PLIST_FILE" 2>/dev/null || true
info "LaunchAgent macOS configurado ($PLIST_FILE)."

# --- 6. Configurar Aliases e PATH no macOS (~/.zshrc e ~/.bash_profile) ---
setup_macos_shell() {
    local rc="$1"
    [ ! -f "$rc" ] && touch "$rc"

    if ! grep -q 'LOCAL_BIN' "$rc" && ! grep -q "$LOCAL_BIN" "$rc"; then
        echo "export PATH=\"$LOCAL_BIN:\$PATH\"" >> "$rc"
    fi

    MARKER="# >>> vpn-egsys >>>"
    MARKER_END="# <<< vpn-egsys <<<"
    sed -i '' "/$MARKER/,/$MARKER_END/d" "$rc" 2>/dev/null || true

    cat >> "$rc" << 'EOF'
# >>> vpn-egsys >>>
alias vpnro="vpn connect ro"
alias vpnpr="vpn connect pr"
alias vpnam="vpn connect am"
alias vpnsc="vpn connect sc"
alias vpnto="vpn connect to"
alias vpnoff="vpn disconnect"
alias vpnstatus="vpn status"
# <<< vpn-egsys <<<
EOF
}

setup_macos_shell "$HOME/.zshrc"
setup_macos_shell "$HOME/.bash_profile"
info "Aliases e variáveis de ambiente configurados para o shell do macOS."

# --- 7. Assistente de Configuração de VPNs ---
echo -e "\n${BOLD}=== Configuração Inicial de VPNs ===${NC}"
read -rp "Deseja cadastrar uma VPN agora? (S/n): " CFG_NOW
if [[ "$CFG_NOW" != "n" && "$CFG_NOW" != "N" ]]; then
    "$LOCAL_BIN/vpn" add || true
fi

echo -e "\n${BOLD}${GREEN}=== Instalação no macOS concluída com sucesso! ===${NC}"
echo -e "Use o comando ${CYAN}vpn${NC} no terminal para gerenciar suas conexões:"
echo -e "  • ${CYAN}vpn list${NC}       - Listar VPNs configuradas"
echo -e "  • ${CYAN}vpn connect <id>${NC} - Conectar a uma VPN (ex: vpn ro, vpn sc)"
echo -e "  • ${CYAN}vpn status${NC}     - Ver status em tempo real"
echo -e "  • ${CYAN}vpn off${NC}        - Desconectar"
echo -e "  • ${CYAN}vpn add${NC}        - Adicionar nova VPN (SNX ou IPsec)"
echo ""
