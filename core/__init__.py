"""core - Pacote de gerenciamento unificado do vpn-egsys."""
from .vpn_manager import (
    discover_vpns,
    connect_vpn,
    disconnect_all,
    get_active_vpn,
    write_vpn_config,
    parse_vpn_config,
    is_macos,
    is_linux,
    get_config_dir,
    VPNBackend,
)

__all__ = [
    'discover_vpns',
    'connect_vpn',
    'disconnect_all',
    'get_active_vpn',
    'write_vpn_config',
    'parse_vpn_config',
    'is_macos',
    'is_linux',
    'get_config_dir',
    'VPNBackend',
]
