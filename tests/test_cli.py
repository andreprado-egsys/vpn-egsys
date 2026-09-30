#!/usr/bin/env python3
"""
tests/test_cli.py - Testes de integração do comando de linha de comando 'vpn'.
"""

import os
import sys
import subprocess
import unittest

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VPN_BIN = os.path.join(PROJECT_ROOT, "vpn")


class TestVPNCLI(unittest.TestCase):

    def test_cli_help(self):
        res = subprocess.run([VPN_BIN, "--help"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0)
        self.assertIn("Gerenciador Universal de VPNs egSYS", res.stdout)
        self.assertIn("list", res.stdout)
        self.assertIn("connect", res.stdout)
        self.assertIn("disconnect", res.stdout)
        self.assertIn("status", res.stdout)

    def test_cli_list(self):
        res = subprocess.run([VPN_BIN, "list"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0)
        self.assertIn("VPNs Configuradas (egSYS)", res.stdout)

    def test_cli_status(self):
        res = subprocess.run([VPN_BIN, "status"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0)
        self.assertIn("Status de Conectividade VPN", res.stdout)


if __name__ == "__main__":
    unittest.main()
