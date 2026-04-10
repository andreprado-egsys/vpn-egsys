# vpn-egsys

Monitor de bandeja e utilitário de configuração para VPN Check Point utilizando `snx-rs`.

## Sistemas Suportados

- **Sistemas baseados em Debian/Ubuntu** (Ubuntu, Debian, Zorin OS, etc.)
- **Sistemas baseados em Arch Linux** (Arch, CachyOS, EndeavourOS, etc.)
- Arquitetura: x86_64

## Características

- Interface na bandeja do sistema para conectar/desconectar.
- Ícones de status (conectado/desconectado).
- Aliases de terminal para conexão rápida.
- Configuração automática e unificada de credenciais (RO, PR e AM).
- Detecção automática de sistema operacional para instalação de dependências.
- Gerenciamento inteligente de processos para evitar conflitos.
- Autostart com o sistema.

## Instalação

```bash
git clone https://github.com/andreprado-egsys/vpn-egsys.git
cd vpn-egsys
chmod +x install.sh
./install.sh
```

## Uso via Terminal

Após a instalação, você pode usar os seguintes comandos:

- `vpnro`: Conecta à VPN Rondônia.
- `vpnpr`: Conecta à VPN Paraná.
- `vpnam`: Conecta à VPN Amazonas.
- `vpnoff`: Desconecta a VPN ativa e encerra processos snx-rs.
- `vpnstatus`: Verifica o status da interface de rede e logs da conexão.

## Atualização e Configuração

Se você já possui a aplicação instalada e deseja adicionar uma nova VPN (como a de AM) ou atualizar suas credenciais existentes de forma segura:

```bash
git pull
chmod +x update.sh
./update.sh
```
O script `update.sh` encerra a aplicação ativa, valida dependências do sistema e permite configurar ou atualizar as credenciais de todas as VPNs suportadas.

## Dependências

O instalador cuida de tudo, mas os componentes principais são:
- `snx-rs` (v5.2.3+)
- `python3-gi` (PyGObject)
- `libayatana-appindicator`
- `webkit2gtk` (para autenticação web se necessário)
