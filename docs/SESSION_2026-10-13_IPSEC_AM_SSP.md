# Sessão 2026-10-13 — VPN AM SSP IPsec ao vivo, conformidade sudo-rs e release v2.2.3

**Projeto:** vpn-egsys · **Rastreabilidade:** PSEI-338 · **Release:** v2.2.3 (commit `994e921`, dual-path origin+privado)

## Contexto
`sudo ./update.sh` abortava na verificação de dependências: chave OpenPGP do repo HashiCorp
rotacionada (`NO_PUBKEY FC9CA96ACA026560`) e erro transitório de espelho Mozilla. Corrigido com
reinstalação do keyring e retry; update concluído em sequência.

## Trabalho executado
1. **Backend IPsec ativado no host de desenvolvimento**: instalação `strongswan`/`strongswan-starter`/
   `strongswan-pki` (dpkg conffile mantido com `--force-confold`, bloco gerenciado preservado).
2. **Teste real contra o FortiGate AM SSP (138.185.153.20, IKEv1 XAuth+PSK)** em dois hosts
   (máquina local e PC de suporte remoto, mesmo NAT de saída):
   - Túnel com credenciais do suporte estabelecido (`established successfully`, SA INSTALLED,
     ping na rede interna 0% de perda, ~85 ms).
   - Com a conta do analista local, o gateway responde MM1/MM2, aceita a proposta
     (AES256/SHA2_256/DH14) e **abandona a troca antes do XAuth** — conclusão: conta não
     habilitada no policy do gateway (log entregue ao solicitante; PSK/senhas nunca registrados
     neste arquivo).
   - Confirmado que Aggressive Mode **não** é o modo do gateway (fica silencioso); Main Mode correto.
3. **Bug de render**: `render_stroke_block` fixava `aggressive=no`/`forceencaps=yes` ignorando o
   perfil — passou a materializar os campos (`vpn*.conf` → `/etc/ipsec.conf`).
4. **Bug de desconexão silenciosa (bandeja)**: `sudo-rs` 0.2.8 (Ubuntu 25.10) casa curingas com
   prefixo em argumentos (`down vpn*`) de forma **intermitente** → `sudo -n ipsec down` pedia
   autenticação, falhava sem tty e a bandeja reportava sucesso com a SA ainda INSTALLED.
   Fixes: sudoers com glob puro `up *`/`down *` (install.sh/update.sh/docs), validação de SA
   pós-down com erro explícito, propagação do fracasso em `disconnect_all`.
5. **Helper tolerante**: `vpn-ipsec-apply` sem binário `ipsec` avisa e sai 0 (sem traceback de
   `FileNotFoundError`).
6. **PC remoto (suporte)**: encontrado com vpn-egsys v2.0 antigo; atualizado para v2.2.2/v2.2.3,
   `strongswan-starter`+`pki` instalados, perfil AM SSP criado, ciclo completo
   conectar/desconectar validado por `vpn vpnamssp`/`vpn off` e código da bandeja.
   Observação operacional: após gravar PSK novo, `ipsec rereadsecrets` pode ser necessário.
7. **Docs sincronizadas** (este ciclo): README, CHANGELOG (2.2.3), docs/SECURITY, docs/ROADMAP,
   docs/DESENVOLVIMENTO, docs/IPSEC, docs/INSTALAÇÃO, docs/ARQUITETURA.
8. **vpn-commit**: F0–F7 completos; auditoria pré/pós do GitHub oficial 100% sanitizada; push
   dual-path usando `id_ed25519` (o `~/.ssh/config` força a chave digilabtec em github.com).

## Quality gate
`./run_tests.sh` — 40/40 OK (3 execuções durante o ciclo).

---

# Ciclo 2 (tarde/noite de 2026-10-13) — v2.2.4: `vpn-ipsec-ctl`, bandeja estável e modelo byte-a-byte

## Contexto
O "glob puro" da v2.2.3 falhou em produção no Ubuntu 25.10: `sudo-rs` 0.2.8 **não casa nenhum
coringa de argumento** em NOPASSWD (teste de isolamento com regra única `ipsec down *` provou;
mensagem `sudo-rs: interactive authentication is required`). A bandeja ficou sem up/down sem senha.

## O que foi feito
1. **`vpn-ipsec-ctl` (novo)** — wrapper privilegiado com argv fixo: `stroke|swanctl` ×
   `up|down|status`, validação `^vpn[a-z0-9_-]{2,40}$`, timeouts por operação (40/15/10s).
   Sudoers reduzido a **dois caminhos exatos** (apply + ctl, zero curingas) em install.sh/update.sh.
2. **Core** — `ipsec_cli()` centraliza up/down/status via ctl, com fallback às chamadas brutas
   quando o ctl não está instalado; `run_sudo` reconhece os dois prompts do sudo-rs.
3. **`vpn-ipsec-apply`** — após gravar blocos, executa `ipsec rereadsecrets` + `ipsec reload`
   (fim do "no XAuth password found" por cache de secrets do charon).
4. **Renderer stroke no modelo byte-a-byte do gateway** (arquivos EXEMPLO recebidos do time):
   cabeçalho `config setup` + `charondebug="ike 1, knl 1, cfg 1, esp 0"`, grupos separados por
   linha em branco, e bloco DPD (`ikelifetime=86400s`/`lifetime=43200s`/`dpdaction=restart`/
   `dpddelay=30s`/`dpdtimeout=120s`) em todos os conns IKEv1.
5. **`vpn-tray` à prova de congelamento**:
   - Causa raiz do ícone morto no painel: poll **síncrono** no laço Gtk → `GetLayout` do dbusmenu
     medido em **7,89s** (timeout do painel ~2s). Fix: **um único thread poller** (5s) com
     `GLib.idle_add(_apply_status)`; GetLayout voltou a **0,002s**.
   - Exaustão de recursos pós-cliques (526 threads / 1076 fds): subprocess de status recriado a
     cada ciclo com pipes fechados só por GC cíclico (Python 3.13). Fix: poller único +
     `RLIMIT_NOFILE` elevado a 8192; estado estável medido **5 threads / 15 fds**.
   - Diálogo de gerenciamento: conexão agora assíncrona (fecha o diálogo, executa em thread).
6. **Deploy ao vivo nos 2 hosts** (`/usr/lib/vpn-egsys` + `~/.local/bin/core` de ambos — o core
   userland **desatualizado** era a causa do erro de sudo no tray dos dois PCs): apply refeito,
   `/etc/ipsec.conf` validado byte-a-byte contra o EXEMPLO, tray reiniciado.
7. **Validação via clique D-Bus real no `vpn-tray`** (compositor sem mouse): Event `clicked` em
   "Conectar VPN AMSSP" → 0,001s para responder, SA `INSTALLED` (ESP in UDP, XAuth aprovado);
   "Desconectar" → 0,026s, `0 up`; labels `✓ VPN AMSSP [IPSEC]` / `✗ Desconectado` alternando.

## Desfecho do caso AM SSP
- **Conta do analista LOCAL provisionada no FortiGate** (liberação do time do gateway): `sudo
  ipsec up vpnamssp` agora conclui `XAuth authentication of '941914...' successful`, CHILD_SA
  estabelecida (172.20.0.0/16→ rede interna) e VIP 10.10.254.2. A falha anterior era mesmo
  gateway-side (challenge não enviado / rejeição).
- Aviso lateral sem efeito no túnel: `adding DNS server failed` (resolvconf sem
  `dbus-org.freedesktop.network1.service`) — forteSwan segue; opção futura `handle-mode-dns`.

## Qualidade
- `./run_tests.sh` — **41/41 OK** (golden do renderer com config setup/DPD + novo teste de
  fallback sem ctl).
- Docs 1–8 sincronizadas neste ciclo (v2.2.4 no CHANGELOG/ROADMAP; seções de sudoers reescritas
  em SECURITY/IPSEC/INSTALAÇÃO/ARQUITETURA/DESENVOLVIMENTO; README com bullet v2.2.4).
- **Zero-commit por política** — publicação via `/vpn-commit`.
