#!/bin/bash
set -e

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BOLD}vpn-egsys - Desinstalação${NC}\n"

# Parar processos
killall vpn-tray 2>/dev/null || true
killall snx-rs 2>/dev/null || true
sudo rm -f /run/snx-rs.lock 2>/dev/null || true

# Remover binários e ícones
rm -f ~/.local/bin/vpn-tray
rm -f ~/.local/share/applications/vpn-egsys.desktop
rm -f ~/.config/autostart/vpn-tray.desktop
rm -rf ~/.local/share/icons/vpn-egsys

# Remover sudoers
if [ -f /etc/sudoers.d/vpn-egsys ]; then
    sudo rm -f /etc/sudoers.d/vpn-egsys
    echo -e "${GREEN}[✓]${NC} Sudoers removido."
fi

# Remover aliases do bashrc e zshrc
MARKER="# >>> vpn-egsys >>>"
MARKER_END="# <<< vpn-egsys <<<"
for rc in ~/.bashrc ~/.zshrc; do
    if [ -f "$rc" ] && grep -q "$MARKER" "$rc" 2>/dev/null; then
        sed -i "/${MARKER//\//\\/}/,/${MARKER_END//\//\\/}/d" "$rc"
        echo -e "${GREEN}[✓]${NC} Aliases removidos de $(basename $rc)"
    fi
done

update-desktop-database ~/.local/share/applications/ 2>/dev/null || true

# Perguntar sobre configs
echo ""
read -rp "Remover configurações de VPN (~/.config/snx-rs)? (s/N): " choice
if [[ "$choice" == "s" || "$choice" == "S" ]]; then
    rm -rf ~/.config/snx-rs
    echo -e "${GREEN}[✓]${NC} Configurações removidas."
else
    echo -e "${YELLOW}[!]${NC} Configurações preservadas em ~/.config/snx-rs"
fi

echo -e "\n${GREEN}${BOLD}✓ vpn-egsys removido.${NC}"
echo -e "  O pacote snx-rs NÃO foi removido. Para remover manualmente:"
echo -e "    Arch: sudo pacman -R snx-rs"
echo -e "    Debian/Ubuntu: sudo apt remove snx-rs\n"
