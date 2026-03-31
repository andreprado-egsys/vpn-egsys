# vpn-egsys

Instalador e monitor de VPN Check Point para as redes **RO (Rondônia)** e **PR (Paraná)**, usando [snx-rs](https://github.com/ancwrd1/snx-rs) como cliente VPN.

## O que faz

O `install.sh` executa tudo automaticamente:

1. Detecta o SO e gerenciador de pacotes (apt/dnf/pacman)
2. Instala o `snx-rs` (cliente VPN Check Point em Rust)
3. Instala dependências do tray icon
4. Pede usuário e senha de cada VPN (RO e PR)
5. Cria os arquivos de configuração
6. Instala o monitor na bandeja do sistema
7. Configura aliases no terminal
8. Testa conectividade com os servidores
9. Inicia o tray icon na bandeja

## Sistemas suportados

| Distro | Gerenciador | Status |
|--------|-------------|--------|
| Ubuntu/Kubuntu 22.04+ | apt | ✓ Testado |
| Debian 12+ | apt | ✓ |
| Fedora 38+ | dnf | ✓ |
| Arch Linux | pacman | ✓ |

Requer: x86_64, Python 3, desktop com suporte a tray icon.

## Instalação

```bash
git clone https://github.com/<seu-usuario>/vpn-egsys.git
cd vpn-egsys
./install.sh
```

O instalador pede:
```
Usuário RO: <cpf ou login>
Senha RO: <senha>
Usuário PR: <login.egsys>
Senha PR: <senha>
```

Ao final, o ícone já aparece na bandeja do sistema.

## Uso

### Terminal

```bash
vpnro        # Conectar VPN Rondônia
vpnpr        # Conectar VPN Paraná
vpnoff       # Desconectar
vpnstatus    # Ver status
```

### Bandeja do sistema

Ícone ao lado do relógio:
- 🟢 Cadeado verde → Conectado (mostra qual VPN)
- ⚫ Cadeado cinza → Desconectado

Menu do ícone:
- Status da conexão
- Conectar VPN RO / PR
- Desconectar
- Sair

O monitor inicia automaticamente no login.

## Desinstalação

```bash
./uninstall.sh
```

## Estrutura

```
vpn-egsys/
├── install.sh                  # Instalador interativo
├── uninstall.sh                # Desinstalador
├── vpn-tray                    # Monitor da bandeja (Python/GTK)
├── icons/
│   ├── vpn-connected.svg       # Ícone verde (conectado)
│   └── vpn-disconnected.svg    # Ícone cinza (desconectado)
├── README.md
└── LICENSE
```

## Notas

- Se o `snx-rs` for atualizado, rode `./install.sh` novamente para restaurar permissões SUID.
- Senhas ficam em base64 nos configs (`~/.config/snx-rs/`). Os arquivos são criados com permissão 600.

## Licença

MIT
