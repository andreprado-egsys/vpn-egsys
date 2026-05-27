# Instalação do vpn-egsys

## Pré-requisitos

Antes de iniciar a instalação, certifique-se de que seu sistema atende aos seguintes requisitos:

### Requisitos do Sistema

| Requisito | Versão Mínima | Verificação |
|-----------|---------------|-------------|
| **Sistema Operacional** | Linux (x86_64) | `uname -m` |
| **Arquitetura** | x86_64 | `uname -m` |
| **Git** | 2.0+ | `git --version` |
| **curl** | Qualquer | `curl --version` |
| **sudo** | Qualquer | `sudo --version` |
| **Python** | 3.6+ | `python3 --version` |

**Verificar arquitetura:**
```bash
uname -m
# Deve retornara: x86_64
```

> ⚠️ **IMPORTANTE**: O projeto atualmente só tem suporte para arquitetura x86_64. Para ARM64, será necessário adaptar o script de instalação.

### Espaço em Disco

| Componente | Espaço Requerido |
|------------|------------------|
| Repositório vpn-egsys | ~1 MB |
| snx-rs (binary) | ~5-10 MB |
| Dependências | ~50-100 MB |
| **Total** | **~60-110 MB** |

---

## Métodos de Instalação

### Método 1: Instalação Padrão (Recomendado)

Este é o método mais simples e testado:

```bash
# 1. Clonar o repositório
git clone https://github.com/andreprado-egsys/vpn-egsys.git

# 2. Entrar no diretório
cd vpn-egsys

# 3. Executar o instalador
./install.sh
```

### Método 2: Instalação com Git (Alternativo)

Se preferir não clonar todo o repositório:

```bash
# Baixar apenas o instalador
curl -fSL -o install.sh https://raw.githubusercontent.com/andreprado-egsys/vpn-egsys/main/install.sh

# Tornar executável
chmod +x install.sh

# Executar
./install.sh
```

> ⚠️ **Nota**: Este método não Baixa os ícones e o vpn-tray. Você precisará baixá-los manualmente.

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
    webkit2gtk4.1
```

**Distribuições testadas:**
- Fedora 35 e superiores
- CentOS Stream
- Rocky Linux
- AlmaLinux

### Etapa 3: Instalação do snx-rs

O `snx-rs` é um cliente VPN Check Point de código aberto. O instalador baixará e instalará automaticamente a versão 5.2.3+.

**Versão instalada:** 5.2.3 (ou superior se disponível)

**Processo por distro:**

#### Debian/Ubuntu (DEB package)

```bash
# Download do pacote DEB
curl -fSL -o /tmp/snx-rs.deb \
    "https://github.com/ancwrd1/snx-rs/releases/download/v5.2.3/snx-rs_5.2.3_amd64.deb"

# Instalação
sudo apt install -y /tmp/snx-rs.deb

# Limpeza
rm -f /tmp/snx-rs.deb
```

#### Arch/Fedora (Binary tarball)

```bash
# Download do tarball
curl -fSL -o /tmp/snx-rs.tar.gz \
    "https://github.com/ancwrd1/snx-rs/releases/download/v5.2.3/snx-rs-v5.2.3-x86_64-unknown-linux-gnu.tar.gz"

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
# Deve mostrar: snx-rs 5.2.3
```

### Etapa 4: Configuração do Sudoers

Cria o arquivo `/etc/sudoers.d/vpn-egsys` com permissões NOPASSWD para os comandos necessários.

**Conteúdo do arquivo:**
```
USER ALL=(ALL) NOPASSWD: /usr/bin/snx-rs, /usr/bin/killall snx-rs, /usr/bin/rm -f /run/snx-rs.lock
```

**Processo:**
1. Detecta caminho do `snx-rs` e `killall`
2. Cria regra com NOPASSWD
3. Valida sintaxe com `sudo visudo -cf`
4. Aplica permissões 0440 (root:root)
5. Se validação falhar, remove o arquivo por segurança

**Localização:** `/etc/sudoers.d/vpn-egsys`
**Permissões:** `0440` (somente leitura para root e grupo root)

### Etapa 5: Configuração de VPNs Padrão

O instalador solicitará credenciais para as seguintes VPNs padrão:

| Alias | Descrição | Servidor |
|-------|-----------|----------|
| `vpnro` | VPN Rondônia | 131.72.155.42 |
| `vpnpr` | VPN Paraná | acessoremoto.pr.gov.br |
| `vpnam` | VPN Amazonas | sslvpn.prodam.am.gov.br |

**Para cada VPN:**
1. Exibe nome e descrição
2. Solicita usuário
3. Solicita senha (input oculto)
4. Cria arquivo `~/.config/snx-rs/{alias}.conf`

**Formato do arquivo .conf:**
```ini
server-name={servidor}
user-name={usuario}
password={senha_base64}
ignore-server-cert=true
login-type=vpn
```

> ✅ **Opcional**: Você pode pular a configuração de qualquer VPN pressionando Enter sem digitar nada. As VPNs podem ser adicionadas posteriormenta via `./update.sh`.

### Etapa 6: Geração de Aliases

Cria atalhos no shell para conexão rápida às VPNs.

**Arquivos modificados:**
- `~/.bashrc`
- `~/.zshrc` (se existir)

**Aliases gerados:**
```bash
# >>> vpn-egsys >>>
alias vpnro="sudo killall snx-rs 2>/dev/null; sleep 0.5; sudo rm -f /run/snx-rs.lock 2>/dev/null; nohup sudo /usr/bin/snx-rs -m standalone -c ~/.config/snx-rs/vpnro.conf -l info > /tmp/snx-rs.log 2>&1 & sleep 3 && tail -n 5 /tmp/snx-rs.log"
alias vpnpr="..."
alias vpnam="..."
alias vpnoff="sudo killall snx-rs 2>/dev/null; sleep 1; sudo rm -f /run/snx-rs.lock 2>/dev/null; echo 'VPN desconectada'"
alias vpnstatus="ip addr show snx-xfrm 2>/dev/null && tail -n 10 /tmp/snx-rs.log 2>/dev/null || echo 'VPN não conectada'"
# <<< vpn-egsys <<<
```

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

**2. Testar conexão manual:**
```bash
sudo snx-rs -m standalone -c ~/.config/snx-rs/vpnro.conf -l debug
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
wget https://github.com/ancwrd1/snx-rs/releases/download/v5.2.3/snx-rs_5.2.3_amd64.deb
sudo apt install -y ./snx-rs_5.2.3_amd64.deb
rm snx-rs_5.2.3_amd64.deb
```

**Arch/Fedora:**
```bash
wget https://github.com/ancwrd1/snx-rs/releases/download/v5.2.3/snx-rs-v5.2.3-x86_64-unknown-linux-gnu.tar.gz
tar -xf snx-rs-v5.2.3-x86_64-unknown-linux-gnu.tar.gz
sudo install -m 755 snx-rs /usr/bin/
sudo install -m 755 snxctl /usr/bin/  # se existir
rm -rf snx-rs-v5.2.3-x86_64-unknown-linux-gnu* snx-rs
```

### 3. Configurar Sudoers

```bash
# Criar arquivo
echo "$USER ALL=(ALL) NOPASSWD: /usr/bin/snx-rs, /usr/bin/killall snx-rs, /usr/bin/rm -f /run/snx-rs.lock" | sudo tee /etc/sudoers.d/vpn-egsys > /dev/null

# Ajustar permissões
sudo chmod 0440 /etc/sudoers.d/vpn-egsys
sudo chown root:root /etc/sudoers.d/vpn-egsys

# Validar
sudo visudo -cf /etc/sudoers.d/vpn-egsys
```

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
alias vpnro="sudo killall snx-rs 2>/dev/null; sleep 0.5; sudo rm -f /run/snx-rs.lock 2>/dev/null; nohup sudo snx-rs -m standalone -c ~/.config/snx-rs/vpnro.conf -l info > /tmp/snx-rs.log 2>&1 & sleep 3 && tail -n 5 /tmp/snx-rs.log"
alias vpnoff="sudo killall snx-rs 2>/dev/null; sleep 1; sudo rm -f /run/snx-rs.lock 2>/dev/null; echo 'VPN desconectada'"
alias vpnstatus="ip addr show snx-xfrm 2>/dev/null && tail -n 10 /tmp/snx-rs.log 2>/dev/null || echo 'VPN não conectada'"
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
killall snx-rs 2>/dev/null || true
sudo rm -f /run/snx-rs.lock

# Remover arquivos
rm -f ~/.local/bin/vpn-tray
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
