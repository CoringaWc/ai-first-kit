#!/usr/bin/env bash
# mcps.sh — merge registry/global-mcps.json into ~/.config/opencode/opencode.jsonc.
# Requires log.sh sourced first. Requires python3 + python3-json5 on PATH.
#
# Behavior:
#   - If the config file does not exist: create it with the kit's MCPs.
#   - If it exists: parse it via json5 (handles // and /* */ comments),
#     merge MCPs under top-level "mcp" key, preserve all other keys,
#     write back as pretty JSON. If the original contained comments,
#     a timestamped backup is created and the user is warned BEFORE the
#     destructive overwrite.
#   - Idempotent: re-running with no registry change produces no file change.

AFK_OPENCODE_CONFIG="${AFK_OPENCODE_CONFIG:-$HOME/.config/opencode/opencode.jsonc}"
AFK_MCP_REGISTRY="${AFK_MCP_REGISTRY:-${AFK_KIT_DIR:-$HOME/.config/opencode/ai-first-kit}/registry/global-mcps.json}"

apply_global_mcps() {
  if ! command -v python3 >/dev/null 2>&1; then
    log_error "python3 required to merge MCPs into opencode config"
    return 1
  fi
  if ! python3 -c "import json5" >/dev/null 2>&1; then
    log_error "python3-json5 required (apt install python3-json5)"
    return 1
  fi
  if [[ ! -f "$AFK_MCP_REGISTRY" ]]; then
    log_warn "MCP registry not found: $AFK_MCP_REGISTRY — skipping"
    return 0
  fi
  mkdir -p "$(dirname "$AFK_OPENCODE_CONFIG")"

  AFK_OPENCODE_CONFIG="$AFK_OPENCODE_CONFIG" \
  AFK_MCP_REGISTRY="$AFK_MCP_REGISTRY" \
  python3 - <<'PY'
import json, os, re, sys, datetime
import json5

cfg_path = os.environ["AFK_OPENCODE_CONFIG"]
reg_path = os.environ["AFK_MCP_REGISTRY"]

def _has_comments(raw: str) -> bool:
    # Detects // and /* */ outside of double-quoted strings.
    in_str = False
    esc = False
    i = 0
    while i < len(raw):
        ch = raw[i]
        if esc:
            esc = False; i += 1; continue
        if ch == "\\":
            esc = True; i += 1; continue
        if ch == '"':
            in_str = not in_str; i += 1; continue
        if not in_str and ch == "/" and i + 1 < len(raw):
            nxt = raw[i+1]
            if nxt == "/" or nxt == "*":
                return True
        i += 1
    return False

# Load existing config (or start empty)
if os.path.isfile(cfg_path):
    raw = open(cfg_path).read()
    has_comments = _has_comments(raw)
    try:
        cfg = json5.loads(raw)
    except Exception as e:
        print(f"[mcps] ERROR: existing config is not parseable JSON/JSONC: {e}", file=sys.stderr)
        sys.exit(2)
    if not isinstance(cfg, dict):
        print("[mcps] ERROR: existing config root is not an object", file=sys.stderr)
        sys.exit(2)
else:
    raw = ""
    has_comments = False
    cfg = {"$schema": "https://opencode.ai/config.json"}

# Load MCP registry
with open(reg_path) as f:
    reg = json.load(f)
mcps = reg.get("mcps", [])

cfg.setdefault("mcp", {})
for entry in mcps:
    name = entry["name"]
    transport = entry.get("transport", "http")
    block = {"type": transport, "enabled": True}
    if transport == "http":
        block["url"] = entry["url"]
    if entry.get("auth") == "oauth":
        block["auth"] = "oauth"
    cfg["mcp"][name] = block  # final assignment; diff check below decides whether to write

new_text = json.dumps(cfg, indent=2, sort_keys=True) + "\n"
old_text = raw

if new_text == old_text:
    print(f"[mcps] no changes ({cfg_path} already in sync)")
    sys.exit(0)

# Destructive write incoming. If the original had comments, back up first
# and warn the user BEFORE we touch the file.
if has_comments:
    ts = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_path = f"{cfg_path}.bak-{ts}"
    with open(backup_path, "w") as f:
        f.write(raw)
    print(f"[mcps] WARN: original config had comments; backed up to {backup_path}", file=sys.stderr)
    print(f"[mcps] WARN: comments will not be preserved in the rewritten file.", file=sys.stderr)

with open(cfg_path, "w") as f:
    f.write(new_text)
print(f"[mcps] wrote {cfg_path} ({len(mcps)} MCPs merged)")
PY

  log_info "MCPs applied. For GitHub MCP, run: opencode mcp auth github"
}
