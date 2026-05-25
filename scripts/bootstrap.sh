#!/usr/bin/env bash
# bootstrap.sh — entrypoint to install the ai-first-kit globally.
# Usage:
#   git clone https://github.com/coringawc/ai-first-kit.git
#   bash ai-first-kit/scripts/bootstrap.sh
#
# Env:
#   AFK_NONINTERACTIVE=1   # accept safe defaults without prompting
#   AFK_DEBUG=1            # verbose logs
#   AFK_KIT_REPO_URL=...   # override repo url (testing)
#   AFK_KIT_BRANCH=main    # override branch
#   AFK_SKIP_TOOLS=1       # skip ensure_* tool installers (for sandboxed tests)
#   AFK_SKIP_CLONE=1       # skip install_kit_clone (when kit is already in place)

set -euo pipefail

_self="${BASH_SOURCE[0]:-$0}"
if [[ -f "$_self" && -d "$(dirname "$_self")/lib" ]]; then
  _lib_dir="$(cd "$(dirname "$_self")/lib" && pwd)"
  # shellcheck disable=SC1091
  source "$_lib_dir/log.sh"
  # shellcheck disable=SC1091
  source "$_lib_dir/detect.sh"
  # shellcheck disable=SC1091
  source "$_lib_dir/deps.sh"
  # shellcheck disable=SC1091
  source "$_lib_dir/install_kit.sh"
  # shellcheck disable=SC1091
  source "$_lib_dir/mcps.sh"
else
  echo "[err ] bootstrap.sh must be executed from a checkout of ai-first-kit (cannot find scripts/lib)." >&2
  echo "       Run: git clone https://github.com/coringawc/ai-first-kit.git && bash ai-first-kit/scripts/bootstrap.sh" >&2
  exit 1
fi

main() {
  log_step "ai-first-kit bootstrap starting"
  require_ubuntu_like

  if [[ "${AFK_SKIP_TOOLS:-0}" != "1" ]]; then
    ensure_apt_pkg git curl ca-certificates python3 python3-json5
    ensure_node_lts
    ensure_gh
    ensure_git_crypt
    ensure_opencode
    ensure_openspec
  else
    log_warn "AFK_SKIP_TOOLS=1 — skipping host tool installers"
  fi

  if [[ "${AFK_SKIP_CLONE:-0}" != "1" ]]; then
    install_kit_clone
  else
    log_warn "AFK_SKIP_CLONE=1 — skipping kit clone"
  fi

  install_kit_symlinks

  apply_global_mcps

  log_step "ai-first-kit bootstrap complete"
  log_info "Next: open opencode and run /ai-first-init inside a project."
}

main "$@"
