# Guia de Configuração e Uso do Protocolo IPsec (vpn-egsys)

O **vpn-egsys** suporta túneis IPsec nos dois modos praticados pelos gateways
usados pela empresa:

- **IKEv1 Main Mode + PSK + XAuth genérico (padrão)** — exigido por gateways
  **FortiGate/FortiOS** (ex: VPN AM SSP). O plugin strongSwan do NetworkManager
  **não** expressa esse híbrido (EAP-usuário + PSK-gateway), por isso o backend
  é o strongSwan nativo via **stroke** (`/etc/ipsec.conf`).
- **IKEv2 (EAP + swanctl)** — para gateways que aceitam IKEv2, configurado pelo
  mesmo perfil com `ipsec-type=ikev2` (gerenciado em `/etc/swanctl/conf.d`).

> **Paridade IKEv1 entre distribuições**: perfis `ikev1-xauth` exigem charon com
> IKEv1 compilado. Em **Ubuntu/derivados** o pacote oficial (`strongswan`) já traz
> IKEv1. Em **Arch/CachyOS**, strongSwan ≥ 6 é empacotado **sem** IKEv1 e o túnel
> aborta com `IKE version 1 not supported` (sem chegar ao gateway). Correção:
> rebuild do PKGBUILD oficial com `--enable-ikev1` (o código v1 entra em
> `libcharon`, não existe `.so` separado) e pin `IgnorePkg = strongswan` no
> `/etc/pacman.conf` para não perder o plugin em updates. `install.sh`/`update.sh`
> detectam e avisam; o erro surge no `vpn`/tray com mensagem específica.

---

## 1. Fluxo de configuração

```
perfil do usuário (~/.config/snx-rs/vpnXX.conf, 0600)
        │  sudo vpn-ipsec-apply (helper NOPASSWD restrito)
        ▼
bloco gerenciado "BEGIN/END vpn-egsys" em /etc/ipsec.conf + /etc/ipsec.secrets
(arquivo completo /etc/swanctl/conf.d/vpn-egsys.conf para perfis ikev2)
        ▼
vpn sc            → sudo ipsec up vpnXX   (IKEv1 XAuth/stroke)
                  → sudo swanctl --initiate --ike vpnXX (IKEv2)
```

O helper só reescreve o bloco entre os marcadores `# BEGIN vpn-egsys (managed)` /
`# END vpn-egsys (managed)` — conexões de terceiros em `/etc/ipsec.conf` nunca
são tocadas. Ele também garante `stroke.load=yes` em
`/etc/strongswan.d/charon/stroke.conf` e o daemon correto
(**strongswan-starter**; o `charon-systemd` não carrega conns stroke e o
`ipsec up` falha silenciosamente com rc 7).

### Por que não NetworkManager?

Medição direta contra o FortiGate da VPN AM SSP (138.185.153.20):

| Caminho NM | Resultado |
|---|---|
| `nmcli` + plugin strongSwan (IKEv2) | gateway responde `NO_PROPOSAL_CHOSEN` a todo IKEv2 |
| Plugin com PSK-only / EAP | plugin IKEv2-only; não existe método "EAP + PSK no gateway" em IKEv1 |
| `nm-l2tp` (L2TP over IPsec) | UDP 1701 sem resposta do gateway |
| vpnc (Cisco, IKEv1 SHA-1) | gateway fica mudo a MM1 SHA-1 (exige SHA-256) |

Conclusão: apenas **stroke IKEv1 com `aes256-sha256-modp2048` + `leftauth2=xauth`**
negocia MM e chega ao desafio XAuth. O aceite final da credencial XAuth depende
do diretório do gateway (FortiGate/AD).

---

## 2. Formato do Arquivo de Configuração (`~/.config/snx-rs/vpnXX.conf`)

```ini
protocol=ipsec
server-name=138.185.153.20
user-name=operador
password=SENHA_EM_BASE64
ipsec-type=ikev1-xauth
psk=PSK_EM_BASE64
routes=172.20.100.0/24
ike=aes256-sha256-modp2048,aes128-sha256-modp1536!   # opcional
esp=aes256-sha256-modp1536,aes128-sha256-modp1536!   # opcional
```

| Campo | Obrigatório | Descrição |
|---|---|---|
| `protocol` | Sim | Definir como `ipsec` |
| `server-name` | Sim | IP/FQDN do gateway |
| `user-name` | Sim | Identidade XAuth (IKEv1) ou EAP identity (IKEv2) |
| `password` | Sim | Senha em Base64 (decodificada só dentro de `/etc`, 0600) |
| `ipsec-type` | Não | `ikev1-xauth` (**padrão**) ou `ikev2`; aliases `ikev1`/`xauth` são normalizados |
| `psk` | Não | PSK do gateway em Base64 (obrigatória na prática p/ FortiGate) |
| `routes` | Não | `rightsubnet`/`remote_ts` (padrão `0.0.0.0/0`) |
| `ike` / `esp` | Não | Proposals stroke/swanctl; vazio usa os defaults acima |
| `aggressive` | Não | `no` (**padrão**, Main Mode) ou `yes` (Aggressive Mode) — materializado desde a v2.2.3 |
| `forceencaps` | Não | `yes` (**padrão**) ou `no` — materializado desde a v2.2.3 |
---

## 3. Comandos de Uso

```bash
vpn add            # assistente: 1) IKEv1 XAuth+PSK (padrão) / 2) IKEv2
vpn amssp          # conecta (aplica blocos + ipsec up / swanctl)
vpn status         # lê ipsec statusall (SA INSTALLED) / swanctl --list-sas
vpn off            # desconecta
```

A conexão só é reportada como conectada quando a SA aparece **INSTALLED** —
`ipsec up` retornar 0 apenas significa que a iniciação foi aceita.

### Via VPN Tray

Menu **Configurar VPNs** → protocolo **IPsec** → escolher **Versão IKE**
(IKEv1 XAuth + PSK é o padrão; IKEv2/swanctl opcional). Remover uma VPN
regenera os blocos gerenciados automaticamente pelo helper.

### Via helper manualmente

```bash
sudo /usr/lib/vpn-egsys/vpn-ipsec-apply --check    # exit 1 se desincronizado
sudo /usr/lib/vpn-egsys/vpn-ipsec-apply            # aplica blocos + reload
sudo /usr/lib/vpn-egsys/vpn-ipsec-apply --uninstall # remove só os blocos gerenciados
```

> ℹ️ Desde a v2.2.3 o helper **tolera strongSwan ausente**: sem o binário `ipsec` ele grava os
> perfis, emite aviso e sai 0 (sem traceback). Desde a v2.2.4 ele também executa
> **`ipsec rereadsecrets` + `ipsec reload`** após gravar os blocos — o cache de segredos do charon
> é invalidado na hora, eliminando o erro "no XAuth password found" no primeiro `up` após
> gravar/rotacionar um PSK ou senha XAuth.

### Conformidade sudo-rs e wrapper `vpn-ipsec-ctl` (v2.2.4)

Teste de isolamento no `sudo-rs` 0.2.8 (Ubuntu 25.10+) provou que ele **não casa nenhum coringa em
argumentos** em regras NOPASSWD — nem `down vpn*`, nem o "glob puro" `down *` da v2.2.3 (`sudo-rs:
interactive authentication is required`). Desde a v2.2.4 o up/down/status passa pelo wrapper
privilegiado `/usr/lib/vpn-egsys/vpn-ipsec-ctl`, e o sudoers contém **apenas dois caminhos exatos**:

```
USER ALL=(root) NOPASSWD: /usr/lib/vpn-egsys/vpn-ipsec-apply, /usr/lib/vpn-egsys/vpn-ipsec-ctl
```

O ctl recebe `stroke|swanctl` + `up|down|status [CONEXAO]`, valida o nome contra
`^vpn[a-z0-9_-]{2,40}$` e traduz para o argv exato do strongSwan (timeouts: up 40s, down 15s,
status 10s). A restrição efetiva é tripla: sanitização do nome no `write_vpn_config`, materialização
apenas por root em `/etc/ipsec.conf` e validação dentro do próprio ctl. O core (`ipsec_cli()`) cai
para as chamadas brutas `ipsec`/`swanctl` apenas em máquinas sem o ctl instalado (sudo interativo).
O `disconnect_ipsec_linux` continua **re-checando a SA** após o down e reportando falha explícita
("SA continua ativa") em vez de sucesso falso.

### Bloco gerado em `/etc/ipsec.conf` (modelo vigente desde v2.2.4)

O `render_stroke_block` materializa exatamente o padrão do modelo fornecido pelo time do gateway
(cabeçalho `config setup`, agrupamentos separados por linha em branco e DPD persistente):

```
# BEGIN vpn-egsys (managed)
config setup
    charondebug="ike 1, knl 1, cfg 1, esp 0"

conn vpnamssp
    auto=add
    keyexchange=ikev1
    aggressive=no
    authby=psk

    ike=aes256-sha256-modp2048,aes128-sha256-modp1536!
    esp=aes256-sha256-modp1536,aes128-sha256-modp1536!

    ikelifetime=86400s
    lifetime=43200s
    dpdaction=restart
    dpddelay=30s
    dpdtimeout=120s

    left=%defaultroute
    leftauth=psk
    leftauth2=xauth
    leftid=%any
    xauth_identity=<CPF>
    leftsourceip=%config

    right=<IP do gateway>
    rightauth=psk
    rightid=%any
    rightsubnet=<routes do perfil>

    forceencaps=yes

# END vpn-egsys (managed)
```

As aspas em `/etc/ipsec.secrets` (`: PSK "..."` / `CPF : XAUTH "..."`) são opcionais na sintaxe
stroke — o gerado com aspas é byte-equivalente em parse ao modelo sem aspas e protege valores com
caracteres especiais.

## 4. Confirmação de rotas liberadas pelo gateway

SA `INSTALLED` não garante que o gateway liberou as redes pedidas: gateways
podem **reduzir o traffic selector** do túnel (ex.: liberar só
`10.200.210.0/24` quando o perfil declara `routes=172.20.100.0/24` — caso
real relatado por dev em 09/10/2026, com o túnel "conectado" e os hosts
internos mudos). Após estabelecer a SA, o core compara as TS remotas
instaladas (`ipsec statusall`, linhas `conn{n}: … === rede` /
`swanctl --list-sas`) com o campo `routes` do perfil e reporta:

> `Túnel IPsec <label> conectado (… ), mas o gateway NÃO liberou as rotas
> <redes> — política de túnel do gateway (as redes não são alcançáveis).`

A correção é sempre no gateway (address book / split tunnel do grupo de
usuários), não no cliente. Diagnóstico manual: `ip route get <IP-interno>`
(deve apontar para o túnel, não para o default) e
`ipsec statusall | grep '==='`.
