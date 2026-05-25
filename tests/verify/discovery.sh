#!/usr/bin/env bash
# discovery.sh — proves opencode actually sees the kit's skills, commands, and
# MCPs after a fresh, network-enabled bootstrap inside a clean sandbox.
#
# This test is NOT part of tests/verify/all.sh because:
#   - It requires outbound network (git clone, npm registry, opencode install).
#   - It runs `opencode run` which spins up a model session and is slow.
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

  # ---------- 3. Filesystem evidence (supporting) ----------
  echo "=== FS: skills ===" | tee /tmp/skills.fs.txt
  ls -la "$HOME/.config/opencode/skills/" | tee -a /tmp/skills.fs.txt
  echo "=== FS: commands ===" | tee /tmp/commands.fs.txt
  ls -la "$HOME/.config/opencode/commands/" | tee -a /tmp/commands.fs.txt
  echo "=== FS: opencode.jsonc ===" | tee /tmp/config.txt
  cat "$HOME/.config/opencode/opencode.jsonc" | tee -a /tmp/config.txt

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
  echo "[discovery] filesystem evidence: OK"

  # ---------- 4. opencode self-introspection ----------
  echo "=== opencode --help ===" >/tmp/opencode.help.txt
  opencode --help >>/tmp/opencode.help.txt 2>&1 || true
  echo "=== opencode mcp --help ===" >>/tmp/opencode.help.txt
  opencode mcp --help >>/tmp/opencode.help.txt 2>&1 || true
  # Try a list subcommand if present (best-effort, non-fatal)
  echo "=== opencode mcp list (best-effort) ===" >>/tmp/opencode.help.txt
  opencode mcp list >>/tmp/opencode.help.txt 2>&1 || true

  echo "[discovery] probing opencode for skills..."
  opencode run "List all skills available to you whose name starts with '\''ai-first-'\''. Output exactly one name per line, in alphabetical order, with no commentary or formatting." \
    >/tmp/opencode.skills.txt 2>&1 || true

  echo "[discovery] probing opencode for MCPs..."
  opencode run "List all MCPs (Model Context Protocol servers) currently configured for you. Output one name per line, in alphabetical order, no commentary." \
    >/tmp/opencode.mcps.txt 2>&1 || true

  echo "[discovery] probing opencode for commands..."
  opencode run "List all slash commands available whose name starts with '\''ai-first-'\''. Output one per line, no commentary." \
    >/tmp/opencode.commands.txt 2>&1 || true

  # ---------- 5. Dump all evidence to host log ----------
  echo
  echo "======== /tmp/opencode.help.txt ========"
  cat /tmp/opencode.help.txt
  echo "======== /tmp/opencode.skills.txt ========"
  cat /tmp/opencode.skills.txt
  echo "======== /tmp/opencode.mcps.txt ========"
  cat /tmp/opencode.mcps.txt
  echo "======== /tmp/opencode.commands.txt ========"
  cat /tmp/opencode.commands.txt
  echo "========================================="

  # ---------- 6. Assertions on opencode self-introspection ----------
  fail=0
  for s in ai-first-bootstrap ai-first-init ai-first-update ai-first-manage-skills; do
    if ! grep -qi "$s" /tmp/opencode.skills.txt; then
      echo "[discovery] FAIL: skill not reported by opencode: $s" >&2
      fail=1
    fi
  done
  for m in context7 github; do
    if ! grep -qi "$m" /tmp/opencode.mcps.txt; then
      echo "[discovery] FAIL: MCP not reported by opencode: $m" >&2
      fail=1
    fi
  done
  for c in ai-first-init ai-first-update; do
    if ! grep -qi "$c" /tmp/opencode.commands.txt; then
      echo "[discovery] FAIL: command not reported by opencode: $c" >&2
      fail=1
    fi
  done
  if [ "$fail" -ne 0 ]; then
    echo "[discovery] FAIL — opencode self-introspection missing entries" >&2
    exit 1
  fi

  echo "[discovery] PASS — opencode sees 4 skills, 2 commands, 2 MCPs from the kit"
'
