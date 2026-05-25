#!/usr/bin/env bash
set -euo pipefail

tests/sandbox/run.sh '
  set -e
  source /kit/scripts/lib/log.sh
  source /kit/scripts/lib/detect.sh
  detect_os
  echo "ID=$AFK_OS_ID"
  echo "WSL=$AFK_IS_WSL"
  require_ubuntu_like
  echo REQUIRE_OK
' 2>&1 | tee /tmp/task-03.out

grep -q '^ID=ubuntu$'  /tmp/task-03.out
grep -q '^WSL=0$'      /tmp/task-03.out
grep -q '^REQUIRE_OK$' /tmp/task-03.out

echo "[verify task-03] PASS"
