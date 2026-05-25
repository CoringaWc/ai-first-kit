#!/usr/bin/env bash
# mcps.sh — merge registry/global-mcps.json into ~/.config/opencode/opencode.jsonc.
# Requires log.sh sourced first. Requires python3 on PATH (apt: python3).
#
# Behavior:
#   - If the config file does not exist: create it with the kit's MCPs.
#   - If it exists: parse it (JSONC: strip // and /* */ comments first),
#     merge MCPs under top-level "mcp" key, preserve all other keys,
#     write back as pretty JSON (we degrade JSONC -> JSON on first merge;
#     comments in user config are LOST — we warn loudly on first run).
#   - Idempotent: re-running with no registry change produces no file change.

AFK_OPENCODE_CONFIG="${AFK_OPENCODE_CONFIG:-$HOME/.config/opencode/opencode.jsonc}"
AFK_MCP_REGISTRY="${AFK_MCP_REGISTRY:-${AFK_KIT_DIR:-$HOME/.config/opencode/ai-first-kit}/registry/global-mcps.json}"

apply_global_mcps() {
  if ! command -v python3 >/dev/null 2>&1; then
    log_error "python3 required to merge MCPs into opencode config"
    return 1
  fi
  if [[ ! -f "$AFK_MCP_REGISTRY" ]]; then
    log_warn "MCP registry not found: $AFK_MCP_REGISTRY — skipping"
    return 0
  fi
  mkdir -p "$(dirname "$AFK_OPENCODE_CONFIG")"

  local existed=0
  [[ -f "$AFK_OPENCODE_CONFIG" ]] && existed=1

  AFK_OPENCODE_CONFIG="$AFK_OPENCODE_CONFIG" \
  AFK_MCP_REGISTRY="$AFK_MCP_REGISTRY" \
  python3 - <<'PY'
import json, os, re, sys

cfg_path = os.environ["AFK_OPENCODE_CONFIG"]
reg_path = os.environ["AFK_MCP_REGISTRY"]

def strip_jsonc(text):
    # Remove /* ... */ block comments
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    # Remove // line comments (not inside strings — simple heuristic)
    out_lines = []
    for line in text.splitlines():
        in_str = False
        esc = False
        cut = None
        for i, ch in enumerate(line):
            if esc:
                esc = False; continue
            if ch == "\\":
                esc = True; continue
            if ch == '"':
                in_str = not in_str; continue
            if not in_str and ch == "/" and i + 1 < len(line) and line[i+1] == "/":
                cut = i; break
        out_lines.append(line if cut is None else line[:cut])
    # Remove trailing commas (JSONC allows them)
    cleaned = "\n".join(out_lines)
    cleaned = re.sub(r",(\s*[}\]])", r"\1", cleaned)
    return cleaned

# Load existing config (or start empty)
if os.path.isfile(cfg_path):
    raw = open(cfg_path).read()
    try:
        cfg = json.loads(strip_jsonc(raw))
    except json.JSONDecodeError as e:
        print(f"[mcps] ERROR: existing config is not parseable JSONC: {e}", file=sys.stderr)
        sys.exit(2)
    if not isinstance(cfg, dict):
        print("[mcps] ERROR: existing config root is not an object", file=sys.stderr)
        sys.exit(2)
else:
    cfg = {"$schema": "https://opencode.ai/config.json"}

# Load MCP registry
with open(reg_path) as f:
    reg = json.load(f)
mcps = reg.get("mcps", [])

cfg.setdefault("mcp", {})
changed = False
for entry in mcps:
    name = entry["name"]
    transport = entry.get("transport", "http")
    block = {"type": transport, "enabled": True}
    if transport == "http":
        block["url"] = entry["url"]
    # OAuth is opencode's "auth": "oauth" — opencode handles tokens via `opencode mcp auth <name>`.
    if entry.get("auth") == "oauth":
        block["auth"] = "oauth"
    if cfg["mcp"].get(name) != block:
        cfg["mcp"][name] = block
        changed = True

# Always write back as JSON (sorted keys for stable diff)
new_text = json.dumps(cfg, indent=2, sort_keys=True) + "\n"
old_text = open(cfg_path).read() if os.path.isfile(cfg_path) else ""
if new_text != old_text:
    with open(cfg_path, "w") as f:
        f.write(new_text)
    print(f"[mcps] wrote {cfg_path} ({len(mcps)} MCPs merged)")
else:
    print(f"[mcps] no changes ({cfg_path} already in sync)")
PY

  if (( existed == 1 )); then
    log_warn "If your previous $AFK_OPENCODE_CONFIG had comments, they were stripped during merge."
  fi
  log_info "MCPs applied. For GitHub MCP, run: opencode mcp auth github"
}
