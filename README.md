# vpn-egsys

Instalador e monitor de VPN Check Point para as redes **RO (Rondônia)** e **PR (Paraná)**, usando [snx-rs](https://github.com/ancwrd1/snx-rs) como cliente VPN.

## O que faz

- Instala o `snx-rs` (cliente VPN Check Point moderno, em Rust)
- Configura credenciais para VPN RO e VPN PR
- Instala monitor na bandeja do sistema (tray icon) que mostra qual VPN está conectada
- Cria aliases no terminal para conexão rápida
- Autostart no login

## Requisitos

- Ubuntu/Kubuntu 22.04+ (testado em 25.10)
- KDE Plasma (para o tray icon)
- Acesso sudo (para instalar snx-rs e configurar permissões)

## Instalação

```bash
git clone https://github.com/<seu-usuario>/vpn-egsys.git
cd vpn-egsys
chmod +x install.sh
./install.sh
```

O instalador vai pedir:
1. Usuário e senha da VPN RO
2. Usuário e senha da VPN PR

As senhas são armazenadas em base64 nos configs locais (`~/.config/snx-rs/`).

## Uso

### Terminal

```bash
vpnro        # Conectar VPN Rondônia
vpnpr        # Conectar VPN Paraná
vpnoff       # Desconectar
vpnstatus    # Ver status da conexão
```

### Interface gráfica

- Procure **"VPN Monitor"** no menu de aplicativos
- Um ícone aparece na bandeja do sistema (ao lado do relógio)
- Clique no ícone para:
  - Ver qual VPN está conectada
  - Conectar VPN RO ou PR
  - Desconectar

O ícone muda automaticamente:
- 🔒 `network-vpn` → Conectado (mostra qual VPN)
- 🔓 `network-vpn-disabled` → Desconectado

## Desinstalação

```bash
cd vpn-egsys
chmod +x uninstall.sh
./uninstall.sh
```

## Estrutura

```
vpn-egsys/
├── install.sh      # Instalador interativo
├── uninstall.sh    # Desinstalador
├── vpn-tray        # Monitor da bandeja (Python/GTK)
├── README.md
└── LICENSE
```

## Arquivos instalados

| Arquivo | Descrição |
|---------|-----------|
| `~/.config/snx-rs/vpnro.conf` | Config VPN RO |
| `~/.config/snx-rs/vpnpr.conf` | Config VPN PR |
| `~/.config/snx-rs/snx-rs.conf` | Config padrão (cópia do ativo) |
| `~/.local/bin/vpn-tray` | Script do monitor |
| `~/.local/share/applications/vpn-egsys.desktop` | Atalho no menu |
| `~/.config/autostart/vpn-tray.desktop` | Autostart no login |

## Notas

- O `snx-rs` precisa de permissão SUID para criar interfaces de túnel. O instalador configura isso automaticamente.
- Se o `snx-rs` for atualizado via `apt`, o SUID é perdido. Rode `./install.sh` novamente ou: `sudo chmod u+s /usr/bin/snx-rs /usr/bin/snxctl`
- As senhas ficam em base64 (não é criptografia). Proteja os arquivos de config.

## Licença

MIT
