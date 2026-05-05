# vpn-egsys

Monitor de bandeja e gerenciador de VPN Check Point via `snx-rs`.

## Sistemas Suportados

- **Debian/Ubuntu** (Ubuntu, Debian, Zorin OS, Linux Mint, Pop!_OS, etc.)
- **Arch Linux** (Arch, CachyOS, EndeavourOS, Manjaro, etc.)
- **Fedora/RHEL** (Fedora, CentOS, Rocky, etc.)
- Arquitetura: x86_64

## Características

- Descoberta dinâmica de VPNs — adicione quantas quiser, o sistema se adapta
- Interface na bandeja do sistema (tray) com status em tempo real
- Aliases de terminal gerados automaticamente para cada VPN configurada
- Configuração automática de `sudoers.d` — sem edição manual, sem senha repetida
- Gerenciador interativo para listar, adicionar, atualizar e remover VPNs
- Preserva configurações existentes — nunca sobrescreve sem confirmação
- Autostart com o sistema
- Suporte a bash e zsh

## Instalação

```bash
git clone https://github.com/andreprado-egsys/vpn-egsys.git
cd vpn-egsys
./install.sh
```

O instalador:
1. Detecta sua distro e instala dependências
2. Instala o `snx-rs` se necessário
3. Configura `/etc/sudoers.d/vpn-egsys` automaticamente (sem precisar editar manualmente)
4. Pergunta credenciais apenas para VPNs ainda não configuradas
5. Gera aliases dinâmicos e inicia o monitor de bandeja

## Uso via Terminal

Os aliases são gerados dinamicamente com base nas VPNs configuradas:

- `vpnro` — Conecta à VPN Rondônia
- `vpnpr` — Conecta à VPN Paraná
- `vpnam` — Conecta à VPN Amazonas
- `vpnoff` — Desconecta a VPN ativa
- `vpnstatus` — Verifica status da conexão

Novos aliases são criados automaticamente ao adicionar VPNs via `update.sh`.

## Gerenciamento de VPNs

```bash
./update.sh
```

Menu interativo com opções:
1. **Listar** VPNs configuradas
2. **Adicionar** nova VPN
3. **Atualizar** credenciais de VPN existente
4. **Remover** VPN
5. **Regenerar** aliases
6. **Atualizar** vpn-tray

Também aceita argumentos diretos: `./update.sh listar`, `./update.sh adicionar`, etc.

## Desinstalação

```bash
./uninstall.sh
```

Remove binários, aliases, sudoers e autostart. Pergunta antes de apagar configurações de VPN.

## Dependências

Instaladas automaticamente pelo `install.sh`:
- `snx-rs` (v5.2.3+)
- `python3-gi` / `python-gobject`
- `libayatana-appindicator`
- `webkit2gtk`
