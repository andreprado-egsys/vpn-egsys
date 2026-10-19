#!/usr/bin/env python3
"""
tests/test_tray_bus_env.py - Regressão: o relançamento do vpn-tray em
install.sh/update.sh deve normalizar DBUS_SESSION_BUS_ADDRESS.

Contexto (2026-10-19, CachyOS/KDE): libdbus rejeita endereço sem o separador
":" (ex.: /run/user/1000/bus) e o ayatana cai para XEmbed sem erro visível
quando o stderr é descartado — o tray fica sem StatusNotifierItem e o menu
deixa de ser acessível via D-Bus. Os scripts agora compõem BUS_ADDR com
prefixo unix:path= e fallback /run/user/<uid>/bus antes do nohup.
"""

import os
import re
import subprocess
import unittest

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = ("install.sh", "update.sh")

_BLOCK_RE = re.compile(
    r'BUS_ADDR="\$\{DBUS_SESSION_BUS_ADDRESS:-\}".*?\nfi\n', re.DOTALL
)


def _read(script):
    with open(os.path.join(PROJECT_ROOT, script), "r", encoding="utf-8") as f:
        return f.read()


class TestTrayBusEnv(unittest.TestCase):

    def test_normalizer_block_present(self):
        """Todo script com relançamento do tray deve normalizar o bus antes do nohup."""
        for script in SCRIPTS:
            source = _read(script)
            self.assertIsNotNone(
                _BLOCK_RE.search(source),
                f"{script}: bloco de normalização de BUS_ADDR ausente",
            )
            nohup = re.search(r'nohup "\$LOCAL_BIN/vpn-tray"', source)
            block = _BLOCK_RE.search(source)
            self.assertLess(
                block.start(), nohup.start(),
                f"{script}: normalização deve vir antes do nohup do vpn-tray",
            )
            self.assertIn('DBUS_SESSION_BUS_ADDRESS="$BUS_ADDR"', source,
                          f"{script}: sudo do tray deve usar BUS_ADDR normalizado")

    def _run_block(self, env):
        """Executa o bloco extraído de update.sh em bash e retorna BUS_ADDR."""
        block = _BLOCK_RE.search(_read("update.sh")).group(0)
        proc = subprocess.run(
            ["bash", "-c", block + 'echo "$BUS_ADDR"'],
            capture_output=True, text=True, env=env, check=True,
        )
        return proc.stdout.strip()

    def test_raw_path_gets_unix_prefix(self):
        uid = os.getuid()
        env = {"PATH": "/usr/bin:/bin", "TARGET_USER": os.getlogin(),
               "DBUS_SESSION_BUS_ADDRESS": "/run/user/%d/bus" % uid}
        self.assertEqual(self._run_block(env), "unix:path=/run/user/%d/bus" % uid)

    def test_valid_address_passes_through(self):
        env = {"PATH": "/usr/bin:/bin", "TARGET_USER": os.getlogin(),
               "DBUS_SESSION_BUS_ADDRESS": "unix:path=/run/user/1000/bus"}
        self.assertEqual(self._run_block(env), "unix:path=/run/user/1000/bus")

    def test_missing_address_builds_runtime_dir(self):
        env = {"PATH": "/usr/bin:/bin", "TARGET_USER": os.getlogin()}
        addr = self._run_block(env)
        self.assertRegex(addr, r"^unix:path=/run/user/\d+/bus$")


if __name__ == "__main__":
    unittest.main()
