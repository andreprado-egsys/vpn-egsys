#!/bin/bash
set -e

# vpn-egsys v2 - Script de Atualização/Migração
# Migra da arquitetura standalone para command mode + NM integration
# Compatível: Ubuntu, Debian, Zorin, Arch, CachyOS, EndeavourOS, Manjaro

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SNX_RS_VERSION="6.0.6"
CONFIG_DIR="$HOME/.config/snx-rs"
LOCAL_BIN="$HOME/.local/bin"
ICON_DIR="$HOME/.local/share/icons/vpn-egsys"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo -e "${BOLD}=== vpn-egsys v2: Atualização/Migração ===${NC}\n"

# --- 0. Obter privilégios sudo (janela gráfica se disponível) ---
if ! sudo -n true 2>/dev/null; then
    if [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
        if command -v zenity &>/dev/null; then
            PASSWD=$(zenity --password --title="vpn-egsys" \
                --text="Senha de administrador:" 2>/dev/null) || error "Cancelado."
            echo "$PASSWD" | sudo -S true 2>/dev/null || error "Senha incorreta."
            unset PASSWD
        elif command -v kdialog &>/dev/null; then
            PASSWD=$(kdialog --password "vpn-egsys: Senha de administrador" 2>/dev/null) || error "Cancelado."
            echo "$PASSWD" | sudo -S true 2>/dev/null || error "Senha incorreta."
            unset PASSWD
        else
            sudo -v || error "Falha na autenticação sudo."
        fi
    else
        sudo -v || error "Falha na autenticação sudo."
    fi
fi
info "Privilégios de administrador obtidos."

# --- 1. Parar tudo ---
warn "Encerrando instâncias ativas..."
killall vpn-tray 2>/dev/null || true
killall snx-rs 2>/dev/null || true
sudo systemctl stop snx-rs.service 2>/dev/null || true
sleep 1
sudo rm -f /run/snx-rs.lock 2>/dev/null || true
info "Processos encerrados."

# --- 2. Detectar SO ---
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME="$NAME"; OS_ID="$ID"; OS_ID_LIKE="$ID_LIKE"
    fi
    if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" || "$OS_ID" == "zorin" || \
          "$OS_ID" == "linuxmint" || "$OS_ID" == "pop" || \
          "$OS_ID_LIKE" == *"ubuntu"* || "$OS_ID_LIKE" == *"debian"* ]]; then
        PKG_MANAGER="apt"
    elif [[ "$OS_ID" == "arch" || "$OS_ID" == "cachyos" || "$OS_ID" == "endeavouros" || \
            "$OS_ID" == "manjaro" || "$OS_ID_LIKE" == *"arch"* ]]; then
        PKG_MANAGER="pacman"
    else
        command -v apt &>/dev/null && PKG_MANAGER="apt"
        command -v pacman &>/dev/null && PKG_MANAGER="pacman"
    fi
    [ -z "$PKG_MANAGER" ] && error "Gerenciador de pacotes não detectado."
    info "Sistema: ${OS_NAME:-desconhecido} | Gerenciador: $PKG_MANAGER"
}
detect_os

# --- 3. Verificar pré-requisitos ---
command -v systemctl &>/dev/null || error "systemd não encontrado."
if ! systemctl is-active --quiet NetworkManager 2>/dev/null; then
    sudo systemctl start NetworkManager 2>/dev/null || error "NetworkManager não está disponível."
fi
info "Pré-requisitos OK."

# --- 4. Atualizar snx-rs se necessário ---
# Command mode requer snx-rs >= 5.0
NEEDS_SNX_UPDATE=false
if command -v snx-rs &>/dev/null && command -v snxctl &>/dev/null; then
    CURRENT_VER=$(snx-rs --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
    MAJOR_VER=$(echo "$CURRENT_VER" | cut -d. -f1)
    if [ "$MAJOR_VER" -lt 5 ]; then
        NEEDS_SNX_UPDATE=true
    else
        info "snx-rs v${CURRENT_VER} instalado (command mode suportado)."
    fi
else
    NEEDS_SNX_UPDATE=true
fi

if [ "$NEEDS_SNX_UPDATE" = true ]; then
    warn "Atualizando snx-rs para v${SNX_RS_VERSION}..."
    if [ "$PKG_MANAGER" == "apt" ]; then
        URL="https://github.com/ancwrd1/snx-rs/releases/download/v${SNX_RS_VERSION}/snx-rs-v${SNX_RS_VERSION}-linux-x86_64.deb"
        TMP_PKG=$(mktemp /tmp/snx-rs-XXXX.deb)
        curl -fSL -o "$TMP_PKG" "$URL" || error "Falha ao baixar snx-rs"
        sudo apt install -y "$TMP_PKG"; rm -f "$TMP_PKG"
    elif [ "$PKG_MANAGER" == "pacman" ]; then
        URL="https://github.com/ancwrd1/snx-rs/releases/download/v${SNX_RS_VERSION}/snx-rs-v${SNX_RS_VERSION}-linux-x86_64.tar.xz"
        TMP_PKG=$(mktemp /tmp/snx-rs-XXXX.tar.xz)
        curl -fSL -o "$TMP_PKG" "$URL" || error "Falha ao baixar snx-rs"
        TMP_DIR=$(mktemp -d); tar -xJf "$TMP_PKG" -C "$TMP_DIR"
        SNX_BIN=$(find "$TMP_DIR" -name "snx-rs" -type f | head -1)
        CTL_BIN=$(find "$TMP_DIR" -name "snxctl" -type f | head -1)
        [ -z "$SNX_BIN" ] && error "snx-rs não encontrado no arquivo"
        [ -z "$CTL_BIN" ] && error "snxctl não encontrado no arquivo"
        sudo install -m 755 "$SNX_BIN" /usr/bin/snx-rs
        sudo install -m 755 "$CTL_BIN" /usr/bin/snxctl
        rm -rf "$TMP_DIR" "$TMP_PKG"
    fi
    info "snx-rs v${SNX_RS_VERSION} instalado."
else
    info "snx-rs v${SNX_RS_VERSION} já atualizado."
fi

# Permissões SUID
for bin in /usr/bin/snx-rs /usr/bin/snxctl; do
    [ -f "$bin" ] && sudo chown root:root "$bin" && sudo chmod u+s "$bin"
done

# --- 5. Instalar dependências faltantes ---
warn "Verificando dependências..."
if [ "$PKG_MANAGER" == "apt" ]; then
    sudo apt update -qq
    sudo apt install -y python3-gi python3-requests gir1.2-gtk-3.0 \
        gir1.2-ayatanaappindicator3-0.1 network-manager curl \
        libwebkit2gtk-4.0-37 2>/dev/null || \
    sudo apt install -y python3-gi python3-requests gir1.2-gtk-3.0 \
        gir1.2-ayatanaappindicator3-0.1 network-manager curl \
        libwebkit2gtk-4.1-0 2>/dev/null || \
    sudo apt install -y python3-gi python3-requests gir1.2-gtk-3.0 \
        gir1.2-ayatanaappindicator3-0.1 network-manager curl
elif [ "$PKG_MANAGER" == "pacman" ]; then
    sudo pacman -Sy --noconfirm --needed python-gobject python-requests gtk3 \
        libayatana-appindicator networkmanager curl webkit2gtk 2>/dev/null || \
    sudo pacman -Sy --noconfirm --needed python-gobject python-requests gtk3 \
        libayatana-appindicator networkmanager curl
fi
info "Dependências OK."

# --- 6. Configurar credenciais (opcional) ---
setup_vpn_config() {
    local name=$1 label=$2 server=$3
    local conf_file="$CONFIG_DIR/$name.conf"

    echo -e "\n${BOLD}$label${NC}"
    if [ -f "$conf_file" ]; then
        read -rp "Deseja atualizar credenciais? (s/N): " choice
        [[ "$choice" != "s" && "$choice" != "S" ]] && return
    fi
    read -rp "Usuário $name: " USER_INPUT
    [ -z "$USER_INPUT" ] && warn "Pulando $label." && return
    read -rsp "Senha $name: " PASS_INPUT; echo ""
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
    info "Credenciais $label atualizadas."
}

setup_vpn_config "vpnro" "VPN RO - Rondônia" "131.72.155.42"
setup_vpn_config "vpnpr" "VPN PR - Paraná" "acessoremoto.pr.gov.br"
setup_vpn_config "vpnam" "VPN AM - Amazonas" "sslvpn.prodam.am.gov.br"

# --- 7. Instalar/atualizar systemd service ---
warn "Configurando serviço systemd..."
sudo mkdir -p /root/.config/snx-rs
sudo cp "$SCRIPT_DIR/snx-rs.service" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable snx-rs.service
sudo systemctl restart snx-rs.service
sleep 2
if systemctl is-active --quiet snx-rs.service; then
    info "Serviço snx-rs (command mode) ativo."
else
    warn "Serviço snx-rs pode não estar estável. Verifique: systemctl status snx-rs"
fi

# --- 8. Instalar/atualizar NM dispatcher ---
warn "Atualizando dispatcher NetworkManager..."
sudo mkdir -p /etc/NetworkManager/dispatcher.d
sudo cp "$SCRIPT_DIR/99-snx-vpn.sh" /etc/NetworkManager/dispatcher.d/
sudo chmod 755 /etc/NetworkManager/dispatcher.d/99-snx-vpn.sh
sudo chown root:root /etc/NetworkManager/dispatcher.d/99-snx-vpn.sh
info "Dispatcher NM atualizado."

# --- 9. Recriar conexões NM ---
warn "Atualizando conexões VPN no NetworkManager..."
bash "$SCRIPT_DIR/nm-snx-setup.sh"

# --- 10. Atualizar vpn-tray e ícones ---
mkdir -p "$LOCAL_BIN" "$ICON_DIR"
cp "$SCRIPT_DIR/vpn-tray" "$LOCAL_BIN/vpn-tray"
chmod +x "$LOCAL_BIN/vpn-tray"
cp "$SCRIPT_DIR/icons/"*.svg "$ICON_DIR/"
info "vpn-tray atualizado."

# --- 11. Atualizar aliases ---
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
info "Aliases atualizados."

# --- 12. Garantir ~/.local/bin no PATH ---
if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        [ -f "$rc" ] && grep -q '.local/bin' "$rc" || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
    done
fi

# --- 13. Reiniciar tray ---
nohup "$LOCAL_BIN/vpn-tray" > /dev/null 2>&1 &
info "Monitor da bandeja reiniciado."

echo -e "\n${GREEN}${BOLD}✓ Migração para v2 concluída!${NC}"
echo -e "${BOLD}VPNs agora visíveis no NetworkManager.${NC}"
echo -e "Use: applet NM, terminal (vpnro/vpnpr/vpnam) ou tray icon.\n"
