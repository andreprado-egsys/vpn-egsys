#!/bin/bash
# 99-snx-vpn.sh - NetworkManager dispatcher para snx-rs
# Instalado em /etc/NetworkManager/dispatcher.d/
# Compatível com: Ubuntu, Debian, Arch, CachyOS e derivados

IFACE="$1"
ACTION="$2"

LOG="/var/log/snx-vpn-dispatcher.log"
SNXCTL="/usr/bin/snxctl"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG" 2>/dev/null; }

# Verifica se snxctl existe
[ -x "$SNXCTL" ] || exit 0

# Identifica VPN snx-rs de duas formas:
# 1. Conexão tipo dummy com interface snx-vpn* (fallback)
# 2. Conexão tipo vpn com vpn.data contendo gateway=snx-*

VPN_ID=""

case "$IFACE" in
    snx-vpn*)
        # Modo dummy: extrai ID da interface
        VPN_ID="${IFACE#snx-}"
        ;;
    *)
        # Modo VPN: verifica se é uma conexão snx-rs via CONNECTION_UUID
        if [ -n "$CONNECTION_UUID" ]; then
            GATEWAY=$(nmcli -t -f vpn.data connection show "$CONNECTION_UUID" 2>/dev/null | grep "gateway=" | sed 's/.*gateway=//' | sed 's/,.*//')
            case "$GATEWAY" in
                snx-*)
                    VPN_ID="${GATEWAY#snx-}"
                    ;;
            esac
        fi
        # Se não identificou, verifica pelo nome da conexão
        if [ -z "$VPN_ID" ] && [ -n "$CONNECTION_ID" ]; then
            case "$CONNECTION_ID" in
                *"RO"*|*"Rondônia"*) VPN_ID="vpnro" ;;
                *"PR"*|*"Paraná"*)   VPN_ID="vpnpr" ;;
                *"AM"*|*"Amazonas"*) VPN_ID="vpnam" ;;
            esac
        fi
        ;;
esac

[ -z "$VPN_ID" ] && exit 0

# Descobre o config file buscando em /home/*/
find_config() {
    for home in /home/*; do
        [ -d "$home/.config/snx-rs" ] || continue
        local conf="$home/.config/snx-rs/${VPN_ID}.conf"
        if [ -f "$conf" ]; then
            echo "$conf"
            return
        fi
    done
}

case "$ACTION" in
    up|vpn-up)
        log "NM UP: iface=$IFACE action=$ACTION vpn_id=$VPN_ID"

        CONF_FILE=$(find_config)
        if [ -z "$CONF_FILE" ]; then
            log "ERRO: Config não encontrada para $VPN_ID em /home/*/.config/snx-rs/"
            exit 1
        fi

        # Desconecta qualquer VPN ativa antes
        $SNXCTL disconnect 2>/dev/null || true
        sleep 1

        # Copia config para o local padrão do snx-rs command mode
        USER_HOME=$(dirname "$(dirname "$(dirname "$CONF_FILE")")")
        SNX_CONF="$USER_HOME/.config/snx-rs/snx-rs.conf"
        cp "$CONF_FILE" "$SNX_CONF"
        chown --reference="$CONF_FILE" "$SNX_CONF" 2>/dev/null || true

        log "Conectando via snxctl (config: $CONF_FILE)"
        $SNXCTL connect

        # Aguarda snxctl reportar connected (máx 25s)
        TIMEOUT=25
        for i in $(seq 1 $TIMEOUT); do
            if $SNXCTL status 2>/dev/null | grep -qi "connected"; then
                log "CONECTADO em ${i}s ($VPN_ID)"
                exit 0
            fi
            sleep 1
        done

        log "TIMEOUT (${TIMEOUT}s) aguardando conexão: $VPN_ID"
        $SNXCTL disconnect 2>/dev/null || true
        exit 1
        ;;

    down|vpn-down)
        log "NM DOWN: iface=$IFACE action=$ACTION vpn_id=$VPN_ID"
        $SNXCTL disconnect 2>/dev/null || true
        log "Desconectado: $VPN_ID"
        ;;
esac

exit 0
