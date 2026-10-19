# SESSION 2026-10-19 — Fork storm da bandeja v2.2.7 (estação prado)

> Camada 3 — gitignored na `main` de produto; arquivado no repositório privado via
> branch `private/sessions-*` pelo `/vpn-commit`.

## Objetivo
Diagnosticar por que a estação `prado` (Ubuntu 25.10, KDE X11) estava congelando navegadores e
verificar se a causa vinha dos relatórios de manutenção de 2026-10-16; corrigir em produção e
propagar a correção para o projeto-fonte.

## Diagnóstico
| Evidência | Valor |
|---|---|
| `stroke status` no `auth.log` (3 dias) | 19.700.000 chamadas (~5.500/min) |
| Forks por segundo (`/proc/stat processes`) | ~2.700 |
| Load average (12 cores) | 85–95 · 0% idle · swap 6 G |
| Causa | `GLib.idle_add(self.check_status)` + `check_status()` → `return True` |
| Prova viva | `idle_add(lambda: True)` executou 201× em 2 s |
| Liberação | `kill` do PID → load caiu imediatamente |

Registros em `vpn-tray` (`_async_connect` L241 / `_async_disconnect` L253 / `check_status` L206 da
v2.2.6, edição de 16/10 18:16). Relatórios de 16/16 **não** são a causa (sysctl/udev/VAAPI/cache/
Ferdium OK; flags do Chrome já ativas).

## Fix aplicado
1. Produção: `~/.local/bin/vpn-tray` patcheado (`return False` + shebang `/usr/bin/python3`),
   backup `.bak-20261019-125220`, tray relançado (PID final 2430790).
2. Fonte: mesmo diff em `vpn-egsys/vpn-tray`, backup `.bak-20261019-130923`.
3. Regressão: `tests/test_tray_idle.py` (AST: `idle_add` callbacks → `False`; shebang pinado).
4. `./run_tests.sh` → **44 testes · QUALITY GATE APROVADO**.

## Validação pós-fix (60 s)
- 12 chamadas `stroke status`/min · 14 forks/s · load 1,48 · 12 Gi mem disponível.

## Rastreabilidade
- Jira: PSEI-416 (task criada e concluída).
- CHANGELOG `[2.2.7] - 2026-10-19`; docs Camada 1/2 atualizados (README, ARQUITETURA,
  DESENVOLVIMENTO, ROADMAP, USO, INSTALAÇÃO).
- Pendência resolvida: `install.sh:384`, `update.sh:295` e `user-setup.sh:41` copiam o `vpn-tray`
  do projeto — sem o fix na fonte o próximo `update.sh` reverteria a correção.

## Saúde para revalidar se o sintoma voltar
```bash
grep -c 'stroke status' /var/log/auth.log   # esperado ~12/min
cat /proc/loadavg
```
