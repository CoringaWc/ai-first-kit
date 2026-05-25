#!/usr/bin/env bash
# discovery.sh — proves opencode actually sees the kit's skills, commands, and
# MCPs after a fresh, network-enabled bootstrap inside a clean sandbox.
#
# This test is NOT part of tests/verify/all.sh because:
#   - It requires outbound network (git clone, npm registry, opencode install).
#   - It runs `opencode run` for skills/commands probes and is slow.
#
# Discovery strategy by layer:
#   - Filesystem  : ls + grep on opencode.jsonc (fast, deterministic)
#   - MCPs        : parse `opencode mcp list` output (deterministic; the CLI
#                   actually loads them through opencode's own loader, so a
#                   server appearing here proves opencode loaded it — even if
#                   the connection itself failed downstream like github
#                   needing OAuth)
#   - Skills      : ask the agent to list ai-first-* skills (opencode injects
#                   them into the system prompt at session start; no CLI
#                   subcommand exists to enumerate them). Retried once on
#                   transient failure since the agent can sometimes refuse
#                   filesystem-probing tool calls.
#   - Commands    : same as skills.
#
# Run manually:
#   tests/verify/discovery.sh
set -euo pipefail

echo "[discovery] launching sandbox bootstrap + opencode discovery probes..."

tests/sandbox/run.sh '
  set -euo pipefail

  # ---------- 1. Full non-interactive bootstrap ----------
  sudo apt-get update -qq
  sudo apt-get install -y -qq git curl ca-certificates python3 python3-json5 >/dev/null
  export AFK_NONINTERACTIVE=1
  bash /kit/scripts/bootstrap.sh

  # ---------- 2. Make opencode discoverable on PATH ----------
  export PATH="$HOME/.opencode/bin:$HOME/.local/share/mise/shims:$PATH"
  if [ -x "$HOME/.local/bin/mise" ]; then
    eval "$($HOME/.local/bin/mise activate bash 2>/dev/null || true)"
  fi
  if ! command -v opencode >/dev/null 2>&1; then
    echo "[discovery] FAIL: opencode not on PATH after bootstrap" >&2
    echo "PATH=$PATH" >&2
    exit 1
  fi
  echo "[discovery] opencode resolved to: $(command -v opencode)"
  opencode --version || true

  # ---------- 3. Filesystem evidence (fast, deterministic) ----------
  echo "=== FS: skills ==="
  ls -la "$HOME/.config/opencode/skills/" || true
  echo "=== FS: commands ==="
  ls -la "$HOME/.config/opencode/commands/" || true
  echo "=== FS: opencode.jsonc ==="
  cat "$HOME/.config/opencode/opencode.jsonc"

  fs_skill_count=$(ls -1 "$HOME/.config/opencode/skills/" 2>/dev/null | grep -c "^ai-first-" || true)
  fs_cmd_count=$(ls -1 "$HOME/.config/opencode/commands/" 2>/dev/null | grep -c "^ai-first-.*\.md$" || true)
  echo "[discovery] fs_skill_count=$fs_skill_count fs_cmd_count=$fs_cmd_count"

  if [ "$fs_skill_count" -ne 4 ]; then
    echo "[discovery] FAIL: expected 4 ai-first-* skills on disk, got $fs_skill_count" >&2; exit 1
  fi
  if [ "$fs_cmd_count" -ne 2 ]; then
    echo "[discovery] FAIL: expected 2 ai-first-*.md commands on disk, got $fs_cmd_count" >&2; exit 1
  fi
  if ! grep -q "\"context7\"" "$HOME/.config/opencode/opencode.jsonc"; then
    echo "[discovery] FAIL: context7 missing from opencode.jsonc" >&2; exit 1
  fi
  if ! grep -q "\"github\"" "$HOME/.config/opencode/opencode.jsonc"; then
    echo "[discovery] FAIL: github missing from opencode.jsonc" >&2; exit 1
  fi
  echo "[discovery] filesystem layer: OK"

  # ---------- 4. MCP layer: parse `opencode mcp list` ----------
  # Deterministic: opencode mcp list reads opencodes own loader, so if a server
  # name appears in the output, opencode has actually accepted the config block.
  # Connection state (connected/failed) does not matter for discovery — failed
  # github is expected because OAuth is not done in CI.
  echo "=== opencode mcp list ==="
  mcp_out=$(opencode mcp list 2>&1)
  echo "$mcp_out"

  if ! echo "$mcp_out" | grep -q "context7"; then
    echo "[discovery] FAIL: opencode mcp list did not report context7" >&2
    exit 1
  fi
  if ! echo "$mcp_out" | grep -q "github"; then
    echo "[discovery] FAIL: opencode mcp list did not report github" >&2
    exit 1
  fi
  if echo "$mcp_out" | grep -q "No MCP servers configured"; then
    echo "[discovery] FAIL: opencode loaded zero MCP servers (silent type drop?)" >&2
    exit 1
  fi
  echo "[discovery] MCP layer: OK (opencode loaded both servers)"

  # ---------- 5. Skills + commands layer: ask the agent (with retry) ----------
  # opencode injects available skills into the system prompt at session start;
  # there is no CLI subcommand to enumerate them. The agent answer is the
  # only source of truth. Retry once on empty / tool-refused output.

  probe_agent() {
    local prompt="$1" out_file="$2" attempt
    for attempt in 1 2; do
      opencode run "$prompt" >"$out_file" 2>&1 || true
      # Heuristic: if the output contains any of our expected tokens or any
      # ai-first- prefix, we consider the probe successful and let the
      # downstream assertions decide pass/fail.
      if grep -qi "ai-first-" "$out_file"; then
        return 0
      fi
      echo "[discovery] probe attempt $attempt produced no ai-first-* tokens; retrying..." >&2
      sleep 2
    done
    return 0  # Let assertions report the failure with full context.
  }

  echo "[discovery] probing opencode for skills..."
  probe_agent \
    "List every skill available in this session whose name starts with the literal string ai-first-. Reply with the names only, one per line, no bullets, no commentary, no markdown. If you do not have access to any such skill, reply exactly: NONE." \
    /tmp/opencode.skills.txt

  echo "[discovery] probing opencode for commands..."
  probe_agent \
    "List every slash command available in this session whose name starts with ai-first-. Reply with the names only, one per line, no slash prefix, no bullets, no commentary. If you do not have access to any such command, reply exactly: NONE." \
    /tmp/opencode.commands.txt

  echo "======== /tmp/opencode.skills.txt ========"
  cat /tmp/opencode.skills.txt
  echo "======== /tmp/opencode.commands.txt ========"
  cat /tmp/opencode.commands.txt
  echo "========================================="

  fail=0
  for s in ai-first-bootstrap ai-first-init ai-first-update ai-first-manage-skills; do
    if ! grep -qi "$s" /tmp/opencode.skills.txt; then
      echo "[discovery] FAIL: skill not reported by agent: $s" >&2
      fail=1
    fi
  done
  for c in ai-first-init ai-first-update; do
    if ! grep -qi "$c" /tmp/opencode.commands.txt; then
      echo "[discovery] FAIL: command not reported by agent: $c" >&2
      fail=1
    fi
  done
  if [ "$fail" -ne 0 ]; then
    echo "[discovery] FAIL — agent introspection missing entries" >&2
    exit 1
  fi
  echo "[discovery] skills + commands layer: OK"

  echo "[discovery] PASS — opencode sees 4 skills, 2 commands, 2 MCPs from the kit"
'
