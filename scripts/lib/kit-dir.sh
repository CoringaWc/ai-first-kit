#!/usr/bin/env bash
# kit-dir.sh — resolve_kit_dir helper. Source, do not execute.
#
# Resolution order:
#   1. $AFK_KIT_DIR env var (if set and validates).
#   2. Auto-discover via ~/.config/opencode/skills/ai-first-init symlink target.
#   3. Current working directory (if it looks like a kit clone).
#
# Validation: a "kit dir" must contain both registry/global-mcps.json and packs/.
#
# On success: sets AFK_KIT_DIR and exports it. Returns 0.
# On failure: prints error to stderr. Returns 1.

_kit_dir_validate() {
  local d="$1"
  [[ -n "$d" && -d "$d" ]] || return 1
  [[ -f "$d/registry/global-mcps.json" ]] || return 1
  [[ -d "$d/packs" ]] || return 1
  return 0
}

resolve_kit_dir() {
  # 1. env var
  if [[ -n "${AFK_KIT_DIR:-}" ]]; then
    if _kit_dir_validate "$AFK_KIT_DIR"; then
      export AFK_KIT_DIR
      return 0
    fi
    printf "[err] AFK_KIT_DIR is set to '%s' but it is not a valid kit clone.\n" "$AFK_KIT_DIR" >&2
    return 1
  fi

  # 2. symlink auto-discovery
  local link="${HOME}/.config/opencode/skills/ai-first-init"
  if [[ -L "$link" ]]; then
    local target
    target="$(readlink -f "$link")" || target=""
    if [[ -n "$target" ]]; then
      local candidate
      candidate="$(cd "$target/../.." 2>/dev/null && pwd)" || candidate=""
      if _kit_dir_validate "$candidate"; then
        AFK_KIT_DIR="$candidate"
        export AFK_KIT_DIR
        return 0
      fi
    fi
  fi

  # 3. cwd fallback (useful for create-pack when run inside the kit clone)
  local cwd
  cwd="$(pwd)"
  if _kit_dir_validate "$cwd"; then
    AFK_KIT_DIR="$cwd"
    export AFK_KIT_DIR
    return 0
  fi

  printf "[err] Could not resolve AFK_KIT_DIR. Set it explicitly or run 'ai-first-bootstrap' first.\n" >&2
  return 1
}
