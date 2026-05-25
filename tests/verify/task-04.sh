#!/usr/bin/env bash
set -euo pipefail

# We do not actually download Node/mise/opencode here (heavyweight). We verify:
#  - ensure_apt_pkg is idempotent for an installed package (no sudo needed).
#  - ensure_node_lts returns 0 when a satisfying `node` is already on PATH.
#  - The bail-out logic respects PATH, not just `command -v`.
tests/sandbox/run.sh '
  set -e
  source /kit/scripts/lib/log.sh
  source /kit/scripts/lib/detect.sh
  source /kit/scripts/lib/deps.sh

  ensure_apt_pkg bash
  echo APT_NOOP_OK

  mkdir -p /tmp/fakebin
  cat > /tmp/fakebin/node <<EOS
#!/usr/bin/env bash
case "\$1" in
  --version) echo v22.0.0 ;;
  -p) echo 22 ;;
esac
EOS
  chmod +x /tmp/fakebin/node
  PATH="/tmp/fakebin:$PATH" ensure_node_lts
  echo NODE_OK
' 2>&1 | tee /tmp/task-04.out

grep -q '^APT_NOOP_OK$' /tmp/task-04.out
grep -q '^NODE_OK$'     /tmp/task-04.out

echo "[verify task-04] PASS"
