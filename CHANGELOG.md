# Changelog — vpn-egsys

Todas as alterações notáveis neste projeto serão documentadas neste arquivo.
O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/)
e este projeto adere ao [Semantic Versioning](https://semver.org/lang/pt-BR/).

## [2.2.3] - 2026-10-13

### Corrigido
- **sudoers compatível com `sudo-rs` (Ubuntu 25.10+)** — regras `ipsec up/down vpn*` trocadas
  por glob puro `up *`/`down *`: o `sudo-rs` casa curingas com prefixo em argumentos de forma
  intermitente, fazendo o up/down da bandeja exigir senha e falhar em silêncio.
- **`disconnect_ipsec_linux` valida a SA após o `ipsec down`** — reporta falha real
  ("SA continua ativa") em vez de sucesso falso; `disconnect_all` propaga o erro à bandeja.
- **`render_stroke_block` respeita os campos do perfil** — `aggressive` e `forceencaps`
  de `vpn*.conf` agora são materializados em `/etc/ipsec.conf` (antes havia valor fixo).
- **`vpn-ipsec-apply` tolera strongSwan ausente** — sem o binário `ipsec` o helper grava os
  perfis, emite aviso e sai 0, sem traceback (`FileNotFoundError` no reload).

## [2.2.2] - 2026-10-10

### Adicionado
- **Execução assíncrona não-bloqueante no `vpn-tray`** — as chamadas de conexão e
  desconexão (`connect_vpn` e `disconnect_all`) agora operam em threads de segundo
  plano (`threading.Thread(daemon=True)`), eliminando o congelamento da interface
  gráfica GTK durante negociações IPsec e timeouts de gateway (ex: FortiGate com 3
  desafios XAuth).
- **Feedback visual imediato e notificações no Desktop** — o status do item de menu
  muda instantaneamente para `⌛ Conectando [VPN]...` ou `⌛ Desconectando...` ao
  clique do analista, atualizando o ícone de forma thread-safe via `GLib.idle_add`
  e disparando notificações nativas pelo `notify-send` com o resultado do backend.

### Corrigido
- **Alinhamento do fluxo automático IPsec AM SSP** — diagnóstico do incidente com
  sintaxe de `/etc/ipsec.conf` (indentação na linha 1) e correção do perfil
  `vpnamssp.conf` de `ikev2` para `ikev1-xauth`, assegurando que o helper
  `vpn-ipsec-apply` gere os blocos gerenciados automaticamente no `/etc/` sem
  necessidade de intervenção manual do usuário.
- **Relatório formal de diagnóstico para a SSP/AM** — geração de documento técnico
  auditável (`RELATORIO_TECNICO_VPN_SSP_AM.md`) com evidências brutas de IKE/XAuth
  para alinhamento junto à equipe de infraestrutura do CICC/SSP.

---

## [2.2.1] - 2026-10-10

### Adicionado
- **Verificação de rotas liberadas pelo gateway** — após a SA `INSTALLED`,
  `connect_ipsec_linux` compara as TS remotas instaladas (`ipsec statusall` /
  `swanctl --list-sas`) com o campo `routes` do perfil
  (`VPNBackend.installed_remote_ts`, `VPNBackend.missing_released_routes`) e
  reporta aviso explícito quando o gateway reduz o traffic selector e não
  libera a rede interna (cenário do túnel "conectado sem rota" relatado pela
  dev em 09/10/2026). Validado ao vivo com gateway forteSwan mockado em
  netns que liberava apenas `10.200.210.0/24` para um perfil que declarava
  `172.20.100.0/24`.

### Corrigido
- **Parse de CHILD SA no `ipsec statusall`** — o formato real usa chaves
  (`conn{n}: INSTALLED` / `local === remote`), não colchetes; a checagem de
  SA estabelecida agora reconhece ambos. Descoberto pela simulação netns.

### Alterado
- **`update.sh` cobre o lado privilegiado IPsec** — novo bloco 10b sincroniza
  `core/` + `vpn-ipsec-apply` em `/usr/lib/vpn-egsys`, regrava
  `/etc/sudoers.d/vpn-egsys` (validado com `visudo -c`), habilita
  `strongswan-starter` e roda o apply; o wizard agora oferta
  IKEv1 XAuth+PSK como padrão (IKEv2/swanctl opcional), alinhado ao
  `install.sh`. Fluxo do analista passa a ser `git clone` + `./update.sh`
  com cobertura 100% em máquinas já instaladas.

---

## [2.2.0] - 2026-10-10

### Alterado
- **IPsec: backend stroke IKEv1 XAuth+PSK (padrão)** — gateways FortiGate
  (ex: VPN AM SSP) só negociam IKEv1 Main Mode + PSK + XAuth SHA-256; o plugin
  strongSwan do NetworkManager (IKEv2-only) foi removido do caminho de conexão.
  - `core/vpn_manager.py`: novos renderizadores puros (`render_stroke_block`,
    `render_secrets_block`, `render_swanctl_block`, `apply_markers`,
    `strip_markers`); `connect/disconnect/status` IPsec Linux usam
    `sudo ipsec up|down|statusall` (IKEv1) e `swanctl` (IKEv2) via
    `run_sudo` NOPASSWD, com confirmação de SA `INSTALLED` antes de reportar
    conexão; perfis normativizam `ikev1`/`xauth` → `ikev1-xauth` (padrão).
  - Novo helper privilegiado `vpn-ipsec-apply` (`/usr/lib/vpn-egsys/`):
    materializa os perfis `vpn*.conf` do usuário nos blocos gerenciados
    `# BEGIN/END vpn-egsys` de `/etc/ipsec.conf`/`ipsec.secrets` e em
    `/etc/swanctl/conf.d/vpn-egsys.conf`; garante `stroke.load=yes` e a unit
    `strongswan-starter`; suporta `--check` e `--uninstall`.
  - `install.sh`: sudoers restrito validado com `visudo -c -f`
    (`/etc/sudoers.d/vpn-egsys`), remoção de `network-manager-strongswan`
    das dependências, habilitação de `strongswan-starter`.
  - `vpn`, `vpn-tray`, `user-setup.sh`: seleção/wizard com `ikev1-xauth` como
    padrão; bandeja agora grava `ipsec-type` e remove apenas o perfil
    (regenerando os blocos via helper, sem `nmcli connection delete`).
  - `nm-snx-setup.sh`: não cria mais conexões `vpn-type strongswan` no NM.

### Adicionado
- Testes unitários dos renderizadores (golden do modelo validado em produção),
  escape/injeção em `ipsec.secrets`, idempotência de marcadores, backends
  Linux com `subprocess` mockado e varredura de segurança do
  `vpn-ipsec-apply` (ACH-VPN-006/007).
- `docs/IPSEC.md` reescrito: fluxo perfis → helper → stroke/swanctl e a
  tabela de incompatibilidades NM/vpnc/L2tp medidas contra o FortiGate AM SSP.

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
