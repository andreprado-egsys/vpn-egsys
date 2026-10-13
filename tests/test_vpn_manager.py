#!/usr/bin/env python3
"""
tests/test_vpn_manager.py - Testes unitários para o núcleo de gerenciamento de VPNs.
"""

import os
import sys
import time
import base64
import tempfile
import subprocess
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
    run_sudo,
    decode_secret,
    escape_stroke_value,
    render_stroke_block,
    render_secrets_block,
    render_swanctl_block,
    apply_markers,
    strip_markers,
    is_ipsec_v1_profile,
    is_ipsec_v2_profile,
    MARK_BEGIN,
    MARK_END,
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
        self.assertIn("[IPsec/IKEv1-XAuth]", discovered["vpnsc"]["display_name"])

    def test_platform_detection(self):
        # Garante que as funções de SO retornam booleano
        self.assertIsInstance(is_macos(), bool)
        self.assertIsInstance(is_linux(), bool)


AM_V1_PROFILE = {
    'protocol': 'ipsec',
    'ipsec-type': 'ikev1-xauth',
    'server-name': '192.0.2.1',
    'user-name': '99999999999',
    'password': base64.b64encode(b'S3nha!Teste').decode(),
    'psk': base64.b64encode(b'psk-teste-9').decode(),
    'routes': '172.20.100.0/24',
}


class TestIpsecRenderers(unittest.TestCase):
    """Testes dos renderizers puros de configuração strongSwan."""

    def setUp(self):
        self.test_dir = tempfile.mkdtemp()

    def tearDown(self):
        import shutil
        shutil.rmtree(self.test_dir, ignore_errors=True)

    def test_render_stroke_block_golden(self):
        block = render_stroke_block({'vpnamssp': AM_V1_PROFILE})
        self.assertTrue(block.startswith(MARK_BEGIN))
        self.assertTrue(block.rstrip().endswith(MARK_END))
        self.assertIn('config setup\n    charondebug="ike 1, knl 1, cfg 1, esp 0"\n', block)
        expected_conn = (
            "conn vpnamssp\n"
            "    auto=add\n"
            "    keyexchange=ikev1\n"
            "    aggressive=no\n"
            "    authby=psk\n"
            "\n"
            "    ike=aes256-sha256-modp2048,aes128-sha256-modp1536!\n"
            "    esp=aes256-sha256-modp1536,aes128-sha256-modp1536!\n"
            "\n"
            "    ikelifetime=86400s\n"
            "    lifetime=43200s\n"
            "    dpdaction=restart\n"
            "    dpddelay=30s\n"
            "    dpdtimeout=120s\n"
            "\n"
            "    left=%defaultroute\n"
            "    leftauth=psk\n"
            "    leftauth2=xauth\n"
            "    leftid=%any\n"
            "    xauth_identity=99999999999\n"
            "    leftsourceip=%config\n"
            "\n"
            "    right=192.0.2.1\n"
            "    rightauth=psk\n"
            "    rightid=%any\n"
            "    rightsubnet=172.20.100.0/24\n"
            "\n"
            "    forceencaps=yes\n"
        )
        self.assertIn(expected_conn, block)

    def test_render_stroke_block_ignores_snx_and_v2(self):
        profiles = {
            'vpnro': {'protocol': 'snx', 'server-name': 'x'},
            'vpnsc': {'protocol': 'ipsec', 'ipsec-type': 'ikev2', 'server-name': 'y'},
        }
        self.assertEqual(render_stroke_block(profiles), "")

    def test_render_secrets_block_psk_and_xauth(self):
        block = render_secrets_block({'vpnamssp': AM_V1_PROFILE})
        self.assertIn(': PSK "psk-teste-9"', block)
        self.assertIn('99999999999 : XAUTH "S3nha!Teste"', block)

    def test_render_secrets_block_dedups_psk(self):
        p2 = dict(AM_V1_PROFILE)
        p2['user-name'] = 'outro'
        block = render_secrets_block({'vpna': AM_V1_PROFILE, 'vpnb': p2})
        self.assertEqual(block.count(': PSK "psk-teste-9"'), 1)

    def test_escape_stroke_value(self):
        self.assertEqual(escape_stroke_value('a"b'), 'a\\"b')
        self.assertEqual(escape_stroke_value('a\\b'), 'a\\\\b')
        self.assertEqual(escape_stroke_value('a\nb\r'), 'ab')

    def test_escape_in_rendered_secrets(self):
        prof = dict(AM_V1_PROFILE)
        prof['password'] = base64.b64encode(b'p4ss"wo\\rd').decode()
        block = render_secrets_block({'vpnxx': prof})
        self.assertIn('XAUTH "p4ss\\"wo\\\\rd"', block)
        self.assertNotIn('\n"\n', block)

    def test_decode_secret(self):
        self.assertEqual(decode_secret(base64.b64encode(b'abc').decode()), 'abc')
        self.assertEqual(decode_secret('not!!base64'), '')
        self.assertEqual(decode_secret(''), '')

    def test_render_swanctl_block_only_v2(self):
        profiles = {
            'vpnsc': {'protocol': 'ipsec', 'ipsec-type': 'ikev2',
                      'server-name': 'vpn.pm.sc.gov.br', 'user-name': 'op',
                      'password': base64.b64encode(b'senha').decode()},
            'vpnamssp': AM_V1_PROFILE,
        }
        block = render_swanctl_block(profiles)
        self.assertIn('vpnsc {', block)
        self.assertIn('version = 2', block)
        self.assertNotIn('vpnamssp', block)
        self.assertEqual(render_swanctl_block({'vpnamssp': AM_V1_PROFILE}), "")

    def test_apply_markers_replace_and_preserve(self):
        original = "config setup\n    charondebug=\"ike 1\"\n\nconn terceira\n    left=1.1.1.1\n"
        block1 = render_stroke_block({'vpna': AM_V1_PROFILE})
        out = apply_markers(original, block1)
        self.assertIn(MARK_BEGIN, out)
        self.assertIn("conn terceira", out)
        self.assertIn("config setup", out)

        block2 = render_stroke_block({'vpnb': AM_V1_PROFILE})
        out2 = apply_markers(out, block2)
        self.assertIn("conn vpnb", out2)
        self.assertNotIn("conn vpna", out2)
        self.assertEqual(out2.count(MARK_BEGIN), 1)

        # idempotência
        out3 = apply_markers(out2, block2)
        self.assertEqual(out2, out3)

    def test_strip_markers_roundtrip(self):
        original = "conn terceira\n    left=1.1.1.1\n"
        with_block = apply_markers(original, render_stroke_block({'vpna': AM_V1_PROFILE}))
        stripped = strip_markers(with_block)
        self.assertNotIn(MARK_BEGIN, stripped)
        self.assertNotIn("conn vpna", stripped)
        self.assertIn("conn terceira", stripped)
        self.assertEqual(strip_markers("nada aqui"), "nada aqui")

    @patch("core.vpn_manager.get_config_dir")
    def test_write_vpn_config_normalizes_ikev1_aliases(self, mock_cfg_dir):
        mock_cfg_dir.return_value = self.test_dir
        conf_path = write_vpn_config(
            "amssp", "192.0.2.1", "user", "cGFzcw==",
            protocol="ipsec", ipsec_type="ikev1")
        parsed = parse_vpn_config(conf_path)
        self.assertEqual(parsed['ipsec-type'], 'ikev1-xauth')
        # padrão do assinatura também é ikev1-xauth
        conf_path2 = write_vpn_config(
            "amssp2", "1.2.3.4", "user", "cGFzcw==", protocol="ipsec")
        self.assertEqual(parse_vpn_config(conf_path2)['ipsec-type'], 'ikev1-xauth')


class TestIpsecBackendLinux(unittest.TestCase):
    """VPNBackend IPsec Linux com subprocess mockado (sem tocar no sistema)."""

    def _conf(self, **over):
        data = dict(AM_V1_PROFILE)
        data.update(over)
        return {'id': data.get('_id', 'vpnamssp'), 'label': 'VPN AM SSP', 'data': data}

    @patch("core.vpn_manager.run_sudo")
    @patch("core.vpn_manager.os.path.exists")
    def test_connect_v1_uses_stroke_after_apply(self, mock_exists, mock_run):
        mock_exists.return_value = True
        ok_out = subprocess.CompletedProcess(
            [], 0,
            "  vpnamssp{2}:  INSTALLED, TUNNEL, reqid 1\n"
            "  vpnamssp{2}:   192.0.2.1/32 === 172.20.100.0/24\n", "")
        mock_run.side_effect = [
            subprocess.CompletedProcess([], 0, "", ""),        # vpn-ipsec-apply
            subprocess.CompletedProcess([], 0, "", ""),        # ipsec up
            ok_out,                                            # statusall (poll 1)
            ok_out,                                            # statusall (rotas)
        ]
        with patch("core.vpn_manager.shutil.which", return_value='/usr/bin/ipsec'):
            ok, msg = VPNBackend.connect_ipsec_linux(self._conf())
        self.assertTrue(ok)
        self.assertIn("IKEv1 XAuth/stroke", msg)
        self.assertNotIn("NÃO liberou", msg)
        cmds = [c.args[0] for c in mock_run.call_args_list]
        self.assertIn(['/usr/lib/vpn-egsys/vpn-ipsec-apply'], cmds)
        self.assertIn(['/usr/lib/vpn-egsys/vpn-ipsec-ctl', 'stroke', 'up', 'vpnamssp'], cmds)

    @patch("core.vpn_manager.run_sudo")
    @patch("core.vpn_manager.os.path.exists")
    def test_connect_v1_warns_when_gateway_withholds_route(self, mock_exists, mock_run):
        """Caso do relato da dev: SA INSTALLED mas o gateway só liberou outra rede."""
        mock_exists.return_value = True
        narrow_out = subprocess.CompletedProcess(
            [], 0,
            "  vpnamssp{2}:  INSTALLED, TUNNEL, reqid 1\n"
            "  vpnamssp{2}:   192.0.2.1/32 === 10.200.210.0/24\n", "")
        mock_run.side_effect = [
            subprocess.CompletedProcess([], 0, "", ""),
            subprocess.CompletedProcess([], 0, "", ""),
            narrow_out,
            narrow_out,
        ]
        with patch("core.vpn_manager.shutil.which", return_value='/usr/bin/ipsec'):
            ok, msg = VPNBackend.connect_ipsec_linux(self._conf())
        self.assertTrue(ok)
        self.assertIn("NÃO liberou", msg)
        self.assertIn("172.20.100.0/24", msg)

    @patch("core.vpn_manager.run_sudo")
    @patch("core.vpn_manager.os.path.exists")
    def test_connect_v1_rc0_without_sa_fails(self, mock_exists, mock_run):
        mock_exists.return_value = True
        mock_run.side_effect = [
            subprocess.CompletedProcess([], 0, "", ""),
            subprocess.CompletedProcess([], 0, "", ""),
            subprocess.CompletedProcess([], 0, "Security Associations (0 up)\n", ""),
        ] * 8
        with patch("core.vpn_manager.time.sleep"), \
             patch("core.vpn_manager.shutil.which", return_value='/usr/bin/ipsec'):
            ok, msg = VPNBackend.connect_ipsec_linux(self._conf())
        self.assertFalse(ok)
        self.assertIn("não estabeleceu", msg)

    @patch("core.vpn_manager.run_sudo")
    @patch("core.vpn_manager.os.path.exists")
    def test_connect_v2_uses_swanctl(self, mock_exists, mock_run):
        mock_exists.return_value = True
        mock_run.side_effect = [
            subprocess.CompletedProcess([], 0, "", ""),                        # apply
            subprocess.CompletedProcess([], 0, "", ""),                        # swanctl initiate
            subprocess.CompletedProcess([], 0, "  vpnsc: ESTABLISHED\n", ""),  # list-sas
            subprocess.CompletedProcess([], 0, "  vpnsc: ESTABLISHED\n", ""),  # list-sas (rotas)
        ]
        conf = self._conf(**{'ipsec-type': 'ikev2'})
        conf['id'] = 'vpnsc'
        ok, msg = VPNBackend.connect_ipsec_linux(conf)
        self.assertTrue(ok)
        self.assertIn("IKEv2/swanctl", msg)
        mock_run.assert_any_call(['/usr/lib/vpn-egsys/vpn-ipsec-ctl', 'swanctl', 'up', 'vpnsc'], timeout=40)

    @patch("core.vpn_manager.run_sudo")
    @patch("core.vpn_manager.os.path.exists")
    def test_connect_reports_apply_failure(self, mock_exists, mock_run):
        mock_exists.return_value = True
        mock_run.return_value = MagicMock(returncode=1, stdout='', stderr='perm denied')
        ok, msg = VPNBackend.connect_ipsec_linux(self._conf())
        self.assertFalse(ok)
        self.assertIn("vpn-ipsec-apply falhou", msg)

    @patch("core.vpn_manager.shutil.which", return_value=None)
    @patch("core.vpn_manager.os.path.exists", return_value=False)
    def test_connect_without_helper_or_bins(self, mock_exists, mock_which):
        ok, msg = VPNBackend.connect_ipsec_linux(self._conf())
        self.assertFalse(ok)
        self.assertIn("install.sh", msg)

    @patch("core.vpn_manager.run_sudo")
    @patch("core.vpn_manager.os.path.exists")
    def test_disconnect_v1_downs_stroke(self, mock_exists, mock_run):
        mock_exists.return_value = True
        mock_run.return_value = MagicMock(returncode=0, stdout='', stderr='')
        with patch("core.vpn_manager.shutil.which", return_value='/usr/bin/ipsec'):
            ok, msg = VPNBackend.disconnect_ipsec_linux(self._conf())
        self.assertTrue(ok)
        mock_run.assert_any_call(['/usr/lib/vpn-egsys/vpn-ipsec-ctl', 'stroke', 'down', 'vpnamssp'],
                                 timeout=15)

    @patch("core.vpn_manager.run_sudo")
    @patch("core.vpn_manager.os.path.exists", return_value=False)
    def test_disconnect_falls_back_to_raw_ipsec_without_ctl(self, mock_exists, mock_run):
        mock_run.return_value = MagicMock(returncode=0, stdout='', stderr='')
        with patch("core.vpn_manager.shutil.which", return_value='/usr/bin/ipsec'):
            ok, msg = VPNBackend.disconnect_ipsec_linux(self._conf())
        self.assertTrue(ok)
        mock_run.assert_any_call(['ipsec', 'down', 'vpnamssp'], timeout=15)

    @patch("core.vpn_manager.run_sudo")
    def test_statusall_installed_parsed(self, mock_run):
        stdout = ("Connections:\n"
                  "  vpnamssp[6]: \"vpnamssp\"[6]...INSTALLED\n"
                  "  vpnotro[1]: \"vpnotro\"[1] %out) 1.2.3.4\n")
        mock_run.return_value = MagicMock(returncode=0, stdout=stdout, stderr='')
        conf = self._conf()
        conf['id'] = 'vpnamssp'
        with patch("core.vpn_manager.shutil.which", return_value='/usr/bin/ipsec'):
            self.assertTrue(VPNBackend.is_ipsec_active_linux(conf))
            other = self._conf()
            other['id'] = 'vpnoutro'
            self.assertFalse(VPNBackend.is_ipsec_active_linux(other))
            fail = MagicMock(returncode=1, stdout='', stderr='')
            mock_run.return_value = fail
            self.assertFalse(VPNBackend.is_ipsec_active_linux(conf))


class TestRouteCoverage(unittest.TestCase):
    """Cobertura de rotas do perfil vs TS liberadas pelo gateway (caso SNX-RO relatado)."""

    def _conf(self, routes, ipsec_type='ikev1-xauth', vpn_id='vpnamssp'):
        data = dict(AM_V1_PROFILE)
        data['ipsec-type'] = ipsec_type
        data['routes'] = routes
        return {'id': vpn_id, 'label': 'VPN', 'data': data}

    @patch("core.vpn_manager.run_sudo")
    def test_installed_remote_ts_stroke(self, mock_run):
        stdout = ("      vpnamssp{6}:  INSTALLED, TUNNEL, reqid 1\n"
                  "      vpnamssp{6}:   192.0.2.1/32 === 10.200.210.0/24\n"
                  "      vpnamssp{7}:  INSTALLED, TUNNEL, reqid 2\n"
                  "      vpnamssp{7}:   192.0.2.1/32 === 198.51.100.4\n"
                  "      vpnamssp{8}:  INSTALL_ACQUIRE\n"
                  "      vpnamssp{8}:   192.0.2.1/32 === 203.0.113.0/24\n")
        mock_run.return_value = MagicMock(returncode=0, stdout=stdout, stderr='')
        with patch("core.vpn_manager.shutil.which", return_value='/usr/bin/ipsec'):
            ts = VPNBackend.installed_remote_ts(self._conf('10.200.210.0/24'))
        self.assertEqual(ts, ['10.200.210.0/24', '198.51.100.4'])

    @patch("core.vpn_manager.run_sudo")
    def test_installed_remote_ts_swanctl(self, mock_run):
        stdout = ("vpnsc: #1, ESTABLISHED, IKEv2, ...\n"
                  "  local '192.0.2.1' @ eth0\n"
                  "  remote '198.51.100.1' @ eth0\n"
                  "  192.0.2.1/32 === 172.20.100.0/24  INSTALLED, TUNNEL\n"
                  "vpnotro: #2, ESTABLISHED, IKEv2, ...\n"
                  "  192.0.2.1/32 === 10.9.9.0/24  INSTALLED, TUNNEL\n")
        mock_run.return_value = MagicMock(returncode=0, stdout=stdout, stderr='')
        with patch("core.vpn_manager.shutil.which", return_value='/usr/bin/swanctl'):
            ts = VPNBackend.installed_remote_ts(self._conf('', ipsec_type='ikev2', vpn_id='vpnsc'))
        self.assertEqual(ts, ['172.20.100.0/24'])

    def test_missing_released_routes_scenarios(self):
        cases = [
            ('172.20.100.0/24', ['172.20.100.0/24'], []),
            ('172.20.100.0/24', ['172.20.100.0/23'], []),
            ('172.20.100.0/24', ['10.200.210.0/24'], ['172.20.100.0/24']),
            ('172.20.100.0/24,10.5.0.0/16', ['10.5.0.0/16'], ['172.20.100.0/24']),
            ('172.20.100.10', ['172.20.100.0/24'], []),
            ('172.20.100.10', ['172.20.100.10'], []),
            ('', ['10.0.0.0/8'], []),
            ('172.20.100.0/24', ['garbage/999'], []),
            ('172.20.100.0/24', [], []),
        ]
        for routes, ts_list, expected in cases:
            with self.subTest(routes=routes, ts=ts_list):
                conf = self._conf(routes)
                with patch.object(VPNBackend, 'installed_remote_ts', return_value=ts_list), \
                     patch("core.vpn_manager.shutil.which", return_value='/usr/bin/ipsec'):
                    self.assertEqual(VPNBackend.missing_released_routes(conf), expected)


if __name__ == "__main__":
    unittest.main()
