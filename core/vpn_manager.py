#!/usr/bin/env python3
"""
core/vpn_manager.py - Gerenciador Unificado de VPNs (SNX + IPsec) Cross-Platform.
Compatível com Linux e macOS (Darwin).
"""

import os
import sys
import glob
import base64
import platform
import subprocess
from typing import Dict, Optional, Tuple, Any, List

CONFIG_DIR = os.path.expanduser('~/.config/snx-rs')
VPN_EGSYS_DIR = os.path.expanduser('~/.config/vpn-egsys')

KNOWN_LABELS: Dict[str, str] = {
    'vpnro': 'VPN RO - Rondônia',
    'vpnpr': 'VPN PR - Paraná',
    'vpnam': 'VPN AM - Amazonas',
    'vpnmt': 'VPN MT - Mato Grosso',
    'vpnsc': 'VPN SC - Santa Catarina',
    'vpnto': 'VPN TO - Tocantins',
    'vpnprgp': 'VPN PR GP',
}


def get_platform_system() -> str:
    """Retorna o sistema operacional ('Linux', 'Darwin', etc.)."""
    return platform.system()


def is_macos() -> bool:
    """Retorna True se estiver executando no macOS."""
    return get_platform_system() == 'Darwin'


def is_linux() -> bool:
    """Retorna True se estiver executando no Linux."""
    return get_platform_system() == 'Linux'


def get_config_dir() -> str:
    """Retorna o diretório principal de configurações com retrocompatibilidade."""
    if os.path.exists(VPN_EGSYS_DIR):
        return VPN_EGSYS_DIR
    return CONFIG_DIR


def ensure_config_dir() -> str:
    """Garante que o diretório de configurações exista com permissões seguras (0700)."""
    cfg_dir = get_config_dir()
    os.makedirs(cfg_dir, mode=0o700, exist_ok=True)
    return cfg_dir


def parse_vpn_config(filepath: str) -> Dict[str, str]:
    """Lê e faz o parsing de um arquivo de configuração .conf."""
    data: Dict[str, str] = {}
    if not os.path.exists(filepath):
        return data

    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            if '=' in line:
                k, v = line.split('=', 1)
                data[k.strip().lower()] = v.strip()

    # Protocolo padrão é 'snx' se não for especificado
    if 'protocol' not in data:
        data['protocol'] = 'snx'

    return data


def write_vpn_config(
    vpn_id: str,
    server: str,
    user: str,
    password_b64: str,
    protocol: str = 'snx',
    ipsec_type: str = 'ikev2',
    psk_b64: str = '',
    routes: str = '',
    extra_options: Optional[Dict[str, str]] = None
) -> str:
    """Grava as configurações de uma VPN com permissão estrita 0600."""
    cfg_dir = ensure_config_dir()
    vpn_id = vpn_id.lower().replace(' ', '')
    if not vpn_id.startswith('vpn'):
        vpn_id = f'vpn{vpn_id}'
    vpn_id = ''.join(c for c in vpn_id if c.isalnum())

    conf_path = os.path.join(cfg_dir, f'{vpn_id}.conf')

    lines = [
        f'protocol={protocol}',
        f'server-name={server}',
        f'user-name={user}',
        f'password={password_b64}',
    ]

    if protocol == 'ipsec':
        lines.append(f'ipsec-type={ipsec_type}')
        if psk_b64:
            lines.append(f'psk={psk_b64}')
        if routes:
            lines.append(f'routes={routes}')
    else:
        # SNX defaults
        lines.append('ignore-server-cert=true')
        lines.append('login-type=vpn')

    if extra_options:
        for k, v in extra_options.items():
            lines.append(f'{k}={v}')

    with open(conf_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines) + '\n')

    os.chmod(conf_path, 0o600)
    return conf_path


def discover_vpns() -> Dict[str, Dict[str, Any]]:
    """Descobre todas as VPNs configuradas no diretório do usuário."""
    configs: Dict[str, Dict[str, Any]] = {}
    cfg_dir = get_config_dir()

    search_dirs = [cfg_dir]
    if cfg_dir != VPN_EGSYS_DIR and os.path.exists(VPN_EGSYS_DIR):
        search_dirs.append(VPN_EGSYS_DIR)

    for sdir in search_dirs:
        for conf in sorted(glob.glob(os.path.join(sdir, 'vpn*.conf'))):
            name = os.path.basename(conf).replace('.conf', '')
            if name in configs:
                continue
            parsed = parse_vpn_config(conf)
            label = KNOWN_LABELS.get(name, f'VPN {name[3:].upper()}')
            protocol = parsed.get('protocol', 'snx').lower()
            proto_tag = '[IPsec]' if protocol == 'ipsec' else '[SNX]'

            configs[name] = {
                'id': name,
                'label': label,
                'display_name': f'{label} {proto_tag}',
                'protocol': protocol,
                'server': parsed.get('server-name', ''),
                'user': parsed.get('user-name', ''),
                'conf_file': conf,
                'data': parsed
            }

    return configs


class VPNBackend:
    """Classe base para controle e status de túneis VPN."""

    @staticmethod
    def connect_snx(conf_path: str, label: str) -> Tuple[bool, str]:
        """Conecta VPN Check Point via snxctl e NetworkManager."""
        cfg_dir = get_config_dir()
        snx_conf = os.path.join(cfg_dir, 'snx-rs.conf')

        try:
            # 1. Desconecta qualquer sessão anterior
            subprocess.run(['snxctl', 'disconnect'], capture_output=True, timeout=5)
            if is_linux():
                subprocess.run(['nmcli', 'connection', 'down', label], capture_output=True, timeout=3)

            # 2. Copia a configuração ativa
            with open(conf_path, 'r', encoding='utf-8') as f:
                content = f.read()
            with open(snx_conf, 'w', encoding='utf-8') as f:
                f.write(content)
            os.chmod(snx_conf, 0o600)

            # 3. Dispara a conexão
            subprocess.Popen(['snxctl', 'connect'])
            if is_linux():
                subprocess.Popen(['nmcli', 'connection', 'up', label])

            return True, "Comando de conexão SNX disparado."
        except Exception as e:
            return False, f"Erro ao conectar SNX: {str(e)}"

    @staticmethod
    def disconnect_snx(label: str = '') -> Tuple[bool, str]:
        """Desconecta a sessão ativa de SNX."""
        try:
            subprocess.run(['snxctl', 'disconnect'], capture_output=True, timeout=5)
            if is_linux() and label:
                subprocess.run(['nmcli', 'connection', 'down', label], capture_output=True, timeout=3)
            return True, "Sessão SNX desconectada."
        except Exception as e:
            return False, f"Erro ao desconectar SNX: {str(e)}"

    @staticmethod
    def get_snx_status() -> Optional[str]:
        """Verifica o status atual do daemon snxctl."""
        try:
            r = subprocess.run(['snxctl', 'status'], capture_output=True, text=True, timeout=5)
            output = r.stdout.strip() if r.returncode == 0 else ""
            if not output or "desconectado" in output.lower() or "disconnected" in output.lower():
                return None
            return output
        except Exception:
            return None

    # --- IPsec Linux ---
    @staticmethod
    def connect_ipsec_linux(conf: Dict[str, Any]) -> Tuple[bool, str]:
        """Conecta túnel IPsec no Linux via NetworkManager ou strongSwan."""
        label = conf['label']
        name = conf['id']

        # 1. Tenta via nmcli se a conexão existir
        res = subprocess.run(['nmcli', 'connection', 'up', label], capture_output=True, text=True, timeout=15)
        if res.returncode == 0:
            return True, f"Túnel IPsec {label} conectado via NetworkManager."

        # 2. Fallback: tenta swanctl ou ipsec se disponível
        if subprocess.run(['which', 'swanctl'], capture_output=True).returncode == 0:
            res_swan = subprocess.run(['swanctl', '--initiate', '--ike', name], capture_output=True, text=True, timeout=15)
            if res_swan.returncode == 0:
                return True, f"Túnel IPsec {label} conectado via swanctl."

        if subprocess.run(['which', 'ipsec'], capture_output=True).returncode == 0:
            res_ipsec = subprocess.run(['sudo', 'ipsec', 'up', name], capture_output=True, text=True, timeout=15)
            if res_ipsec.returncode == 0:
                return True, f"Túnel IPsec {label} conectado via strongSwan."

        return False, f"Falha ao conectar IPsec no Linux: {res.stderr.strip() or 'Serviço IPsec não encontrado'}"

    @staticmethod
    def disconnect_ipsec_linux(conf: Dict[str, Any]) -> Tuple[bool, str]:
        """Desconecta túnel IPsec no Linux."""
        label = conf.get('label', '')
        name = conf.get('id', '')

        if label:
            subprocess.run(['nmcli', 'connection', 'down', label], capture_output=True, timeout=5)
        if subprocess.run(['which', 'swanctl'], capture_output=True).returncode == 0 and name:
            subprocess.run(['swanctl', '--terminate', '--ike', name], capture_output=True, timeout=5)
        if subprocess.run(['which', 'ipsec'], capture_output=True).returncode == 0 and name:
            subprocess.run(['sudo', 'ipsec', 'down', name], capture_output=True, timeout=5)

        return True, f"Túnel IPsec {label or name} desconectado."

    @staticmethod
    def is_ipsec_active_linux(conf: Dict[str, Any]) -> bool:
        """Verifica se o túnel IPsec está ativo no Linux."""
        label = conf.get('label', '')
        name = conf.get('id', '')

        # Verifica via nmcli
        if label:
            r = subprocess.run(['nmcli', '-t', '-f', 'NAME,TYPE,STATE', 'connection', 'show', '--active'],
                               capture_output=True, text=True, timeout=5)
            if r.returncode == 0 and label in r.stdout:
                return True

        # Verifica via swanctl
        if subprocess.run(['which', 'swanctl'], capture_output=True).returncode == 0:
            r = subprocess.run(['swanctl', '--list-sas'], capture_output=True, text=True, timeout=5)
            if r.returncode == 0 and name in r.stdout:
                return True

        # Verifica interfaces de túnel ipsec0 / xfrm*
        if os.path.exists('/sys/class/net/ipsec0') or any('xfrm' in iface for iface in glob.glob('/sys/class/net/*')):
            return True

        return False

    # --- IPsec macOS ---
    @staticmethod
    def connect_ipsec_macos(conf: Dict[str, Any]) -> Tuple[bool, str]:
        """Conecta túnel IPsec no macOS via scutil --nc."""
        label = conf['label']
        user = conf.get('user', '')
        password_b64 = conf.get('data', {}).get('password', '')

        try:
            # Se senha existir em base64, decodifica
            password = base64.b64decode(password_b64.encode()).decode() if password_b64 else ""

            # Conecta via scutil
            cmd = ['scutil', '--nc', 'start', label]
            if user:
                cmd.extend(['--user', user])
            if password:
                cmd.extend(['--secret', password])

            r = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
            if r.returncode == 0:
                return True, f"Túnel IPsec {label} conectado no macOS."
            return False, f"Falha ao conectar no macOS: {r.stderr.strip()}"
        except Exception as e:
            return False, f"Erro scutil macOS: {str(e)}"

    @staticmethod
    def disconnect_ipsec_macos(conf: Dict[str, Any]) -> Tuple[bool, str]:
        """Desconecta túnel IPsec no macOS via scutil --nc."""
        label = conf.get('label', '')
        try:
            subprocess.run(['scutil', '--nc', 'stop', label], capture_output=True, timeout=5)
            return True, f"Túnel IPsec {label} desconectado no macOS."
        except Exception as e:
            return False, f"Erro ao desconectar no macOS: {str(e)}"

    @staticmethod
    def is_ipsec_active_macos(conf: Dict[str, Any]) -> bool:
        """Verifica se o serviço VPN está conectado no macOS."""
        label = conf.get('label', '')
        try:
            r = subprocess.run(['scutil', '--nc', 'status', label], capture_output=True, text=True, timeout=5)
            if r.returncode == 0 and 'Connected' in r.stdout:
                return True
        except Exception:
            pass
        return False


def connect_vpn(vpn_id: str) -> Tuple[bool, str]:
    """Conecta uma VPN de forma agnóstica a protocolo e plataforma."""
    configs = discover_vpns()
    if vpn_id not in configs:
        return False, f"VPN '{vpn_id}' não encontrada. Use 'vpn list' para listar as disponíveis."

    conf = configs[vpn_id]
    protocol = conf.get('protocol', 'snx').lower()

    if protocol == 'ipsec':
        if is_macos():
            return VPNBackend.connect_ipsec_macos(conf)
        return VPNBackend.connect_ipsec_linux(conf)
    else:
        # Protocolo SNX (Check Point)
        return VPNBackend.connect_snx(conf['conf_file'], conf['label'])


def disconnect_all() -> Tuple[bool, str]:
    """Desconecta qualquer VPN ativa (SNX ou IPsec) em Linux ou macOS."""
    configs = discover_vpns()
    msg_parts = []

    # 1. Desconecta SNX
    ok_snx, msg_snx = VPNBackend.disconnect_snx()
    msg_parts.append(msg_snx)

    # 2. Desconecta IPsec de acordo com o SO
    for vpn_id, conf in configs.items():
        if conf.get('protocol') == 'ipsec':
            if is_macos():
                VPNBackend.disconnect_ipsec_macos(conf)
            elif is_linux():
                VPNBackend.disconnect_ipsec_linux(conf)

    return True, "Sessões VPN desconectadas."


def get_active_vpn() -> Optional[Dict[str, Any]]:
    """Identifica e retorna a VPN ativa no momento, ou None se desconectado."""
    configs = discover_vpns()

    # 1. Checa IPsec
    for vpn_id, conf in configs.items():
        if conf.get('protocol') == 'ipsec':
            if is_macos() and VPNBackend.is_ipsec_active_macos(conf):
                return conf
            elif is_linux() and VPNBackend.is_ipsec_active_linux(conf):
                return conf

    # 2. Checa SNX
    snx_status = VPNBackend.get_snx_status()
    if snx_status:
        cfg_dir = get_config_dir()
        active_conf_file = os.path.join(cfg_dir, 'snx-rs.conf')
        if os.path.exists(active_conf_file):
            try:
                with open(active_conf_file, 'r', encoding='utf-8') as f:
                    active_content = f.read().strip()
                for vpn_id, conf in configs.items():
                    if conf.get('protocol') == 'snx' and os.path.exists(conf['conf_file']):
                        with open(conf['conf_file'], 'r', encoding='utf-8') as f:
                            if f.read().strip() == active_content:
                                return conf
            except Exception:
                pass
        return {
            'id': 'snx-active',
            'label': 'VPN Check Point (Ativa)',
            'display_name': 'VPN Check Point [SNX]',
            'protocol': 'snx',
            'details': snx_status
        }

    return None
