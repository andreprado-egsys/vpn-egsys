# Histórico Cumulativo de Sessões e Evolução — vpn-egsys

Este documento é a Single Source of Truth (SSOT) interna cumulativa e contínua do desenvolvimento do **vpn-egsys**, registrando detalhadamente as sessões de trabalho, decisões técnicas de arquitetura, correções aplicadas e auditorias.

> 🔒 **Aviso de Confidencialidade Interna**: Este arquivo contém metadados de engenharia e aprendizados de sessões. É estritamente gitignored para não vazar em branches públicas da empresa.

---

## Índice Cronológico
- [Sessão 2026-09-30 (Parte 2): Auditoria e Testes de Pentest Black Box (ACH-VPN-001 a ACH-VPN-010)](#sessão-2026-09-30-parte-2-auditoria-e-testes-de-pentest-black-box-ach-vpn-001-a-ach-vpn-010)
- [Sessão 2026-09-30: Evolução Multi-Protocolo IPsec e Suporte Cross-Platform (Linux & macOS) - v2.1.0](#sessão-2026-09-30-evolução-multi-protocolo-ipsec-e-suporte-cross-platform-linux--macos---v210)
- [Sessão 2026-05-27: Modernização para Command Mode snx-rs v6 e VPN Tray v2.0](#sessão-2026-05-27-modernização-para-command-mode-snx-rs-v6-e-vpn-tray-v20)
- [Sessão 2026-05-20: Criação da Suíte de VPNs e Aliases Iniciais v1.0](#sessão-2026-05-20-criação-da-suíte-de-vpns-e-aliases-iniciais-v10)

---

## Sessão 2026-09-30 (Parte 2): Auditoria e Testes de Pentest Black Box (ACH-VPN-001 a ACH-VPN-010)

### 1. Contexto e Demanda
Aplicação compulsória da metodologia de Pentest Black Box e Security Hardening validada no egSYS Orion (ACH-001 a ACH-011) para o ecossistema `vpn-egsys`. O objetivo era submeter a ferramenta a vetores reais de ataque (Command Injection, Path Traversal, CRLF Injection, Insecure File Permissions, Subprocess Hijacking, DoS por strings gigantes) e comprovar mitigação defensiva por evidência com testes automatizados.

### 2. Ações de Engenharia Realizadas
1. **Sanitização Defensiva contra CRLF Injection (`core/vpn_manager.py`)**:
   - Implementação de `sanitize_config_value` expurgando `\r` e `\n` em todos os parâmetros antes de persistir em arquivos `.conf`.
2. **Hardening do CLI `vpn`**:
   - Sanitização de argumentos nos comandos `vpn connect <id>` e `vpn remove <id>`, rejeitando caracteres não alfanuméricos com código de erro 1 e mensagem de segurança antes de qualquer processamento.
3. **Criação da Suíte de Pentest (`tests/test_security_pentest.py`)**:
   - Implementados 10 testes automatizados cobrindo os achados ACH-VPN-001 a ACH-VPN-010.
   - Quality Gate expandido para 18 testes automatizados aprovados com 100% de sucesso.
4. **Publicação da Matriz de Segurança**:
   - Criado [`docs/SECURITY.md`](SECURITY.md) detalhando cada vetor e sua mitigação correspondente.

---

## Sessão 2026-09-30: Evolução Multi-Protocolo IPsec e Suporte Cross-Platform (Linux & macOS) - v2.1.0

### 1. Contexto e Demanda
A equipe técnica da egSYS (engenharia, suporte N1/N2/N3 e liderança) utiliza estações de trabalho mistas (Linux Ubuntu/Debian, Arch/CachyOS e macOS com processadores Intel e Apple Silicon M1-M4). Anteriormente, a ferramenta `vpn-egsys` funcionava exclusivamente no Linux e apenas para o protocolo Check Point (`snx-rs`), o que impedia os analistas que utilizam computadores Apple de conectar ou gerenciar VPNs, além de não atender aos estados e órgãos públicos que exigem conexões baseadas em túneis **IPsec (IKEv2)** (ex.: Santa Catarina, Tocantins, etc.).

### 2. Ações de Engenharia Realizadas
1. **Camada Unificada de Conectividade (`core/vpn_manager.py`)**:
   - Desenvolvida a camada de abstração em Python puro sem dependências externas obrigatórias.
   - Detecção dinâmica de plataforma via `platform.system()`.
   - Suporte a `protocol=snx` e `protocol=ipsec` com parsing defensivo e gravação de arquivos com permissões Unix `0600`.
   - Integração com `NetworkManager` (`nmcli`) e `strongSwan`/`swanctl` no Linux.
   - Integração com os frameworks nativos de rede do macOS (`scutil --nc` e `networksetup`).
2. **Utilitário de Linha de Comando Universal (`vpn`)**:
   - Criação do binário executável universal em Python `vpn` no diretório raiz e instalado em `~/.local/bin/vpn`.
   - Implementação de subcomandos `list`, `connect`, `disconnect`, `status`, `add` e `remove`.
   - Compatibilidade com atalhos rápidos (`vpn ro` equivale a `vpn connect ro`; `vpn off` desconecta).
   - Wizard interativo para adicionar conexões com suporte a senhas mascaradas via `getpass`.
3. **Evolução do Monitor de Bandeja (`vpn-tray`)**:
   - Implementado padrão de motor duplo:
     - No Linux: Backend GTK 3 + AyatanaAppIndicator (mantendo 100% de compatibilidade com GNOME 46+, KDE e XFCE).
     - No macOS: Backend `pystray` + AppKit nativo na barra de menus superior do sistema.
   - Diálogo de configuração expandido com combobox de protocolo (Check Point SNX vs IPsec/IKEv2).
4. **Instaladores e Serviços Cross-Platform**:
   - `install.sh`: Adicionada detecção no topo para redirecionar para `macos/install_macos.sh` quando executado em macOS. No Linux, adicionados pacotes de IPsec (`strongswan`, `network-manager-strongswan`).
   - `update.sh`: Atualizado para copiar o binário `vpn` e a pasta `core/`.
   - `user-setup.sh`: Atualizado para ambiente de usuário padrão no Linux e macOS.
   - `macos/install_macos.sh`: Instalador nativo para macOS com suporte a Homebrew, dependências Python, cópia de binários e registro de LaunchAgent.
   - `macos/com.egsys.vpn-tray.plist`: LaunchAgent para inicialização automática na sessão de login do macOS.
   - `macos/setup_ipsec.sh`: Script auxiliar para criação de serviços IKEv2 no macOS.
5. **Quality Gate Automatizado**:
   - Criado `run_tests.sh` executando validação sintática Bash (`bash -n`), compilação de bytecode Python (`py_compile`) e bateria de testes unitários.
   - Criados `tests/test_vpn_manager.py` e `tests/test_cli.py` com 8 testes cobrindo 100% dos fluxos de configuração e CLI.
6. **Governança Canônica e Documentação**:
   - Criados [`CHANGELOG.md`](CHANGELOG.md), [`docs/ROADMAP.md`](docs/ROADMAP.md), [`docs/IPSEC.md`](docs/IPSEC.md) e [`docs/MACOS.md`](docs/MACOS.md).
   - Atualizados [`README.md`](README.md) e [`AGENTS.md`](AGENTS.md).
   - Criada a tríade de skills de governança: `vpn-commit`, `vpn-docs-sync`, `vpn-jira-sync`.

---

## Sessão 2026-05-27: Modernização para Command Mode snx-rs v6 e VPN Tray v2.0

### 1. Contexto e Demanda
O cliente `snx-rs` em versões legadas (v4/v5) operava em modo standalone, abrindo processos avulsos que frequentemente ficavam zumbis em `/run/snx-rs.lock` e exigiam reautenticação manual frequente. Além disso, as rotas e o DNS levavam vários segundos para propagar após a mensagem de conexão concluída.

### 2. Ações de Engenharia Realizadas
1. **Migração para Command Mode**:
   - `snx-rs` configurado como daemon de sistema via systemd (`snx-rs.service`) rodando com `-m command`.
   - Controle unificado via `snxctl connect`, `snxctl disconnect` e `snxctl status`.
2. **Conexão Síncrona**:
   - O comando de conexão agora aguarda ativamente a criação da interface `snx-xfrm` e aplicação das rotas antes de retornar sucesso ao usuário.
3. **Monitor de Bandeja vpn-tray**:
   - Criação do aplicativo em Python com interface GTK 3 e ícones de status (`network-vpn` / `network-vpn-disconnected`).
   - Suporte a múltiplos ambientes gráficos Linux (GNOME 46+, KDE, XFCE).
4. **Resolução de Instabilidade no Amazonas (PRODAM/AM)**:
   - Identificada queda recorrente do gateway da PRODAM quando recebia pacotes de keepalive constantes.
   - Inseridas as diretivas `no-keepalive=false` (posteriormente corrigido para remover no-keepalive e manter apenas `ike-persist=true`).

---

## Sessão 2026-05-20: Criação da Suíte de VPNs e Aliases Iniciais v1.0

### 1. Contexto e Demanda
Necessidade de padronizar a conexão às redes estaduais de Rondônia (RO), Paraná (PR) e Amazonas (AM) para os analistas da egSYS, eliminando a dependência do cliente proprietário Check Point SNX de 32 bits (incompatível com kernels Linux modernos de 64 bits).

### 2. Ações de Engenharia Realizadas
- Adoção da implementação moderna em Rust do Check Point SNX (`snx-rs`).
- Criação dos scripts iniciais `install.sh` e `user-setup.sh`.
- Geração de aliases no `.bashrc` e `.zshrc` (`vpnro`, `vpnpr`, `vpnam`, `vpnoff`, `vpnstatus`).
