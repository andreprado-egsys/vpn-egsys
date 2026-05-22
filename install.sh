#!/bin/bash
set -e

# vpn-egsys v2 - Instalador com integração NetworkManager
# Suporta: Ubuntu, Debian, Zorin, Arch Linux, CachyOS e derivados.

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SNX_RS_VERSION="6.0.6"
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
echo "║     vpn-egsys v2 - Instalador       ║"
echo "║   VPN Check Point (RO, PR e AM)     ║"
echo "║   Integração NetworkManager         ║"
echo "╚══════════════════════════════════════╝"
echo -e "${NC}"

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

# --- 1. Preparação ---
warn "Preparando o ambiente..."
killall vpn-tray 2>/dev/null || true
killall snx-rs 2>/dev/null || true
sudo systemctl stop snx-rs.service 2>/dev/null || true
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
        error "Sistema operacional não identificado"
    fi

    ARCH=$(uname -m)
    [ "$ARCH" != "x86_64" ] && error "Arquitetura $ARCH não suportada. Apenas x86_64."

    if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" || "$OS_ID" == "zorin" || \
          "$OS_ID" == "linuxmint" || "$OS_ID" == "pop" || \
          "$OS_ID_LIKE" == *"ubuntu"* || "$OS_ID_LIKE" == *"debian"* ]]; then
        PKG_MANAGER="apt"
    elif [[ "$OS_ID" == "arch" || "$OS_ID" == "cachyos" || "$OS_ID" == "endeavouros" || \
            "$OS_ID" == "manjaro" || "$OS_ID_LIKE" == *"arch"* ]]; then
        PKG_MANAGER="pacman"
    else
        if command -v apt &>/dev/null; then PKG_MANAGER="apt";
        elif command -v pacman &>/dev/null; then PKG_MANAGER="pacman";
        else error "Gerenciador de pacotes não suportado (apt/pacman não encontrado)."; fi
    fi
    info "Sistema: $OS_NAME ($OS_ID) | Gerenciador: $PKG_MANAGER"
}

detect_os

# --- 2. Verificar pré-requisitos ---
check_prerequisites() {
    # NetworkManager é obrigatório
    if ! systemctl is-active --quiet NetworkManager 2>/dev/null; then
        if systemctl is-enabled --quiet NetworkManager 2>/dev/null; then
            sudo systemctl start NetworkManager
        else
            error "NetworkManager não está ativo. Instale e ative antes de continuar."
        fi
    fi

    # Verificar versão do NM (precisa >= 1.8 para dummy)
    NM_VER=$(nmcli --version 2>/dev/null | grep -oP '\d+\.\d+' | head -1)
    if [ -n "$NM_VER" ]; then
        NM_MAJOR=$(echo "$NM_VER" | cut -d. -f1)
        NM_MINOR=$(echo "$NM_VER" | cut -d. -f2)
        if [ "$NM_MAJOR" -lt 1 ] || ([ "$NM_MAJOR" -eq 1 ] && [ "$NM_MINOR" -lt 8 ]); then
            error "NetworkManager $NM_VER muito antigo. Precisa >= 1.8."
        fi
        info "NetworkManager $NM_VER detectado."
    fi

    # systemd é obrigatório
    if ! command -v systemctl &>/dev/null; then
        error "systemd não encontrado. Este projeto requer systemd."
    fi
}

check_prerequisites

# --- 3. Instalar snx-rs ---
install_snx_rs() {
    if command -v snx-rs &>/dev/null && command -v snxctl &>/dev/null; then
        local ver=$(snx-rs --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
        local major=$(echo "$ver" | cut -d. -f1)
        if [ "$major" -ge 5 ]; then
            info "snx-rs v${ver} já instalado (command mode suportado)."
            return
        fi
        warn "snx-rs v${ver} muito antigo, atualizando para v${SNX_RS_VERSION}..."
    else
        warn "Instalando snx-rs v${SNX_RS_VERSION}..."
    fi

    if [ "$PKG_MANAGER" == "apt" ]; then
        URL="https://github.com/ancwrd1/snx-rs/releases/download/v${SNX_RS_VERSION}/snx-rs-v${SNX_RS_VERSION}-linux-x86_64.deb"
        TMP_PKG=$(mktemp /tmp/snx-rs-XXXX.deb)
        curl -fSL -o "$TMP_PKG" "$URL" || error "Falha ao baixar snx-rs .deb"
        sudo apt install -y "$TMP_PKG"
        rm -f "$TMP_PKG"
    elif [ "$PKG_MANAGER" == "pacman" ]; then
        URL="https://github.com/ancwrd1/snx-rs/releases/download/v${SNX_RS_VERSION}/snx-rs-v${SNX_RS_VERSION}-linux-x86_64.tar.xz"
        TMP_PKG=$(mktemp /tmp/snx-rs-XXXX.tar.xz)
        curl -fSL -o "$TMP_PKG" "$URL" || error "Falha ao baixar snx-rs .tar.xz"
        TMP_DIR=$(mktemp -d)
        tar -xJf "$TMP_PKG" -C "$TMP_DIR"
        # Binários podem estar na raiz ou em subdiretório
        SNX_BIN=$(find "$TMP_DIR" -name "snx-rs" -type f | head -1)
        CTL_BIN=$(find "$TMP_DIR" -name "snxctl" -type f | head -1)
        [ -z "$SNX_BIN" ] && error "snx-rs não encontrado no arquivo baixado"
        [ -z "$CTL_BIN" ] && error "snxctl não encontrado no arquivo baixado"
        sudo install -m 755 "$SNX_BIN" /usr/bin/snx-rs
        sudo install -m 755 "$CTL_BIN" /usr/bin/snxctl
        rm -rf "$TMP_DIR" "$TMP_PKG"
    fi

    # Verificar instalação
    command -v snx-rs &>/dev/null || error "snx-rs não foi instalado corretamente"
    command -v snxctl &>/dev/null || error "snxctl não foi instalado corretamente"
    info "snx-rs v${SNX_RS_VERSION} instalado."
}

install_snx_rs

# --- 4. Instalar dependências ---
warn "Instalando dependências..."
if [ "$PKG_MANAGER" == "apt" ]; then
    sudo apt update -qq
    # webkit2gtk: tenta 4.0 primeiro (Ubuntu 22.04), fallback para 4.1 (Ubuntu 24.04+)
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
info "Dependências instaladas."

# --- 4b. Extensão AppIndicator para GNOME (tray icon) ---
if [ "$XDG_CURRENT_DESKTOP" = "GNOME" ] || [ "$XDG_CURRENT_DESKTOP" = "ubuntu:GNOME" ]; then
    warn "GNOME detectado - instalando suporte a tray icon..."
    if [ "$PKG_MANAGER" == "apt" ]; then
        sudo apt install -y gnome-shell-extension-appindicator 2>/dev/null || true
    elif [ "$PKG_MANAGER" == "pacman" ]; then
        sudo pacman -S --noconfirm --needed gnome-shell-extension-appindicator 2>/dev/null || true
    fi
    # Ativa a extensão
    gnome-extensions enable appindicatorsupport@rgcjonas.gmail.com 2>/dev/null || true
    info "Extensão AppIndicator instalada. Pode ser necessário reiniciar a sessão GNOME."
fi
for bin in /usr/bin/snx-rs /usr/bin/snxctl; do
    if [ -f "$bin" ]; then
        sudo chown root:root "$bin"
        sudo chmod u+s "$bin"
    fi
done
info "Permissões SUID configuradas."

# --- 6. Configurar systemd-resolved (se disponível, para split DNS) ---
setup_resolved() {
    if command -v resolvectl &>/dev/null || systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        # Já está ativo, verificar se /etc/resolv.conf aponta para ele
        if [ -L /etc/resolv.conf ]; then
            local target=$(readlink -f /etc/resolv.conf)
            if [[ "$target" == *"systemd"* ]]; then
                info "systemd-resolved já configurado (split DNS ativo)."
                return
            fi
        fi
        warn "systemd-resolved detectado mas /etc/resolv.conf não aponta para ele."
        warn "Para split DNS, execute: sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf"
    else
        warn "systemd-resolved não ativo. DNS será configurado via /etc/resolv.conf (sem split DNS)."
        warn "Para melhor privacidade, instale e ative systemd-resolved."
    fi
}

setup_resolved

# --- 7. Credenciais ---
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

add_custom_vpn() {
    echo -e "\n${BOLD}Adicionar nova VPN${NC}"
    read -rp "Identificador (ex: vpnsc, vpnto, vpnmt): " VPN_ID
    [ -z "$VPN_ID" ] && return
    read -rp "Nome/Label (ex: VPN SC - Santa Catarina): " VPN_LABEL
    [ -z "$VPN_LABEL" ] && return
    read -rp "Servidor (IP ou hostname): " VPN_SERVER
    [ -z "$VPN_SERVER" ] && return
    setup_vpn_config "$VPN_ID" "$VPN_LABEL" "$VPN_SERVER"
}

echo -e "\n${BOLD}=== Configuração de Credenciais ===${NC}"

# Verifica se já existem configs
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
    read -rp "Deseja modificar alguma credencial existente? (s/N): " MODIFY
    if [[ "$MODIFY" == "s" || "$MODIFY" == "S" ]]; then
        setup_vpn_config "vpnro" "VPN RO - Rondônia" "131.72.155.42"
        setup_vpn_config "vpnpr" "VPN PR - Paraná" "acessoremoto.pr.gov.br"
        setup_vpn_config "vpnam" "VPN AM - Amazonas" "sslvpn.prodam.am.gov.br"
    fi
else
    # Primeira instalação - configura as VPNs padrão
    setup_vpn_config "vpnro" "VPN RO - Rondônia" "131.72.155.42"
    setup_vpn_config "vpnpr" "VPN PR - Paraná" "acessoremoto.pr.gov.br"
    setup_vpn_config "vpnam" "VPN AM - Amazonas" "sslvpn.prodam.am.gov.br"
fi

# Permitir adicionar VPNs extras
while true; do
    echo ""
    read -rp "Deseja adicionar outra VPN? (s/N): " ADD_MORE
    [[ "$ADD_MORE" != "s" && "$ADD_MORE" != "S" ]] && break
    add_custom_vpn
done

info "Configurações de credenciais finalizadas."

# --- 8. Instalar systemd service ---
warn "Configurando serviço snx-rs..."
sudo mkdir -p /root/.config/snx-rs
sudo cp "$SCRIPT_DIR/snx-rs.service" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable snx-rs.service
sudo systemctl restart snx-rs.service
# Aguarda o serviço estabilizar
sleep 2
if systemctl is-active --quiet snx-rs.service; then
    info "Serviço snx-rs (command mode) ativo."
else
    warn "Serviço snx-rs iniciou mas pode não estar estável. Verifique: systemctl status snx-rs"
fi

# --- 9. Instalar NM dispatcher ---
warn "Instalando dispatcher NetworkManager..."
sudo mkdir -p /etc/NetworkManager/dispatcher.d
sudo cp "$SCRIPT_DIR/99-snx-vpn.sh" /etc/NetworkManager/dispatcher.d/
sudo chmod 755 /etc/NetworkManager/dispatcher.d/99-snx-vpn.sh
sudo chown root:root /etc/NetworkManager/dispatcher.d/99-snx-vpn.sh
info "Dispatcher NM instalado."

# --- 10. Criar conexões NM ---
warn "Criando conexões VPN no NetworkManager..."
bash "$SCRIPT_DIR/nm-snx-setup.sh"

# --- 11. vpn-tray e ícones ---
mkdir -p "$LOCAL_BIN" "$ICON_DIR"
cp "$SCRIPT_DIR/vpn-tray" "$LOCAL_BIN/vpn-tray"
chmod +x "$LOCAL_BIN/vpn-tray"
cp "$SCRIPT_DIR/icons/"*.svg "$ICON_DIR/"
info "vpn-tray e ícones instalados."

# --- 12. Desktop entry e autostart ---
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

# --- 13. Aliases (dinâmicos baseados nos configs existentes) ---
setup_aliases() {
    local shell_rc=$1
    [ ! -f "$shell_rc" ] && return

    MARKER="# >>> vpn-egsys >>>"
    MARKER_END="# <<< vpn-egsys <<<"
    sed -i "/$MARKER/,/$MARKER_END/d" "$shell_rc" 2>/dev/null || true

    {
        echo "$MARKER"
        # Gera função para cada vpn*.conf
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

# --- 14. Garantir ~/.local/bin no PATH ---
if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        [ -f "$rc" ] && grep -q '.local/bin' "$rc" || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
    done
    warn "Adicionado ~/.local/bin ao PATH (recarregue o shell)."
fi

# --- 15. Iniciar tray ---
nohup "$LOCAL_BIN/vpn-tray" > /dev/null 2>&1 &
info "Monitor da bandeja iniciado."

echo -e "\n${BOLD}${GREEN}=== Instalação v2 concluída com sucesso! ===${NC}"
echo -e "${BOLD}As VPNs agora aparecem no NetworkManager.${NC}"
echo -e "Use: applet NM, terminal (vpnro/vpnpr/vpnam) ou tray icon.\n"
