#!/usr/bin/env bash
# Verifica estrutura mínima de uma SKILL.md
# Uso: ./verify-skill.sh .agents/skills/<slug>/SKILL.md

set -euo pipefail

SKILL="${1:?path para SKILL.md obrigatório}"
[[ -f "$SKILL" ]] || { echo "FAIL: $SKILL não existe"; exit 1; }

# Frontmatter presente (tolerante a CRLF e BOM)
head -1 "$SKILL" | tr -d '\r\357\273\277' | grep -qx -- '---' || { echo "FAIL: frontmatter ausente"; exit 1; }

# Seções obrigatórias (ancoradas no início da linha)
for section in "## Consistency First" "## Quick Reference" "## Workflow" "## Anti-Patterns" "## Verification" "## Related"; do
  grep -qE "^${section}( |\$)" "$SKILL" || { echo "FAIL: falta seção '$section'"; exit 1; }
done

# PyYAML disponível?
python3 -c 'import yaml' 2>/dev/null || { echo "FAIL: PyYAML necessário (apt install python3-yaml ou pip install pyyaml)"; exit 1; }

# Frontmatter válido (path via argv — sem injeção)
python3 - "$SKILL" <<'PY'
import sys, yaml
path = sys.argv[1]
with open(path) as f:
    content = f.read()
parts = content.split('---', 2)
if len(parts) < 3:
    sys.exit('FAIL: frontmatter malformado')
fm = yaml.safe_load(parts[1])
for k in ('name', 'description', 'license', 'metadata'):
    if k not in fm:
        sys.exit(f'FAIL: frontmatter sem {k}')
if not isinstance(fm.get('metadata'), dict):
    sys.exit('FAIL: metadata deve ser objeto')
print('OK: frontmatter válido')
PY

# Verifica ordem das seções
python3 - "$SKILL" <<'PY'
import sys
path = sys.argv[1]
with open(path) as f:
    lines = f.read().splitlines()
expected = ["## Consistency First", "## Quick Reference", "## Workflow", "## Anti-Patterns", "## Verification", "## Related"]
found = [l.rstrip() for l in lines if l.startswith("## ") and l.rstrip() in expected]
if found != expected:
    sys.exit(f'FAIL: ordem das seções incorreta. Esperado {expected}, encontrado {found}')
print('OK: ordem das seções correta')
PY

# Tamanho razoável
LINES=$(wc -l < "$SKILL")
if [[ $LINES -gt 200 ]]; then
  echo "WARN: SKILL.md tem $LINES linhas (>200). Considere mover detalhes para rules/<topico>.md"
fi

echo "OK: $SKILL"
