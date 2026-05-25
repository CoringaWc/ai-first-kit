#!/usr/bin/env bash
set -euo pipefail

tests/sandbox/run.sh '
  set -e
  python3 - <<PY
import json
for path, key in [
  ("/kit/registry/global-skills.json", "skills"),
  ("/kit/registry/global-mcps.json",   "mcps"),
  ("/kit/registry/global-tools.json",  "tools"),
]:
  with open(path) as f: data = json.load(f)
  assert key in data and isinstance(data[key], list) and data[key], f"missing {key} in {path}"
  print(f"OK {path} {len(data[key])} entries")

# Validate skill source format: <owner>/<repo>@<skill>
import re
with open("/kit/registry/global-skills.json") as f:
  skills = json.load(f)["skills"]
pat = re.compile(r"^[\w.-]+/[\w.-]+@[\w.-]+$")
for s in skills:
  assert pat.match(s["source"]), f"bad source: {s}"
print(f"OK skill sources match <owner>/<repo>@<skill>")
PY
' 2>&1 | tee /tmp/task-05.out

grep -q 'OK /kit/registry/global-skills.json' /tmp/task-05.out
grep -q 'OK /kit/registry/global-mcps.json'   /tmp/task-05.out
grep -q 'OK /kit/registry/global-tools.json'  /tmp/task-05.out
grep -q 'OK skill sources match'              /tmp/task-05.out

echo "[verify task-05] PASS"
