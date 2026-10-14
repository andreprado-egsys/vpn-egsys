# Roadmap de Evolução — vpn-egsys

Este documento detalha o planejamento estratégico de evolução técnica e operacional do **vpn-egsys**, alinhado às demandas de conectividade e segurança perimetral da egSYS nos estados atendidos.

---

## 🧭 Visão Estratégica
Prover aos times de engenharia, DevOps e suporte N1/N2/N3 uma plataforma corporativa unificada, segura, leve e multiplataforma (Linux e macOS) para gerenciamento de túneis VPN governamentais, com zero atrito de configuração e telemetria transparente.

---

## 🗺️ Fases do Roadmap

### Fase 1: Fundação e Estabilização Linux (Concluída - v2.0.0)
- [x] Migração de arquitetura standalone para command mode com `snx-rs` v6.x.
- [x] Serviço de sistema via `systemd` (`snx-rs.service`) com auto-restart em caso de falha.
- [x] Conexão síncrona com verificação de rotas e injeção de DNS split.
- [x] Monitor de bandeja visual em GTK 3 (`vpn-tray`) com suporte a GNOME 46+, KDE e XFCE.
- [x] Suporte multi-usuário com script `user-setup.sh` para computadores compartilhados.
- [x] Descoberta dinâmica de túneis cadastrados no diretório `~/.config/snx-rs/`.

### Fase 2: Expansão Multi-Protocolo & Cross-Platform (Concluída - v2.1.0 / Jira PSEI-336)
- [x] Implementação de suporte nativo ao protocolo **IPsec (IKEv2)** com autenticação por credencial e PSK.
- [x] Suporte nativo ao sistema operacional **macOS** (Intel x86_64 e Apple Silicon M1/M2/M3/M4).
- [x] Desenho do módulo core unificado [`core/vpn_manager.py`](../core/vpn_manager.py) para abstração de SO e protocolo.
- [x] Utilitário de linha de comando universal [`vpn`](../vpn) com suporte a `list`, `connect`, `disconnect`, `status`, `add` e `remove`.
- [x] Suporte a barra de menus do macOS no `vpn-tray` via `pystray` e AppKit.
- [x] Autostart no macOS via LaunchAgent (`macos/com.egsys.vpn-tray.plist`).
- [x] Bateria de testes unitários automatizados com runner de Quality Gate (`run_tests.sh`).
- [x] Formalização das diretrizes operacionais de governança com [`AGENTS.md`](../AGENTS.md) e tríade de skills (`vpn-commit`, `vpn-docs-sync`, `vpn-jira-sync`).

### Fase 2.1: Pentest Black Box, Presets Estaduais & Hardening Multi-Usuário (Concluída - v2.1.1)
- [x] Bateria de Pentest Defensivo Black Box (ACH-VPN-001 a ACH-VPN-010) com 18/18 testes verdes no Quality Gate (total vigente após a Fase 2.2: 41 testes).
- [x] Diálogo gráfico com Presets Rápidos de Estados (SC, TO, RO, PR, AM) e alternância reativa de campos IPsec no `vpn-tray`.
- [x] Hardening Multi-Usuário com resolução de `$SUDO_USER`, permissão `0600`, e autostart sem root.
- [x] Documento de governança de segurança [`docs/SECURITY.md`](SECURITY.md).

### Fase 2.2: Backend IPsec nativo stroke IKEv1 XAuth+PSK & Helper Privilegiado (Concluída - v2.2.0/2.2.1)
- [x] IKEv1 XAuth+PSK (stroke) como padrão do projeto — suporte real a gateways FortiGate (VPN AM SSP), que rejeitam IKEv2 (`NO_PROPOSAL_CHOSEN`); plugin strongSwan do NetworkManager removido do caminho.
- [x] Helper root `vpn-ipsec-apply` (`/usr/lib/vpn-egsys/`) materializando blocos gerenciados em `/etc/ipsec.conf`, `/etc/ipsec.secrets` e `/etc/swanctl/conf.d/vpn-egsys.conf`, com sudoers NOPASSWD restrito a conns `vpn*` (validado com `visudo -c`).
- [x] Conexão sem NM: apply → `ipsec up`/`swanctl --initiate` → poll de SA `INSTALLED` (parse corrigido para o formato real com chaves `conn{n}:`).
- [x] **Verificação de rotas liberadas pelo gateway** (v2.2.1): `installed_remote_ts` + `missing_released_routes` com aviso explícito de traffic selector reduzido; validado ao vivo contra gateway simulado em netns.
- [x] **Bandeja Assíncrona Não-Bloqueante (v2.2.2)**: concorrência via `threading.Thread(daemon=True)` em `vpn-tray` eliminando congelamentos de UI durante timeouts de rede ou desafios XAuth, com feedback imediato `⌛ Conectando...` e notificações desktop nativas.
- [x] **Conformidade sudo-rs & verificação de desconexão (v2.2.3)**: `disconnect_ipsec_linux`
  re-checa a SA e reporta falha real, `aggressive`/`forceencaps` do perfil respeitados no render
  stroke, helper tolera binário `ipsec` ausente; validado ao vivo contra FortiGate AM SSP (2 hosts).
  *(O sudoers "glob puro" desta versão foi substituído na v2.2.4 — o `sudo-rs` 0.2.8 não casa
  nenhum coringa de argumento.)*
- [x] **Wrapper `vpn-ipsec-ctl`, bandeja à prova de congelamento e modelo byte-a-byte do gateway (v2.2.4)**: sudoers com dois caminhos exatos (zero curingas), `ipsec_cli()` no core com fallback, `rereadsecrets`/`reload` automáticos no apply, stroke com `config setup`/`charondebug` + DPD no padrão do time do gateway, poller único de threads no `vpn-tray` (GetLayout 7,9s → 0,002s) e `RLIMIT_NOFILE` 8192; ciclo Conectar/Desconectar validado por clique D-Bus em 2 hosts reais.
- [x] **Paridade IKEv1 entre distribuições (v2.2.5)**: `charon_ikev1_missing()` no core detecta libcharon sem `task_manager_v1` (strongSwan ≥ 6 do Arch/CachyOS) e o `vpn`/tray devolvem a causa real do `IKE version 1 not supported`; guard de pacman no `install.sh`/`update.sh` avisa quando falta o IKEv1 ou quando o `IgnorePkg = strongswan` não está pinado; guia `docs/IPSEC.md` documenta o rebuild `--enable-ikev1`. Validado em host Arch/CachyOS com `strongswan 6.1.0-2.1`.
- [x] `update.sh` (bloco 10b) provisiona helpers + sudoers + `strongswan-starter` — fluxo do analista `git clone`/`git pull && ./update.sh` com cobertura 100% em máquina já instalada.
- [x] Suíte expandida para 41 testes (renderizadores, escapes, statusall real, cobertura de rotas, idempotência de marcadores, fallback sem ctl).

### Fase 3: Segurança Avançada & Integração com Keyring (Planejada - Q4 2026)
- [ ] **Integração com Keyring do Sistema**:
  - Linux: Armazenamento de senhas no `SecretService` / `gnome-keyring` / `KWallet` via biblioteca `keyring` de Python, eliminando armazenamento em texto base64.
  - macOS: Integração nativa com o **Apple Keychain** (Cofre das Chaves) via comando `security` do macOS.
- [ ] **Autenticação Multi-Fator (MFA / 2FA)**:
  - Suporte a desafio OTP interativo no terminal (`vpn`) e na bandeja (`vpn-tray`) para gateways que exigem token temporário (TOTP/SMS).
- [ ] **Health-Check Proativo & Auto-Healing**:
  - Monitoramento contínuo da integridade do túnel com ping periódico para IPs internos da rede estadual.
  - Reconexão transparente em caso de perda transitória de pacotes.
- [ ] **Uninstall completo do backend IPsec**:
  - `uninstall.sh` deve embutir `vpn-ipsec-apply --uninstall`, remover `/etc/sudoers.d/vpn-egsys`,
    desabilitar `strongswan-starter` e limpar `/usr/lib/vpn-egsys` (hoje é procedimento manual).

### Fase 4: Integração de Observabilidade e SAPA 2.0 (Planejada - Q1 2027)
- [ ] **Plugin para o Orion Web**:
  - Exposição de status de túnel local via WebSocket para o painel egSYS Orion, permitindo ao analista saber se a VPN necessária para o estado está ativa no navegador.
- [ ] **Empacotamento de Distribuição**:
  - Criação de pacote `.deb` (Debian/Ubuntu) e pacote PKGBUILD no repositório Arch AUR para instalação com um comando via gerenciador de pacotes oficial.
  - Criação de Homebrew Formula (`brew install egsys/tap/vpn-egsys`) para usuários de macOS.
