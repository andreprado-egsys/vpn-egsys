#!/usr/bin/env python3
"""
tests/test_vpn_manager.py - Testes unitários para o núcleo de gerenciamento de VPNs.
"""

import os
import tempfile
import unittest
from unittest.mock import patch, MagicMock

import sys
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from core.vpn_manager import (
    parse_vpn_config,
    write_vpn_config,
    discover_vpns,
    VPNBackend,
    is_macos,
    is_linux,
)


class TestVPNManager(unittest.TestCase):

    def setUp(self):
        self.test_dir = tempfile.mkdtemp()

    def tearDown(self):
        import shutil
        shutil.rmtree(self.test_dir, ignore_errors=True)

    def test_parse_snx_config(self):
        conf_file = os.path.join(self.test_dir, "vpnro.conf")
        with open(conf_file, "w") as f:
            f.write("server-name=131.72.155.42\n")
            f.write("user-name=andre.prado\n")
            f.write("password=bXlzZWNyZXRwYXNz\n")
            f.write("ignore-server-cert=true\n")
            f.write("login-type=vpn\n")

        parsed = parse_vpn_config(conf_file)
        self.assertEqual(parsed["protocol"], "snx")
        self.assertEqual(parsed["server-name"], "131.72.155.42")
        self.assertEqual(parsed["user-name"], "andre.prado")
        self.assertEqual(parsed["login-type"], "vpn")

    def test_parse_ipsec_config(self):
        conf_file = os.path.join(self.test_dir, "vpnsc.conf")
        with open(conf_file, "w") as f:
            f.write("protocol=ipsec\n")
            f.write("server-name=vpn.pm.sc.gov.br\n")
            f.write("user-name=operador\n")
            f.write("password=c2VuaGFpcHNlYw==\n")
            f.write("ipsec-type=ikev2\n")
            f.write("routes=10.0.0.0/8,172.20.0.0/16\n")

        parsed = parse_vpn_config(conf_file)
        self.assertEqual(parsed["protocol"], "ipsec")
        self.assertEqual(parsed["server-name"], "vpn.pm.sc.gov.br")
        self.assertEqual(parsed["user-name"], "operador")
        self.assertEqual(parsed["ipsec-type"], "ikev2")
        self.assertEqual(parsed["routes"], "10.0.0.0/8,172.20.0.0/16")

    @patch("core.vpn_manager.get_config_dir")
    def test_write_vpn_config_permissions_and_content(self, mock_get_cfg_dir):
        mock_get_cfg_dir.return_value = self.test_dir

        conf_path = write_vpn_config(
            vpn_id="to",
            server="vpn.to.gov.br",
            user="andre",
            password_b64="cGFzczEyMw==",
            protocol="ipsec",
            ipsec_type="ikev2",
            routes="10.10.0.0/16"
        )

        self.assertTrue(os.path.exists(conf_path))
        self.assertTrue(conf_path.endswith("vpnto.conf"))

        # Valida permissões 0600
        mode = oct(os.stat(conf_path).st_mode & 0o777)
        self.assertEqual(mode, "0o600")

        # Valida conteúdo parseado
        parsed = parse_vpn_config(conf_path)
        self.assertEqual(parsed["protocol"], "ipsec")
        self.assertEqual(parsed["server-name"], "vpn.to.gov.br")
        self.assertEqual(parsed["user-name"], "andre")
        self.assertEqual(parsed["routes"], "10.10.0.0/16")

    @patch("core.vpn_manager.get_config_dir")
    def test_discover_vpns_multi_protocol(self, mock_get_cfg_dir):
        mock_get_cfg_dir.return_value = self.test_dir

        # Cria 1 SNX e 1 IPsec
        write_vpn_config("ro", "131.72.155.42", "user_ro", "cGFzcw==", protocol="snx")
        write_vpn_config("sc", "vpn.pm.sc.gov.br", "user_sc", "cGFzcw==", protocol="ipsec")

        discovered = discover_vpns()
        self.assertIn("vpnro", discovered)
        self.assertIn("vpnsc", discovered)

        self.assertEqual(discovered["vpnro"]["protocol"], "snx")
        self.assertEqual(discovered["vpnsc"]["protocol"], "ipsec")
        self.assertIn("[SNX]", discovered["vpnro"]["display_name"])
        self.assertIn("[IPsec]", discovered["vpnsc"]["display_name"])

    def test_platform_detection(self):
        # Garante que as funções de SO retornam booleano
        self.assertIsInstance(is_macos(), bool)
        self.assertIsInstance(is_linux(), bool)


if __name__ == "__main__":
    unittest.main()
