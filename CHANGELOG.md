# Changelog — vpn-egsys

Todas as alterações notáveis neste projeto serão documentadas neste arquivo.
O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/)
e este projeto adere ao [Semantic Versioning](https://semver.org/lang/pt-BR/).

## [2.2.9] - 2026-10-28 (Jira PSEI-416)

### Corrigido
- **Bandeja em sessão Wayland pura** — `setup_display()` do `vpn-tray` exigia `DISPLAY` e
  abortava com "Nenhum display encontrado" mesmo com compositor Wayland ativo quando as
  variáveis de sessão não chegavam ao processo (autostart, `sudo -u`, shell limpo). Agora o
  runtime dir é deduzido do uid (`/run/user/<uid>`), o `WAYLAND_DISPLAY` é descoberto pelos
  sockets `wayland-*` desse diretório (ignorando os `*.lock`) e o abortamento só ocorre quando
  **não há** X11 **nem** Wayland.
- **Dois usuários na mesma máquina** — o `StatusNotifierItem` era registrado com o id fixo
  `vpn-monitor`; o segundo tray substituía/silenciava o primeiro no watcher do KDE. O id passa a
  ser `vpn-monitor-<uid>`.
- **Ícone próprio fora do tema do sistema** — o `ICON_DIR` do projeto só era consultado no
  fallback de nome; agora é registrado no `Gtk.IconTheme` (`append_search_path`) **antes** da
  primeira busca, então o SVG do projeto resolve mesmo sem a cópia em `hicolor/`.
- **Gate não reproduzível em Arch/CachyOS** — `test_connect_v1_rc0_without_sa_fails` lia o
  `libcharon.so` real da estação: em strongSwan ≥ 6 sem IKEv1 o ramo específico era escolhido e a
  asserção genérica "não estabeleceu" falhava (48 testes → 1 falha no HEAD publicado). O teste
  agora isola `charon_ikev1_missing()` e o ramo oposto ganhou caso próprio.

### Adicionado
- **`tests/test_tray_wayland_env.py`** — regressão com execução real de `setup_display` isolado
  por AST sobre sistema de arquivos sintético (Wayland puro, socket `.lock`, ausência total de
  display, valores existentes preservados) e contrato textual do id por uid e do registro de
  `ICON_DIR`. Suíte: 56 testes.
- **`test_connect_v1_without_ikev1_in_charon_reports_rebuild`** em `tests/test_vpn_manager.py` —
  cobre a mensagem de charon sem IKEv1 (`--enable-ikev1` / `IgnorePkg`).

## [2.2.8] - 2026-10-19 (Jira PSEI-416)

### Corrigido
- **Endereço do bus de sessão no relançamento do `vpn-tray`** — `install.sh` e `update.sh` passavam
  `DBUS_SESSION_BUS_ADDRESS` ao `sudo -u … nohup vpn-tray` sem validação. A libdbus rejeita
  endereço sem o separador `:` (ex.: caminho puro `/run/user/1000/bus`) e o Ayatana cai para
  XEmbed **sem erro visível** quando o stderr é descartado — o tray fica sem StatusNotifierItem
  e o menu perde o acesso via D-Bus (KDE/Wayland). Os scripts agora compõem `BUS_ADDR`: validam o
  variável da sessão (passagem direta se contiver `:`), prefixam `unix:path=` em caminho puro e,
  na ausência da variável, constroem `unix:path=/run/user/<uid>/bus` do usuário real (`SUDO_USER`).

### Adicionado
- **`tests/test_tray_bus_env.py`** — regressão do normalizador: contrato textual nos dois scripts
  (bloco antes do `nohup`) e execução real do bloco em bash para os três casos (caminho puro →
  prefixo, endereço válido → intocado, ausente → construído do runtime dir). Suíte: 48 testes.

### Validado
- **PSEI-416 (fork storm) em estação CachyOS/KDE Wayland**: ciclo Conectar → Desconectar →
  Conectar disparado por clique D-Bus real no menu da bandeja — 2 processos `sudo` em 30 s
  (~4/min do poller de 5 s, vs ~5.500/min observados no Ubuntu pré-fix), tray estável em
  6 threads e ~67 MB de RSS. Qualidade: gate 48/48.

## [2.2.7] - 2026-10-19 (Jira PSEI-416)

### Corrigido
- **Fork storm no `vpn-tray` (regressão 2.2.6)** — `check_status()` retornava `True` e era
  registrado via `GLib.idle_add(self.check_status)` em `_async_connect`/`_async_disconnect`.
  Em GLib, callback de *idle* retornando `True` **re-agenda o source para sempre**: a cada passo
  do main loop era criada uma thread que chamava `get_active_vpn()` → `sudo vpn-ipsec-ctl
  stroke status`. Resultado observado na estação Ubuntu: **~5.500 chamadas sudo/minuto**
  (19,7 M em 3 dias, `auth.log`), ~2.700 forks/s, 0% de CPU idle e load 85–95 em 12 cores —
  máquina inutilizável e navegadores congelados. `check_status()` agora retorna `False`
  (execução única; o poller `_status_loop` de 5 s continua dono da UI). Pós-fix medido:
  12 chamadas/min, 14 forks/s, load 1,5.
- **Shebang do `vpn-tray` pinado em `/usr/bin/python3`** — `#!/usr/bin/env python3` resolvia
  para o python do linuxbrew (presente no PATH da sessão) que não tem PyGObject, quebrando
  `import gi` no autostart. O `plist` do macOS continua usando `/usr/local/bin/python3`
  explicitamente, então não há efeito no macOS.

### Adicionado
- **`tests/test_tray_idle.py`** — regressão estática (AST): todo callback registrado em
  `GLib.idle_add(self.X)` deve retornar `False`, e o shebang deve pinar o python do sistema.

## [2.2.6] - 2026-10-16

### Corrigido
- **Ícone da bandeja invisível no estado desconectado** — `vpn-tray` decidia o nome do ícone testando
  apenas `theme.has_icon('network-vpn')`, o que mantinha `network-vpn-disconnected` (nome que **não
  existe** no tema Breeze nem no `IconThemePath` do projeto). O item ficava sem ícone na bandeja do
  Plasma exatamente quando não há túnel ativo, tornando impossível clicar para fazer login. Cada nome
  passou a ser validado individualmente, com fallback para `vpn-connected`/`vpn-disconnected`.
- **Ícones do projeto instalados no tema de usuário** — `install.sh`, `update.sh` e `user-setup.sh`
  agora copiam `icons/*.svg` também para `~/.local/share/icons/hicolor/scalable/apps/`, além da cópia
  plana em `~/.local/share/icons/vpn-egsys` usada pelo `IconThemePath` do SNI. Assim GTK e os hosts
  StatusNotifier resolvem os ícones **por nome**, sem depender do caminho explícito do arquivo.

## [2.2.5] - 2026-10-13

### Corrigido
- **Paridade IKEv1 Arch/CachyOS vs Ubuntu** — perfis `ikev1-xauth` (ex: VPN AM SSP) falhavam
  em silêncio no CachyOS porque o `strongswan` 6.x dos repositórios Arch é compilado sem
  IKEv1 (`IKE version 1 not supported` no charon, antes de qualquer troca com o gateway).
  `core/vpn_manager.py` detecta o binário sem `task_manager_v1` e devolve mensagem específica
  com a correção (rebuild `--enable-ikev1` + `IgnorePkg = strongswan`); `install.sh` e
  `update.sh` verificam IKEv1 e o pin do pacman em sistemas com pacman e alertam; o guia
  `docs/IPSEC.md` documenta a diferença entre distribuições. Validado em host Arch/CachyOS com
  `strongswan 6.1.0-2.1` rebuildado: `ipsec up vpnamssp` estabelece XAuth + CHILD_SA.

## [2.2.4] - 2026-10-13

### Adicionado
- **Wrapper privilegiado `vpn-ipsec-ctl`** (`/usr/lib/vpn-egsys/vpn-ipsec-ctl`) — único ponto
  de entrada root para up/down/status (stroke e swanctl), com validação estrita de nome de conn
  (`^vpn[a-z0-9_-]{2,40}$`) e timeouts por operação (up 40s, down 15s, status 10s). O sudoers
  passou a conter **apenas dois caminhos exatos** (apply + ctl), sem nenhum curinga.
- **`ipsec_cli()` no core** — todas as ações IPsec do `vpn`, da bandeja e do helper agora roteiam
  pelo ctl quando instalado, com fallback retrocompatível às chamadas brutas `ipsec`/`swanctl`.
- **`vpn-ipsec-apply` executa `ipsec rereadsecrets` + `ipsec reload`** após gravar os blocos —
  elimina o erro "no XAuth password found" causado pelo cache de segredos do charon.
- **Renderer stroke no modelo byte-a-byte do padrão do gateway** — cabeçalho
  `config setup` + `charondebug="ike 1, knl 1, cfg 1, esp 0"` e agrupamentos com linha em branco
  (authby / proposals / tempos / left / right / forceencaps).
- **Bloco DPD persistente em todos os conns IKEv1** — `ikelifetime=86400s`, `lifetime=43200s`,
  `dpdaction=restart`, `dpddelay=30s`, `dpdtimeout=120s`.
- **Endurecimento do `vpn-tray`** — um único thread poller de longa duração (5s) no lugar do
  `GLib.timeout_add` síncrono, elevação de `RLIMIT_NOFILE` para 8192 e conexão assíncrona no
  diálogo de gerenciamento.

### Corrigido
- **Congelamento do ícone no painel GNOME** — o poll síncrono de status bloqueava o laço Gtk e o
  `GetLayout` do dbusmenu ultrapassava o timeout do painel (medição real: 7,89s → 0,002s após a
  correção; ícone voltava a responder a cliques normalmente).
- **Exaustão de file descriptors/threads após cliques** (526 threads / 1076 fds) — pipes de
  subprocess fechados só por GC cíclico no Python 3.13 com poller recriado a cada ciclo; o poller
  único e o limite elevado eliminaram o churn (estado estável medido: 5 threads / 15 fds).
- **sudo-rs 0.2.8 não casa curingas de argumento — nunca** — teste de isolamento com regra única
  provou que o desenho "glob puro" da v2.2.3 falha em `sudo-rs` (mensagem "interactive
  authentication is required"), tornando o ctl + sudoers exato a única forma NOPASSWD viável no
  Ubuntu 25.10+. Documentação das versões anteriores corrigida para refletir o desenho vigente.

### Validado
- Quality Gate 41/41 (novo teste de fallback sem ctl; golden do renderer com config setup + DPD).
- Ciclo completo via clique D-Bus no `vpn-tray` em 2 hosts reais: Conectar → SA `INSTALLED`
  (ESP in UDP, XAuth aprovado), Desconectar → `0 up`, labels do menu alternando corretamente.

## [2.2.3] - 2026-10-13

> ⚠️ *Preterido pela v2.2.4:* o sudoers "glob puro" desta versão não funciona no `sudo-rs`
> 0.2.8 (ele não casa nenhum coringa de argumento); o desenho vigente é o wrapper `vpn-ipsec-ctl`
> com caminhos exatos.

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
