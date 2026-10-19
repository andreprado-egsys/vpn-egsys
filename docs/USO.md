# Guia de Uso do vpn-egsys

## Visão Geral

O **vpn-egsys** oferece três formas integradas de interação em Linux e macOS:

| Método | Descrição | Vantagens |
|--------|-----------|-----------|
| **CLI Universal (`vpn`)** | Utilitário moderno multiplataforma | Rápido, auto-explicativo, suporta SNX e IPsec |
| **Terminal (Aliases)** | Atalhos diretos no shell (`vpnro`, `vpnsc`) | Familiaridade e agilidade em scripts |
| **Bandeja do Sistema (`vpn-tray`)**| Interface gráfica na barra de status | Visual, intuitivo, status em tempo real |

---

## Uso Via CLI Universal (`vpn`)

O comando `vpn` está disponível diretamente no terminal em Linux e macOS:

```bash
# 1. Listar todas as VPNs e seus protocolos
vpn list

# 2. Conectar rapidamente a um estado (Check Point ou IPsec)
vpn ro       # Conecta à VPN Rondônia
vpn sc       # Conecta à VPN Santa Catarina (IPsec)
vpn pr       # Conecta à VPN Paraná
vpn am       # Conecta à VPN Amazonas

# 3. Verificar status detalhado da conexão ativa
vpn status

# 4. Desconectar qualquer túnel ativo
vpn off

# 5. Adicionar nova VPN interativamente (SNX ou IPsec)
vpn add

# 6. Remover uma VPN cadastrada
vpn remove <id>
```

---

## Uso Via Terminal

### Aliases Disponíveis

Os aliases são gerados automaticamente para cada VPN configurada em `~/.config/snx-rs/`.

#### Aliases de VPN

Cada arquivo `vpn*.conf` gera um alias com o mesmo nome:

| Alias | VPN | Ação |
|-------|-----|------|
| `vpnro` | VPN Rondônia | Conecta à VPN do Rondônia |
| `vpnpr` | VPN Paraná | Conecta à VPN do Paraná |
| `vpnam` | VPN Amazonas | Conecta à VPN do Amazonas |
| `vpnsp` | VPN São Paulo | Conecta à VPN de São Paulo |
| `...` | ... | ... |

**Formato do alias (função, command mode vigente):**
```bash
vpnro() { snxctl disconnect 2>/dev/null; sleep 1; cp ~/.config/snx-rs/vpnro.conf ~/.config/snx-rs/snx-rs.conf; snxctl connect 2>&1; for i in $(seq 1 20); do snxctl status 2>/dev/null | grep -qiE 'conectado desde|connected since' && echo "✓ vpnro conectada" && return 0; sleep 1; done; echo "✗ Timeout"; }
```

**O que a função faz:**
1. `snxctl disconnect` — encerra sessão SNX ativa no daemon (command mode)
2. Copia o perfil `vpnro.conf` para o perfil ativo `snx-rs.conf`
3. `snxctl connect` — solicita conexão ao daemon `snx-rs.service`
4. Poll de até 20s em `snxctl status` até "conectado desde"

> Aliases cobrem o caminho **SNX**; para perfis IPsec use `vpn connect <id>` (ou a bandeja).

#### Aliases Globais

| Alias | Descrição | Comando |
|-------|-----------|---------|
| `vpnoff` | Desconecta a VPN ativa | `snxctl disconnect` |
| `vpnstatus` | Verifica status da conexão | `snxctl status` |

### Exemplos de Uso

#### Conectar a uma VPN

```bash
# Conectar à VPN do Paraná
vpnpr

# Aguardar some segundos para conexão ser estabelecida
# O alias exibe as últimas linhas do log automaticamente
```

#### Verificar Status

```bash
# Verificar se está conectado
vpnstatus
```

**Exemplo de saída:**
```
3: snx-xfrm: <BROADCAST,NOARP> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff
    inet 10.0.0.1/24 scope global snx-xfrm
       valid_lft forever preferred_lft forever
INFO 2024-01-15 10:30:00 Connected to VPN
```

Ou, se desconectado:
```
VPN não conectada
```

#### Desconectar

```bash
# Desconectar a VPN ativa
vpnoff
```

**Exemplo de saída:**
```
VPN desconectada
```

#### Conexão Sequencial

```bash
# Desconectar e conectar a outra VPN
vpnoff
sleep 2
vpnro
```

#### Script de Conexão

Crie um script para conectar automaticamente:

```bash
#!/bin/bash
# conectar-vpn.sh

VPN="$1"

echo "Conectando à $VPN..."
${VPN}

# Aguardar conexão
sleep 5

# Verificar
if ip addr show snx-xfrm &>/dev/null; then
    echo "✓ Conectado à $VPN"
else
    echo "✗ Falha ao conectar"
    exit 1
fi
```

**Uso:**
```bash
chmod +x conectar-vpn.sh
./conectar-vpn.sh vpnpr
```

---

## Uso Via Bandeja do Sistema

### Visão Geral da Interface

O **vpn-tray** exibe um ícone na bandeja do sistema com as seguintes características:

| Estado | Ícone | Título do Tooltip |
|--------|-------|-------------------|
| Desconectado | ![vpn-disconnected.svg](vpn-disconnected.svg) | "VPN Desconectada" |
| Conectado | ![vpn-connected.svg](vpn-connected.svg) | "VPN: {nome_vpn}" |

### Menu da Bandeja

Ao clicar no ícone, o seguinte menu é exibido:

```
╔═════════════════════════════════════════════════════╗
║ ✓ VPN RO - Rondônia (131.72.155.42) [SNX]          ║ ← Status atual
╠═════════════════════════════════════════════════════╣
║ --------------------------------------------------- ║
║ [SNX]   Conectar VPN RO - Rondônia (131.72.155.42)  ║
║ [SNX]   Conectar VPN PR - Paraná (acessoremoto...)  ║
║ [SNX]   Conectar VPN AM - Amazonas (sslvpn.prod...) ║
║ [IPsec] Conectar VPN SC - Santa Catarina            ║
║ [IPsec] Conectar VPN TO - Tocantins                 ║
║ --------------------------------------------------- ║
║ Desconectar                                         ║
║ --------------------------------------------------- ║
║ ➕ Adicionar VPN...                                  ║ ← Diálogo com Presets e Protocolos
║ ⚙ Gerenciar VPNs...                                 ║ ← Edição de credenciais e remoção
║ --------------------------------------------------- ║
║ Sair                                                ║
╚═════════════════════════════════════════════════════╝
```

### Ações do Menu

| Item | Ação | Descrição |
|------|------|-----------|
| **Status** | - | Mostra estado atual (`✓ Conectado`, `✗ Desconectado` ou `⌛ Conectando...`) |
| **Conectar {VPN}** | `on_connect()` | Dispara conexão assíncrona em thread (`threading.Thread`) sem congelar a UI |
| **Desconectar** | `on_disconnect()` | Desconecta a VPN ativa de forma assíncrona |
| **➕ Adicionar VPN...** | `show_vpn_dialog()` | Abre diálogo visual com presets de estados (SC, TO, RO, PR, AM) e seletor SNX/IPsec |
| **⚙ Gerenciar VPNs...** | `show_management_dialog()`| Lista túneis cadastrados com botões para Editar credenciais ou Remover |
| **Sair** | `on_quit()` | Encerra o vpn-tray |

### Como Usar

#### Conectar a uma VPN
1. Clique no ícone da bandeja.
2. Selecione a VPN desejada (ex: `[IPsec] Conectar VPN AMSSP` ou `[SNX] Conectar VPN RO`).
3. O status exibirá imediatamente `⌛ Conectando [VPN]...` sem travar a interface.
4. Ao concluir, o ícone atualiza via `GLib.idle_add` (callback `check_status()` retorna `False` desde a v2.2.7 — ver `docs/ARQUITETURA.md` §3) e o desktop emite notificação via `notify-send`.

#### Desconectar
1. Clique no ícone da bandeja.
2. Selecione "Desconectar".
3. O status exibirá `⌛ Desconectando...` e o túnel será encerrado em background.

#### Adicionar / Configurar via Interface Gráfica
1. Clique no ícone da bandeja e selecione **➕ Adicionar VPN...**
2. (Opcional) Escolha um **Preset de Estado** (`SC`, `TO`, `RO`, `PR` ou `AM`) para preencher automaticamente o protocolo e o gateway padrão.
3. Se selecionar **IPsec**, os campos de **Chave PSK** e **Rotas adicionais** tornam-se visíveis reativamente.
4. Preencha usuário e senha e clique em **Salvar VPN**. O novo túnel aparecerá imediatamente no menu e no terminal (`vpn list`).

> ⚠️ **Nota**: Fechar o vpn-tray não desconecta a VPN ativa. Use "Desconectar" ou `vpn off` primeiro.

---

## Gerenciamento de VPNs

### Via Atualização Completa (`update.sh`)

O `update.sh` **não é um menu TUI**: é um fluxo linear de atualização/migração que,
desde a v2.2.1, cobre userland **e** o lado privilegiado IPsec:

```bash
cd vpn-egsys
git pull
./update.sh
```

**O que ele faz (resumo das etapas):**
1. Atualiza snx-rs para v6.0.6 (se necessário) e aplica SUID nos binários
2. Instala dependências de GUI e `strongswan`
3. Wizard de credenciais por VPN (`setup_vpn_config`), com escolha de protocolo:
   `1) SNX` / `2) IPsec (IKEv1 XAuth+PSK — padrão / IKEv2 swanctl opcional)`, campos PSK e rotas
4. Reinstala `snx-rs.service`, dispatcher NM e dummy-ifaces SNX
5. Copia `vpn`, `vpn-tray` e `core/` para `~/.local/bin`
6. **Bloco 10b (privilegiado):** copia `core/` + `vpn-ipsec-apply` para `/usr/lib/vpn-egsys`,
   regrava `/etc/sudoers.d/vpn-egsys` (validado com `visudo -c`), habilita
   `strongswan-starter` e roda `vpn-ipsec-apply` (materializa os blocos em `/etc`)
7. Regenera aliases (bloco marcado `>>> vpn-egsys <<<`), garante PATH e reinicia o tray

> Para adicionar/remover VPNs individualmente use o CLI (`vpn add` / `vpn remove <id>`)
> ou o `vpn-tray` (menu *Configurar VPNs*) — não há subcomandos `./update.sh adicionar`.

## Casos de Uso Comuns

### Caso 1: Adicionar Nova VPN

**Objetivo:** Adicionar VPN para um novo servidor (SNX ou IPsec)

**Passos:**
```bash
# 1. Assistente do CLI (ou vpn-tray > Configurar VPNs)
vpn add
#    id: vpnsp | servidor | usuario | senha
#    se IPsec: 1) IKEv1 XAuth+PSK (padrao) ou 2) IKEv2; PSK e rotas

# 2. Materializar o backend IPsec (somente perfis ipsec)
sudo /usr/lib/vpn-egsys/vpn-ipsec-apply

# 3. Recarregar shell (aliases sao regenerados pelo update.sh)
source ~/.bashrc

# 4. Testar
vpn connect vpnsp && vpn status
```

### Caso 2: Atualizar Credenciais

**Objetivo:** Trocar senha de uma VPN existente (ex.: expirada no gateway)

**Passos:**
```bash
# Re- grave o perfil com o mesmo id (write_vpn_config substitui o .conf):
vpn add   # informe o mesmo id e a nova senha
# IPsec: reaplique os blocos do /etc
sudo /usr/lib/vpn-egsys/vpn-ipsec-apply
# SNX: basta reconectar (o connect copia o perfil para snx-rs.conf)
vpn off && vpn connect vpnpr
```

> Se o gateway responder "Your password has expired" (ex.: Prodam), cadastre a senha
> nova com o usuario no proximo login interativo — nenhum codigo resolve isso do lado cliente.

### Caso 3: Remover VPN

**Objetivo:** Remover uma VPN que não é mais necessária

**Passos:**
```bash
vpn remove vpnpr
# IPsec: o helper remove apenas os blocos gerenciados daquele perfil
sudo /usr/lib/vpn-egsys/vpn-ipsec-apply
source ~/.bashrc   # aliases regenerados no proximo ./update.sh
```

### Caso 4: Solucionar Problemas de Conexão

**Problema:** VPN não conecta

**Passos para diagnóstico:**
```bash
# SNX
snxctl status                       # estado do daemon command mode
journalctl -u snx-rs.service -n 30  # logs do daemon
ip addr show snx-xfrm               # IP interno atribuido?
ip route show table all | grep snx  # rotas pushed pelo gateway

# IPsec
sudo /usr/lib/vpn-egsys/vpn-ipsec-apply --check  # perfil dessincronizado? (exit 1)
ipsec statusall | grep -E 'vpn.*INSTALLED'       # SA instalada?
ipsec statusall | grep '==='                     # TS reais liberados pelo gateway

# IPsec em Arch/CachyOS: o charon pode ter sido compilado SEM IKEv1 (v2.2.5)
grep -qa task_manager_v1 /usr/lib/ipsec/libcharon.so.0.0.0 && echo "IKEv1 OK" || echo "SEM IKEv1"
```

**Soluções comuns:**
- Verificar credenciais no `.conf` (o connect SNX re-copia o perfil ativo)
- "Conectado mas sem rota interna": o gateway reduz o traffic selector — o proprio
  `vpn connect` agora avisa (docs/IPSEC.md §4); e politica do gateway, nao do cliente
- "Negociação abortada: o charon deste sistema foi compilado SEM IKEv1": não é credencial. O
  strongSwan ≥ 6 dos repositórios Arch/CachyOS vem sem IKEv1 e derruba o conn `ikev1-xauth` antes
  de falar com o gateway; reconstruir com `--enable-ikev1` e pinar `IgnorePkg = strongswan`
  (docs/INSTALAÇÃO.md — Arch Linux e derivados). Em Debian/Ubuntu o pacote oficial já traz IKEv1
- Reiniciar o daemon SNX: `sudo systemctl restart snx-rs.service`

### Caso 5: Mudar para Outro Computador

**Objetivo:** Migrar configurações para novo computador

**Passos:**
```bash
# No computador antigo (atencao: contem credenciais - transporte cifrado):
tar -czf vpn-configs.tar.gz ~/.config/snx-rs/

# No computador novo:
# 1. sudo ./install.sh   (instalacao completa, incluindo backend IPsec - Etapa 11b)
# 2. Restaurar configuracoes:
tar -xzf vpn-configs.tar.gz -C ~/
chmod 600 ~/.config/snx-rs/*.conf
# 3. Materializar IPsec:
sudo /usr/lib/vpn-egsys/vpn-ipsec-apply
# 4. Recarregar shell
source ~/.bashrc
```

---

## Dicas e Truques

### Dica 1: Conexão Rápida

Use o histórico do shell para reconectar:
```bash
# Conectar
vpnpr

# Desconectar
vpnoff

# Reconectar (seta para cima + Enter)
↑ + Enter
```

### Dica 2: Verificar IP VPN

```bash
# Verificar IP atribuído pela VPN
ip addr show snx-xfrm | grep inet

# Ou
ip -4 addr show snx-xfrm
```

### Dica 3: Testar Conexão

```bash
# Testar conectividade com servidor interno
ping 10.0.0.1

# Testar acesso a recurso interno
curl http://intranet.example.com
```

### Dica 4: Monitorar Logs

```bash
# Monitorar logs em tempo real
tail -f /tmp/snx-rs.log

# Filtrar por erro
tail -f /tmp/snx-rs.log | grep -i error

# Limpar logs
> /tmp/snx-rs.log
```

### Dica 5: Conectar sem Logs

Silencie a função de atalho (SNX):
```bash
# No ~/.bashrc, dentro do bloco >>> vpn-egsys <<<, troque `snxctl connect 2>&1` por:
snxctl connect > /dev/null 2>&1
```

### Dica 6: Conexão com Log Debug

Para solucionar problemas, observe o daemon em vez de lançar standalone:
```bash
# Logs do daemon command mode em tempo real
journalctl -u snx-rs.service -f

# IPsec: verbose controlado pelo helper/status
sudo /usr/lib/vpn-egsys/vpn-ipsec-apply --check && ipsec up vpnXX
ipsec statusall | grep -E 'vpn.*INSTALLED|==='
```

### Dica 7: Criar Atalho para VPN Favorita

Crie um alias pessoal no seu `.bashrc`:
```bash
alias minhavpn=vpnpr
```

### Dica 8: Script de Reconexão Automática

```bash
#!/bin/bash
# reconectar-vpn.sh

MAX_TRIES=3
DELAY=5

for i in $(seq 1 $MAX_TRIES); do
    echo "Tentativa $i de $MAX_TRIES..."
    vpnoff 2>/dev/null
    sleep 2
    vpnpr
    
    if ip addr show snx-xfrm &>/dev/null; then
        echo "✓ Conectado com sucesso!"
        exit 0
    fi
    
    sleep $DELAY
done

echo "✗ Falha após $MAX_TRIES tentativas"
exit 1
```

---

## Variáveis de Ambiente

### Variáveis Usadas pelo vpn-egsys

| Variável | Valor Padrão | Descrição |
|----------|--------------|-----------|
| `HOME` | `/home/usuario` | Localização dos arquivos de configuração |
| `PATH` | - | Deve incluir `~/.local/bin` |
| `DISPLAY` | `:0` | Display X11 para GTK |
| `XDG_RUNTIME_DIR` | `/run/user/{uid}` | Runtime directory |

### Personalizar Localizações

Você pode personalizar os caminhos editando os scripts:

**Em `install.sh` e `update.sh`:**
```bash
CONFIG_DIR="$HOME/.config/snx-rs"
LOCAL_BIN="$HOME/.local/bin"
ICON_DIR="$HOME/.local/share/icons/vpn-egsys"
APPS_DIR="$HOME/.local/share/applications"
AUTOSTART_DIR="$HOME/.config/autostart"
SUDOERS_FILE="/etc/sudoers.d/vpn-egsys"
```

---

## Solução de Problemas

### Problema: Comando não encontrado

**Sintoma:** `bash: vpnpr: command not found`

**Soluções:**
1. Recarregar o shell: `source ~/.bashrc`
2. Verificar se aliases existem: `alias | grep vpn`
3. Verificar se o bloco existe no `.bashrc`: `grep "vpn-egsys" ~/.bashrc`
4. Regenerar aliases: `./update.sh aliases`

### Problema: Ícone não aparece na bandeja

**Sintomas:**
- vpn-tray está rodando mas ícone não aparece
- `ps aux | grep vpn-tray` mostra processo

**Soluções:**
1. Verificar erros: `~/.local/bin/vpn-tray 2>&1`
2. Reiniciar: `./update.sh tray`
3. Para Wayland: usar X11 ou instalar extensões AppIndicator
4. Verificar dependências: `python3 -c "import gi; gi.require_version('Gtk', '3.0'); gi.require_version('AyatanaAppIndicator3', '0.1')"`

### Problema: VPN conecta mas não tem internet

**Sintomas:**
- `vpnstatus` mostra conectado
- Não é possível acessar recursos internos

**Soluções:**
1. Verificar interface: `ip addr show snx-xfrm`
2. Verificar rota: `ip route show`
3. Verificar DNS: `cat /etc/resolv.conf`
4. Testar com IP direto: `ping 8.8.8.8`
5. Verificar logs: `tail -n 20 /tmp/snx-rs.log`

### Problema: Senha errada

**Sintoma:** Erro de autenticação nos logs

**Solução:**
1. Atualizar credenciais: `./update.sh atualizar`
2. Verificar se senha está correta no `.conf`
3. Regenerar senha base64: `echo -n "minha_senha" | base64`

### Problema: Arquivo de configuração corrompido

**Sintoma:** Erros ao conectar

**Solução:**
1. Verificar sintaxe: `cat ~/.config/snx-rs/vpnpr.conf`
2. Comparar com formato correto:
   ```ini
   server-name=servidor
   user-name=usuario
   password=base64_password
   ignore-server-cert=true
   login-type=vpn
   ```
3. Recriar arquivo manualmente ou via `./update.sh atualizar`

---

## Resumo de Comandos

| Ação | Comando | Método |
|------|---------|--------|
| Conectar | `vpnpr`, `vpnro`, etc. | Terminal |
| Desconectar | `vpnoff` | Terminal |
| Verificar status | `vpnstatus` | Terminal |
| Conectar | Clicar ícone → Conectar {VPN} | Bandeja |
| Desconectar | Clicar ícone → Desconectar | Bandeja |
| Listar VPNs | `./update.sh listar` | Gerenciador |
| Adicionar VPN | `./update.sh adicionar` | Gerenciador |
| Atualizar VPN | `./update.sh atualizar` | Gerenciador |
| Remover VPN | `./update.sh remover` | Gerenciador |
| Regenerar aliases | `./update.sh aliases` | Gerenciador |
| Atualizar tray | `./update.sh tray` | Gerenciador |
| Instalar | `./install.sh` | Instalador |
| Desinstalar | `./uninstall.sh` | Desinstalador |
