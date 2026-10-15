# Sessão 2026-10-13 21:11 (-0300) — Paridade IKEv1 Arch/CachyOS e Release v2.2.5

**Projeto:** egSYS VPN (`vpn-egsys`) · **Branch:** `main` · **Commit:** `bc447ac` · **Jira:** PSEI-338
**Ciclo:** diagnóstico → correção no produto → release/commit dual-path → sincronização documental

---

## 1. Contexto

O perfil IPsec `vpnamssp` (IKEv1 Main Mode + PSK + XAuth, Fortinet) conectava no PC Ubuntu de
trabalho e falhava no notebook CachyOS com `establishing connection 'vpnamssp' failed`. O log do
charon trazia a causa real: **`IKE version 1 not supported`** — o strongSwan ≥ 6 dos repositórios
Arch/CachyOS é compilado sem IKEv1, enquanto o `strongswan 6.0.1-6ubuntu1` do Ubuntu o habilita.
O produto não distinguia esse caso de credencial errada: a mensagem era sempre "verifique
credenciais no gateway".

## 2. O que foi feito

| # | Ação | Evidência |
|---|------|-----------|
| 1 | Rebuild do `strongswan` 6.1.0-2 com `--enable-ikev1`, empacotado como `6.1.0-2.1` e instalado | `pacman -Qi strongswan` → 6.1.0-2.1 (repo: 6.1.0-2) |
| 2 | Pin do pacote contra update do repositório | `/etc/pacman.conf` linha `IgnorePkg = ... strongswan` |
| 3 | `charon_ikev1_missing()` no core (procura `task_manager_v1` no `libcharon`) + mensagem específica na falha de conexão IKEv1 | função retorna `False` neste host; conn `vpnamssp` carregado como IKEv1 |
| 4 | Guarda de paridade em `install.sh`/`update.sh` (só em distro com `pacman`): warn se faltar IKEv1 ou o pin | blocos após a seção do `strongswan-starter` |
| 5 | Docs: `docs/IPSEC.md` (nota de paridade), `README.md`, `docs/ROADMAP.md`, `CHANGELOG.md` `[2.2.5]` | commit `bc447ac` |
| 6 | Release dual-path (`origin` egsys-dev + `privado`), com pré/pós-auditoria de sanitização | ambos `35b7763..bc447ac`; `origin/main` sem arquivo proibido |
| 7 | Sync documental completo (esta sessão): `AGENTS.md`, `docs/ARQUITETURA.md`, `docs/DESENVOLVIMENTO.md`, `docs/INSTALAÇÃO.md`, `docs/USO.md`, `docs/SECURITY.md` | inventário na §5 |

## 3. Estado do repositório antes do commit

`origin/main` tinha avançado **2 commits** (`994e921` v2.2.3, `35b7763` v2.2.4) tocando os mesmos
5 arquivos do trabalho local. Integração: backup do diff, stash com tag única, fast-forward do
`main`, reaplicação. Único conflito: `CHANGELOG.md` (mesmo ponto de inserção do `[Unreleased]`) —
resolvido promovendo a entrada a `[2.2.5] - 2026-10-13` acima da 2.2.4.

## 4. Evidências de validação

- Quality Gate: **41/41 OK** (`bash -n` + `py_compile` + unittest) após a integração.
- `ipsec statusall`: `vpnamssp: %any...<gateway> IKEv1`, local PSK + XAuth; SA e rotas establecidas
  no teste ao vivo (`ipsec up vpnamssp`).
- Varredura de segredos no diff: zero hits. Staging com 7 arquivos de produto, nenhum proibido.

## 5. Inventário documental desta sincronização

| Arquivo | Camada | Alteração |
|---|---|---|
| `AGENTS.md` | 1 | Regra de produto: IKEv1 exige charon com o plugin compilado; Arch/CachyOS não embarca |
| `docs/ARQUITETURA.md` | 1 | Linha "Guarda de paridade IKEv1" na tabela do backend; nota `charon_ikev1_missing()` no fluxo IPsec |
| `docs/DESENVOLVIMENTO.md` | 1 | Comentário da guarda no esqueleto de `provision_ipsec_backend()`; dívida de teste de `charon_ikev1_missing()` |
| `docs/INSTALAÇÃO.md` | 1 | Bloco de rebuild + pin em *Arch Linux e derivados*; novo problema na seção de solução de falhas; **sudoers manual corrigido de glob (v2.2.2) para os dois caminhos exatos (v2.2.4)** |
| `docs/USO.md` | 1 | Caso 4: checagem de IKEv1 no diagnóstico e solução específica para o abortamento |
| `docs/IPSEC.md` | 1 | Nota de paridade marcada como v2.2.5 e com remissão ao passo a passo |
| `docs/SECURITY.md` | 1 | Extensão v2.2.5: diagnóstico de build é leitura-only, sem nova superfície |
| `docs/history.md` | 3 | Entrada cumulativa do ciclo v2.2.5 |

## 6. Destilação de Aprendizados — 4 Quadrantes

### Quadrante 1 — Erros, falhas e omissões detectadas
- **Sintoma confundido com credencial.** A mensagem única "verifique credenciais no gateway"
  escondeu uma falha de *build* do charon por vários ciclos. Lição: falha antes da primeira
  troca com o gateway não pode ser reportada como rejeição de autenticação.
- **Teste de diagnóstico enganoso.** `ls /usr/lib/ipsec/plugins | grep ikev1` volta vazio **mesmo
  num build correto** em strongSwan ≥ 6, porque o código IKEv1 compila dentro de `libcharon`.
  O indicador correto é o símbolo `task_manager_v1`.
- **Débito documental herdado do v2.2.4.** `docs/INSTALAÇÃO.md` ainda ensinava o sudoers com
  globs (`ipsec up *`) que o `sudo-rs` 0.2.8 não casa — corrigido nesta passada.
- **Erro de digitação em doc publicada** (`surfia` → `surge`), pego na revisão pré-commit.

### Quadrante 2 — Lembretes e requisitos explícitos do usuário
- Commit dual-path obrigatório: `origin` (egsys-dev) sanitizado + `privado`, com auditoria pré e
  pós-push em todas as branches remotas.
- Conventional Commits sem acento, com ID do Jira (PSEI-338 para a trilha IPsec).
- Camada 3 (`docs/SESSION_*`, `docs/history.md`) permanece gitignored na `main` e só vai para
  branch `private/sessions-*` pelo `/vpn-commit`.
- **Segurança pessoal:** uma senha root apareceu em chat — precisa ser trocada.
- Nunca rodar comando que exija senha de sudo em modo autônomo; o usuário executa via `!`.

### Quadrante 3 — Correções cirúrgicas e refatorações aplicadas
- `charon_ikev1_missing()` isolado como função pura de detecção, chamada só no ramo de falha do
  IKEv1 (`not v2`), sem tocar no caminho feliz nem no IKEv2.
- Guard de `pacman` é **não-fatal** (`warn`) e condicionado a `command -v pacman`, para não
  interferir em Debian/Ubuntu/Fedora nem abortar a instalação.
- `CHANGELOG.md`: entrada `[Unreleased]` promovida a `[2.2.5] - 2026-10-13` para casar com o
  versionamento semântico já praticado (cada release tem verbete, README e ROADMAP).
- `sed` de pin documentado como `/^IgnorePkg/s/$/ strongswan/` (genérico) em vez de fixar o número
  da linha.

### Quadrante 4 — Inovações e evoluções futuras
- Cobertura automatizada de `charon_ikev1_missing()` via parâmetro de caminho do `.so` ou
  `mock_open` (hoje é verificação manual no host).
- Oferecer **fallback Libreswan** para IKEv1 em distro sem rebuild (chaotic-aur tem 5.4.1), ou
  migrar o perfil para IKEv2/swanctl quando o gateway suportar.
- Checagem proativa de paridade de backend no `vpn status` (reportar "IKEv1 indisponível neste
  host" antes do clique de conectar).
- Roadmap Fase 3: keyring (gnome-keyring/Apple Keychain) e MFA dinâmico continuam pendentes.

## 7. Pendências abertas

1. Trocar a senha root exposta em conversa.
2. `vpnam` (SNX Prodam) segue com credencial rejeitada pelo gateway — aguardando revalidação pela
   Prodam; alheio a este fix.
3. Sincronização desta documentação ainda **sem commit** (política zero-commit desta skill) →
   acionar `/vpn-commit`.
