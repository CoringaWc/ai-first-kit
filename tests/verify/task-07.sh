#!/usr/bin/env bash
set -euo pipefail

tests/sandbox/run.sh '
  set -e
  python3 - <<PY
import os, re, sys
ROOT = "/kit/skills"
expected = ["ai-first-bootstrap","ai-first-init","ai-first-update","ai-first-manage-skills"]
for name in expected:
    path = os.path.join(ROOT, name, "SKILL.md")
    assert os.path.isfile(path), f"missing {path}"
    body = open(path).read()
    m = re.search(r"^---\s*\nname:\s*(\S+)\s*\ndescription:\s*(.+?)\n---", body, re.S|re.M)
    assert m, f"no frontmatter in {path}"
    assert m.group(1) == name, f"name mismatch in {path}: got {m.group(1)}"
    assert len(m.group(2).strip()) > 20, f"description too short in {path}"
    print(f"OK {name}")
PY
' 2>&1 | tee /tmp/task-07.out

grep -q '^OK ai-first-bootstrap$'      /tmp/task-07.out
grep -q '^OK ai-first-init$'           /tmp/task-07.out
grep -q '^OK ai-first-update$'         /tmp/task-07.out
grep -q '^OK ai-first-manage-skills$'  /tmp/task-07.out

echo "[verify task-07] PASS"
