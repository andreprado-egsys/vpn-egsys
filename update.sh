#!/bin/bash
set -e

# vpn-egsys - Gerenciador de VPNs
# Uso: ./update.sh [listar|adicionar|atualizar|remover]

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

CONFIG_DIR="$HOME/.config/snx-rs"
LOCAL_BIN="$HOME/.local/bin"
ICON_DIR="$HOME/.local/share/icons/vpn-egsys"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# --- Listar VPNs configuradas ---
list_vpns() {
    echo -e "\n${BOLD}VPNs configuradas:${NC}\n"
    local count=0
    for conf in $(find "$CONFIG_DIR" -name "vpn*.conf" 2>/dev/null | sort); do
        local name=$(basename "$conf" .conf)
        local server=$(grep "^server-name=" "$conf" | cut -d= -f2)
        local user=$(grep "^user-name=" "$conf" | cut -d= -f2)
        echo -e "  ${CYAN}${name}${NC} → ${server} (${user})"
        ((count++))
    done
    if [ "$count" -eq 0 ]; then
        warn "Nenhuma VPN configurada."
    else
        echo -e "\n  Total: ${count} VPN(s)"
    fi
    echo ""
}

# --- Adicionar nova VPN ---
add_vpn() {
    echo -e "\n${BOLD}Adicionar nova VPN${NC}\n"
    read -rp "Nome curto (ex: vpnsp, vpnrj): " vpn_name
    [[ -z "$vpn_name" ]] && error "Nome não pode ser vazio."
    # Normalizar: prefixar com vpn se não tiver
    [[ "$vpn_name" != vpn* ]] && vpn_name="vpn${vpn_name}"

    local conf="$CONFIG_DIR/${vpn_name}.conf"
    if [ -f "$conf" ]; then
        warn "$vpn_name já existe. Use 'atualizar' para modificar."
        return
    fi

    read -rp "Servidor (IP ou hostname): " server
    [[ -z "$server" ]] && error "Servidor não pode ser vazio."
    read -rp "Usuário: " vpn_user
    [[ -z "$vpn_user" ]] && error "Usuário não pode ser vazio."
    read -rsp "Senha: " vpn_pass; echo ""
    [[ -z "$vpn_pass" ]] && error "Senha não pode ser vazia."

    mkdir -p "$CONFIG_DIR"
    cat > "$conf" <<EOF
server-name=${server}
user-name=${vpn_user}
password=$(echo -n "$vpn_pass" | base64)
ignore-server-cert=true
login-type=vpn
EOF
    chmod 600 "$conf"
    info "$vpn_name adicionada."
    regenerate_aliases
    update_tray
}

# --- Atualizar VPN existente ---
update_vpn() {
    echo -e "\n${BOLD}Atualizar VPN existente${NC}\n"
    list_vpns

    read -rp "Nome da VPN para atualizar: " vpn_name
    [[ "$vpn_name" != vpn* ]] && vpn_name="vpn${vpn_name}"
    local conf="$CONFIG_DIR/${vpn_name}.conf"
    [ ! -f "$conf" ] && error "$vpn_name não encontrada."

    local cur_server=$(grep "^server-name=" "$conf" | cut -d= -f2)
    local cur_user=$(grep "^user-name=" "$conf" | cut -d= -f2)

    echo -e "  Servidor atual: ${cur_server}"
    echo -e "  Usuário atual:  ${cur_user}\n"

    read -rp "Novo servidor (Enter para manter): " server
    read -rp "Novo usuário (Enter para manter): " vpn_user
    read -rsp "Nova senha (Enter para manter): " vpn_pass; echo ""

    [ -n "$server" ] && sed -i "s|^server-name=.*|server-name=${server}|" "$conf"
    [ -n "$vpn_user" ] && sed -i "s|^user-name=.*|user-name=${vpn_user}|" "$conf"
    [ -n "$vpn_pass" ] && sed -i "s|^password=.*|password=$(echo -n "$vpn_pass" | base64)|" "$conf"

    info "$vpn_name atualizada."
}

# --- Remover VPN ---
remove_vpn() {
    echo -e "\n${BOLD}Remover VPN${NC}\n"
    list_vpns

    read -rp "Nome da VPN para remover: " vpn_name
    [[ "$vpn_name" != vpn* ]] && vpn_name="vpn${vpn_name}"
    local conf="$CONFIG_DIR/${vpn_name}.conf"
    [ ! -f "$conf" ] && error "$vpn_name não encontrada."

    read -rp "Confirma remoção de $vpn_name? (s/N): " confirm
    [[ "$confirm" != "s" && "$confirm" != "S" ]] && return

    rm -f "$conf"
    info "$vpn_name removida."
    regenerate_aliases
    update_tray
}

# --- Regenerar aliases ---
regenerate_aliases() {
    local snx_path
    snx_path=$(command -v snx-rs)

    for shell_rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        [ ! -f "$shell_rc" ] && continue
        local marker="# >>> vpn-egsys >>>"
        local marker_end="# <<< vpn-egsys <<<"
        sed -i "/${marker//\//\\/}/,/${marker_end//\//\\/}/d" "$shell_rc" 2>/dev/null || true

        {
            echo "$marker"
            for conf in $(find "$CONFIG_DIR" -name "vpn*.conf" 2>/dev/null | sort); do
                local name=$(basename "$conf" .conf)
                echo "alias ${name}=\"sudo killall snx-rs 2>/dev/null; sleep 0.5; sudo rm -f /run/snx-rs.lock 2>/dev/null; nohup sudo ${snx_path} -m standalone -c ${conf} -l info > /tmp/snx-rs.log 2>&1 & sleep 3 && tail -n 5 /tmp/snx-rs.log\""
            done
            echo "alias vpnoff=\"sudo killall snx-rs 2>/dev/null; sleep 1; sudo rm -f /run/snx-rs.lock 2>/dev/null; echo 'VPN desconectada'\""
            echo "alias vpnstatus=\"ip addr show snx-xfrm 2>/dev/null && tail -n 10 /tmp/snx-rs.log 2>/dev/null || echo 'VPN não conectada'\""
            echo "$marker_end"
        } >> "$shell_rc"
    done
    info "Aliases regenerados."
}

# --- Atualizar tray ---
update_tray() {
    killall vpn-tray 2>/dev/null || true
    sleep 0.5
    # Atualizar binário
    if [ -f "$SCRIPT_DIR/vpn-tray" ]; then
        cp "$SCRIPT_DIR/vpn-tray" "$LOCAL_BIN/vpn-tray"
        chmod +x "$LOCAL_BIN/vpn-tray"
        [ -d "$SCRIPT_DIR/icons" ] && cp "$SCRIPT_DIR/icons/"*.svg "$ICON_DIR/" 2>/dev/null
    fi
    nohup "$LOCAL_BIN/vpn-tray" > /dev/null 2>&1 &
    info "Tray reiniciado."
}

# --- Menu principal ---
show_menu() {
    echo -e "${BOLD}"
    echo "╔══════════════════════════════════════╗"
    echo "║    vpn-egsys - Gerenciador de VPNs   ║"
    echo "╚══════════════════════════════════════╝"
    echo -e "${NC}"
    echo "  1) Listar VPNs configuradas"
    echo "  2) Adicionar nova VPN"
    echo "  3) Atualizar VPN existente"
    echo "  4) Remover VPN"
    echo "  5) Regenerar aliases"
    echo "  6) Atualizar vpn-tray"
    echo "  0) Sair"
    echo ""
}

# --- Execução ---
if [ $# -ge 1 ]; then
    case "$1" in
        listar|list)    list_vpns ;;
        adicionar|add)  add_vpn ;;
        atualizar|update) update_vpn ;;
        remover|remove) remove_vpn ;;
        aliases)        regenerate_aliases ;;
        tray)           update_tray ;;
        *) echo "Uso: $0 [listar|adicionar|atualizar|remover|aliases|tray]"; exit 1 ;;
    esac
else
    while true; do
        show_menu
        read -rp "Opção: " opt
        case "$opt" in
            1) list_vpns ;;
            2) add_vpn ;;
            3) update_vpn ;;
            4) remove_vpn ;;
            5) regenerate_aliases ;;
            6) update_tray ;;
            0) echo ""; exit 0 ;;
            *) warn "Opção inválida." ;;
        esac
    done
fi
