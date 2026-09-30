# Guia de Instalação e Uso no macOS (vpn-egsys)

O **vpn-egsys** foi projetado para rodar de forma nativa e transparente no **macOS** (compatível com Monterey, Ventura, Sonoma e Sequoia, em arquiteturas Intel x86_64 e Apple Silicon M1/M2/M3/M4).

---

## 1. Pré-Requisitos no macOS

- **Homebrew** instalado:
  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ```
- **Python 3** (geralmente instalado via `brew install python3`).

---

## 2. Instalação Rápida

Clone o repositório e execute o instalador (ele detecta automaticamente o ambiente macOS):

```bash
git clone git@github.com:egsys-dev/vpn-egsys.git
cd vpn-egsys
chmod +x install.sh
./install.sh
```

### O que o instalador faz no macOS:
1. Detecta o kernel `Darwin` e arquitetura (`arm64` ou `x86_64`).
2. Instala dependências Python para menu bar (`pystray` e `Pillow`).
3. Instala os binários `vpn`, `vpn-tray` e os módulos `core/` em `~/.local/bin`.
4. Configura o LaunchAgent do macOS em `~/Library/LaunchAgents/com.egsys.vpn-tray.plist` para autostart na inicialização da sessão.
5. Injeta aliases úteis no `~/.zshrc` e `~/.bash_profile`.

---

## 3. Comandos Disponíveis no Terminal do macOS

Recarregue o terminal (`source ~/.zshrc`) ou use diretamente:

```zsh
vpn list             # Lista todas as conexões cadastradas
vpn ro               # Conecta à VPN RO
vpn pr               # Conecta à VPN PR
vpn am               # Conecta à VPN AM
vpn sc               # Conecta à VPN SC (IPsec)
vpn off              # Desconecta qualquer sessão ativa
vpn status           # Exibe o status da VPN conectada
vpn add              # Wizard interativo para adicionar nova VPN (SNX ou IPsec)
vpn remove <id>      # Remove conexão
```

---

## 4. Ícone na Barra de Menus (Menu Bar)

O monitor de bandeja roda na barra superior do macOS via `pystray` (AppKit nativo da Apple):
- Ícone verde: VPN Conectada.
- Ícone cinza: Desconectado.
- Clique para conectar qualquer VPN, ver status ou desconectar.
