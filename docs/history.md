# Histórico Cumulativo — egSYS VPN (`vpn-egsys`)

Registro não-linear de ciclos de engenharia, release e auditoria. Camada 3 da documentação
(estritamente gitignored na `main` de produto; arquivado no repositório privado via branch
`private/sessions-YYYY-MM-DD` executada pelo `/vpn-commit`).

---

## 2026-10-14 — Recuperação & Homologação vpn-tray CachyOS (KDE Wayland)

**Jira:** PSEI-355 · **Posto de Trabalho:** CachyOS (Arch-based, KDE Plasma 6 Wayland)
**Relatório:** `docs/SESSION_2026-10-14_CACHYOS_TRAY_RECOVERY.md`

- **Sintoma:** Congelamento e lentidão severa do `vpn-tray` na bandeja do sistema sob KDE Wayland.
- **Diagnóstico:** O processo em execução (`PID 2596`) ainda utilizava a versão pré-v2.2.4 de `~/.local/bin/vpn-tray`, com `Max open files = 1024` e polling síncrono via `GLib.timeout_add_seconds(3, ...)`. Sob Wayland, a exaustão de descritores de pipes travava o barramento D-Bus / StatusNotifierItem.
- **Correção:** Backup defensivo dos binários do usuário, sincronização da versão atualizada do `vpn-tray` e pacote `core/` para `~/.local/bin/` e inicialização supervisionada no systemd user slice (`systemd-run --user --unit=vpn-tray`). Limite `RLIMIT_NOFILE` elevado para 8192 e poller assíncrono persistente ativo. Zero alteração ou impacto nos perfis de VPN existentes sob `~/.config/snx-rs/`.
- **Quality Gate:** 41/41 PASS no `./run_tests.sh`.

---

## 2026-10-13 — v2.2.5 · Paridade IKEv1 entre distribuições

**Jira:** PSEI-338 · **Commit:** `bc447ac` (publicado em `origin` egsys-dev e `privado`)
**Relatório:** `docs/SESSION_2026-10-13_2111_IKEv1-Paridade-Release-v2.2.5.md`

- **Causa-raiz:** perfis `ikev1-xauth` falhavam em host Arch/CachyOS porque o strongSwan ≥ 6
  daqueles repositórios é compilado sem IKEv1 (`IKE version 1 not supported` no charon, antes de
  qualquer troca com o gateway). O produto reportava isso como "verifique credenciais no gateway".
- **Correção:** `charon_ikev1_missing()` no core (sonda do símbolo `task_manager_v1` dentro de
  `libcharon` — em 6.x não existe `.so` separado de ikev1), mensagem específica na falha, guarda
  não-fatal de `pacman` no `install.sh`/`update.sh` (IKEv1 ausente ou `IgnorePkg = strongswan` sem
  pin) e nota de compatibilidade em `docs/IPSEC.md`.
- **Ambiente:** rebuild local `strongswan 6.1.0-2.1` com `--enable-ikev1`, pinado no `pacman.conf`;
  `ipsec up vpnamssp` estabelece XAuth + CHILD_SA e o charon carrega o conn como IKEv1.
- **Release:** `origin/main` estava 2 commits à frente (v2.2.3 `994e921`, v2.2.4 `35b7763`) sobre os
  mesmos arquivos; integrado por fast-forward + reaplicação, único conflito em `CHANGELOG.md`.
  Quality Gate **41/41**; pré e pós-auditoria de sanitização em `origin/main` sem achados.
- **Docs (camada 1):** `AGENTS.md`, `ARQUITETURA`, `DESENVOLVIMENTO`, `INSTALAÇÃO`, `USO`, `SECURITY`,
  `IPSEC`, `ROADMAP`, `README`, `CHANGELOG` sincronizados. Ajuste de débito herdado: o sudoers
  manual em `docs/INSTALAÇÃO.md` ainda ensinava glob (`ipsec up *`), substituído pelos dois caminhos
  exatos do `vpn-ipsec-ctl` (padrão v2.2.4).

---

## Backfill (síntese dos ciclos anteriores, extraída do `git log` + `CHANGELOG.md`)

| Data | Versão | Ciclo | Commits |
|---|---|---|---|
| 2026-10-13 | v2.2.4 | Wrapper `vpn-ipsec-ctl` com sudoers de dois caminhos exatos (sudo-rs 0.2.8 não casa curinga), `rereadsecrets`/`reload` no apply, stroke byte-a-byte do padrão do gateway com DPD, `vpn-tray` com poller único e `RLIMIT_NOFILE` 8192 | `35b7763` (PSEI-355) |
| 2026-10-13 | v2.2.3 | sudoers em glob puro (preterido na 2.2.4), validação de SA no disconnect, `aggressive`/`forceencaps` respeitados no render, helper tolera `ipsec` ausente | `994e921` (PSEI-338) |
| 2026-10-10 | v2.2.2 | Execução assíncrona não-bloqueante no `vpn-tray` (threads daemon) e sincronização de docs | `166f1e8` (PSEI-353) |
| 2026-10-10 | v2.2.1 | Aviso quando o gateway instala a SA mas não libera as rotas; `update.sh` bloco 10b provisiona helper/sudoers/starter; label AM SSP | `0048488`, `57c366b`, `ebb06b0`, `1690931` |
| 2026-10-10 | v2.2.0 | Backend IPsec stroke IKEv1 XAuth+PSK com helper privilegiado `vpn-ipsec-apply` e sudoers restrito | `7ec0ff0` (PSEI-338) |
| 2026-09-30 | v2.1.1 | Presets estaduais, UI reativa multi-protocolo, hardening de `SUDO_USER` | `65e8951` (PSEI-337) |
| 2026-09-30 | v2.1.0 | Pentest defensivo ACH-VPN-001..010, sanitização estrita, docs | `e318d60` (PSEI-336) |
| 2026-09-30 | v2.0.x | Suporte IPsec + compatibilidade macOS; governança de agentes e travas sanitárias | `295dcaa`, `495afc8` |
| 2026-06-08 | — | Correção de keepalive que quebrava rotas internas da Prodam | `c0815a3` |

---
