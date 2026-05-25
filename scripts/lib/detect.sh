#!/usr/bin/env bash
# detect.sh — host detection. Source, do not execute.
# Requires log.sh to be sourced first.

# detect_os
# Sets globals: AFK_OS_ID, AFK_OS_ID_LIKE, AFK_OS_VERSION, AFK_IS_WSL (0|1)
# AFK_IS_WSL is set ONLY when running on a real WSL host — not inside a
# container running on a WSL host (Docker on WSL2 shares the WSL kernel,
# so /proc/version would falsely match otherwise).
detect_os() {
  AFK_OS_ID=""; AFK_OS_ID_LIKE=""; AFK_OS_VERSION=""; AFK_IS_WSL=0
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    AFK_OS_ID="${ID:-}"
    AFK_OS_ID_LIKE="${ID_LIKE:-}"
    AFK_OS_VERSION="${VERSION_ID:-}"
  fi
  # Skip WSL detection if we are clearly inside a container.
  local in_container=0
  [[ -f /.dockerenv || -f /run/.containerenv ]] && in_container=1
  if [[ "$in_container" == "0" ]] && grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
    AFK_IS_WSL=1
  fi
  log_debug "detect_os: ID=$AFK_OS_ID ID_LIKE=$AFK_OS_ID_LIKE VERSION=$AFK_OS_VERSION WSL=$AFK_IS_WSL CONTAINER=$in_container"
}

is_wsl() { [[ "${AFK_IS_WSL:-0}" == "1" ]]; }

# require_ubuntu_like — exits 1 if host is not Ubuntu/Debian-derived.
require_ubuntu_like() {
  detect_os
  case "$AFK_OS_ID" in
    ubuntu|debian) return 0 ;;
  esac
  case " $AFK_OS_ID_LIKE " in
    *" ubuntu "*|*" debian "*) return 0 ;;
  esac
  log_error "Unsupported OS: ID='$AFK_OS_ID' ID_LIKE='$AFK_OS_ID_LIKE'. This kit supports Ubuntu/Debian/WSL Ubuntu only."
  exit 1
}
