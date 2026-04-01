# vpn-egsys

Monitor de bandeja e utilitário de configuração para VPN Check Point utilizando `snx-rs`.

## Sistemas Suportados

- **Ubuntu** (20.04+)
- **Debian** (11+)
- **Zorin OS**
- **Arch Linux**
- **CachyOS**
- E outros derivados dessas bases.

## Características

- Interface na bandeja do sistema para conectar/desconectar.
- Ícones de status (conectado/desconectado).
- Aliases de terminal para conexão rápida.
- Configuração automática de credenciais (criptografadas em Base64 apenas para o arquivo de config).
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
- `vpnoff`: Desconecta a VPN ativa.
- `vpnstatus`: Verifica o status e logs da conexão.

## Dependências

O instalador cuida de tudo, mas os componentes principais são:
- `snx-rs` (v5.2.3+)
- `python3-gi` (PyGObject)
- `libayatana-appindicator`
- `webkit2gtk` (para autenticação web se necessário)
