# vpn-egsys v2.1 (Multi-Protocolo & Cross-Platform)

Gerenciador universal de VPNs, monitor de bandeja (`vpn-tray`), utilitário de terminal (`vpn`) e integração com **Check Point (SNX via `snx-rs`)** e **IPsec (IKEv2)** para estações **Linux** e **macOS**.

## Novidades v2.1
- **Suporte Multi-Protocolo**: Check Point SSL Network Extender (SNX) e IPsec (IKEv2).
- **Suporte Cross-Platform**: Linux (Ubuntu, Debian, Arch, CachyOS) e macOS (Monterey, Ventura, Sonoma, Sequoia - Intel & Apple Silicon).
- **CLI Universal `vpn`**: comandos rápidos no terminal (`vpn list`, `vpn ro`, `vpn off`, `vpn status`, `vpn add`).
- **Tray Nativo macOS**: compatibilidade com a barra de menus do macOS via `pystray` / AppKit nativo e LaunchAgent `launchd`.
- **Suíte de Testes Automatizados**: testes unitários de configuração e CLI (`./run_tests.sh`).
- **snx-rs em command mode** — roda como serviço systemd no Linux com restart automático.
- **Conexão síncrona** — sem delay de rotas/DNS; reporta com precisão quando tudo está pronto.

## Sistemas Suportados
- **Linux**:
  - Debian/Ubuntu (Ubuntu, Debian, Zorin OS, Linux Mint, Pop!_OS)
  - Arch Linux (Arch, CachyOS, EndeavourOS, Manjaro)
  - Desktops: GNOME, KDE Plasma, XFCE
- **macOS**:
  - macOS 12+ (Monterey, Ventura, Sonoma, Sequoia)
  - Apple Silicon (M1/M2/M3/M4) e Intel x86_64

## Instalação (PC novo)

```bash
git clone git@github.com:egsys-dev/vpn-egsys.git
cd vpn-egsys
chmod +x install.sh
./install.sh
```

O instalador:
1. Detecta o SO e instala dependências
2. Instala snx-rs (se necessário)
3. Configura serviço systemd
4. Pergunta credenciais das VPNs (RO, PR, AM + opção de adicionar outras)
5. Cria aliases no terminal
6. Instala VPN Tray com autostart
7. No GNOME: instala extensão AppIndicator

## Atualização (PCs com versão anterior)

```bash
cd vpn-egsys
git pull
./update.sh
```

O `update.sh` migra automaticamente da arquitetura antiga (standalone) para a nova (command mode).

## Uso

### Via VPN Tray (recomendado)

O ícone na bandeja do sistema permite:
- **Conectar** qualquer VPN configurada
- **Desconectar** a VPN ativa
- **⚙ Configurar VPNs** — adicionar ou remover VPNs

### Via Terminal (CLI Universal `vpn`)

O utilitário `vpn` permite gerenciar todas as conexões em Linux e macOS:
```bash
vpn list             # Lista todas as VPNs (id, protocolo SNX/IPsec, status, servidor)
vpn ro               # Conecta rapidamente à VPN RO (ou vpn connect ro)
vpn sc               # Conecta rapidamente à VPN SC
vpn off              # Desconecta a VPN ativa
vpn status           # Exibe status detalhado da conexão ativa
vpn add              # Wizard interativo para adicionar nova VPN (SNX ou IPsec)
vpn remove <id>      # Remove uma VPN configurada
```

Aliases rápidos também continuam disponíveis:
- `vpnro`, `vpnpr`, `vpnam`, `vpnsc`, `vpnto`, `vpnoff`, `vpnstatus`

### Via SAPA (egsys-tool)

A SAPA verifica automaticamente se a VPN necessária está conectada:
- Se estiver → libera acesso
- Se não estiver → solicita que o usuário conecte pelo VPN Tray ou `vpn <estado>`

## Arquitetura Multi-Protocolo & Cross-Platform

```
     ┌───────────────────────┐         ┌──────────────────────┐
     │  vpn-tray (Bandeja)   │         │  vpn CLI (Terminal)  │
     │  Linux: Gtk/Ayatana   │         │  Linux & macOS       │
     │  macOS: pystray/AppKit│         │                      │
     └───────────┬───────────┘         └──────────┬───────────┘
                 │                                │
                 ▼                                ▼
     ┌────────────────────────────────────────────────────────┐
     │            core.vpn_manager (Camada Unificada)         │
     └───────────────────┬────────────────────────┬───────────┘
                         │                        │
         ┌───────────────┴────────┐      ┌────────┴──────────────┐
         ▼                        ▼      ▼                       ▼
    [Check Point SNX]     [IPsec Linux] [Check Point macOS]  [IPsec macOS]
      snxctl daemon        NetworkManager /   snx-rs /         scutil --nc /
      systemd service       strongSwan      command mode       networksetup
```

## Adicionar nova VPN

### Via CLI Interativo (Recomendado)
```bash
vpn add
```

### Via VPN Tray
Menu → ⚙ Configurar VPNs → Adicionar (Selecione o protocolo SNX ou IPsec)

### Manualmente via Arquivo de Configuração
Crie o arquivo `~/.config/snx-rs/vpnXX.conf` com permissão `0600`:

**Formato Check Point (SNX):**
```ini
protocol=snx
server-name=SERVIDOR_IP_OU_HOST
user-name=USUARIO
password=SENHA_EM_BASE64
ignore-server-cert=true
login-type=vpn
```

**Formato IPsec (IKEv2):**
```ini
protocol=ipsec
server-name=SERVIDOR_IP_OU_HOST
user-name=USUARIO
password=SENHA_EM_BASE64
ipsec-type=ikev2
routes=10.0.0.0/8,172.20.0.0/16
```
## Dependências

Instaladas automaticamente:
- `snx-rs` v5.x+ (com `snxctl`)
- `python3-gi` (PyGObject)
- `libayatana-appindicator`
- `networkmanager`
- `gnome-shell-extension-appindicator` (apenas GNOME)

## Desinstalação

```bash
chmod +x uninstall.sh
./uninstall.sh
```

## Troubleshooting

### VPN PRODAM/AM desconecta após poucos segundos
O gateway da PRODAM pode bloquear pacotes keepalive. A config `vpnam.conf` já inclui automaticamente:
```
no-keepalive=true
ike-persist=true
```
Se já tinha a config antiga, aplique manualmente:
```bash
echo -e "no-keepalive=true\nike-persist=true" >> ~/.config/snx-rs/vpnam.conf
```
Se ainda não estabilizar, tente adicionar `tunnel-type=ssl` na config.

### VPN Tray não aparece (GNOME)
```bash
sudo apt install gnome-shell-extension-appindicator
gnome-extensions enable appindicatorsupport@rgcjonas.gmail.com
```
Reinicie a sessão (logout/login).

### snxctl não conecta
```bash
systemctl status snx-rs.service   # Verificar se o serviço está ativo
snxctl status                      # Ver estado atual
```

### Timeout na conexão
Verifique se o servidor está acessível:
```bash
snx-rs -m info -s SERVIDOR -X true
```
