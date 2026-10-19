#!/usr/bin/env python3
"""
tests/test_tray_idle.py - Regressão: callbacks registrados em GLib.idle_add
devem retornar False.

Contexto (2026-10-19): check_status retornava True e era registrado via
GLib.idle_add(self.check_status) em on_connect/on_disconnect. Em GLib, True
re-agenda o source para sempre, gerando um loop infinito de threads ->
get_active_vpn() -> sudo vpn-ipsec-ctl stroke status (fork storm de ~5.500
chamadas/min, load 95 em 12 cores, estação inutilizável).
"""

import ast
import os
import unittest

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TRAY_PATH = os.path.join(PROJECT_ROOT, "vpn-tray")


def _idle_callback_names(tree):
    """Nomes de métodos passados diretamente a GLib.idle_add(self.<nome>)."""
    names = set()
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        func = node.func
        if isinstance(func, ast.Attribute) and func.attr == "idle_add" and node.args:
            first = node.args[0]
            if isinstance(first, ast.Attribute):
                names.add(first.attr)
    return names


def _method_returns(tree, method_name):
    """Valores literários retornados pelo método (None se só cai no fim)."""
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name == method_name:
            return [
                ast.literal_eval(r.value)
                for r in ast.walk(node)
                if isinstance(r, ast.Return) and r.value is not None
                and isinstance(r.value, ast.Constant)
            ]
    return []


class TestTrayIdleCallback(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        with open(TRAY_PATH, "r", encoding="utf-8") as f:
            cls.source = f.read()
        cls.tree = ast.parse(cls.source)

    def test_idle_callbacks_exist(self):
        """Sanidade: o tray registra callbacks em idle_add (fonte do bug)."""
        names = _idle_callback_names(self.tree)
        self.assertIn("check_status", names)
        self.assertIn("_apply_status", names)

    def test_idle_callbacks_must_return_false(self):
        """Todo callback registrado em GLib.idle_add(self.X) deve retornar False.

        True mantém o source ativo e o GLib o re-invoca continuamente — em
        check_status isso disparava uma thread + subprocesso sudo por passo.
        """
        for name in sorted(_idle_callback_names(self.tree)):
            returns = _method_returns(self.tree, name)
            self.assertTrue(returns, f"{name}: nenhum return literal encontrado")
            self.assertNotIn(
                True, returns,
                f"{name} retorna True e é registrado em GLib.idle_add — "
                "isso re-agenda o callback para sempre (fork storm)",
            )

    def test_shebang_pins_system_python(self):
        """#!/usr/bin/env python3 resolve para o python do linuxbrew no PATH da
        estação, que não tem PyGObject — o tray morre no import gi."""
        self.assertTrue(self.source.startswith("#!/usr/bin/python3"),
                        "vpn-tray deve pinar o interpretador do sistema")


if __name__ == "__main__":
    unittest.main()
