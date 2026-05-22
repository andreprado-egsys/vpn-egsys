#!/bin/bash
# vpn-egsys - Desinstalador completo

set -e

echo "=== Desinstalando vpn-egsys ==="

# Parar processos
killall vpn-tray 2>/dev/null || true
sudo systemctl stop snx-rs.service 2>/dev/null || true
sudo systemctl disable snx-rs.service 2>/dev/null || true

# Remover systemd service
sudo rm -f /etc/systemd/system/snx-rs.service
sudo systemctl daemon-reload

# Remover NM dispatcher
sudo rm -f /etc/NetworkManager/dispatcher.d/99-snx-vpn.sh

# Remover conexões NM dummy
nmcli connection delete "VPN RO - Rondônia" 2>/dev/null || true
nmcli connection delete "VPN PR - Paraná" 2>/dev/null || true
nmcli connection delete "VPN AM - Amazonas" 2>/dev/null || true

# Remover binários e ícones
rm -f "$HOME/.local/bin/vpn-tray"
rm -rf "$HOME/.local/share/icons/vpn-egsys"
rm -f "$HOME/.local/share/applications/vpn-egsys.desktop"
rm -f "$HOME/.config/autostart/vpn-tray.desktop"

# Remover aliases
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -f "$rc" ] && sed -i '/# >>> vpn-egsys >>>/,/# <<< vpn-egsys <<</d' "$rc"
done

# Remover lock
sudo rm -f /run/snx-rs.lock

echo "[✓] vpn-egsys desinstalado."
echo "Nota: credenciais em ~/.config/snx-rs/ e snx-rs binário foram preservados."
