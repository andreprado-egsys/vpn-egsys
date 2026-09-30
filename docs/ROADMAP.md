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

### Fase 3: Segurança Avançada & Integração com Keyring (Planejada - Q4 2026)
- [ ] **Integração com Keyring do Sistema**:
  - Linux: Armazenamento de senhas no `SecretService` / `gnome-keyring` / `KWallet` via biblioteca `keyring` de Python, eliminando armazenamento em texto base64.
  - macOS: Integração nativa com o **Apple Keychain** (Cofre das Chaves) via comando `security` do macOS.
- [ ] **Autenticação Multi-Fator (MFA / 2FA)**:
  - Suporte a desafio OTP interativo no terminal (`vpn`) e na bandeja (`vpn-tray`) para gateways que exigem token temporário (TOTP/SMS).
- [ ] **Health-Check Proativo & Auto-Healing**:
  - Monitoramento contínuo da integridade do túnel com ping periódico para IPs internos da rede estadual.
  - Reconexão transparente em caso de perda transitória de pacotes.

### Fase 4: Integração de Observabilidade e SAPA 2.0 (Planejada - Q1 2027)
- [ ] **Plugin para o Orion Web**:
  - Exposição de status de túnel local via WebSocket para o painel egSYS Orion, permitindo ao analista saber se a VPN necessária para o estado está ativa no navegador.
- [ ] **Empacotamento de Distribuição**:
  - Criação de pacote `.deb` (Debian/Ubuntu) e pacote PKGBUILD no repositório Arch AUR para instalação com um comando via gerenciador de pacotes oficial.
  - Criação de Homebrew Formula (`brew install egsys/tap/vpn-egsys`) para usuários de macOS.
