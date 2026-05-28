#!/usr/bin/env bash
# sync-global-opencode.sh - capture or install the curated global OpenCode workflow.
#
# Usage:
#   scripts/sync-global-opencode.sh capture [source-config-dir]
#   scripts/sync-global-opencode.sh install [target-config-dir]
#
# The snapshot intentionally excludes dependency folders and caches so packages
# are always installed on the target with package managers. It keeps the workflow surface: config, skills,
# commands, agents, prompts, plugins, hooks, scripts, manifests, bundled repos,
# and documentation.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SNAPSHOT_DIR="$KIT_ROOT/templates/opencode-global"

usage() {
  cat >&2 <<'EOF'
Usage:
  sync-global-opencode.sh capture [source-config-dir]
  sync-global-opencode.sh install [target-config-dir]

Defaults:
  source-config-dir: ~/.config/opencode
  target-config-dir: ~/.config/opencode

Environment:
  AFK_YES=1             Do not prompt before destructive install.
  AFK_SKIP_NPM=1        Skip npm install steps. Intended only for tests.
EOF
}

require_rsync() {
  if ! command -v rsync >/dev/null 2>&1; then
    echo "[err ] rsync is required. Install it first." >&2
    exit 1
  fi
}

rsync_excludes=(
  "--exclude=.git/"
  "--exclude=node_modules/"
  "--exclude=node_modules-ecc/"
  "--exclude=**/node_modules/"
  "--exclude=__pycache__/"
  "--exclude=**/__pycache__/"
  "--exclude=*.pyc"
  "--exclude=.DS_Store"
)

capture() {
  local source_dir="${1:-$HOME/.config/opencode}"
  if [[ ! -d "$source_dir" ]]; then
    echo "[err ] source config dir not found: $source_dir" >&2
    exit 1
  fi

  require_rsync
  rm -rf "$SNAPSHOT_DIR"
  mkdir -p "$SNAPSHOT_DIR"
  rsync -a --delete "${rsync_excludes[@]}" "$source_dir/" "$SNAPSHOT_DIR/"

  cat > "$SNAPSHOT_DIR/README.md" <<'EOF'
# OpenCode Global Snapshot

This directory is a curated mirror of the global OpenCode workflow from the
maintainer machine. It is installed by `scripts/sync-global-opencode.sh install`.

Included: `opencode.jsonc`, `AGENTS.md`, skills, commands, agents, prompts,
plugins, hooks, scripts, manifests, bundled references, CCG/ECC/GSD/OpenSpec
runtime files, and local documentation.

Excluded intentionally: `node_modules`, `node_modules-ecc`, Python bytecode,
and caches. Reinstall dependencies after copying with `npm ci` where lockfiles
exist.
EOF

  echo "[ok  ] captured OpenCode global snapshot to $SNAPSHOT_DIR"
}

install_snapshot() {
  local target_dir="${1:-$HOME/.config/opencode}"
  if [[ ! -d "$SNAPSHOT_DIR" ]]; then
    echo "[err ] snapshot not found: $SNAPSHOT_DIR" >&2
    exit 1
  fi

  require_rsync
  mkdir -p "$(dirname "$target_dir")"

  if [[ -d "$target_dir" ]]; then
    local backup_dir="${target_dir}.bak-ai-first-kit-$(date +%Y%m%d-%H%M%S)"
    echo "[info] backing up existing config to $backup_dir"
    rsync -a "${rsync_excludes[@]}" "$target_dir/" "$backup_dir/"
  fi

  if [[ "${AFK_YES:-0}" != "1" ]]; then
    echo "[warn] this will replace $target_dir with the ai-first-kit snapshot." >&2
    read -r -p "Continue? [y/N] " answer
    case "$answer" in
      y|Y|yes|YES) ;;
      *) echo "[info] aborted"; exit 0 ;;
    esac
  fi

  rm -rf "$target_dir"
  mkdir -p "$target_dir"
  rsync -a --delete "$SNAPSHOT_DIR/" "$target_dir/"

  if [[ "${AFK_SKIP_NPM:-0}" != "1" ]]; then
    restore_dependencies "$target_dir"
  fi

  echo "[ok  ] installed OpenCode global snapshot to $target_dir"
  echo "[info] restart opencode so config-time files and plugins reload"
}

restore_dependencies() {
  local target_dir="$1"

  if ! command -v npm >/dev/null 2>&1; then
    echo "[err ] npm is required to install snapshot packages" >&2
    exit 1
  fi

  while IFS= read -r lockfile; do
    (cd "$(dirname "$lockfile")" && npm ci)
  done < <(find "$target_dir" \
    -path '*/node_modules/*' -prune -o \
    -path '*/node_modules-ecc/*' -prune -o \
    -name package-lock.json -print | sort)
}

main() {
  local mode="${1:-}"
  shift || true
  case "$mode" in
    capture) capture "$@" ;;
    install) install_snapshot "$@" ;;
    -h|--help|help) usage ;;
    *) usage; exit 1 ;;
  esac
}

main "$@"
