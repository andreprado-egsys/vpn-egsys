# Guia de Uso do vpn-egsys

## Visão Geral

O **vpn-egsys** oferece duas formas principais de interação:

| Método | Descrição | Vantagens |
|--------|-----------|-----------|
| **Terminal (Aliases)** | Comandos rápidos no shell | Rápido, scriptável, familiar |
| **Bandeja do Sistema** | Interface gráfica na bandeja | Visual, intuitivo, status em tempo real |

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

**Formato do alias:**
```bash
alias vpnro="sudo killall snx-rs 2>/dev/null; sleep 0.5; sudo rm -f /run/snx-rs.lock 2>/dev/null; nohup sudo snx-rs -m standalone -c ~/.config/snx-rs/vpnro.conf -l info > /tmp/snx-rs.log 2>&1 & sleep 3 && tail -n 5 /tmp/snx-rs.log"
```

**O que o alias faz:**
1. `sudo killall snx-rs` - Finaliza qualquer conexão VPN ativa
2. `sleep 0.5` - Aguarda meio segundo
3. `sudo rm -f /run/snx-rs.lock` - Remove o lock file
4. `nohup sudo snx-rs ...` - Inicia nova conexão em background
5. `sleep 3` - Aguarda 3 segundos
6. `tail -n 5 /tmp/snx-rs.log` - Exibe últimas 5 linhas do log

#### Aliases Globais

| Alias | Descrição | Comando |
|-------|-----------|---------|
| `vpnoff` | Desconecta a VPN ativa | `sudo killall snx-rs; sleep 1; sudo rm -f /run/snx-rs.lock; echo 'VPN desconectada'` |
| `vpnstatus` | Verifica status da conexão | `ip addr show snx-xfrm && tail -n 10 /tmp/snx-rs.log || echo 'VPN não conectada'` |

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
╔══════════════════════════╗
║ ✓ VPN AM - Amazonas (sslvpn.prodam.am.gov.br)  ║ ← Status atual
╠══════════════════════════╣
║ ------------------------------------------ ║
║ Conectar VPN AM - Amazonas (sslvpn.prod... ║
║ Conectar VPN PR - Paraná (acessoremoto.p... ║
║ Conectar VPN RO - Rondônia (131.72.155.42) ║
║ ------------------------------------------ ║
║ Desconectar                              ║
║ ------------------------------------------ ║
║ Sair                                    ║
╚══════════════════════════╝
```

### Ações do Menu

| Item | Ação | Descrição |
|------|------|-----------|
| **Status** | - | Mostra estado atual (desabilitado) |
| **Conectar {VPN}** | `on_connect()` | Conecta à VPN especificada |
| **Desconectar** | `on_disconnect()` | Desconecta a VPN ativa |
| **Sair** | `on_quit()` | Encerra o vpn-tray |

### Como Usar

#### Conectar a uma VPN

1. Clique no ícone da bandeja
2. Selecione "Conectar {Nome da VPN}"
3. Aguarde alguns segundos
4. O ícone mudará para conectado ✓
5. O tooltip mostrará "VPN: {Nome da VPN}"

#### Desconectar

1. Clique no ícone da bandeja
2. Selecione "Desconectar"
3. Aguarde ~1 segundo
4. O ícone mudará para desconectado ✗
5. O tooltip mostrará "VPN Desconectada"

#### Verificar Status

- Passe o mouse sobre o ícone para ver o tooltip
- O tooltip mostra o status atual

#### Fechar o Monitor

1. Clique no ícone da bandeja
2. Selecione "Sair"

> ⚠️ **Nota**: Fechar o vpn-tray não desconecta a VPN ativa. Use "Desconectar" ou `vpnoff` primeiro.

---

## Gerenciamento de VPNs

### Via Menu Interativo (`update.sh`)

Execute o gerenciador:
```bash
./update.sh
```

**Menu Principal:**
```
╔══════════════════════════════════════╗
║    vpn-egsys - Gerenciador de VPNs   ║
╚══════════════════════════════════════╝

  1) Listar VPNs configuradas
  2) Adicionar nova VPN
  3) Atualizar VPN existente
  4) Remover VPN
  5) Regenerar aliases
  6) Atualizar vpn-tray
  0) Sair

Opção: 
```

#### Opção 1: Listar VPNs

**Comando:**
```bash
./update.sh listar
# ou
./update.sh list
```

**Exemplo de saída:**
```
VPNs configuradas:

  vpnro → 131.72.155.42 (usuario_ro)
  vpnpr → acessoremoto.pr.gov.br (usuario_pr)
  vpnam → sslvpn.prodam.am.gov.br (usuario_am)

  Total: 3 VPN(s)
```

#### Opção 2: Adicionar Nova VPN

**Comando:**
```bash
./update.sh adicionar
# ou
./update.sh add
```

**Processo:**
```
Adicionar nova VPN

Nome curto (ex: vpnsp, vpnrj): vpnsp
Servidor (IP ou hostname): vpn.saude.sp.gov.br
Usuário: usuario_sp
Senha: 
```

> 💡 **Dicas:**
> - O nome deve ser único
> - Se não começou com "vpn", ele será prefixado automaticamente
> - A senha é ocultada durante a digitação

**Arquivo criado:** `~/.config/snx-rs/vpnsp.conf`

#### Opção 3: Atualizar VPN Existente

**Comando:**
```bash
./update.sh atualizar
# ou
./update.sh update
```

**Processo:**
```
Atualizar VPN existente

VPNs configuradas:

  vpnro → 131.72.155.42 (usuario_ro)
  vpnpr → acessoremoto.pr.gov.br (usuario_pr)
  vpnam → sslvpn.prodam.am.gov.br (usuario_am)

Nome da VPN para atualizar: vpnpr

  Servidor atual: acessoremoto.pr.gov.br
  Usuário atual:  usuario_pr

Novo servidor (Enter para manter): 
Novo usuário (Enter para manter): novo_usuario
Nova senha (Enter para manter): 
```

> 💡 **Dica**: Pressione Enter sem digitar nada para manter o valor atual.

#### Opção 4: Remover VPN

**Comando:**
```bash
./update.sh remover
# ou
./update.sh remove
```

**Processo:**
```
Remover VPN

VPNs configuradas:

  vpnro → 131.72.155.42 (usuario_ro)
  vpnpr → acessoremoto.pr.gov.br (usuario_pr)
  vpnam → sslvpn.prodam.am.gov.br (usuario_am)

Nome da VPN para remover: vpnpr
Confirma remoção de vpnpr? (s/N): s
```

> ⚠️ **Cuidado**: A remoção é permanente. O arquivo `.conf` é apagado.

**Arquivo removido:** `~/.config/snx-rs/vpnpr.conf`

#### Opção 5: Regenerar Aliases

**Comando:**
```bash
./update.sh aliases
```

**O que faz:**
1. Remove os aliases antigos do `.bashrc` e `.zshrc`
2. Gera novos aliases baseados nas VPNs atuais
3. Atualiza ambos os arquivos

**Útil quando:**
- Adicionou ou removeu VPNs
- Modificou configurações de VPN
- Os aliases pararam de funcionar

#### Opção 6: Atualizar vpn-tray

**Comando:**
```bash
./update.sh tray
```

**O que faz:**
1. Para o vpn-tray atual
2. Copia o novo binário de `vpn-tray` do repositório
3. Copia os ícones atualizados
4. Reinicia o vpn-tray

**Útil quando:**
- Fez modificações no código do vpn-tray
- Atualizou o repositório
- O vpn-tray parou de funcionar

---

## Casos de Uso Comuns

### Caso 1: Adicionar Nova VPN

**Objetivo:** Adicionar VPN para um novo servidor

**Passos:**
```bash
# 1. Adicionar via menu interativo
./update.sh
# Selecionar opção 2 (Adicionar nova VPN)

# Ou via comando direto
./update.sh adicionar

# 2. Preencher as informações
# Nome: vpnsp
# Servidor: vpn.example.com
# Usuário: meu_usuario
# Senha: minha_senha

# 3. Regenerar aliases (opcional, é feito automaticamente)
./update.sh aliases

# 4. Recarregar shell
source ~/.bashrc

# 5. Testar
vpnsp
```

### Caso 2: Atualizar Credenciais

**Objetivo:** Mudar a senha de uma VPN existente

**Passos:**
```bash
# 1. Atualizar via menu
./update.sh atualizar

# 2. Selecionar a VPN
# 3. Deixar servidor e usuário em branco (Enter)
# 4. Digitar nova senha

# 5. Testar conexão
vpnoff
sleep 2
vpnpr
```

### Caso 3: Remover VPN

**Objetivo:** Remover uma VPN que não é mais necessária

**Passos:**
```bash
# 1. Remover via menu
./update.sh remover

# 2. Selecionar a VPN a remover
# 3. Confirmar com 's'

# 4. Regenerar aliases
./update.sh aliases

# 5. Recarregar shell
source ~/.bashrc
```

### Caso 4: Solucionar Problemas de Conexão

**Problema:** VPN não conecta

**Passos para diagnóstico:**
```bash
# 1. Verificar logs
cat /tmp/snx-rs.log

# 2. Testar conexão manual
tail -f /tmp/snx-rs.log &
sudo snx-rs -m standalone -c ~/.config/snx-rs/vpnpr.conf -l debug

# 3. Verificar interface de rede
ip addr show snx-xfrm

# 4. Verificar processo
ps aux | grep snx-rs

# 5. Verificar conectividade
ping acessoremoto.pr.gov.br
```

**Soluções comuns:**
- Verificar credenciais no `.conf`
- Testar com outro servidor
- Reiniciar o snx-rs: `sudo killall snx-rs`

### Caso 5: Mudar para Outro Computador

**Objetivo:** Migrar configurações para novo computador

**Passos:**
```bash
# No computador antigo:
# 1. Copiar configurações de VPN
tar -czf vpn-configs.tar.gz ~/.config/snx-rs/

# No computador novo:
# 1. Instalar vpn-egsys
# 2. Restaurar configurações
tar -xzf vpn-configs.tar.gz -C ~/

# 3. Regenerar aliases
cd vpn-egsys
./update.sh aliases

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

Modifique o alias para não mostrar logs:
```bash
# No ~/.bashrc, substitua o alias por:
alias vpnpr="sudo killall snx-rs 2>/dev/null; sleep 0.5; sudo rm -f /run/snx-rs.lock 2>/dev/null; nohup sudo snx-rs -m standalone -c ~/.config/snx-rs/vpnpr.conf -l info > /dev/null 2>&1 &"
```

### Dica 6: Conexão com Log Debug

Para solucionar problemas, use log debug:
```bash
# Temporariamente
sudo snx-rs -m standalone -c ~/.config/snx-rs/vpnpr.conf -l debug

# Ou crie um alias de debug
alias vpnpr-debug="sudo killall snx-rs 2>/dev/null; sleep 0.5; sudo rm -f /run/snx-rs.lock 2>/dev/null; nohup sudo snx-rs -m standalone -c ~/.config/snx-rs/vpnpr.conf -l debug > /tmp/snx-rs-debug.log 2>&1 & sleep 3 && tail -n 20 /tmp/snx-rs-debug.log"
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
