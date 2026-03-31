#!/bin/bash
set -e

echo "Desinstalando vpn-egsys..."

killall snx-rs 2>/dev/null || true
killall vpn-tray 2>/dev/null || true
rm -f /run/snx-rs.lock 2>/dev/null || true

rm -f ~/.local/bin/vpn-tray
rm -f ~/.local/share/applications/vpn-egsys.desktop
rm -f ~/.config/autostart/vpn-tray.desktop
rm -rf ~/.local/share/icons/vpn-egsys
rm -rf ~/.config/snx-rs

MARKER="# >>> vpn-egsys >>>"
MARKER_END="# <<< vpn-egsys <<<"
if grep -q "$MARKER" ~/.bashrc 2>/dev/null; then
    sed -i "/$MARKER/,/$MARKER_END/d" ~/.bashrc
fi

update-desktop-database ~/.local/share/applications/ 2>/dev/null || true

echo "vpn-egsys removido."
echo "O pacote snx-rs NÃO foi removido. Para remover: sudo apt remove snx-rs"
