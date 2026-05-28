#!/usr/bin/env bash
# Enable the optional pt_BR metadata overlay for OpenCode command descriptions.

set -euo pipefail

CONFIG_PATH="${1:-$HOME/.config/opencode/opencode.jsonc}"
CONFIG_DIR="$(cd "$(dirname "$CONFIG_PATH")" && pwd)"

required_plugins=(
  "./plugins/pt-br-metadata.js"
  "./plugins/plugin-display-names.js"
)

for plugin in "${required_plugins[@]}"; do
  plugin_path="$CONFIG_DIR/${plugin#./}"
  if [[ ! -f "$plugin_path" ]]; then
    echo "[err ] required plugin file not found: $plugin_path" >&2
    exit 1
  fi
done

python3 - "$CONFIG_PATH" <<'PY'
import json
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
required = ["./plugins/pt-br-metadata.js", "./plugins/plugin-display-names.js"]

raw = config_path.read_text(encoding="utf-8")
try:
    data = json.loads(raw)
except json.JSONDecodeError as exc:
    raise SystemExit(f"[err ] {config_path} must be valid JSON/JSONC without comments for this command: {exc}")

plugins = data.get("plugin")
if plugins is None:
    plugins = []
elif not isinstance(plugins, list):
    raise SystemExit("[err ] opencode config field 'plugin' must be an array")

existing_names = set()
for entry in plugins:
    if isinstance(entry, str):
        existing_names.add(entry)
    elif isinstance(entry, list) and entry:
        existing_names.add(entry[0])

for plugin in required:
    if plugin not in existing_names:
        plugins.append(plugin)

data["plugin"] = plugins
config_path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"[ok  ] enabled pt_BR metadata overlay in {config_path}")
PY

echo "[info] restart opencode for plugin config changes to take effect"
