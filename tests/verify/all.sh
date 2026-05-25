#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

for v in tests/verify/task-*.sh; do
  echo
  echo "===== $v ====="
  "$v"
done

echo
echo "[verify all] ALL TASKS PASS"
