# Política de Segurança & Relatório de Hardening Pentest — vpn-egsys

Este documento consolida a arquitetura de segurança, matriz de mitigação contra vulnerabilidades e os resultados da suíte de testes de **Pentest Black Box** (modelada no padrão de segurança do egSYS Orion).

---

## 🛡️ Matriz de Mitigações Pentest (ACH-VPN-001 a ACH-VPN-010)

| ID | Vetor de Ameaça / Vulnerabilidade | Severidade | Mecanismo de Mitigação Implementado | Teste Automatizado |
|---|---|---|---|---|
| **ACH-VPN-001** | Command Injection via ID de VPN | Crítica | Sanitização estrita do identificador via `.isalnum()`, rejeitando caracteres de controle de shell (`;`, `&`, `\|`, `$`, `` ` ``). | `test_ach_vpn_001_command_injection_neutralized` |
| **ACH-VPN-002** | Path Traversal em Arquivos de Configuração | Alta | Isolamento forçado do diretório de destino sob `~/.config/snx-rs/` com prefixação determinística `vpnXX.conf` e `realpath` checking. | `test_ach_vpn_002_path_traversal_blocked` |
| **ACH-VPN-003** | CRLF Configuration File Injection | Alta | Sanitização compulsória (`sanitize_config_value`) removendo `\r` e `\n` de todos os campos antes da escrita. | `test_ach_vpn_003_crlf_injection_neutralized` |
| **ACH-VPN-004** | Permissões Inseguras em Credenciais | Crítica | Aplicação estrita de `chmod 0600` em todo arquivo `.conf` gerado (apenas leitura/escrita pelo proprietário). | `test_ach_vpn_004_file_permissions_hardening` |
| **ACH-VPN-005** | Negação de Serviço via IDs Inválidos | Média | Validação defensiva levantando `ValueError` caso o ID resulte vazio após sanitização. | `test_ach_vpn_005_invalid_id_raises_value_error` |
| **ACH-VPN-006** | Vazamento de Segredos e Chaves no Código | Crítica | Varredura estática regex em todos os arquivos (`*.py`, `*.sh`, `*.plist`, `*.md`) bloqueando senhas e chaves privadas. | `test_ach_vpn_006_no_hardcoded_secrets_in_repo` |
| **ACH-VPN-007** | Subprocess Execution Hijacking (`shell=True`) | Alta | Proibição absoluta de `shell=True` no Python. Todas as invocações passam listas de argumentos atômicas. | `test_ach_vpn_007_no_shell_true_usage` |
| **ACH-VPN-008** | Buffer Overflow / DoS por Strings Gigantes | Média | Resiliência do parser Python tratando entradas com mais de 50.000 caracteres sem estouro de pilha. | `test_ach_vpn_008_large_payload_resilience` |
| **ACH-VPN-009** | Injeção de Parâmetros Maliciosos no CLI `vpn` | Alta | Bloqueio antecipado no parser CLI (`cmd_connect` e `cmd_remove`) rejeitando qualquer caractere especial com código de erro 1. | `test_ach_vpn_009_cli_injection_resilience` |
| **ACH-VPN-010** | XML Injection no LaunchAgent macOS | Média | Validação estrita do XML com `xml.etree.ElementTree`, garantindo integridade de sintaxe do `plist`. | `test_ach_vpn_010_macos_plist_xml_integrity` |

---

## 🧪 Execução do Quality Gate de Segurança

Para executar compulsoriamente toda a bateria de testes de segurança e pentest:

```bash
./run_tests.sh
```

Ou isoladamente via unittest:

```bash
python3 -m unittest tests/test_security_pentest.py -v
```
