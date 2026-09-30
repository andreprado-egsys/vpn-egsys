# AGENTS.md — vpn-egsys

`egSYS VPN Manager` — Suíte corporativa de automação, configuração, monitor de bandeja (`vpn-tray`),
CLI universal (`vpn`), suporte multi-protocolo (Check Point SNX e IPsec/IKEv2) e compatibilidade
cross-platform (**Linux** e **macOS**).

## Regra de produto (anti-desvio — INEGOCIÁVEL)
- **Multi-Protocolo**: Suporte transparente a Check Point (`snx-rs` / `snxctl`) e IPsec (`strongSwan` / `NetworkManager` no Linux; `scutil --nc` / `networksetup` nativo no macOS).
- **Cross-Platform**: Instalação e execução com 0 atrito em Linux (Debian, Ubuntu, Arch, CachyOS) e macOS (Intel e Apple Silicon M1/M2/M3/M4).
- **Zero credenciais em claro no repositório**: Arquivos de configuração `.conf` locais são gerados
  exclusivamente em runtime sob `~/.config/snx-rs/` com permissão estrita `0600` e gitignored.

## Comandos Operacionais
- Quality Gate: `./run_tests.sh` (Bash -n + py_compile + unittest)
- CLI Universal: `vpn list`, `vpn ro`, `vpn off`, `vpn status`, `vpn add`, `vpn remove`
- Instalação: `./install.sh` (auto-detecta Linux vs macOS)
- Atualização: `./update.sh`
- Monitor de bandeja: `./vpn-tray` (Gtk/AppIndicator no Linux; pystray/AppKit no macOS)
- Status do túnel ativo: `vpn status` ou `snxctl status`

## Git (dual-path, padrão Orion / Jiraview)
- `origin` = empresa (sanitizado): `git@github.com:egsys-dev/vpn-egsys.git`
- `privado` = desenvolvedor: `git@github.com:andreprado-egsys/vpn-egsys.git`
- Antes de qualquer commit: auditoria de secrets (regex no diff) + auditoria de sanitização
  nas branches do GitHub da empresa (ver skill `vpn-commit`).
- Conventional Commits obrigatório: `tipo(escopo): descrição sem acento`.
- **Nunca commitar**: `docs/SESSION_*`, `docs/history.md`, `*.conf`, `*.log`, `.env*`, `*.bak*`,
  metadados de agente (`.opencode/`, `.hermes/`, `.kiro/`, `.agent/`, `openspec/`, `graphify-out/`).

## Segurança e Hardening
- Senhas são codificadas em base64 apenas localmente nas configs sob `~/.config/snx-rs/` do usuário.
- Nenhuma chave privada, token ou senha deve estar hardcoded em scripts ou documentação.
- O `.gitignore` bloqueia compulsória e preventivamente qualquer arquivo `.conf` ou `.log`.

## Jira (padrão PSEI / Infraestrutura, sanitizado)
- Tasks sanitizadas (padrão vpn-jira-sync): sem menções a IA/LLM/prompts, sem credenciais,
  sem dados sensíveis de cliente/empresa, sem URLs de repositório privado, sem caminhos internos.
  Ver skill `vpn-jira-sync`.
