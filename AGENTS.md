# AGENTS.md — vpn-egsys

`egSYS VPN Manager` — Suíte corporativa de automação, configuração, monitor de bandeja (vpn-tray),
integração snxctl e gerenciamento de VPNs Check Point (snx-rs) para os estados atendidos pela egSYS
(RO, PR, AM, SC, TO e demais).

## Regra de produto (anti-desvio — INEGOCIÁVEL)
- **snx-rs em command mode** como padrão corporativo gerenciado por systemd (`snx-rs.service`).
- Zero credenciais em claro no repositório. Arquivos de configuração `.conf` locais são gerados
  exclusivamente em runtime sob `~/.config/snx-rs/` com permissão restrita e gitignored.
- Multi-distro transparente (Ubuntu/Debian e Arch/CachyOS).

## Comandos Operacionais
- Instalação completa (host novo): `./install.sh`
- Atualização e migração de VPNs: `./update.sh`
- Setup por usuário (sem sudo): `./user-setup.sh`
- Desinstalação: `./uninstall.sh`
- Monitor de bandeja (Python 3 / PyGObject): `./vpn-tray`
- Serviço snx-rs: `systemctl status snx-rs.service`
- Controle CLI direto: `snxctl status`, `snxctl connect <vpn>`, `snxctl disconnect`

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
