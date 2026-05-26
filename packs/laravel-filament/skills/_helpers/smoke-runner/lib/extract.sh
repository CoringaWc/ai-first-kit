#!/usr/bin/env bash
# shellcheck shell=bash
# Extract bash code blocks from the "## Workflow" section of a SKILL.md.
# Concatenates them in order with shared shell state preserved.
#
# Usage:
#   extract_workflow_bash <SKILL.md path>  -> prints concatenated script to stdout
#
# Strategy: a tiny python3 script. Avoids fragile awk/sed for fenced block parsing.

extract_workflow_bash() {
    local skill="$1"
    python3 - "$skill" <<'PY'
import sys, re, pathlib
p = pathlib.Path(sys.argv[1])
text = p.read_text(encoding='utf-8')

# Slice from "## Workflow" up to next top-level "## " heading.
m = re.search(r'(?ms)^## Workflow\b.*?(?=^## )', text)
if not m:
    sys.exit(f"no Workflow section in {p}")
section = m.group(0)

# Pull every ```bash ... ``` block in order.
blocks = re.findall(r'```bash\s*\n(.*?)```', section, flags=re.DOTALL)
if not blocks:
    sys.exit(f"no bash blocks in Workflow of {p}")

# Concatenate with separator comments for debug.
out = []
for i, b in enumerate(blocks, 1):
    out.append(f"# --- workflow block {i} from {p.name} ---")
    out.append(b.rstrip())
print("\n".join(out))
PY
}
