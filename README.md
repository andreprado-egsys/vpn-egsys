# vpn-egsys v2

Monitor de bandeja, integração snxctl e utilitário de configuração para VPN Check Point utilizando `snx-rs`.

## Novidades v2

- **snx-rs em command mode** — roda como serviço systemd com restart automático
- **snxctl** — controle confiável via `snxctl connect/disconnect/status`
- **Conexão síncrona** — sem delay de rotas/DNS; só reporta "conectado" quando tudo está pronto
- **VPN Tray** — ícone na bandeja com menu para conectar/desconectar/configurar
- **Descoberta dinâmica** — detecta automaticamente todas as VPNs configuradas
- **Multi-distro** — Ubuntu, Debian, Zorin, Mint, Pop, Arch, CachyOS, EndeavourOS, Manjaro

## Sistemas Suportados

- **Debian/Ubuntu** (Ubuntu, Debian, Zorin OS, Linux Mint, Pop!_OS)
- **Arch Linux** (Arch, CachyOS, EndeavourOS, Manjaro)
- **Desktop**: GNOME, KDE Plasma, XFCE
- Arquitetura: x86_64

## Instalação (PC novo)

```bash
git clone https://github.com/andreprado-egsys/vpn-egsys.git
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

### Via Terminal

Aliases gerados automaticamente para cada VPN configurada:
- `vpnro` — Conecta à VPN Rondônia
- `vpnpr` — Conecta à VPN Paraná
- `vpnam` — Conecta à VPN Amazonas
- `vpnoff` — Desconecta a VPN ativa
- `vpnstatus` — Status detalhado da conexão

### Via SAPA (egsys-tool)

A SAPA verifica automaticamente se a VPN necessária está conectada:
- Se estiver → libera acesso
- Se não estiver → solicita que o usuário conecte pelo VPN Tray

## Arquitetura v2

```
VPN Tray (bandeja)          Terminal (aliases)
       │                           │
       ▼                           ▼
   snxctl connect/disconnect/status
       │
       ▼
snx-rs (systemd service, -m command)
       │
       ▼
Interface snx-xfrm + Rotas + DNS ✓
```

## Adicionar nova VPN

### Via VPN Tray
Menu → ⚙ Configurar VPNs → Adicionar

### Via Terminal
Crie o arquivo `~/.config/snx-rs/vpnXX.conf`:
```
server-name=SERVIDOR
user-name=USUARIO
password=SENHA_EM_BASE64
ignore-server-cert=true
login-type=vpn
```

Depois rode `./update.sh` para gerar aliases e conexões NM.

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
