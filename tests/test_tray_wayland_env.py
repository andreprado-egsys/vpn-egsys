#!/usr/bin/env python3
"""
tests/test_tray_wayland_env.py - Regressão: autodetecção de ambiente gráfico do
vpn-tray (XDG_RUNTIME_DIR, WAYLAND_DISPLAY, D-Bus) e registro do StatusNotifierItem.

Contexto (2026-10-28, CachyOS/KDE Wayland): o tray partia do pressuposto de que
DISPLAY existe. Sem variáveis de sessão (relançamento via autostart/systemd, shell
limpo) ele abortava mesmo havendo sessão Wayland real, e dois usuários na mesma
máquina registravam o mesmo id 'vpn-monitor' no StatusNotifier — o segundo some da
bandeja. O IconTheme também não conhecia ICON_DIR, então o ícone só aparecia se o
svg já estivesse instalado no tema hicolor.
"""

import ast
import os
import re
import unittest

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TRAY_PATH = os.path.join(PROJECT_ROOT, "vpn-tray")
FAKE_UID = 4321


def _tray_source():
    with open(TRAY_PATH, "r", encoding="utf-8") as f:
        return f.read()


def _setup_display_source():
    tree = ast.parse(_tray_source())
    for node in ast.walk(tree):
        if isinstance(node, ast.FunctionDef) and node.name == "setup_display":
            return ast.get_source_segment(_tray_source(), node)
    raise AssertionError("vpn-tray: função setup_display não encontrada")


class _FakePath:
    def __init__(self, exists_paths):
        self._exists = set(exists_paths)

    def exists(self, path):
        return path in self._exists

    def join(self, *parts):
        return os.path.join(*parts)

    def basename(self, path):
        return os.path.basename(path)


class _FakeOS:
    def __init__(self, environ, exists_paths):
        self.environ = environ
        self.getuid = lambda: FAKE_UID
        self.path = _FakePath(exists_paths)


class _FakeGlob:
    """Mapeia os padrões reais do tray para um sistema de arquivos sintético."""

    def __init__(self, sockets):
        self._sockets = sockets

    def glob(self, pattern):
        if pattern.startswith("/tmp/.X11-unix/"):
            return [s for s in self._sockets if s.startswith("/tmp/.X11-unix/X")]
        runtime = "/run/user/%d/" % FAKE_UID
        if pattern.startswith(runtime):
            return [s for s in self._sockets if s.startswith(runtime)]
        return []


class _FakeSys:
    @staticmethod
    def exit(code=0):
        raise SystemExit(code)

    class _Err:
        def write(self, *_a):
            pass
    stderr = _Err()

    @staticmethod
    def print(*_a, **_k):
        pass


def _run_setup_display(sockets, environ):
    """Executa setup_display isolado e retorna o ambiente resultante."""
    src = _setup_display_source()
    exists = set(sockets) | {"/run/user/%d" % FAKE_UID, "/run/user/%d/bus" % FAKE_UID}
    env = dict(environ)
    ns = {
        "os": _FakeOS(env, exists),
        "glob": _FakeGlob(sockets),
        "sys": _FakeSys,
    }
    exec(compile(src, "vpn-tray", "exec"), ns)
    ns["setup_display"]()
    return env


class TestTrayWaylandEnv(unittest.TestCase):

    def test_xdg_runtime_dir_is_derived_from_uid(self):
        env = _run_setup_display(["/run/user/%d/wayland-0" % FAKE_UID], {})
        self.assertEqual(env.get("XDG_RUNTIME_DIR"), "/run/user/%d" % FAKE_UID)

    def test_wayland_display_discovered_without_x11(self):
        """Sessão Wayland pura (KDE) não pode mais derrubar o tray por falta de DISPLAY."""
        sockets = ["/run/user/%d/wayland-0" % FAKE_UID,
                   "/run/user/%d/wayland-0.lock" % FAKE_UID]
        env = _run_setup_display(sockets, {})
        self.assertEqual(env.get("WAYLAND_DISPLAY"), "wayland-0")
        self.assertNotIn("DISPLAY", env)
        self.assertEqual(env.get("DBUS_SESSION_BUS_ADDRESS"),
                         "unix:path=/run/user/%d/bus" % FAKE_UID)

    def test_lock_file_is_not_a_socket(self):
        sockets = ["/run/user/%d/wayland-1.lock" % FAKE_UID]
        with self.assertRaises(SystemExit):
            _run_setup_display(sockets, {})

    def test_aborts_without_x11_and_without_wayland(self):
        with self.assertRaises(SystemExit):
            _run_setup_display([], {})

    def test_existing_values_are_respected(self):
        env = _run_setup_display(["/tmp/.X11-unix/X9"],
                                 {"DISPLAY": ":1", "WAYLAND_DISPLAY": "wayland-3",
                                  "XDG_RUNTIME_DIR": "/run/user/1000"})
        self.assertEqual(env["DISPLAY"], ":1")
        self.assertEqual(env["WAYLAND_DISPLAY"], "wayland-3")
        self.assertEqual(env["XDG_RUNTIME_DIR"], "/run/user/1000")

    def test_indicator_id_is_unique_per_uid(self):
        """Dois usuários na mesma máquina precisam de StatusNotifierItem distintos."""
        self.assertRegex(
            _tray_source(),
            r"new_with_path\(\s*\n?\s*f'vpn-monitor-\{os\.getuid\(\)\}'",
            "vpn-tray: id do AppIndicator deve carregar o uid",
        )

    def test_icon_dir_registered_before_theme_lookup(self):
        source = _tray_source()
        append = source.find("theme.append_search_path(ICON_DIR)")
        lookup = source.find("theme.has_icon(")
        self.assertGreater(append, -1, "vpn-tray: ICON_DIR não é registrado no IconTheme")
        self.assertLess(append, lookup,
                        "vpn-tray: registro do ICON_DIR deve anteceder a busca de ícone")


if __name__ == "__main__":
    unittest.main()
