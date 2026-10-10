#!/usr/bin/env python3
"""
core/vpn_manager.py - Gerenciador Unificado de VPNs (SNX + IPsec) Cross-Platform.
Compatível com Linux e macOS (Darwin).
"""

import os
import re
import sys
import glob
import time
import base64
import shutil
import ipaddress
import platform
import subprocess
from typing import Dict, Optional, Tuple, Any, List

CONFIG_DIR = os.path.expanduser('~/.config/snx-rs')
VPN_EGSYS_DIR = os.path.expanduser('~/.config/vpn-egsys')

IPSEC_APPLY_PATH = '/usr/lib/vpn-egsys/vpn-ipsec-apply'


def run_sudo(args: List[str], timeout: int = 30, capture: bool = True) -> subprocess.CompletedProcess:
    """Executa via sudo -n (NOPASSWD); se exigir senha, re-tenta interativo no terminal."""
    cmd = ['sudo', '-n'] + list(args)
    r = subprocess.run(cmd, capture_output=capture, text=True, timeout=timeout)
    if r.returncode == 1 and capture and 'password is required' in (r.stderr or ''):
        r = subprocess.run(['sudo'] + list(args), text=True, timeout=timeout)
    return r

KNOWN_LABELS: Dict[str, str] = {
    'vpnro': 'VPN RO - Rondônia',
    'vpnpr': 'VPN PR - Paraná',
    'vpnam': 'VPN AM - Amazonas',
    'vpnamsspsnx': 'VPN AM SSP - Check Point (SNX)',
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


def sanitize_config_value(value: Any) -> str:
    """Sanitiza strings de configuração removendo quebras de linha e caracteres de controle (CRLF Injection)."""
    if value is None:
        return ""
    val_str = str(value)
    # Remove terminadores de linha e caracteres de controle perigosos
    return val_str.replace('\r', '').replace('\n', '').strip()


def write_vpn_config(
    vpn_id: str,
    server: str,
    user: str,
    password_b64: str,
    protocol: str = 'snx',
    ipsec_type: str = 'ikev1-xauth',
    psk_b64: str = '',
    routes: str = '',
    extra_options: Optional[Dict[str, str]] = None
) -> str:
    """Grava as configurações de uma VPN com permissão estrita 0600 e sanitização defensiva."""
    cfg_dir = ensure_config_dir()
    vpn_id_raw = vpn_id.lower().replace(' ', '')
    if not vpn_id_raw.startswith('vpn'):
        vpn_id_raw = f'vpn{vpn_id_raw}'
    vpn_id = ''.join(c for c in vpn_id_raw if c.isalnum())

    if not vpn_id or vpn_id == 'vpn':
        raise ValueError(f"Identificador de VPN inválido: '{vpn_id_raw}'")

    # Sanitização contra CRLF injection em todos os campos
    server_clean = sanitize_config_value(server)
    user_clean = sanitize_config_value(user)
    pass_clean = sanitize_config_value(password_b64)
    proto_clean = sanitize_config_value(protocol).lower()
    ipsec_type_clean = sanitize_config_value(ipsec_type).lower()
    if ipsec_type_clean in ('xauth', 'ikev1'):
        ipsec_type_clean = 'ikev1-xauth'
    psk_clean = sanitize_config_value(psk_b64)
    routes_clean = sanitize_config_value(routes)

    conf_path = os.path.join(cfg_dir, f'{vpn_id}.conf')

    lines = [
        f'protocol={proto_clean}',
        f'server-name={server_clean}',
        f'user-name={user_clean}',
        f'password={pass_clean}',
    ]

    if proto_clean == 'ipsec':
        lines.append(f'ipsec-type={ipsec_type_clean}')
        if psk_clean:
            lines.append(f'psk={psk_clean}')
        if routes_clean:
            lines.append(f'routes={routes_clean}')
    else:
        # SNX defaults
        lines.append('ignore-server-cert=true')
        lines.append('login-type=vpn')

    if extra_options:
        for k, v in extra_options.items():
            k_clean = sanitize_config_value(k)
            v_clean = sanitize_config_value(v)
            if k_clean:
                lines.append(f'{k_clean}={v_clean}')

    with open(conf_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines) + '\n')

    os.chmod(conf_path, 0o600)
    return conf_path


# --- Materialização de configuração strongSwan (usada pelo helper vpn-ipsec-apply) ---

MARK_BEGIN = "# BEGIN vpn-egsys (managed)"
MARK_END = "# END vpn-egsys (managed)"

DEFAULT_IKE_PROPOSALS = "aes256-sha256-modp2048,aes128-sha256-modp1536!"
DEFAULT_ESP_PROPOSALS = "aes256-sha256-modp1536,aes128-sha256-modp1536!"


def decode_secret(value: str) -> str:
    """Decodifica segredos base64 dos perfis; retorna '' se ausente/inválido."""
    if not value:
        return ""
    try:
        return base64.b64decode(value, validate=True).decode('utf-8', 'replace')
    except Exception:
        return ""


def escape_stroke_value(value: Any) -> str:
    """Escapa valores para aspas de ipsec.conf/ipsec.secrets."""
    cleaned = sanitize_config_value(value)
    return cleaned.replace('\\', '\\\\').replace('"', '\\"')


def is_ipsec_v1_profile(data: Dict[str, str]) -> bool:
    return (data.get('protocol', 'snx').lower() == 'ipsec'
            and data.get('ipsec-type', 'ikev1-xauth').lower() != 'ikev2')


def is_ipsec_v2_profile(data: Dict[str, str]) -> bool:
    return (data.get('protocol', 'snx').lower() == 'ipsec'
            and data.get('ipsec-type', '').lower() == 'ikev2')


def render_stroke_block(profiles: Dict[str, Dict[str, Any]]) -> str:
    """Bloco gerado para /etc/ipsec.conf (stroke IKEv1 Main Mode + PSK + XAuth)."""
    lines = [MARK_BEGIN]
    rendered = 0
    for vpn_id, data in sorted(profiles.items()):
        if not is_ipsec_v1_profile(data):
            continue
        server = sanitize_config_value(data.get('server-name', ''))
        user = sanitize_config_value(data.get('user-name', ''))
        routes = (sanitize_config_value(data.get('routes', '')) or '0.0.0.0/0').replace(' ', '')
        ike = sanitize_config_value(data.get('ike', '')) or DEFAULT_IKE_PROPOSALS
        esp = sanitize_config_value(data.get('esp', '')) or DEFAULT_ESP_PROPOSALS
        if not server:
            continue
        rendered += 1
        lines.extend([
            f"conn {vpn_id}",
            "    auto=add",
            "    keyexchange=ikev1",
            "    aggressive=no",
            "    authby=psk",
            f"    ike={ike}",
            f"    esp={esp}",
            "    left=%defaultroute",
            "    leftauth=psk",
            "    leftauth2=xauth",
            "    leftid=%any",
            f"    xauth_identity={user}",
            "    leftsourceip=%config",
            f"    right={server}",
            "    rightauth=psk",
            "    rightid=%any",
            f"    rightsubnet={routes}",
            "    forceencaps=yes",
            "",
        ])
    if not rendered:
        return ""
    lines.append(MARK_END)
    return "\n".join(lines).rstrip() + "\n"


def render_secrets_block(profiles: Dict[str, Dict[str, Any]]) -> str:
    """Bloco gerado para /etc/ipsec.secrets (PSK do gateway + XAUTH do usuário)."""
    lines = [MARK_BEGIN]
    psks, xauths = set(), []
    for vpn_id, data in sorted(profiles.items()):
        if not is_ipsec_v1_profile(data):
            continue
        psk = decode_secret(data.get('psk', ''))
        user = sanitize_config_value(data.get('user-name', ''))
        pwd = decode_secret(data.get('password', ''))
        if psk:
            psks.add(escape_stroke_value(psk))
        if user and pwd:
            xauths.append((escape_stroke_value(user), escape_stroke_value(pwd)))
    for psk in sorted(psks):
        lines.append(f': PSK "{psk}"')
    for user, pwd in xauths:
        lines.append(f'{user} : XAUTH "{pwd}"')
    if not psks and not xauths:
        return ""
    lines.append(MARK_END)
    return "\n".join(lines).rstrip() + "\n"


def render_swanctl_block(profiles: Dict[str, Dict[str, Any]]) -> str:
    """Conteúdo gerenciado de /etc/swanctl/conf.d/vpn-egsys.conf (perfis IKEv2)."""
    conns, secrets = [], []
    for vpn_id, data in sorted(profiles.items()):
        if not is_ipsec_v2_profile(data):
            continue
        server = sanitize_config_value(data.get('server-name', ''))
        user = sanitize_config_value(data.get('user-name', ''))
        routes = (sanitize_config_value(data.get('routes', '')) or '0.0.0.0/0').replace(' ', '')
        ike = sanitize_config_value(data.get('ike', '')) or 'aes256-sha256-modp2048'
        esp = sanitize_config_value(data.get('esp', '')) or 'aes256-sha256-modp2048'
        psk = escape_stroke_value(decode_secret(data.get('psk', '')))
        pwd = escape_stroke_value(decode_secret(data.get('password', '')))
        if not server:
            continue
        conns.append(
            f"        {vpn_id} {{\n"
            f"            version = 2\n"
            f"            remote_addrs = {server}\n"
            f"            vips = 0.0.0.0\n"
            f"            proposals = {ike}\n"
            f"            local {{\n"
            f"                auth = eap-mschapv2\n"
            f"                eap_id = {user}\n"
            f"            }}\n"
            f"            remote {{\n"
            f"                auth = psk\n"
            f"                id = %any\n"
            f"            }}\n"
            f"            children {{\n"
            f"                {vpn_id} {{\n"
            f"                    remote_ts = {routes}\n"
            f"                    esp_proposals = {esp}\n"
            f"                }}\n"
            f"            }}\n"
            f"        }}"
        )
        if user and pwd:
            secrets.append(
                f"        eap-{vpn_id} {{\n"
                f"            id-1 = {user}\n"
                f'            secret = "{pwd}"\n'
                f"        }}"
            )
        if psk:
            secrets.append(
                f"        ike-{vpn_id} {{\n"
                f'            secret = "{psk}"\n'
                f"        }}"
            )
    if not conns:
        return ""
    body = (
        f"{MARK_BEGIN}\n"
        f"connections {{\n" + "\n".join(conns) + "\n}}\n\n"
        f"secrets {{\n" + "\n".join(secrets) + "\n}}\n"
        f"{MARK_END}\n"
    )
    return body


def apply_markers(content: str, block: str) -> str:
    """Substitui (ou anexa) o bloco entre marcadores, preservando o resto do arquivo."""
    if MARK_BEGIN in content and MARK_END in content:
        pre, rest = content.split(MARK_BEGIN, 1)
        _old, _, post = rest.partition(MARK_END)
        return f"{pre}{block}\n{post.lstrip(chr(10))}"
    sep = "" if content.endswith("\n") or not content else "\n"
    return f"{content}{sep}\n{block}\n"


def strip_markers(content: str) -> str:
    """Remove o bloco gerenciado de um arquivo."""
    if MARK_BEGIN not in content:
        return content
    pre, rest = content.split(MARK_BEGIN, 1)
    _old, _, post = rest.partition(MARK_END)
    return (pre + post).strip("\n") + ("\n" if (pre + post).strip() else "")


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
            if protocol == 'ipsec':
                proto_tag = ('[IPsec/IKEv2]' if is_ipsec_v2_profile(parsed)
                             else '[IPsec/IKEv1-XAuth]')
            else:
                proto_tag = '[SNX]'

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
        """Conecta túnel IPsec no Linux via helper vpn-ipsec-apply + strongSwan nativo.

        IKEv1 XAuth+PSK usa stroke (ipsec up); IKEv2 usa swanctl --initiate.
        O plugin strongSwan do NetworkManager NÃO cobre esses gateways
        (IKEv2-only e sem híbrido EAP-usuário + PSK-gateway).
        """
        name = conf['id']
        label = conf.get('label', name)
        data = conf.get('data', {})
        v2 = is_ipsec_v2_profile(data)

        if os.path.exists(IPSEC_APPLY_PATH):
            applied = run_sudo([IPSEC_APPLY_PATH], timeout=30)
            if applied.returncode != 0:
                detail = (applied.stderr or applied.stdout or "").strip()[-300:]
                return False, f"vpn-ipsec-apply falhou: {detail}"
        elif not shutil.which('ipsec') and not shutil.which('swanctl'):
            return False, ("Nenhum backend IPsec encontrado. Execute 'sudo ./install.sh' "
                           "para provisionar strongSwan e o helper vpn-ipsec-apply.")

        cmd = ['swanctl', '--initiate', '--ike', name] if v2 else ['ipsec', 'up', name]
        res = run_sudo(cmd, timeout=40)
        kind = 'IKEv2/swanctl' if v2 else 'IKEv1 XAuth/stroke'
        if res.returncode == 0:
            # rc 0 no stroke apenas aceita a iniciação; a SA precisa ficar INSTALLED
            # (verificação ativa — o gateway pode rejeitar o XAuth logo em seguida).
            for _ in range(8):
                if VPNBackend.is_ipsec_active_linux(conf):
                    missing = VPNBackend.missing_released_routes(conf)
                    if missing:
                        return True, (f"Túnel IPsec {label} conectado ({kind}), "
                                      f"mas o gateway NÃO liberou as rotas "
                                      f"{', '.join(missing)} — política de túnel "
                                      f"do gateway (as redes não são alcançáveis).")
                    return True, f"Túnel IPsec {label} conectado ({kind})."
                time.sleep(2)
            return False, (f"Negociação {kind} iniciada mas a SA não estabeleceu "
                           f"(verifique credenciais no gateway; 'journalctl -u strongswan-starter').")
        lines = (res.stdout or res.stderr or "").strip().splitlines()
        detail = " | ".join(lines[-3:]) if lines else "sem detalhes (ver 'vpn status')"
        return False, f"Falha ao conectar {label} ({kind}): {detail}"

    @staticmethod
    def disconnect_ipsec_linux(conf: Dict[str, Any]) -> Tuple[bool, str]:
        """Desconecta túnel IPsec no Linux (stroke e swanctl, best-effort)."""
        label = conf.get('label', '')
        name = conf.get('id', '')
        if not name:
            return True, "Nada a desconectar."
        data = conf.get('data', {})
        if is_ipsec_v2_profile(data) and shutil.which('swanctl'):
            run_sudo(['swanctl', '--terminate', '--ike', name], timeout=15, capture=True)
        if shutil.which('ipsec'):
            run_sudo(['ipsec', 'down', name], timeout=15, capture=True)
        return True, f"Túnel IPsec {label or name} desconectado."

    @staticmethod
    def is_ipsec_active_linux(conf: Dict[str, Any]) -> bool:
        """Verifica se a SA do túnel está INSTALLED/ESTABLISHED (sem falsos positivos de xfrm)."""
        name = conf.get('id', '')
        if not name:
            return False
        data = conf.get('data', {})
        if is_ipsec_v2_profile(data) and shutil.which('swanctl'):
            r = run_sudo(['swanctl', '--list-sas'], timeout=10, capture=True)
            if r.returncode == 0:
                for line in r.stdout.splitlines():
                    if line.strip().startswith(f"{name}:") and 'ESTABLISHED' in line:
                        return True
            return False
        if not shutil.which('ipsec'):
            return False
        r = run_sudo(['ipsec', 'statusall'], timeout=10, capture=True)
        if r.returncode != 0:
            return False
        for line in r.stdout.splitlines():
            stripped = line.strip()
            if stripped.startswith(f"{name}[") or stripped.startswith(f"{name}{{"):
                if 'INSTALLED' in stripped:
                    return True
        return False

    @staticmethod
    def installed_remote_ts(conf: Dict[str, Any]) -> List[str]:
        """TS remotas das SAs-filhas INSTALLED do túnel (stroke statusall ou swanctl)."""
        name = conf.get('id', '')
        data = conf.get('data', {})
        if not name:
            return []
        if is_ipsec_v2_profile(data) and shutil.which('swanctl'):
            r = run_sudo(['swanctl', '--list-sas'], timeout=10, capture=True)
            if r.returncode != 0:
                return []
            ts: List[str] = []
            in_conn = False
            for line in r.stdout.splitlines():
                stripped = line.strip()
                if stripped.startswith(f"{name}:"):
                    in_conn = True
                elif re.match(r'^\S+: #\d+, ', stripped):
                    in_conn = False
                if in_conn and '===' in stripped and 'INSTALLED' in stripped:
                    m = re.search(r'===\s+(\S+)', stripped)
                    if m:
                        ts.append(m.group(1))
            return ts
        if not shutil.which('ipsec'):
            return []
        r = run_sudo(['ipsec', 'statusall'], timeout=10, capture=True)
        if r.returncode != 0:
            return []
        # statusall real: CHILD SAs usam chaves "name{n}:" — a linha INSTALLED traz o
        # estado e uma linha "local === remote" subsequente traz as TS da criança.
        ts = []
        up_children = set()
        for line in r.stdout.splitlines():
            stripped = line.strip()
            m = re.match(rf'^{re.escape(name)}\{{(\d+)\}}:', stripped)
            if not m:
                continue
            idx = m.group(1)
            if 'INSTALLED' in stripped:
                up_children.add(idx)
            m_ts = re.search(r'===\s+(\S+)', stripped)
            if m_ts and (idx in up_children or 'INSTALLED' in stripped):
                ts.append(m_ts.group(1))
        return ts

    @staticmethod
    def missing_released_routes(conf: Dict[str, Any]) -> List[str]:
        """Rotas declaradas no perfil que NÃO estão cobertas por nenhuma SA INSTALLED.

        Reproduz o caso relatado pela dev: túnel estabelecido, mas o gateway
        libera apenas parte das redes — o cliente não deve reportar sucesso pleno.
        Retorna [] se não houver rotas declaradas ou se as TS não forem parseáveis
        (evita alarme falso).
        """
        routes = [rt.strip() for rt in conf.get('data', {}).get('routes', '').split(',') if rt.strip()]
        if not routes:
            return []
        nets = []
        for ts in VPNBackend.installed_remote_ts(conf):
            try:
                nets.append(ipaddress.ip_network(ts if '/' in ts else f'{ts}/32', strict=False))
            except ValueError:
                continue
        if not nets:
            return []
        missing = []
        for rt in routes:
            try:
                net = ipaddress.ip_network(rt if '/' in rt else f'{rt}/32')
            except ValueError:
                continue
            if not any(net.version == n.version and net.subnet_of(n) for n in nets):
                missing.append(rt)
        return missing

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
