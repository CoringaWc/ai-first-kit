#!/usr/bin/env bash
set -euo pipefail

test -f LICENSE
grep -q "MIT License" LICENSE
grep -q "ai-first-kit" README.md
grep -q "## Status" README.md
grep -q "Not yet implemented" README.md
grep -q "git clone https://github.com/coringawc/ai-first-kit.git" README.md

echo "[verify task-00] PASS"
