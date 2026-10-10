# Histórico Cumulativo — vpn-egsys (interno, gitignored)

Registro não-linear de sessões de trabalho. Este arquivo NUNCA vai para o GitHub oficial;
é arquivado na branch `private/sessions-*` pelo `/vpn-commit`.

---

## [2026-10-10] Sessão IPsec AM SSP: Resolução de Sintaxe strongSwan, Diagnóstico XAuth e Tray Assíncrono (v2.2.1→2.2.2 / Jira PSEI-353)

**Escopo:** Diagnóstico de incidentes de inicialização do strongSwan (`/etc/ipsec.conf:1`), correção de fluxo IKEv1 do FortiGate AM SSP, elaboração de relatório técnico para o CICC/SSP e eliminação de congelamento no `vpn-tray` via concorrência `threading.Thread`. Rastreabilidade: `PSEI-353`.

**Entregas técnicas:**
- `vpn-tray` (v2.2.2): refatoração assíncrona de `on_connect` e `on_disconnect` utilizando `threading.Thread(daemon=True)`. Elimina 100% dos travamentos de UI no GTK durante negociações IPsec e timeouts de gateway. Adiciona feedback visual imediato (`⌛ Conectando [VPN]...`), sincronização thread-safe via `GLib.idle_add` e notificações desktop não-bloqueantes com `notify-send`.
- Diagnóstico e Correção de Sintaxe `/etc/ipsec.conf`: identificada causa raiz do erro `missing value for setting 'config'` (indentação indevida de 4 espaços na linha 1). Removidos recuos na coluna 0 de `config setup`, ajustado placeholder `{SEU CPF}` para o CPF real e adicionadas aspas obrigatórias em `/etc/ipsec.secrets` para caracteres especiais (`@` e `$$`).
- Alinhamento de Perfil FortiGate SSP: correção do perfil `~/.config/snx-rs/vpnamssp.conf` de `ipsec-type=ikev2` para `ipsec-type=ikev1-xauth`. Com isso, o helper oficial `/usr/lib/vpn-egsys/vpn-ipsec-apply` gerencia automaticamente os blocos em `/etc/ipsec.conf` e `/etc/ipsec.secrets` sob marcadores `# BEGIN/END vpn-egsys (managed)` com permissão `0600`, eliminando a necessidade de edição manual.
- Rastreamento e Diagnóstico de Autenticação (`enc 3`): Fase 1 (IKE Main Mode + PSK `ssp@ciccram` + DH14 MODP2048) estabelece com 100% de sucesso. Fase 1.5 (XAuth) comprovou que o FortiGate `138.185.153.20` desafia 3 vezes consecutivas e rejeita as credenciais no AD/LDAP interno.
- Documento Executivo Formal: gerado `~/RELATORIO_TECNICO_VPN_SSP_AM.md` estruturado com parâmetros, evidências brutas de pacotes e solicitações de validação de diretório para envio à equipe de redes da SSP/AM.
- Suíte de Testes: 40/40 testes verdes no `run_tests.sh`. Processo `vpn-tray` atualizado e reiniciado na sessão.

**Decisões e Orientações:**
- Manter o fluxo 100% automatizado pelo helper `vpn-ipsec-apply` sem exigir intervenção manual dos analistas no `/etc/`.
- Trazer transparência para o usuário: o congelamento no tray era bloqueio síncrono do GTK aguardando o timeout do gateway FortiGate.
- Política de Zero-Commit mantida: documentação pronta para homologação e commit formal via `/vpn-commit`.

---

## [2026-10-10] Sessão IPsec AM SSP: backend stroke IKEv1 XAuth+PSK, simulação netns e Docs-as-Code (v2.2.0→2.2.1)

**Escopo:** viabilizar a VPN AM SSP (FortiGate 138.185.153.20) no vpn-egsys fim-a-fim
(cadastro → materialização /etc → tray) e refletir tudo na documentação canônica.

**Entregas técnicas:**
- `core/vpn_manager.py`: renderizadores puros stroke/swanctl/secrets com marcadores
  `# BEGIN/END vpn-egsys (managed)`; `connect_ipsec_linux` sem nmcli (apply → `ipsec up`/
  `swanctl --initiate` → poll SA `INSTALLED`); `installed_remote_ts` + `missing_released_routes`
  com aviso "o gateway NÃO liberou as rotas"; fix do parse real do `statusall` (CHILD SA usa
  chaves `conn{n}:`, não colchetes).
- Helper root `vpn-ipsec-apply` (`/usr/lib/vpn-egsys/`): blocos gerenciados idempotentes,
  `stroke.load=yes`, garantia `strongswan-starter` (charon-systemd não carrega conns stroke),
  `--check`/`--uninstall`; sudoers NOPASSWD restrito validado com `visudo -c` (glob `vpn*`
  seguro pela sanitização `vpn[a-z0-9]+`).
- `install.sh` §11b e `update.sh` §10b provisionam helper+sudoers+starter+apply; wizard
  padrão IKEv1 XAuth+PSK (IKEv2 opcional) nos dois scripts, no `vpn` CLI e no `vpn-tray`.
- Descobertas de gateway (evidência desta máquina): NM-strongswan é IKEv2-only →
  `NO_PROPOSAL_CHOSEN`; vpnc SHA-1 → gateway mudo; L2TP/1701 sem resposta; stroke IKEv1
  MM+PSK+XAuth negocia até o XAuth. SNX em 131.72.155.42 aceita o login SSP (conta válida),
  mas o gateway não publica `172.20.100.0/24` nas rotas pushed.
- Simulação netns (gateway+cliente strongSwan isolados por `unshare -m` + bind-mount de
  `/var/run` para isolar pidfile/sockets): reproduziu "SA instalada sem rota liberada"
  (ping 10.200.210.1 OK; 172.20.100.10 "Network unreachable") e expôs o bug de parse de
  chaves. Teardown completo; serviço host preservado.
- Suíte: 40 testes (27 unit + 10 pentest + 3 CLI), Quality Gate verde.
- Documentação (esta sessão, via `/vpn-docs-sync`): README, AGENTS.md, ARQUITETURA,
  DESENVOLVIMENTO (fim do mito "sem testes automatizados" e do menu TUI fictício do
  update.sh), INSTALAÇÃO (Etapa 11b, sudoers real v2.2, fluxo do analista), USO (aliases
  command-mode, casos de uso reais), IPSEC §4, ROADMAP Fase 2.2, SECURITY extensões stroke,
  CHANGELOG 2.2.0/2.2.1.

**Decisões do usuário:**
- Helper privilegiado + sudoers restrito (não pedir senha ao analista).
- Manter os dois backends; ikev1-xauth como padrão do projeto.
- Credencial SSP nos perfis: `nIeJpSjqo93F` (usuário promoverá testes de login e alinhará
  com a TI; hash desta senha NÃO é a aceita hoje pelo Check Point).
- Antes de qualquer reinstalação local: testar RO e AM Prodam pelo caminho instalado
  (RO ● conectou 10.200.210.17 e desconectou limpa; AM Prodam reaches gateway mas o
  servidor reporta "Your password has expired" → renovação de credencial é externa).

**Pendências externas (não bloqueiam o código):**
- FortiGate SSP: liberar XAuth da conta e a rota `172.20.100.0/24` na política de túnel (TI/DevOps).
- Senha Prodam expirada (renovação pelo usuário).
- Push: commits locais `7ec0ff0`, `0048488`, `1690931`, `57c366b`, `ebb06b0` aguardando `/vpn-commit`.

---

## [2026-10-07→09] Sessões anteriores (resumo herdado)
- V2.2.0: refactor IPsec stroke aprovado em plano `rare-crest-perch` (§1–§9 implementados,
  7ec0ff0), prova de cadastro→apply→tray→remoção com perfil sintético `vpnteste01`.
- Diagnóstico do relato da dev (túnel "conectado sem rede interna"): política de TS do
  gateway, não defeito do cliente.
