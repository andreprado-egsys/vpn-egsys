# Desenvolvimento do vpn-egsys

## Visão Geral

Este documento descreve a estrutura de desenvolvimento do **vpn-egsys**, incluindo como contribuir, estruturas de código, padrões e boas práticas.

---

## Estrutura do Projeto

```
vpn-egsys/
├── README.md              # Documentação principal para usuários
├── CHANGELOG.md           # Histórico formal de versões (Keep a Changelog)
├── AGENTS.md              # Diretrizes canônicas para agentes e desenvolvedores
├── LICENSE                # Licença MIT
├── package.json           # Metadados do projeto
├── .gitignore             # Travas de sanitização e proteção de credenciais
├── run_tests.sh           # Runner do Quality Gate (Bash + py_compile + unittest)
│
├── vpn                    # CLI universal de terminal (Linux & macOS)
├── vpn-tray               # Monitor de bandeja (GTK no Linux / pystray no macOS)
├── vpn-ipsec-apply        # Helper privilegiado root: materializa blocos stroke/swanctl em /etc
│
├── core/                  # Módulos Python unificados
│   ├── __init__.py
│   └── vpn_manager.py     # Driver de conectividade SNX e IPsec
│
├── tests/                 # Bateria de testes automatizados
│   ├── test_vpn_manager.py
│   ├── test_cli.py
│   └── test_security_pentest.py # Suíte de Pentest Black Box (ACH-VPN-001 a 010)
│
├── macos/                 # Utilitários e serviços dedicados para macOS
│   ├── install_macos.sh
│   ├── setup_ipsec.sh
│   └── com.egsys.vpn-tray.plist # LaunchAgent para autostart no login
│
├── install.sh             # Script de instalação universal (Linux e macOS)
├── update.sh              # Gerenciador e migrador de VPNs
├── uninstall.sh           # Script de desinstalação
├── user-setup.sh          # Setup sem privilégios de administrador
├── nm-snx-setup.sh        # Provisionador NetworkManager (SNX — dummy-iface; IPsec não passa pelo NM)
├── 99-snx-vpn.sh          # Dispatcher NetworkManager
│
├── icons/                 # Ícones SVG de status
│   ├── vpn-connected.svg
│   └── vpn-disconnected.svg
│
└── docs/                  # Documentação técnica Docs-as-Code
    ├── ARQUITETURA.md     # Arquitetura do sistema
    ├── DESENVOLVIMENTO.md # Este arquivo
    ├── INSTALAÇÃO.md      # Guia de instalação detalhado
    ├── IPSEC.md           # Manual do protocolo IPsec (IKEv1 XAuth+PSK padrão / IKEv2)
    ├── MACOS.md           # Manual de instalação e uso no macOS
    ├── ROADMAP.md         # Plano de evolução estratégica
    ├── SECURITY.md        # Política de segurança e matriz de pentest
    └── USO.md             # Manual de uso (CLI e Tray)
```

---

## Configuração do Ambiente de Desenvolvimento

### Clonar o Repositório (Dual-Path)

```bash
# 1. Clonar repositório
git clone git@github.com:egsys-dev/vpn-egsys.git
cd vpn-egsys

# 2. Configurar remote privado
git remote add privado git@github.com:andreprado-egsys/vpn-egsys.git
```

### Instalar Dependências de Desenvolvimento

**Debian/Ubuntu:**
```bash
sudo apt install -y \
    git \
    python3 \
    python3-pip \
    python3-gi \
    gir1.2-gtk-3.0 \
    gir1.2-ayatanaappindicator3-0.1 \
    libwebkit2gtk-4.0-37 \
    shellcheck  # Para linting de Bash
```

**Arch:**
```bash
sudo pacman -S --needed \
    git \
    python \
    python-pip \
    python-gobject \
    gtk3 \
    libayatana-appindicator \
    webkit2gtk \
    shellcheck
```

**Fedora:**
```bash
sudo dnf install -y \
    git \
    python3 \
    python3-pip \
    python3-gobject \
    gtk3 \
    libayatana-appindicator-gtk3 \
    webkit2gtk4.1 \
    ShellCheck
```

---

## Estrutura do Código

### 1. `install.sh` - Script de Instalação

**Linguagem:** Bash
**Linhas:** ~524
**Responsabilidade:** Instalação completa do sistema

#### Funções Principais

```bash
# Detecção do sistema
detect_distro() {
    # Lê /etc/os-release
    # Define PKG_MANAGER (apt, pacman, dnf)
}

# Instalação de dependências
install_deps() {
    # Instala pacotes conforme distro
}

# Instalação do snx-rs
install_snx_rs() {
    # Baixa e instala snx-rs v6.0.6 (command mode requer >= 5.0)
}

# Configuração do sudoers
setup_sudoers() {
    # Cria /etc/sudoers.d/vpn-egsys (valida com visudo -c antes de instalar)
}

# Provisionamento do backend IPsec (seção 11b)
provision_ipsec_backend() {
    # Copia core/ + vpn-ipsec-apply + vpn-ipsec-ctl para /usr/lib/vpn-egsys
    # Escreve sudoers NOPASSWD com dois caminhos exatos (apply + ctl — sem curingas; sudo-rs
    # 0.2.8 não casa coringa de argumento) e valida com visudo -c antes de instalar
    # Habilita strongswan-starter (desabilita strongswan/charon-systemd)
    # Guarda de paridade IKEv1 (v2.2.5, só com pacman no PATH): warn se o libcharon não tiver
    # task_manager_v1, ou se IgnorePkg não listar strongswan — não falha a instalação
    # Roda vpn-ipsec-apply --user $TARGET_USER (gravou secrets → rereadsecrets + reload)
}

# Configuração de VPN
setup_vpn() {
    # Solicita credenciais e cria .conf
}

# Geração de aliases
setup_aliases() {
    # Adiciona aliases no .bashrc e .zshrc
}

# Instalação do vpn-tray
install_tray() {
    # Copia arquivos e configura autostart
}
```

#### Variáveis Globais

```bash
SNX_RS_VERSION="6.0.6"
CONFIG_DIR="$HOME/.config/snx-rs"
LOCAL_BIN="$HOME/.local/bin"
APPS_DIR="$HOME/.local/share/applications"
AUTOSTART_DIR="$HOME/.config/autostart"
ICON_DIR="$HOME/.local/share/icons/vpn-egsys"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUDOERS_FILE="/etc/sudoers.d/vpn-egsys"
```

#### Boas Práticas

- Usar `set -e` para falhar em erros
- Validar sudoers antes de aplicar
- Perguntar confirmação para ações destrutivas
- Preservar configurações existentes
- Usar cores para feedback visual (GREEN, YELLOW, RED)

### 2. `update.sh` - Gerenciador de VPNs

**Linguagem:** Bash
**Linhas:** ~376
**Responsabilidade:** Atualização/migração linear da instalação (Linux) — desde a v2.2.1 cobre também o lado privilegiado IPsec, sendo `git pull && ./update.sh` suficiente em máquina já instalada. (No macOS delega para `macos/install_macos.sh`.)

#### Etapas (ordem de execução)

```bash
# 0. Aquisição de privilégios sudo (zenity/kdialog quando gráfico)
# 1. Parada de instâncias ativas (vpn-tray, snx-rs, lock file)
# 2. Detecção de distro (apt/pacman)
# 3. Pré-requisitos (systemd, NetworkManager ativo)
# 4. Atualização snx-rs -> v6.0.6 se major < 5 + SUID em /usr/bin/snx-rs|snxctl
# 5. Dependências de GUI (python-gi, appindicator, networkmanager, webkit2gtk)
# 6. setup_vpn_config(): wizard de credenciais por VPN — protocolo 1=SNX /
#    2=IPsec, e dentro de IPsec: 1=IKEv1 XAuth+PSK (padrão) / 2=IKEv2 swanctl,
#    com campos psk= e routes= gravados no vpnXX.conf (0600)
# 7. systemd: (re)instala e inicia snx-rs.service (command mode)
# 8. Dispatcher NM 99-snx-vpn.sh
# 9. nm-snx-setup.sh (somente dummy-ifaces de SNX; IPsec não passa pelo NM)
# 10. Userland: vpn, vpn-tray, core/, ícones -> ~/.local/bin
# 10b. Backend IPsec privilegiado (espelho da seção 11b do install.sh):
#      core/ + vpn-ipsec-apply -> /usr/lib/vpn-egsys; sudoers restrito
#      reescrito com validação visudo -c; strongswan-starter habilitado;
#      vpn-ipsec-apply --user $TARGET_USER aplicado
# 11. Aliases (bloco marcado >>> vpn-egsys <<<) e PATH
# 12. Reinício do vpn-tray na sessão gráfica do usuário alvo
```

#### Modo argumento

```bash
./update.sh            # fluxo linear completo (interativo nas credenciais)
```

> Nota: versões antigas deste doc descreviam um menu TUI (`show_menu`,
> `add_vpn`, `remove_vpn`...) que não existe no script vigente.

### 3. `uninstall.sh` - Script de Desinstalação

**Linguagem:** Bash
**Linhas:** ~40
**Responsabilidade:** Remoção completa do sistema

#### Processo (comportamento real do script)

1. Parar processos (vpn-tray; stop+disable `snx-rs.service`)
2. Remover `snx-rs.service` + dispatcher NM `99-snx-vpn.sh` + lock
3. Remover conexões NM dummy (RO/PR/AM)
4. Remover userland: `~/.local/bin/vpn-tray`, ícones, .desktop, autostart e aliases
   (nota: `vpn` e `core/` em `~/.local/bin` não são removidos)
5. Preservar credenciais (`~/.config/snx-rs/`) e o binário snx-rs

> **O backend IPsec privilegiado NÃO é removido pelo uninstall.sh** (gap conhecido, registrado no
> Roadmap Fase 3). Remoção manual:
> ```bash
> sudo /usr/lib/vpn-egsys/vpn-ipsec-apply --uninstall   # só os blocos gerenciados
> sudo rm -f /etc/sudoers.d/vpn-egsys
> sudo systemctl disable --now strongswan-starter
> sudo rm -rf /usr/lib/vpn-egsys
> ```

#### Boas Práticas

- Usar `set -e` para falhar em erros
- Nunca tocar em `~/.config/snx-rs/` sem confirmação explícita (preservado por padrão)
- Exibir instruções para remoção manual do snx-rs

### 4. `vpn-tray` - Monitor de Bandeja

**Linguagem:** Python 3
**Linhas:** ~582
**Responsabilidade:** Monitoramento e interface gráfica

#### Estrutura da Classe

```python
class VPNTray:
    def __init__(self):
        """Inicializa o AppIndicator e descobre VPNs."""
        self.indicator = AyatanaAppIndicator3.Indicator.new_with_path(...)
        self.vpns = discover_vpns()
        self.build_menu()
        GLib.timeout_add_seconds(3, self.check_status)
        self.check_status()

    def discover_vpns(self):
        """Descobre VPNs em ~/.config/snx-rs/."""
        # Usa glob.glob para encontrar vpn*.conf
        # Parseia server-name para label
        # Retorna dict {name: {'label': ..., 'conf': ...}}

    def build_menu(self):
        """Constrói o menu GTK."""
        # Cria menu com:
        # - status_item (desabilitado)
        # - itens para cada VPN
        # - separador
        # - Desconectar
        # - separador
        # - Sair

    def get_active_vpn(self):
        """Verifica VPN ativa."""
        # Check ip link show snx-xfrm
        # Check ps aux para processo snx-rs
        # Retorna label da VPN ou None

    def check_status(self):
        """Verifica e atualiza status."""
        # Chamado a cada 3 segundos
        # Atualiza ícone e título
        # Retorna True para continuar

    def on_connect(self, widget, key):
        """Conecta à VPN."""
        # core.vpn_manager.connect_vpn(id):
        #  SNX   -> snxctl connect (daemon command mode) + nmcli up <label>
        #  IPsec -> vpn-ipsec-apply -> ipsec up / swanctl --initiate

    def on_disconnect(self, widget):
        """Desconecta VPN."""
        # core.vpn_manager.disconnect_vpn() (snxctl disconnect / ipsec down)

    def on_quit(self, widget):
        """Encerra o aplicativo."""
        Gtk.main_quit()
```

#### Importações

```python
import gi
import subprocess
import os
import signal
import glob

gi.require_version('Gtk', '3.0')
gi.require_version('AyatanaAppIndicator3', '0.1')
from gi.repository import Gtk, AyatanaAppIndicator3, GLib
```

#### Constantes

```python
ICON_DIR = os.path.expanduser('~/.local/share/icons/vpn-egsys')
CONFIG_DIR = os.path.expanduser('~/.config/snx-rs')
SNX_RS = '/usr/bin/snx-rs'
```

#### Boas Práticas

- Usar `subprocess` para comandos shell
- Tratar exceções com try/except
- Usar GLib.timeout para agendamento
- Expandir paths com `os.path.expanduser`
- Usar `signal.signal(signal.SIGINT, signal.SIG_DFL)` para Ctrl+C

---

## Padrões de Código

### Padrões para Bash

#### Nomenclatura

| Tipo | Padrão | Exemplo |
|------|--------|---------|
| Variáveis | UPPER_CASE | `CONFIG_DIR`, `PKG_MANAGER` |
| Funções | snake_case | `detect_distro()`, `install_deps()` |
| Variáveis locais | snake_case | `local tmp_file`, `local snx_path` |

#### Formatação

```bash
# Use 4 espaços para indentação (não tabs)
if [ -f "$file" ]; then
    echo "File exists"
fi

# Use aspas duplas para variáveis
if [ ! -f "$CONFIG_DIR/vpn.conf" ]; then
    # ...
fi

# Use [[ ]] para condicionais complexas
if [[ "$PKG_MANAGER" == "apt" || "$PKG_MANAGER" == "pacman" ]]; then
    # ...
fi

# Use chaves para agrupamento
{
    echo "Line 1"
    echo "Line 2"
} > file.txt
```

#### Mensagens

```bash
# Cores para feedback
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'  # No Color

# Funções de log
info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
```

#### Segurança

```bash
# Valide entradas do usuário
[[ -z "$vpn_name" ]] && error "Nome não pode ser vazio."

# Use set -e para falhar em erros
set -e

# Valide sudoers antes de aplicar
if sudo visudo -cf "$SUDOERS_FILE" &>/dev/null; then
    info "Sudoers válido."
else
    sudo rm -f "$SUDOERS_FILE"
    error "Erro na validação do sudoers."
fi
```

### Padrões para Python

#### Nomenclatura

| Tipo | Padrão | Exemplo |
|------|--------|---------|
| Classes | PascalCase | `VPNTray`, `VPNManager` |
| Métodos | snake_case | `get_active_vpn()`, `check_status()` |
| Variáveis | snake_case | `config_dir`, `icon_dir` |
| Constantes | UPPER_CASE | `ICON_DIR`, `CONFIG_DIR` |

#### Formatação

```python
# Use 4 espaços para indentação (PEP 8)
# Use aspas duplas para strings
# Use aspas simples para chars

if os.path.exists(config_file):
    with open(config_file) as f:
        content = f.read()

# Linhas até 79 caracteres (PEP 8)
# 2 linhas em branco entre classes
# 1 linha em branco entre métodos
```

#### Imports

```python
# Imports padrão em primeiro lugar
import os
import sys
import subprocess

# Terceiros em segundo
import gi

# Locais em terceiro
# (nenhum no momento)
```

#### Tratamento de Erros

```python
# Use try/except para operações que podem falhar
try:
    subprocess.run(['ip', 'link', 'show', 'snx-xfrm'],
                   capture_output=True, text=True, timeout=3)
except subprocess.TimeoutExpired:
    return None
except Exception:
    return None
```

---

## Testes

### Testes Manuais

#### Teste de Instalação

```bash
# Testar em ambiente limpo (VM ou container)
git clone https://github.com/andreprado-egsys/vpn-egsys.git
cd vpn-egsys
./install.sh

# Verificar
which snx-rs
ls ~/.local/bin/vpn-tray
ls ~/.config/snx-rs/
```

#### Teste de Conexão

```bash
# Registrar VPN de teste (assistente interativo)
vpn add

# Conectar/desconectar pelo CLI universal
vpn connect vpntest
vpn status
vpn off
```

#### Teste de Gerenciador / Backend IPsec

```bash
./update.sh                              # fluxo linear de atualização (inclui 10b)
sudo /usr/lib/vpn-egsys/vpn-ipsec-apply --check      # exit 1 se /etc dessincronizado
sudo /usr/lib/vpn-egsys/vpn-ipsec-apply              # reaplica blocos gerenciados
ipsec statusall | grep -E 'vpn.*INSTALLED'           # SA instalada (formato com chaves)
```

### Testes Automatizados (Vigentes — suíte de 41 testes)

O Quality Gate do projeto é o runner `./run_tests.sh` (obrigatório antes de qualquer commit):

```bash
./run_tests.sh
# 1. bash -n            — sintaxe de todos os scripts shell
# 2. python -m py_compile — todos os módulos Python (core, vpn, vpn-tray, helpers)
# 3. python -m unittest discover -s tests — 41 testes (28 unitários + 10 pentest + 3 CLI)
```

#### Estrutura da suíte (`tests/`)

| Arquivo | Cobertura |
|---------|-----------|
| `test_vpn_manager.py` | Parsing/escrita de perfis, sanitização, renderizadores stroke/swanctl (`render_stroke_block`, `render_secrets_block`, `render_swanctl_block`), idempotência de marcadores `BEGIN/END vpn-egsys`, `connect/disconnect_ipsec_linux` com `run_sudo` mockado (apply→up→poll SA `INSTALLED`), parse real do `statusall` (chaves `conn{n}:`), `installed_remote_ts` + `missing_released_routes` (aviso de TS reduzido pelo gateway) |
| `test_security_pentest.py` | Matriz ACH-VPN-001..010 (injeção de comando/CRLF/path traversal, 0600, varredura de secrets incluindo `vpn-ipsec-apply`, proibição de `shell=True`, payload gigante, CLI, plist) |
| `test_cli.py` | Parser do `vpn`: aliases de atalho, validação de ID, `list`/`status` |

#### Rodando isoladamente

```bash
python3 -m unittest tests.test_vpn_manager -v
python3 -m unittest tests.test_security_pentest -v
```

> Os testes de backend usam `@patch` em `core.vpn_manager.run_sudo`/`shutil.which` e nunca tocam
> no sistema real — o túnel AM SSP validado ao vivo em máquina física permanece como
> evidência complementar (ver `docs/IPSEC.md` §3–4).

> **Dívida de teste (v2.2.5):** `charon_ikev1_missing()` lê o `libcharon` real de
> `/usr/lib*/ipsec/`, então fica fora da suíte unitária (que por construção não toca o sistema).
> A verificação é manual, no host: `python3 -c "import sys; sys.path.insert(0,'.'); from
> core.vpn_manager import charon_ikev1_missing as f; print(f())"` — `False` em Ubuntu e em Arch com
> rebuild `--enable-ikev1`, `True` em Arch com o pacote do repositório. Cobertura automatizada
> exigiria injetar o caminho do `.so` por parâmetro ou `mock_open`.

---

## Depuração

### Depuração de Bash

#### Modo Verbose

Adicione `set -x` no início do script:

```bash
#!/bin/bash
set -ex  # -e para falhar em erros, -x para verbose
```

#### Log de Execução

```bash
# Executar com log
bash -x ./install.sh > install.log 2>&1

# Analisar log
less install.log
```

### Depuração de Python

#### Logs do vpn-tray

```bash
# Executar com logs
~/.local/bin/vpn-tray 2>&1 | tee vpn-tray.log
```

#### Debug Interativo

Adicione `pdb` no código:

```python
import pdb; pdb.set_trace()
```

Ou execute com `pdb`:

```bash
python3 -m pdb ~/.local/bin/vpn-tray
```

### Verificar Dependências

```bash
# Verificar Python
python3 -c "import gi; gi.require_version('Gtk', '3.0'); gi.require_version('AyatanaAppIndicator3', '0.1'); print('OK')"

# Verificar snx-rs
snx-rs --version

# Verificar caminhos
which snx-rs
which killall
ls ~/.config/snx-rs/
```

---

## Contribuindo

### Fluxo de Trabalho

1. **Fork o repositório** no GitHub
2. **Clone seu fork** localmente
3. **Crie uma branch** para sua feature/fix
4. **Faça commits** com mensagens descritivas
5. **Push** para seu fork
6. **Abra um Pull Request** para o repositório original

### Convenções de Commit

Use mensagens de commit claras e descritivas:

```bash
# Bons exemplos
git commit -m "feat: adicionar suporte a Fedora/RHEL"
git commit -m "fix: corrigir detecção de distro no Arch"
git commit -m "docs: atualizar README com instruções de instalação"
git commit -m "refactor: extrair função setup_sudoers para módulo separado"

# Maus exemplos (evitar)
git commit -m "fix"
git commit -m "mudanças"
git commit -m "atualização"
```

**Prefixos sugeridos:**
- `feat:` - Nova feature
- `fix:` - Correção de bug
- `docs:` - Atualização de documentação
- `refactor:` - Refatoração de código
- `style:` - Mudanças de formatação
- `chore:` - Tarefas de manutenção
- `test:` - Adição/modificação de testes

### Pull Request

Ao abrir um PR:

1. Use um título claro e descritivo
2. Adicione uma descrição detalhada das mudanças
3. Referencie issues relacionadas (se houver)
4. Inclua capturas de tela (para mudanças visuais)
5. Testou as mudanças localmente

### Revisão de Código

Ao revisar código:

1. Verifique se segue os padrões do projeto
2. Teste as mudanças localmente (se possível)
3. Comente de forma construtiva
4. Aprovar ou solicitar mudanças

---

## Compilação e Empacotamento

### Criar Pacote DEB (Futuro)

Para distribuir como pacote DEB:

```bash
# Criar estrutura de diretórios
mkdir -p vpn-egsys-deb/DEBIAN
mkdir -p vpn-egsys-deb/usr/bin
mkdir -p vpn-egsys-deb/usr/share/vpn-egsys

# Copiar arquivos
cp vpn-tray vpn-egsys-deb/usr/bin/
cp -r icons vpn-egsys-deb/usr/share/vpn-egsys/

# Criar arquivo DEBIAN/control
cat > vpn-egsys-deb/DEBIAN/control <<EOF
Package: vpn-egsys
Version: 2.2.1
Section: net
Priority: optional
Architecture: amd64
Maintainer: Seu Nome <seu@email.com>
Description: Monitor de bandeja e gerenciador de VPN Check Point
EOF

# Criar pacote
dpkg-deb --build vpn-egsys-deb
```

### Criar Pacote RPM (Futuro)

Para distribuir como pacote RPM:

```bash
# Instalar rpm-build
sudo dnf install rpm-build

# Criar especificação
cat > ~/rpmbuild/SPECS/vpn-egsys.spec <<EOF
Name: vpn-egsys
Version: 2.2.1
Release: 1%{?dist}
Summary: VPN Check Point Monitor
License: MIT
URL: https://github.com/andreprado-egsys/vpn-egsys
Source0: vpn-egsys.tar.gz

%description
Monitor de bandeja e gerenciador de VPN Check Point via snx-rs.

%prep
%setup -q

%install
install -m 755 vpn-tray %{buildroot}/%{_bindir}/vpn-tray
install -d %{buildroot}/%{_datadir}/vpn-egsys/icons
cp -r icons/*.svg %{buildroot}/%{_datadir}/vpn-egsys/icons/

%files
%{_bindir}/vpn-tray
%{_datadir}/vpn-egsys/icons/*
EOF

# Criar pacote
rpmbuild -ba ~/rpmbuild/SPECS/vpn-egsys.spec
```

---

## Manutenção

### Atualizar Versão do snx-rs

Para atualizar a versão do snx-rs instalada:

1. Editar `install.sh`:
   ```bash
   SNX_RS_VERSION="5.3.0"  # Nova versão
   ```

2. Verificar se a nova versão existe no GitHub:
   ```bash
   curl -I https://github.com/ancwrd1/snx-rs/releases/download/v5.3.0/snx-rs_5.3.0_amd64.deb
   ```

3. Testar a instalação com a nova versão

### Adicionar Nova Distro

Para adicionar suporte a uma nova distribuição:

1. Adicionar detecção em `detect_distro()`:
   ```bash
   elif echo "$ids" | grep -qwE "novalinux"; then
       PKG_MANAGER="novapkg"
   ```

2. Adicionar instalação de dependências em `install_deps()`:
   ```bash
   novapkg)
       sudo novapkg install -y python-gobject gtk3 ayatana-appindicator webkit2gtk
       ;;
   ```

3. Adicionar instalação do snx-rs em `install_snx_rs()`:
   ```bash
   novapkg)
       # Download e instalação para nova distro
       ;;
   ```

4. Testar em um sistema com a nova distro

---

## Ferramentas Úteis

| Ferramenta | Propósito | Instalação |
|-----------|-----------|-------------|
| shellcheck | Linting de Bash | `sudo apt install shellcheck` |
| shfmt | Formatação de Bash | `go install mvdan.cc/sh/v3/cmd/shfmt@latest` |
| black | Formatação de Python | `pip install black` |
| flake8 | Linting de Python | `pip install flake8` |
| mypy | Type checking Python | `pip install mypy` |
| bats | Testes Bash | `sudo apt install bats` |
| pytest | Testes Python | `pip install pytest` |

---

## Checklist para Novas Contribuições

- [ ] Código segue os padrões do projeto
- [ ] Testado localmente
- [ ] Documentação atualizada (se necessário)
- [ ] Mensagens de commit claras
- [ ] Pull Request com descrição detalhada
- [ ] Referências a issues relacionadas (se houver)
- [ ] Não há segredos (senhas, tokens) no código
- [ ] Código não quebra funcionalidades existentes
