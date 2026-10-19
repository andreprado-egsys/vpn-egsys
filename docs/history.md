# Histórico cumulativo — vpn-egsys

> Camada 3 (gitignored na `main` de produto; arquivado no repositório privado via
> branch `private/sessions-*` pelo `/vpn-commit`). Entrada mais recente no topo.

## 2026-10-19 — v2.2.7 · Fork storm da bandeja (regressão 2.2.6) e shebang pinado (PSEI-416)

- **Causa raiz do travamento da estação `prado` (Ubuntu 25.10/KDE X11):** `_async_connect`/
  `_async_disconnect` registravam `GLib.idle_add(self.check_status)` e `check_status()` retornava
  `True`. Em GLib, callback de *idle* retornando `True` **re-agenda o source para sempre** — cada
  passo do main loop criava thread → `get_active_vpn()` → `sudo /usr/lib/vpn-egsys/vpn-ipsec-ctl
  stroke status` (NOPASSWD, por isso sem senha). Prova viva: `idle_add(lambda: True)` executou
  201× em 2 s.
- **Métricas:** 19,7 M de chamadas `stroke status` em 3 dias (`/var/log/auth.log`), ~5.500/min,
  ~2.700 forks/s (`/proc/stat processes`), load 85–95 em 12 cores, 0% idle, swap 6 G. Pós-fix
  (60 s de janela): 12 chamadas/min, 14 forks/s, load 1,48, 12 Gi de mem disponível → **gate verde**.
- **Fix:** `check_status()` retorna `False` (execução única; `_status_loop` de 5 s continua dono
  da UI) + shebang `#!/usr/bin/python3` (o `env python3` resolvia linuxbrew sem PyGObject e quebrava
  `import gi` no autostart; macOS não é afetado — `plist` usa `$(which python3)`). Backups:
  `~/.local/bin/vpn-tray.bak-20261019-125220` e `vpn-tray.bak-20261019-130923`.
- **Regressão:** `tests/test_tray_idle.py` (AST) — todo `GLib.idle_add(self.X)` deve retornar
  `False` e o shebang deve pinar o python do sistema. Quality Gate **44/44** (28 unit + 10 pentest
  + 3 CLI + 3 bandeja).
- **Documentação (docs-sync):** README (item v2.2.7), CHANGELOG `[2.2.7]`, `docs/ARQUITETURA.md`
  (§Fluxo + invariantes GLib), `docs/DESENVOLVIMENTO.md` (exemplo `_status_loop`, imports, boas
  práticas, suíte 44, tabela `test_tray_idle`), `docs/ROADMAP.md` (44 testes + item Fase 2.2),
  `docs/USO.md` (nota do retorno `False`) e `docs/INSTALAÇÃO.md` (2 sintomas novos: fork storm
  e `ModuleNotFoundError: gi`).
- **Não era a causa:** relatórios de manutenção de 2026-10-16 (sysctl/udev/VAAPI/cache/Ferdium
  e flags do Chrome estavam corretos). Regressão data da edição de 16/10 18:16 (v2.2.6); gatilho
  explodiu no connect/disconnect de 08:45 (VPN RO).
- **Pendência verificada:** `install.sh`/`update.sh`/`user-setup.sh` copiam `vpn-tray` do projeto
  para `~/.local/bin` — sem o fix na fonte, o próximo `update.sh` reverteria a correção (fix já
  aplicado na fonte nesta sessão).

- **Ajuste de débito (2ª passada, 19/10 `d78faf0`):** fluxo do tray em `docs/ARQUITETURA.md` corrigido
  de 3s para 5s (poller `_status_loop`) e monitoramento descrito como thread + `idle_add(False)`;
  título "Novidades v2.2.0" do README alinhado para "Novidades v2.2 (2.2.0 → 2.2.7)".

## 2026-10-13 — v2.2.4 · Wrapper `vpn-ipsec-ctl`, bandeja à prova de congelamento, modelo byte-a-byte
- **sudo-rs 0.2.8 não casa coringa de argumento — nunca** (teste de isolamento com regra única
  `ipsec down *`); o "glob puro" da v2.2.3 foi provado inviável. Sudoers vigente: **dois caminhos
  exatos** (`vpn-ipsec-apply` + `vpn-ipsec-ctl`), zero curingas; up/down/status via wrapper com
  argv fixo e validação `^vpn[a-z0-9_-]{2,40}$` (core: `ipsec_cli()` com fallback bruto).
- `vpn-ipsec-apply` agora roda `rereadsecrets` + `reload` após gravar blocos (fim do cache de
  secrets do charon). Stroke renderizado **byte-a-byte no modelo do gateway**: `config setup` +
  `charondebug`, grupos por linha em branco e DPD (86400s/43200s/restart/30s/120s).
- **Causa raiz do tray travado no painel**: poll síncrono no laço Gtk → `GetLayout` 7,89s (timeout
  do painel ~2s). Fix: poller único de threads (5s) + `RLIMIT_NOFILE` 8192; medido 0,002s e
  estável em 5 threads/15 fds (antes de cliques: churn 526 threads/1076 fds com core desatualizado).
- Validação por **clique D-Bus real** nos 2 hosts: Conectar (0,001s) → SA `INSTALLED` ESP-in-UDP,
  label `✓ VPN AMSSP [IPSEC]`; Desconectar (0,026s) → `0 up`, label `✗ Desconectado`.
- **Caso AM SSP encerrado**: conta do analista local provisionada no FortiGate — XAuth aprovado,
  `connection 'vpnamssp' established successfully`, VIP 10.10.254.2. Aviso lateral inofensivo:
  DNS interno via resolvconf falha (`network1.service not found`) sem efeito no túnel.
- Quality gate 41/41 (golden com config setup/DPD + fallback sem ctl). Docs 1–8 sincronizadas.
  Commit pendente via `/vpn-commit`.
- Details: `docs/SESSION_2026-10-13_IPSEC_AM_SSP.md` (Ciclo 2).

## 2026-10-13 — v2.2.3 · VPN AM SSP ao vivo, conformidade sudo-rs, hardening do disconnect
- Release v2.2.3 (`994e921`): sudoers glob puro `ipsec up/down *`, `disconnect_ipsec_linux`
  valida SA pós-down, `render_stroke_block` respeita `aggressive`/`forceencaps`,
  `vpn-ipsec-apply` tolera binário `ipsec` ausente. Docs 1–8 sincronizadas.
- Teste real FortiGate AM SSP (138.185.153.20): túnel IKEv1 XAuth+PSK estabelecido em 2 hosts
  com credenciais de suporte (SA INSTALLED, ping rede interna 0%/85 ms); conta do analista
  local **não habilitada no gateway** (MM2 aceito, troca abortada antes do XAuth) — log
  formalizado para solicitação de liberação. Main Mode confirmado (Aggressive silencioso).
- PC de suporte remoto migrado de vpn-egsys v2.0 → v2.2.x com backend IPsec completo;
  ciclo conectar/desconectar validado via CLI e código da bandeja.
- Ocorrências de ambiente resolvidas: chave HashiCorp rotacionada (`NO_PUBKEY FC9CA96ACA026560`)
  no apt; dpkg conffile do strongswan-starter mantido com bloco gerenciado preservado;
  `ipsec rereadsecrets` necessário após gravar PSK (cache de secrets do charon).
- Details: `docs/SESSION_2026-10-13_IPSEC_AM_SSP.md`.

## 2026-10-10 — v2.2.2 · Bandeja assíncrona não-bloqueante (`166f1e8`, PSEI-353)
- `connect_vpn`/`disconnect_all` em threads daemon; status `⌛ Conectando...`; notify-send.

## 2026-10 — v2.2.1 · Confirmação de rotas liberadas (PSEI-338)
- `installed_remote_ts`/`missing_released_routes`; aviso quando o gateway reduz o TS.

## 2026-10 — v2.2.0 · Backend IPsec stroke IKEv1 XAuth+PSK (PSEI-338, `7ec0ff0`)
- Helper privilegiado `vpn-ipsec-apply`, sudoers restrito, `strongswan-starter`,
  IKEv2/swanctl opcional, poll de SA INSTALLED.

## 2026-09/10 — v2.1.x · Presets estaduais, UI multi-protocolo, hardening SUDO_USER, pentest ACH-VPN
- `65e8951` (PSEI-337), `e318d60` (PSEI-336) — ver CHANGELOG.md.
