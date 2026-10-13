# Histórico cumulativo — vpn-egsys

> Camada 3 (gitignored na `main` de produto; arquivado no repositório privado via
> branch `private/sessions-*` pelo `/vpn-commit`). Entrada mais recente no topo.

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
