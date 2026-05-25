#!/usr/bin/env bash
set -euo pipefail

echo "[verify task-01] Building sandbox image..."
tests/sandbox/run.sh 'echo SANDBOX_OK && python3 --version' | tee /tmp/task-01.out

grep -q '^SANDBOX_OK$' /tmp/task-01.out
grep -q '^Python 3'   /tmp/task-01.out
echo "[verify task-01] PASS"
