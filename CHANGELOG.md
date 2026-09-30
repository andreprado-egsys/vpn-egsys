# Changelog — vpn-egsys

Todas as alterações notáveis neste projeto serão documentadas neste arquivo.
O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/)
e este projeto adere ao [Semantic Versioning](https://semver.org/lang/pt-BR/).

---

## [2.1.1] - 2026-09-30

### Adicionado
- **Presets Estaduais e Gestão Integrada na Bandeja (`vpn-tray`)**:
  - Seletor de presets rápidos cobrindo **SC (IPsec), TO (IPsec), RO (SNX 131.72.155.42), PR (SNX acessoremoto.pr.gov.br) e AM (SNX sslvpn.prodam.am.gov.br)**.
  - Alternância reativa da interface gráfica: os campos específicos de IPsec (Chave PSK e Rotas adicionais) alternam sua visibilidade instantaneamente ao mudar o protocolo.
  - Diálogo de gerenciamento `show_management_dialog` para adicionar, editar credenciais e remover conexões diretamente pela GUI.
  - Injeção automática de `ike-persist=true` para perfis do Amazonas (`am` / `vpnam`).

### Corrigido
- **Hardening Multi-Usuário em Execuções com Sudo (`install.sh`, `update.sh`, `user-setup.sh`)**:
  - Resolução segura do usuário real via `TARGET_USER="${SUDO_USER:-$USER}"` e home canônico via `getent passwd`.
  - Delegação de execução do `vpn-tray` na sessão gráfica do usuário (`sudo -u "$TARGET_USER" DISPLAY=... DBUS_SESSION_BUS_ADDRESS=... nohup ...`), eliminando a execução acidental da bandeja como `root`.
  - Encerramento confiável de instâncias antigas com `pkill -f "vpn-tray"` e aplicação de `chown "$TARGET_USER:$TARGET_USER"` em arquivos gerados.

---

## [2.1.0] - 2026-09-30 (Jira PSEI-336)

### Adicionado
- **Suporte Multi-Protocolo**:
  - Implementação do protocolo **IPsec (IKEv2)** para conexão com gateways governamentais e estaduais (pfSense, FortiGate, Cisco, MikroTik, strongSwan).
  - Suporte ao parâmetro `protocol=ipsec` e `protocol=snx` no parsing e escrita de configurações (`~/.config/snx-rs/vpnXX.conf`).
  - Suporte a chaves pré-compartilhadas (`psk`) e injeção de rotas personalizadas (`routes`).
- **Compatibilidade Cross-Platform (macOS Darwin)**:
  - Instalador dedicado [`macos/install_macos.sh`](macos/install_macos.sh) com suporte a Homebrew, macOS Monterey, Ventura, Sonoma e Sequoia (Intel e Apple Silicon M1/M2/M3/M4).
  - LaunchAgent [`macos/com.egsys.vpn-tray.plist`](macos/com.egsys.vpn-tray.plist) para autostart na inicialização da sessão de login do usuário.
  - Script de apoio para serviços de rede [`macos/setup_ipsec.sh`](macos/setup_ipsec.sh).
  - Documentação específica [`docs/MACOS.md`](docs/MACOS.md).
- **Camada Unificada de Conectividade (`core/vpn_manager.py`)**:
  - Módulo core Python desacoplado para descoberta de VPNs, leitura, escrita segura com `0600` e disparo de conexões.
  - Abstração de SO (`is_macos()`, `is_linux()`) e protocolo (`connect_vpn()`, `disconnect_all()`, `get_active_vpn()`).
- **CLI Universal `vpn`**:
  - Executável universal para terminal: `vpn list`, `vpn <id>`, `vpn connect <id>`, `vpn disconnect` / `vpn off`, `vpn status`, `vpn add`, `vpn remove`.
  - Assistente interativo no terminal para cadastro de novas VPNs com prompt mascarado de senha.
- **Bandeja Multi-Engine (`vpn-tray`)**:
  - Motor Linux: GTK 3 + AyatanaAppIndicator com seleção visual de protocolo.
  - Motor macOS: `pystray` + AppKit nativo na barra de menus superior do sistema.
  - Seletor de protocolo e rotas nos diálogos de Adicionar e Editar VPN.
- **Quality Gate e Testes Automatizados**:
  - Runner [`run_tests.sh`](run_tests.sh) integrando verificação sintática Bash (`bash -n`), compilação de bytecode Python (`py_compile`) e bateria de testes unitários.
  - Testes unitários [`tests/test_vpn_manager.py`](tests/test_vpn_manager.py) e testes de CLI [`tests/test_cli.py`](tests/test_cli.py) com 100% de cobertura nos fluxos de configuração.
- **Bateria de Pentest Black Box & Security Hardening (ACH-VPN-001 a ACH-VPN-010)**:
  - Criação da suíte [`tests/test_security_pentest.py`](tests/test_security_pentest.py) com 10 testes defensivos baseados no padrão Orion.
  - Validação de mitigação contra Command Injection, Path Traversal, CRLF Injection, permissões `0600`, proibição de `shell=True` e sanitização estrita de CLI.
  - Publicação do documento de governança de segurança [`docs/SECURITY.md`](docs/SECURITY.md).
- **Governança Canônica egSYS**:
  - [`AGENTS.md`](AGENTS.md) com diretrizes de engenharia e regras de produto anti-desvio.
  - Tríade de skills operacionais: `vpn-commit`, `vpn-docs-sync`, `vpn-jira-sync`.
  - Manual técnico [`docs/IPSEC.md`](docs/IPSEC.md).

### Modificado
- `install.sh`: Delegação automática para `macos/install_macos.sh` quando executado em macOS; inclusão de pacotes IPsec (`strongswan`, `network-manager-strongswan`) no Linux; instalação do CLI universal `vpn` e pasta `core/`.
- `update.sh`: Detecção de macOS e atualização dos novos binários `vpn` e `core/`.
- `user-setup.sh`: Cópia do CLI `vpn` e `core/` para `~/.local/bin` e tratamento defensivo quando `snxctl` não está instalado (modo IPsec puro).
- `nm-snx-setup.sh`: Detecção de `protocol=ipsec` para criação de conexões NetworkManager nativas StrongSwan.
- `.gitignore`: Travas sanitárias completas contra arquivos de sessão, credenciais, metadados de IA e históricos internos.

---

## [2.0.0] - 2026-05-27

### Adicionado
- Arquitetura baseada em **snx-rs command mode** executando como daemon gerenciado por `systemd` (`snx-rs.service`).
- Controle confiável de conexão e status via utilitário CLI `snxctl`.
- Conexão síncrona com verificação de rotas e DNS antes de reportar estado conectado.
- Monitor de bandeja `vpn-tray` com interface em Python GTK 3 e AyatanaAppIndicator.
- Descoberta dinâmica de túneis configurados em `~/.config/snx-rs/`.
- Suporte multi-distro Linux: Ubuntu, Debian, Zorin, Linux Mint, Pop!_OS, Arch Linux, CachyOS, EndeavourOS e Manjaro.
- Script de migração e atualização automática `update.sh`.
- Suporte a multi-usuário em estações compartilhadas via `user-setup.sh`.
- Integração de status com a ferramenta de suporte e gestão de servidores SAPA (`egsys-tool`).

### Modificado
- Substituição do modo standalone do `snx-rs` pelo modo daemon com restart automático.
- Migração de aliases do shell para chamar `snxctl connect`/`snxctl disconnect`.

---

## [1.0.0] - 2026-05-20

### Adicionado
- Versão inicial da suíte de VPNs da egSYS para acesso a Rondônia (RO), Paraná (PR) e Amazonas (AM).
- Scripts de instalação e configuração inicial de arquivos `.conf` locais.
- Aliases rápidos no shell (`vpnro`, `vpnpr`, `vpnam`, `vpnoff`, `vpnstatus`).
