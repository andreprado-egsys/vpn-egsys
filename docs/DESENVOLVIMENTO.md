# Desenvolvimento do vpn-egsys

## Visão Geral

Este documento descreve a estrutura de desenvolvimento do **vpn-egsys**, incluindo como contribuir, estruturas de código, padrões e boas práticas.

---

## Estrutura do Projeto

```
vpn-egsys/
├── README.md              # Documentação principal para usuários
├── LICENSE               # Licença MIT
├── package.json          # Placeholder para futuras dependências npm
├── .gitignore            # Arquivos a serem ignorados pelo Git
│
├── install.sh            # Script de instalação (Bash)
├── update.sh             # Gerenciador de VPNs (Bash)
├── uninstall.sh          # Script de desinstalação (Bash)
├── vpn-tray              # Monitor de bandeja (Python 3)
│
├── icons/                # Ícones SVG
│   ├── vpn-connected.svg
│   └── vpn-disconnected.svg
│
└── docs/                 # Documentação técnica
    ├── ARQUITETURA.md    # Arquitetura do sistema
    ├── INSTALAÇÃO.md     # Guia de instalação detalhado
    ├── USO.md            # Manual de uso
    ├── DESENVOLVIMENTO.md # Este arquivo
    └── ROADMAP.md        # Plano de melhorias
```

---

## Configuração do Ambiente de Desenvolvimento

### Pré-requisitos

| Ferramenta | Versão | Propósito |
|-----------|--------|-----------|
| Git | 2.0+ | Controle de versão |
| Python 3 | 3.6+ | Execução do vpn-tray |
| Bash | 4.0+ | Execução dos scripts |
| GTK 3 | 3.0+ | Dependência do vpn-tray |
| PyGObject | - | Bindings Python para GTK |
| Ayatana AppIndicator | 0.1+ | Ícone na bandeja |

### Clonar o Repositório

```bash
# Clonar
git clone https://github.com/andreprado-egsys/vpn-egsys.git
cd vpn-egsys

# Configurar upstream (opcional)
git remote add upstream https://github.com/andreprado-egsys/vpn-egsys.git
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
**Linhas:** ~247
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
    # Baixa e instala snx-rs v5.2.3+
}

# Configuração do sudoers
setup_sudoers() {
    # Cria /etc/sudoers.d/vpn-egsys
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
SNX_RS_VERSION="5.2.3"
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
**Linhas:** ~205
**Responsabilidade:** Gerenciamento interativo de VPNs

#### Funções Principais

```bash
# Listar VPNs
list_vpns() {
    # Exibe VPNs configuradas com servidor e usuário
}

# Adicionar VPN
add_vpn() {
    # Solicita nome, servidor, usuário, senha
    # Cria arquivo .conf em base64
    # Regenera aliases e atualiza tray
}

# Atualizar VPN
update_vpn() {
    # Atualiza servidor, usuário e/ou senha
}

# Remover VPN
remove_vpn() {
    # Remove arquivo .conf
    # Regenera aliases e atualiza tray
}

# Regenerar aliases
regenerate_aliases() {
    # Remove bloco antigo
    # Gera novos aliases para todas as VPNs
}

# Atualizar tray
update_tray() {
    # Para, copia novos arquivos e reinicia
}

# Menu principal
show_menu() {
    # Exibe menu TUI
}
```

#### Fluxo Principal

```bash
# Modo interativo (sem argumentos)
while true; do
    show_menu
    read -rp "Opção: " opt
    case "$opt" in
        1) list_vpns ;;
        2) add_vpn ;;
        3) update_vpn ;;
        4) remove_vpn ;;
        5) regenerate_aliases ;;
        6) update_tray ;;
        0) exit 0 ;;
        *) warn "Opção inválida." ;;
    esac
done

# Modo argumento (com argumentos)
case "$1" in
    listar|list) list_vpns ;;
    adicionar|add) add_vpn ;;
    atualizar|update) update_vpn ;;
    remover|remove) remove_vpn ;;
    aliases) regenerate_aliases ;;
    tray) update_tray ;;
    *) echo "Uso: $0 [listar|adicionar|atualizar|remover|aliases|tray]" ;;
esac
```

### 3. `uninstall.sh` - Script de Desinstalação

**Linguagem:** Bash
**Linhas:** ~53
**Responsabilidade:** Remoção completa do sistema

#### Processo

1. Parar processos (vpn-tray, snx-rs)
2. Remover arquivos instalados
3. Remover configurações do sudoers
4. Remover aliases do shell
5. **Perguntar** antes de remover configs de VPN

#### Boas Práticas

- Usar `set -e` para falhar em erros
- Perguntar confirmação para remover configs
- Não remover snx-rs (deixar para usuário)
- Exibir instruções para remoção manual do snx-rs

### 4. `vpn-tray` - Monitor de Bandeja

**Linguagem:** Python 3
**Linhas:** ~130
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
        # killall snx-rs
        # rm -f /run/snx-rs.lock
        # nohup sudo snx-rs -m standalone -c conf -l info

    def on_disconnect(self, widget):
        """Desconecta VPN."""
        # killall snx-rs
        # rm -f /run/snx-rs.lock

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
# Adicionar VPN de teste
./update.sh adicionar
# Nome: vpntest
# Servidor: 127.0.0.1 (ou servidor válido)
# Usuário: test
# Senha: test

# Testar conexão
vpntest
vpnstatus
vpnoff
```

#### Teste de Gerenciador

```bash
# Testar todas as opções do menu
./update.sh listar
./update.sh adicionar
./update.sh atualizar
./update.sh remover
./update.sh aliases
./update.sh tray
```

### Testes Automáticos (Futuro)

O projeto ainda não tem testes automatizados. Sugestões para implementação:

#### Bash Tests

Usar `bats` (Bash Automated Testing System):

```bash
# Instalar bats
# Debian: sudo apt install bats
# Arch: yay -S bats
# Fedora: sudo dnf install bats

# Criar tests/install.bats
#!/usr/bin/env bats

@test "Detectar distro" {
    run ./install.sh
    # ...
}
```

#### Python Tests

Usar `pytest`:

```python
# tests/test_vpn_tray.py
import pytest
from vpn_tray import discover_vpns, VPNTray

def test_discover_vpns(tmp_path):
    # Criar config fake
    conf = tmp_path / "vpnro.conf"
    conf.write_text("server-name=127.0.0.1\nuser-name=test\n")
    
    # Testar
    vpns = discover_vpns(str(tmp_path))
    assert "vpnro" in vpns
```

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
Version: 1.0.0
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
Version: 1.0.0
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
