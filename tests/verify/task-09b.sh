#!/usr/bin/env bash
set -euo pipefail

tests/sandbox/run.sh '
  set -e
  source /kit/scripts/lib/log.sh
  source /kit/scripts/lib/mcps.sh

  export AFK_KIT_DIR=/kit
  export AFK_OPENCODE_CONFIG=$HOME/.config/opencode/opencode.jsonc
  export AFK_MCP_REGISTRY=/kit/registry/global-mcps.json

  # First apply: file does not exist → must be created with both MCPs.
  apply_global_mcps
  test -f $AFK_OPENCODE_CONFIG && echo CREATED_OK
  python3 -c "
import json
cfg = json.load(open(\"$AFK_OPENCODE_CONFIG\"))
assert \"context7\" in cfg[\"mcp\"], cfg
assert \"github\"   in cfg[\"mcp\"], cfg
assert cfg[\"mcp\"][\"github\"].get(\"auth\") == \"oauth\", cfg[\"mcp\"][\"github\"]
print(\"MCPS_PRESENT\")
"

  # Second apply: idempotent (no change).
  before=$(sha256sum $AFK_OPENCODE_CONFIG | cut -d" " -f1)
  apply_global_mcps
  after=$(sha256sum $AFK_OPENCODE_CONFIG | cut -d" " -f1)
  [[ "$before" == "$after" ]] && echo IDEMPOTENT_OK

  # Third apply: pre-existing user key must survive.
  python3 -c "
import json
p=\"$AFK_OPENCODE_CONFIG\"
cfg=json.load(open(p))
cfg[\"theme\"]=\"opencode\"
cfg[\"mcp\"][\"my-custom\"]={\"type\":\"http\",\"url\":\"http://x\",\"enabled\":True}
json.dump(cfg, open(p, \"w\"), indent=2, sort_keys=True)
"
  apply_global_mcps
  python3 -c "
import json
cfg=json.load(open(\"$AFK_OPENCODE_CONFIG\"))
assert cfg[\"theme\"]==\"opencode\", \"user key lost\"
assert \"my-custom\" in cfg[\"mcp\"], \"user mcp lost\"
assert \"context7\" in cfg[\"mcp\"] and \"github\" in cfg[\"mcp\"], \"managed mcps lost\"
print(\"PRESERVED_OK\")
"
' 2>&1 | tee /tmp/task-09b.out

grep -q '^CREATED_OK$'     /tmp/task-09b.out
grep -q '^MCPS_PRESENT$'   /tmp/task-09b.out
grep -q '^IDEMPOTENT_OK$'  /tmp/task-09b.out
grep -q '^PRESERVED_OK$'   /tmp/task-09b.out

echo "[verify task-09b] PASS"
