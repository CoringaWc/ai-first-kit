#!/usr/bin/env bash
set -euo pipefail

tests/sandbox/run.sh '
  set -e
  test -f /kit/commands/ai-first-init.md   && echo INIT_OK
  test -f /kit/commands/ai-first-update.md && echo UPDATE_OK
  grep -q "^description:" /kit/commands/ai-first-init.md   && echo INIT_FM_OK
  grep -q "^description:" /kit/commands/ai-first-update.md && echo UPDATE_FM_OK
' 2>&1 | tee /tmp/task-08.out

grep -q '^INIT_OK$'      /tmp/task-08.out
grep -q '^UPDATE_OK$'    /tmp/task-08.out
grep -q '^INIT_FM_OK$'   /tmp/task-08.out
grep -q '^UPDATE_FM_OK$' /tmp/task-08.out

echo "[verify task-08] PASS"
