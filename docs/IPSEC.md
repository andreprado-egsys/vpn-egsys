# Guia de Configuração e Uso do Protocolo IPsec (vpn-egsys)

O **vpn-egsys** suporta túneis IPsec nos dois modos praticados pelos gateways
usados pela empresa:

- **IKEv1 Main Mode + PSK + XAuth genérico (padrão)** — exigido por gateways
  **FortiGate/FortiOS** (ex: VPN AM SSP). O plugin strongSwan do NetworkManager
  **não** expressa esse híbrido (EAP-usuário + PSK-gateway), por isso o backend
  é o strongSwan nativo via **stroke** (`/etc/ipsec.conf`).
- **IKEv2 (EAP + swanctl)** — para gateways que aceitam IKEv2, configurado pelo
  mesmo perfil com `ipsec-type=ikev2` (gerenciado em `/etc/swanctl/conf.d`).

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
