#!/bin/bash
set -e

# vpn-egsys - Instalador
# Suporta: Debian/Ubuntu/Zorin/Mint, Arch/CachyOS/EndeavourOS, Fedora/RHEL

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
SUDOERS_FILE="/etc/sudoers.d/vpn-egsys"

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo -e "${BOLD}"
echo "╔══════════════════════════════════════╗"
echo "║       vpn-egsys - Instalador         ║"
echo "║     VPN Check Point via snx-rs       ║"
echo "╚══════════════════════════════════════╝"
echo -e "${NC}"

# --- Detectar distro ---
detect_distro() {
    if [ ! -f /etc/os-release ]; then
        error "Sistema não identificado (/etc/os-release ausente)"
    fi
    . /etc/os-release

    [[ "$(uname -m)" != "x86_64" ]] && error "Apenas x86_64 suportado."

    # Detectar família pela cadeia ID/ID_LIKE
    local ids="$ID $ID_LIKE"
    if echo "$ids" | grep -qwE "arch"; then
        PKG_MANAGER="pacman"
    elif echo "$ids" | grep -qwE "debian|ubuntu"; then
        PKG_MANAGER="apt"
    elif echo "$ids" | grep -qwE "fedora|rhel|centos"; then
        PKG_MANAGER="dnf"
    elif command -v pacman &>/dev/null; then
        PKG_MANAGER="pacman"
    elif command -v apt &>/dev/null; then
        PKG_MANAGER="apt"
    elif command -v dnf &>/dev/null; then
        PKG_MANAGER="dnf"
    else
        error "Gerenciador de pacotes não suportado."
    fi
    info "Sistema: ${PRETTY_NAME:-$ID} | Pacotes: $PKG_MANAGER"
}

# --- Instalar dependências ---
install_deps() {
    warn "Instalando dependências..."
    case "$PKG_MANAGER" in
        apt)
            sudo apt update -qq
            sudo apt install -y python3-gi gir1.2-gtk-3.0 gir1.2-ayatanaappindicator3-0.1 \
                libwebkit2gtk-4.1-0 2>/dev/null || \
            sudo apt install -y python3-gi gir1.2-gtk-3.0 gir1.2-ayatanaappindicator3-0.1 \
                libwebkit2gtk-4.0-37
            ;;
        pacman)
            sudo pacman -S --needed --noconfirm python-gobject gtk3 libayatana-appindicator webkit2gtk
            ;;
        dnf)
            sudo dnf install -y python3-gobject gtk3 libayatana-appindicator-gtk3 webkit2gtk4.1
            ;;
    esac
    info "Dependências instaladas."
}

# --- Instalar snx-rs ---
install_snx_rs() {
    if command -v snx-rs &>/dev/null; then
        info "snx-rs já instalado: $(snx-rs --version 2>/dev/null || echo 'ok')"
        return
    fi
    warn "Instalando snx-rs v${SNX_RS_VERSION}..."
    local base_url="https://github.com/ancwrd1/snx-rs/releases/download/v${SNX_RS_VERSION}"
    case "$PKG_MANAGER" in
        apt)
            local tmp=$(mktemp /tmp/snx-rs-XXXX.deb)
            curl -fSL -o "$tmp" "${base_url}/snx-rs_${SNX_RS_VERSION}_amd64.deb"
            sudo apt install -y "$tmp"; rm -f "$tmp"
            ;;
        pacman|dnf)
            local tmp=$(mktemp /tmp/snx-rs-XXXX.tar.gz)
            curl -fSL -o "$tmp" "${base_url}/snx-rs-v${SNX_RS_VERSION}-x86_64-unknown-linux-gnu.tar.gz"
            local dir=$(mktemp -d); tar -xf "$tmp" -C "$dir"
            sudo install -m 755 "$dir/snx-rs" /usr/bin/
            [ -f "$dir/snxctl" ] && sudo install -m 755 "$dir/snxctl" /usr/bin/
            rm -rf "$dir" "$tmp"
            ;;
    esac
    info "snx-rs instalado."
}

# --- Configurar sudoers.d (sem necessidade de senha para snx-rs) ---
setup_sudoers() {
    local snx_path
    snx_path=$(command -v snx-rs)
    local killall_path
    killall_path=$(command -v killall 2>/dev/null || echo "/usr/bin/killall")

    local rule="${USER} ALL=(ALL) NOPASSWD: ${snx_path}, ${killall_path} snx-rs, /usr/bin/rm -f /run/snx-rs.lock"

    if [ -f "$SUDOERS_FILE" ] && grep -qF "$snx_path" "$SUDOERS_FILE" 2>/dev/null; then
        info "Sudoers já configurado."
        return
    fi

    warn "Configurando sudo sem senha para snx-rs..."
    echo "$rule" | sudo tee "$SUDOERS_FILE" > /dev/null
    sudo chmod 0440 "$SUDOERS_FILE"

    # Validar sintaxe
    if sudo visudo -cf "$SUDOERS_FILE" &>/dev/null; then
        info "Sudoers configurado: ${SUDOERS_FILE}"
    else
        sudo rm -f "$SUDOERS_FILE"
        error "Erro na validação do sudoers. Arquivo removido por segurança."
    fi
}

# --- Configurar VPNs ---
setup_vpn() {
    local name="$1" label="$2" server="$3"
    local conf="$CONFIG_DIR/${name}.conf"

    if [ -f "$conf" ]; then
        info "$label já configurada. Pulando."
        return
    fi

    echo -e "\n${BOLD}Configurar: $label${NC}"
    read -rp "Usuário: " vpn_user
    [[ -z "$vpn_user" ]] && { warn "Pulando $label (usuário vazio)."; return; }
    read -rsp "Senha: " vpn_pass; echo ""
    [[ -z "$vpn_pass" ]] && { warn "Pulando $label (senha vazia)."; return; }

    mkdir -p "$CONFIG_DIR"
    cat > "$conf" <<EOF
server-name=${server}
user-name=${vpn_user}
password=$(echo -n "$vpn_pass" | base64)
ignore-server-cert=true
login-type=vpn
EOF
    chmod 600 "$conf"
    info "$label configurada."
}

# --- Gerar aliases dinamicamente a partir dos .conf existentes ---
setup_aliases() {
    local shell_rc="$1"
    [ ! -f "$shell_rc" ] && return

    local marker="# >>> vpn-egsys >>>"
    local marker_end="# <<< vpn-egsys <<<"

    # Remover bloco antigo
    sed -i "/${marker//\//\\/}/,/${marker_end//\//\\/}/d" "$shell_rc" 2>/dev/null || true

    local snx_path
    snx_path=$(command -v snx-rs)

    {
        echo "$marker"
        # Gerar alias para cada .conf encontrado (ordem alfabética)
        for conf in $(find "$CONFIG_DIR" -name "vpn*.conf" 2>/dev/null | sort); do
            local vpn_name
            vpn_name=$(basename "$conf" .conf)
            echo "alias ${vpn_name}=\"sudo killall snx-rs 2>/dev/null; sleep 0.5; sudo rm -f /run/snx-rs.lock 2>/dev/null; nohup sudo ${snx_path} -m standalone -c ${conf} -l info > /tmp/snx-rs.log 2>&1 & sleep 3 && tail -n 5 /tmp/snx-rs.log\""
        done
        echo "alias vpnoff=\"sudo killall snx-rs 2>/dev/null; sleep 1; sudo rm -f /run/snx-rs.lock 2>/dev/null; echo 'VPN desconectada'\""
        echo "alias vpnstatus=\"ip addr show snx-xfrm 2>/dev/null && tail -n 10 /tmp/snx-rs.log 2>/dev/null || echo 'VPN não conectada'\""
        echo "$marker_end"
    } >> "$shell_rc"
}

# --- Instalar vpn-tray e ícones ---
install_tray() {
    mkdir -p "$LOCAL_BIN" "$ICON_DIR" "$APPS_DIR" "$AUTOSTART_DIR"
    cp "$SCRIPT_DIR/vpn-tray" "$LOCAL_BIN/vpn-tray"
    chmod +x "$LOCAL_BIN/vpn-tray"
    cp "$SCRIPT_DIR/icons/"*.svg "$ICON_DIR/"

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
    update-desktop-database "$APPS_DIR" 2>/dev/null || true
    info "vpn-tray instalado com autostart."
}

# ============ EXECUÇÃO ============

# Fechar instâncias anteriores
killall vpn-tray 2>/dev/null || true
killall snx-rs 2>/dev/null || true
sudo rm -f /run/snx-rs.lock 2>/dev/null || true

detect_distro
install_deps
install_snx_rs
setup_sudoers

echo -e "\n${BOLD}=== Configuração de VPNs ===${NC}"
echo -e "VPNs já configuradas serão preservadas.\n"

# VPNs conhecidas
setup_vpn "vpnro" "VPN RO - Rondônia" "131.72.155.42"
setup_vpn "vpnpr" "VPN PR - Paraná" "acessoremoto.pr.gov.br"
setup_vpn "vpnam" "VPN AM - Amazonas" "sslvpn.prodam.am.gov.br"

# Aliases dinâmicos
setup_aliases "$HOME/.bashrc"
setup_aliases "$HOME/.zshrc"
info "Aliases configurados (baseados nos .conf existentes)."

install_tray

# Iniciar tray
nohup "$LOCAL_BIN/vpn-tray" > /dev/null 2>&1 &
info "Monitor da bandeja iniciado."

echo -e "\n${GREEN}${BOLD}✓ Instalação concluída!${NC}"
echo -e "  Comandos disponíveis: $(find "$CONFIG_DIR" -name "vpn*.conf" 2>/dev/null | sort | xargs -I{} basename {} .conf | tr '\n' ' ')vpnoff vpnstatus"
echo -e "  Reinicie o terminal para usar os aliases.\n"
