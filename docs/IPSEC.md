# Guia de Configuração e Uso do Protocolo IPsec (vpn-egsys)

O **vpn-egsys** suporta túneis baseados no protocolo **IPsec (IKEv2)**, permitindo conectar redes de órgãos públicos e clientes que utilizam appliances como pfSense, FortiGate, Cisco ASA, MikroTik ou servidores StrongSwan/Libreswan.

---

## 1. Visão Geral da Arquitetura IPsec

| Plataforma | Backend de Conexão | Gerenciamento de Credenciais |
|---|---|---|
| **Linux (Ubuntu/Debian, Arch/CachyOS)** | NetworkManager (`nmcli` + `strongswan`) ou daemon nativo `swanctl`/`ipsec` | Arquivo `.conf` local `0600` / NetworkManager Keyfile |
| **macOS (Monterey, Ventura, Sonoma, Sequoia)** | Framework nativo `scutil --nc` e `networksetup` | Keychain / Sistema nativo da Apple |

---

## 2. Formato do Arquivo de Configuração (`~/.config/snx-rs/vpnXX.conf`)

Para cadastrar manualmente uma VPN IPsec, crie um arquivo com permissão `0600`:

```ini
protocol=ipsec
server-name=vpn.cliente.gov.br
user-name=operador
password=SENHA_EM_BASE64
ipsec-type=ikev2
psk=PSK_OPCIONAL_EM_BASE64
routes=10.0.0.0/8,172.20.0.0/16
```

### Parâmetros Suportados

| Campo | Obrigatório | Descrição |
|---|---|---|
| `protocol` | Sim | Definir como `ipsec` |
| `server-name` | Sim | IP público ou FQDN do gateway IPsec |
| `user-name` | Sim | Usuário para autenticação EAP / Xauth |
| `password` | Sim | Senha codificada em Base64 |
| `ipsec-type` | Não | Tipo de conexão: `ikev2` (padrão) ou `xauth` |
| `psk` | Não | Chave pré-compartilhada (Pre-Shared Key) em Base64 |
| `routes` | Não | Lista de sub-redes a injetar na tabela de rotas |

---

## 3. Comandos de Uso

### Via CLI Universal `vpn`

```bash
# Adicionar nova conexão interativamente (selecionar opção 2 - IPsec)
vpn add

# Conectar à VPN IPsec (ex: vpnsc)
vpn sc

# Verificar status
vpn status

# Desconectar
vpn off
```

### Via VPN Tray
Abra o menu da bandeja (`vpn-tray`), clique em **Configurar VPNs**, escolha o protocolo **IPsec / IKEv2** e preencha os dados do servidor.
