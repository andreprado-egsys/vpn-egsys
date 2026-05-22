# vpn-egsys v2

Monitor de bandeja, integração NetworkManager e utilitário de configuração para VPN Check Point utilizando `snx-rs`.

## Novidades v2

- **Integração com NetworkManager** — VPNs aparecem no applet do NM (GNOME, KDE, etc.)
- **Conexão síncrona** — sem delay de rotas/DNS; o sistema só reporta "conectado" quando tudo está pronto
- **snx-rs em command mode** — roda como serviço systemd com restart automático
- **snxctl** — controle confiável via `snxctl connect/disconnect/status`

## Sistemas Suportados

- **Debian/Ubuntu** (Ubuntu, Debian, Zorin OS, etc.)
- **Arch Linux** (Arch, CachyOS, EndeavourOS, etc.)
- Arquitetura: x86_64

## Características

- VPNs visíveis no NetworkManager (applet do sistema)
- Interface na bandeja do sistema para conectar/desconectar
- Ícones de status (conectado/desconectado)
- Aliases de terminal com feedback síncrono
- Configuração automática de credenciais (RO, PR e AM)
- Detecção automática de SO para instalação de dependências
- Serviço systemd com restart automático
- Autostart com o sistema

## Instalação (nova)

```bash
git clone https://github.com/andreprado-egsys/vpn-egsys.git
cd vpn-egsys
chmod +x install.sh
./install.sh
```

## Atualização (PCs com versão anterior)

```bash
cd vpn-egsys
git pull
chmod +x update.sh
./update.sh
```

O `update.sh` migra automaticamente da arquitetura antiga (standalone) para a nova (command mode + NM).

## Uso

### Via NetworkManager (novo!)

As VPNs aparecem no applet do NetworkManager. Basta clicar para conectar/desconectar.

### Via Terminal

- `vpnro` — Conecta à VPN Rondônia (aguarda confirmação)
- `vpnpr` — Conecta à VPN Paraná (aguarda confirmação)
- `vpnam` — Conecta à VPN Amazonas (aguarda confirmação)
- `vpnoff` — Desconecta a VPN ativa
- `vpnstatus` — Status detalhado da conexão via snxctl

### Via Tray Icon

O ícone na bandeja permite conectar/desconectar com um clique.

## Arquitetura v2

```
NetworkManager (applet)
       │
       ▼
NM Dispatcher (99-snx-vpn.sh)
       │
       ▼
snxctl connect/disconnect
       │
       ▼
snx-rs (systemd service, -m command)
       │
       ▼
Interface snx-xfrm + Rotas + DNS ✓
```

## Dependências

Instaladas automaticamente:
- `snx-rs` v6.0.6+ (com `snxctl`)
- `python3-gi` (PyGObject)
- `libayatana-appindicator`
- `networkmanager`
- `webkit2gtk`

## Desinstalação

```bash
chmod +x uninstall.sh
./uninstall.sh
```
