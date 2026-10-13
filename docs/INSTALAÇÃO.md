# Instalação do vpn-egsys

## Pré-requisitos

Antes de iniciar a instalação, certifique-se de que seu sistema atende aos seguintes requisitos:

### Requisitos do Sistema

| Requisito | Versão Mínima | Plataforma |
|-----------|---------------|------------|
| **Sistema Operacional** | Linux (Debian, Ubuntu, Arch, CachyOS) ou macOS 12+ | Linux / macOS |
| **Arquitetura** | x86_64 ou Apple Silicon (arm64 - M1/M2/M3/M4) | Todas |
| **Git** | 2.0+ | `git --version` |
| **Python** | 3.8+ | `python3 --version` |

---

## Métodos de Instalação

### Instalação no Linux (Ubuntu, Debian, Arch, CachyOS)

```bash
# 1. Clonar o repositório oficial da empresa
git clone git@github.com:egsys-dev/vpn-egsys.git

# 2. Entrar no diretório
cd vpn-egsys

# 3. Executar o instalador universal
chmod +x install.sh
./install.sh
```

### Instalação no macOS (Monterey, Ventura, Sonoma, Sequoia)

O instalador detecta automaticamente o macOS e configura os LaunchAgents e binários:

```zsh
# 1. Clonar o repositório oficial
git clone git@github.com:egsys-dev/vpn-egsys.git
cd vpn-egsys

# 2. Executar o instalador
chmod +x install.sh
./install.sh
```

Para mais detalhes da instalação no ecossistema Apple, consulte [`docs/MACOS.md`](MACOS.md).

### Método 2: Instalação com Git (Alternativo)

Se preferir não clonar todo o repositório:

```bash
# Baixar apenas o instalador do repositório oficial
curl -fSL -o install.sh https://raw.githubusercontent.com/egsys-dev/vpn-egsys/main/install.sh

# Tornar executável
chmod +x install.sh

# Executar
./install.sh
```

> 💡 **Nota de Segurança**: Se o script for executado com `sudo ./install.sh`, o instalador detecta automaticamente a variável `$SUDO_USER` e o home do usuário não-root original, garantindo que as configurações de VPN (`~/.config/snx-rs`), atalhos e o autostart do `vpn-tray` sejam instalados para o seu usuário e executados sob sua sessão gráfica (e não sob o usuário `root`).

### Fluxo do Analista (padrão egSYS)

| Cenário | Comando | Escopo |
|---------|---------|--------|
| **Máquina nova** | `git clone … && sudo ./install.sh` | Instalação completa: deps, snx-rs, systemd,NM, tray, wizard, helper `/usr/lib/vpn-egsys/vpn-ipsec-apply`, sudoers NOPASSWD restrito, `strongswan-starter` (Etapa 11b) |
| **Máquina já instalada (manutenção)** | `git pull && ./update.sh` | Desde a v2.2.1 cobre **100%** do cliente: userland (`vpn`, `vpn-tray`, `core/`) **e** o lado privilegiado IPsec (bloco 10b: helper + sudoers + starter + apply) |

Não é preciso desinstalar/reinstalar para atualizar: o `update.sh` é idempotente e regrava os
blocos gerenciados em `/etc` apenas quando há diff (`vpn-ipsec-apply --check` reporta).

---

## Processo de Instalação Detalhado

O instalador executará as seguintes etapas automaticamente:

### Etapa 1: Detecção do Sistema

O script detecta automaticamente:
- Distribuição Linux via `/etc/os-release`
- Família da distro (Debian, Arch, Fedora)
- Gerenciador de pacotes apropriado (apt, pacman, dnf)

**Arquivos consultados:**
- `/etc/os-release` - Identificação da distro
- `/etc/lsb-release` - Informações adicionais (Debian/Ubuntu)

**Variáveis definidas:**
- `ID` - Identificador da distro (ex: ubuntu, arch, fedora)
- `ID_LIKE` - Distros similares (ex: debian, rhel)
- `PRETTY_NAME` - Nome amigável da distro
- `PKG_MANAGER` - Gerenciador de pacotes (apt, pacman, dnf)

### Etapa 2: Instalação de Dependências

Dependências instaladas por família de distro:

#### Debian/Ubuntu e derivados

```bash
# Pacotes instalados
sudo apt update -qq
sudo apt install -y \
    python3-gi \
    gir1.2-gtk-3.0 \
    gir1.2-ayatanaappindicator3-0.1 \
    strongswan \
    libwebkit2gtk-4.1-0  # ou libwebkit2gtk-4.0-37
```

**Distribuições testadas:**
- Ubuntu 20.04 LTS e superiores
- Debian 10 (Buster) e superiores
- Linux Mint 20 e superiores
- Zorin OS
- Pop!_OS
- Elementary OS

#### Arch Linux e derivados

```bash
# Pacotes instalados
sudo pacman -S --needed --noconfirm \
    python-gobject \
    gtk3 \
    libayatana-appindicator \
    strongswan \
    webkit2gtk
```

**Distribuições testadas:**
- Arch Linux
- Manjaro
- EndeavourOS
- CachyOS
- Garuda

#### Fedora/RHEL e derivados

```bash
# Pacotes instalados
sudo dnf install -y \
    python3-gobject \
    gtk3 \
    libayatana-appindicator-gtk3 \
    strongswan \
    webkit2gtk4.1
```

**Distribuições testadas:**
- Fedora 35 e superiores
- CentOS Stream
- Rocky Linux
- AlmaLinux

### Etapa 3: Instalação do snx-rs

O `snx-rs` é um cliente VPN Check Point de código aberto. O instalador baixará e instalará automaticamente a versão 6.0.6 (pin; command mode requer >= 5.0).

**Versão instalada:** 6.0.6

**Processo por distro:**

#### Debian/Ubuntu (DEB package)

```bash
# Download do pacote DEB
curl -fSL -o /tmp/snx-rs.deb \
    "https://github.com/ancwrd1/snx-rs/releases/download/v6.0.6/snx-rs_6.0.6_amd64.deb"

# Instalação
sudo apt install -y /tmp/snx-rs.deb

# Limpeza
rm -f /tmp/snx-rs.deb
```

#### Arch/Fedora (Binary tarball)

```bash
# Download do tarball
curl -fSL -o /tmp/snx-rs.tar.gz \
    "https://github.com/ancwrd1/snx-rs/releases/download/v6.0.6/snx-rs-v6.0.6-x86_64-unknown-linux-gnu.tar.gz"

# Extrair
tar -xf /tmp/snx-rs.tar.gz -C /tmp/snx-rs-extract

# Instalar binários
sudo install -m 755 /tmp/snx-rs-extract/snx-rs /usr/bin/
sudo install -m 755 /tmp/snx-rs-extract/snxctl /usr/bin/

# Limpeza
rm -rf /tmp/snx-rs-extract /tmp/snx-rs.tar.gz
```

**Verificar instalação:**
```bash
snx-rs --version
# Deve mostrar: snx-rs 6.0.6 (command mode requer >= 5.0)
```

### Etapa 4: Configuração do Sudoers

Cria o arquivo `/etc/sudoers.d/vpn-egsys` com permissões NOPASSWD para os comandos necessários.

**Conteúdo (v2.2.x — somente backend IPsec; o SNX não precisa de sudo: daemon systemd + SUID):**
```
USER ALL=(root) NOPASSWD: /usr/lib/vpn-egsys/vpn-ipsec-apply,
    /usr/bin/ipsec up *, /usr/bin/ipsec down *,
    /usr/bin/ipsec statusall, /usr/bin/ipsec reload,
    /usr/bin/swanctl --initiate *, /usr/bin/swanctl --terminate *,
    /usr/bin/swanctl --list-sas
```

O glob puro `*` nos argumentos é intencional: o `sudo-rs` (Ubuntu 25.10+) casa de forma
intermitente curingas com prefixo (ex.: `vpn*`) em argumentos, quebrando a bandeja em
silêncio. A restrição real permanece: os nomes de conexão só existem porque
`write_vpn_config` os sanitiza para `vpn[a-z0-9]+` e apenas root os materializa em
`/etc/ipsec.conf` — um `up/down` de conn inexistente não tem efeito.

**Processo:**
1. Detecta caminho real de `ipsec`/`swanctl` (`command -v`)
2. Cria regras com NOPASSWD
3. Valida sintaxe com `sudo visudo -cf` **antes** de instalar
4. Aplica permissões 0440 (root:root)
5. Se validação falhar, NÃO instala (fallback: senha sudo interativa)

**Localização:** `/etc/sudoers.d/vpn-egsys`
**Permissões:** `0440` (somente leitura para root e grupo root)

### Etapa 5: Configuração de VPNs Padrão

O instalador solicitará credenciais para as seguintes VPNs padrão:

| Alias | Descrição | Servidor |
|-------|-----------|----------|
| `vpnro` | VPN Rondônia | 131.72.155.42 |
| `vpnpr` | VPN Paraná | acessoremoto.pr.gov.br |
| `vpnam` | VPN Amazonas | sslvpn.prodam.am.gov.br |

**Para cada VPN** o assistente pergunta, nesta ordem:
1. **Protocolo**: `1) Check Point SSL (SNX)` [padrão] / `2) IPsec (IKEv1 XAuth+PSK — padrão; IKEv2/swanctl opcional)`
2. Dentro de IPsec: **Tipo de IKEv** `1=IKEv1 XAuth+PSK (padrão) / 2=IKEv2 swanctl`, PSK (opcional) e rotas a injetar (opcional)
3. Usuário e senha (input oculto)
4. Cria `~/.config/snx-rs/{alias}.conf` (0600)

**Formato do arquivo .conf (SNX):**
```ini
server-name={servidor}
user-name={usuario}
password={senha_base64}
ignore-server-cert=true
login-type=vpn
```

**Formato (IPsec — IKEv1 XAuth+PSK, validado contra FortiGate AM SSP):**
```ini
protocol=ipsec
ipsec-type=ikev1-xauth
server-name={gateway}
user-name={usuario}
password={senha_base64}
psk={psk_base64}
routes={rede_interna/24,...}
```

> ✅ **Opcional**: você pode pular qualquer VPN pressionando Enter sem digitar nada. VPNs podem
> ser adicionadas depois via `vpn add`, pelo `vpn-tray` (Configurar VPNs) ou por `./update.sh`.

> ℹ️ Ao final, a **Etapa 11b** materializa os perfis IPsec: helper `vpn-ipsec-apply` grava os
> blocos gerenciados em `/etc/ipsec.conf`/`/etc/ipsec.secrets` (IKEv1) ou
> `/etc/swanctl/conf.d/vpn-egsys.conf` (IKEv2), habilita `strongswan-starter` e faz `ipsec reload`.

### Etapa 6: Geração de Aliases

Cria atalhos no shell para conexão rápida às VPNs.

**Arquivos modificados:**
- `~/.bashrc`
- `~/.zshrc` (se existir)

**Aliases gerados (modelo vigente — command mode via `snxctl`):**
```bash
# >>> vpn-egsys >>>
vpnro() { snxctl disconnect 2>/dev/null; sleep 1; cp ~/.config/snx-rs/vpnro.conf ~/.config/snx-rs/snx-rs.conf; snxctl connect 2>&1; for i in $(seq 1 20); do snxctl status 2>/dev/null | grep -qiE 'conectado desde|connected since' && echo "✓ vpnro conectada" && return 0; sleep 1; done; echo "✗ Timeout"; }
vpnpr() { ... }   # idem, por perfil
vpnam() { ... }   # idem, por perfil
vpnoff() { snxctl disconnect 2>/dev/null; echo "VPN desconectada"; }
vpnstatus() { snxctl status; }
# <<< vpn-egsys <<<
```

Para IPsec use o CLI universal (`vpn connect <id>` / `vpn status` / `vpn off`) — os aliases acima
são específicos do caminho SNX.

**Marcadores:**
- Início: `# >>> vpn-egsys >>>`
- Fim: `# <<< vpn-egsys <<<`

Estes marcadores permitem que o script `update.sh` remova e regenere os aliases quando VPNs são adicionadas ou removidas.

### Etapa 7: Instalação do vpn-tray

Instala o monitor de bandeja do sistema.

**Arquivos copiados:**

| Origem | Destino | Permissões |
|--------|---------|-------------|
| `vpn-tray` | `~/.local/bin/vpn-tray` | +x (executável) |
| `icons/*.svg` | `~/.local/share/icons/vpn-egsys/` | - |

**Desktop Entry criado:**

**Arquivo:** `~/.local/share/applications/vpn-egsys.desktop`
```ini
[Desktop Entry]
Name=VPN Monitor
Comment=Monitor de VPN Check Point
Exec=/home/user/.local/bin/vpn-tray
Icon=/home/user/.local/share/icons/vpn-egsys/vpn-disconnected.svg
Terminal=false
Type=Application
Categories=Network;
```

**Autostart criado:**

**Arquivo:** `~/.config/autostart/vpn-tray.desktop`
```ini
[Desktop Entry]
Name=VPN Tray
Exec=/home/user/.local/bin/vpn-tray
Icon=/home/user/.local/share/icons/vpn-egsys/vpn-disconnected.svg
Terminal=false
Type=Application
```

**Atualização do database de aplicativos:**
```bash
update-desktop-database ~/.local/share/applications/ 2>/dev/null || true
```

### Etapa 8: Inicialização do vpn-tray

O instalador inicia automaticamente o vpn-tray:

```bash
nohup ~/.local/bin/vpn-tray > /dev/null 2>&1 &
```

**Verificar se está rodando:**
```bash
ps aux | grep vpn-tray
```

---

## Pós-Instalação

### Verificar Instalação

**1. Verificar snx-rs:**
```bash
which snx-rs
snx-rs --version
```

**2. Verificar vpn-tray:**
```bash
which vpn-tray
ls -la ~/.local/bin/vpn-tray
```

**3. Verificar configurações:**
```bash
ls -la ~/.config/snx-rs/
cat ~/.config/snx-rs/vpnro.conf
```

**4. Verificar aliases:**
```bash
# Recarregar shell
source ~/.bashrc

# Testar alias
alias vpnro
```

**5. Verificar sudoers:**
```bash
sudo cat /etc/sudoers.d/vpn-egsys
```

**6. Verificar ícone na bandeja:**
- Olhe para a bandeja do sistema (geralmente no canto superior direito)
- Deve aparecer um ícone de VPN desconectada

### Ativar Autostart

O vpn-tray já está configurado para iniciar automaticamente com o sistema. Para verificar:

```bash
ls ~/.config/autostart/vpn-tray.desktop
```

Para desabilitar o autostart:
```bash
rm ~/.config/autostart/vpn-tray.desktop
```

### Testar Conexão

**Via terminal:**
```bash
# Conectar
vpnro

# Aguardar 3 segundos (sleep no alias)
# Verificar status
vpnstatus

# Desconectar
vpnoff
```

**Via bandeja:**
1. Clique no ícone da bandeja
2. Selecione "Conectar VPN RO - Rondônia"
3. O ícone deve mudar para conectado
4. Para desconectar, selecione "Desconectar"

---

## Solução de Problemas

### Problema: "Command not found" para snx-rs

**Causa:** O snx-rs não foi instalado corretamente.

**Solução:**
```bash
# Verificar se o binário existe
ls /usr/bin/snx-rs

# Se não existir, instalar manualmente
./install.sh
```

### Problema: Erro de dependências GTK

**Erros comuns:**
- `ModuleNotFoundError: No module named 'gi'`
- `ImportError: cannot import name AyatanaAppIndicator3`

**Solução:**
```bash
# Debian/Ubuntu
sudo apt install python3-gi gir1.2-gtk-3.0 gir1.2-ayatanaappindicator3-0.1 libwebkit2gtk-4.0-37

# Arch
sudo pacman -S python-gobject gtk3 libayatana-appindicator webkit2gtk

# Fedora
sudo dnf install python3-gobject gtk3 libayatana-appindicator-gtk3 webkit2gtk4.1
```

### Problema: vpn-tray não aparece na bandeja

**Causas possíveis:**
1. O AppIndicator não tem suporte no seu ambiente desktop
2. O vpn-tray não está rodando
3. Problema com permissões

**Solução:**

**1. Verificar se está rodando:**
```bash
ps aux | grep vpn-tray
```

**2. Iniciar manualmente:**
```bash
~/.local/bin/vpn-tray
```

**3. Verificar erros:**
```bash
~/.local/bin/vpn-tray 2>&1
```

**4. Para Wayland:**
O Ayatana AppIndicator pode não funcionar corretamente no Wayland. Tente:
- Usar X11 (logar com Xorg)
- Instalar `gnome-shell-extension-appindicator`

### Problema: Permissão negada ao executar snx-rs

**Causa:** O sudoers não foi configurado corretamente.

**Solução:**

**1. Verificar sudoers:**
```bash
sudo cat /etc/sudoers.d/vpn-egsys
```

**2. Validar sintaxe:**
```bash
sudo visudo -cf /etc/sudoers.d/vpn-egsys
```

**3. Corrigir permissões:**
```bash
sudo chmod 0440 /etc/sudoers.d/vpn-egsys
sudo chown root:root /etc/sudoers.d/vpn-egsys
```

**4. Reexecutar install.sh:**
```bash
./install.sh
```

### Problema: Aliases não funcionam

**Causa:** O shell não foi recarregado.

**Solução:**
```bash
# Recarregar o shell
source ~/.bashrc

# Ou abrir um novo terminal
```

**Verificar se aliases existem:**
```bash
alias | grep vpn
```

### Problema: VPN conecta mas desconecta rapidamente

**Causas possíveis:**
1. Credenciais incorretas
2. Servidor inacessível
3. Problema de rede

**Solução:**

**1. Verificar logs:**
```bash
tail -n 20 /tmp/snx-rs.log
```

**2. Testar conexão manual (command mode via daemon):**
```bash
cp ~/.config/snx-rs/vpnro.conf ~/.config/snx-rs/snx-rs.conf
snxctl connect && snxctl status
journalctl -u snx-rs.service -n 30   # logs do daemon command mode
```

**3. Verificar interface de rede:**
```bash
ip addr show snx-xfrm
```

### Problema: "sudoers file must be mode 0440"

**Solução:**
```bash
sudo chmod 0440 /etc/sudoers.d/vpn-egsys
```

---

## Instalação Manual

Se preferir instalar manualmente, siga estes passos:

### 1. Instalar Dependências

Escolha conforme sua distro:

**Debian/Ubuntu:**
```bash
sudo apt update
sudo apt install -y git curl python3-gi gir1.2-gtk-3.0 gir1.2-ayatanaappindicator3-0.1 libwebkit2gtk-4.0-37
```

**Arch:**
```bash
sudo pacman -S git curl python-gobject gtk3 libayatana-appindicator webkit2gtk
```

**Fedora:**
```bash
sudo dnf install -y git curl python3-gobject gtk3 libayatana-appindicator-gtk3 webkit2gtk4.1
```

### 2. Instalar snx-rs

**Debian/Ubuntu:**
```bash
wget https://github.com/ancwrd1/snx-rs/releases/download/v6.0.6/snx-rs_6.0.6_amd64.deb
sudo apt install -y ./snx-rs_6.0.6_amd64.deb
rm snx-rs_6.0.6_amd64.deb
```

**Arch/Fedora:**
```bash
wget https://github.com/ancwrd1/snx-rs/releases/download/v6.0.6/snx-rs-v6.0.6-x86_64-unknown-linux-gnu.tar.gz
tar -xf snx-rs-v6.0.6-x86_64-unknown-linux-gnu.tar.gz
sudo install -m 755 snx-rs /usr/bin/
sudo install -m 755 snxctl /usr/bin/  # se existir
rm -rf snx-rs-v6.0.6-x86_64-unknown-linux-gnu* snx-rs
```

### 3. Configurar Sudoers (backend IPsec — o mesmo formato do install.sh)

```bash
# Criar arquivo (substitua $USER pelo usuário analista)
cat <<EOF | sudo tee /etc/sudoers.d/vpn-egsys > /dev/null
$USER ALL=(root) NOPASSWD: /usr/lib/vpn-egsys/vpn-ipsec-apply, /usr/bin/ipsec up *, /usr/bin/ipsec down *, /usr/bin/ipsec statusall, /usr/bin/ipsec reload, /usr/bin/swanctl --initiate *, /usr/bin/swanctl --terminate *, /usr/bin/swanctl --list-sas
EOF

# Ajustar permissões
sudo chmod 0440 /etc/sudoers.d/vpn-egsys
sudo chown root:root /etc/sudoers.d/vpn-egsys

# Validar ANTES de usar (se falhar, remova o arquivo)
sudo visudo -cf /etc/sudoers.d/vpn-egsys
```

> O caminho SNX não exige sudo (daemon `snx-rs.service` + SUID nos binários).

### 4. Configurar VPNs

```bash
mkdir -p ~/.config/snx-rs

# Exemplo: vpnro.conf
cat > ~/.config/snx-rs/vpnro.conf <<EOF
server-name=131.72.155.42
user-name=seu_usuario
password=$(echo -n "sua_senha" | base64)
ignore-server-cert=true
login-type=vpn
EOF

chmod 600 ~/.config/snx-rs/vpnro.conf
```

### 5. Gerar Aliases

Adicione ao seu `~/.bashrc`:
```bash
# >>> vpn-egsys >>>
vpnro() { snxctl disconnect 2>/dev/null; sleep 1; cp ~/.config/snx-rs/vpnro.conf ~/.config/snx-rs/snx-rs.conf; snxctl connect 2>&1; for i in $(seq 1 20); do snxctl status 2>/dev/null | grep -qiE 'conectado desde|connected since' && echo "✓ vpnro conectada" && return 0; sleep 1; done; echo "✗ Timeout"; }
vpnoff() { snxctl disconnect 2>/dev/null; echo "VPN desconectada"; }
vpnstatus() { snxctl status; }
# <<< vpn-egsys <<<
```

Recarregue o shell:
```bash
source ~/.bashrc
```

### 6. Instalar vpn-tray

```bash
# Copiar script
cp vpn-tray ~/.local/bin/
chmod +x ~/.local/bin/vpn-tray

# Criar diretórios
mkdir -p ~/.local/share/icons/vpn-egsys
mkdir -p ~/.local/share/applications
mkdir -p ~/.config/autostart

# Copiar ícones
cp icons/*.svg ~/.local/share/icons/vpn-egsys/

# Criar desktop entry
cat > ~/.local/share/applications/vpn-egsys.desktop <<EOF
[Desktop Entry]
Name=VPN Monitor
Comment=Monitor de VPN Check Point
Exec=/home/$(whoami)/.local/bin/vpn-tray
Icon=/home/$(whoami)/.local/share/icons/vpn-egsys/vpn-disconnected.svg
Terminal=false
Type=Application
Categories=Network;
EOF

# Criar autostart
cp ~/.local/share/applications/vpn-egsys.desktop ~/.config/autostart/vpn-tray.desktop

# Atualizar database
update-desktop-database ~/.local/share/applications/ 2>/dev/null || true
```

### 7. Iniciar vpn-tray

```bash
nohup ~/.local/bin/vpn-tray > /dev/null 2>&1 &
```

---

## Desinstalação

Para desinstalar, execute:

```bash
./uninstall.sh
```

Ou manualmente:

```bash
# Parar processos
killall vpn-tray 2>/dev/null || true
sudo systemctl stop snx-rs.service 2>/dev/null || true
sudo rm -f /run/snx-rs.lock

# Backend IPsec (não coberto pelo uninstall.sh — gap na Roadmap Fase 3)
sudo /usr/lib/vpn-egsys/vpn-ipsec-apply --uninstall 2>/dev/null || true
sudo systemctl disable --now strongswan-starter 2>/dev/null || true
sudo rm -rf /usr/lib/vpn-egsys

# Remover arquivos
rm -f ~/.local/bin/vpn-tray ~/.local/bin/vpn
rm -rf ~/.local/bin/core
rm -rf ~/.local/share/icons/vpn-egsys
rm -f ~/.local/share/applications/vpn-egsys.desktop
rm -f ~/.config/autostart/vpn-tray.desktop

# Remover sudoers
sudo rm -f /etc/sudoers.d/vpn-egsys

# Remover aliases do shell
sed -i '/# >>> vpn-egsys >>>/,/# <<< vpn-egsys <<</d' ~/.bashrc 2>/dev/null
sed -i '/# >>> vpn-egsys >>>/,/# <<< vpn-egsys <<</d' ~/.zshrc 2>/dev/null

# Opcional: Remover configurações de VPN
# rm -rf ~/.config/snx-rs

# Opcional: Remover snx-rs
# Debian: sudo apt remove snx-rs
# Arch: sudo pacman -R snx-rs
```
