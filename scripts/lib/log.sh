#!/usr/bin/env bash
# log.sh — logging and prompt helpers. Source, do not execute.

if [[ -t 1 ]]; then
  AFK_C_RESET="\033[0m"
  AFK_C_DIM="\033[2m"
  AFK_C_RED="\033[31m"
  AFK_C_YELLOW="\033[33m"
  AFK_C_GREEN="\033[32m"
  AFK_C_CYAN="\033[36m"
else
  AFK_C_RESET=""; AFK_C_DIM=""; AFK_C_RED=""; AFK_C_YELLOW=""; AFK_C_GREEN=""; AFK_C_CYAN=""
fi

log_info()  { printf "%b[info]%b %s\n"  "$AFK_C_CYAN"   "$AFK_C_RESET" "$*"; }
log_warn()  { printf "%b[warn]%b %s\n"  "$AFK_C_YELLOW" "$AFK_C_RESET" "$*" >&2; }
log_error() { printf "%b[err ]%b %s\n"  "$AFK_C_RED"    "$AFK_C_RESET" "$*" >&2; }
log_step()  { printf "%b==>%b %s\n"     "$AFK_C_GREEN"  "$AFK_C_RESET" "$*"; }
log_debug() { [[ "${AFK_DEBUG:-0}" == "1" ]] && printf "%b[dbg ]%b %s\n" "$AFK_C_DIM" "$AFK_C_RESET" "$*" >&2 || true; }

# ask_yes_no <prompt> [default=Y|N]
# Honors AFK_NONINTERACTIVE=1: returns the default without prompting.
# Default convention: pass the SAFE default (e.g. 'N' for destructive ops).
ask_yes_no() {
  local prompt="$1"
  local default="${2:-N}"
  local hint reply
  case "$default" in
    Y|y) hint="[Y/n]" ;;
    N|n) hint="[y/N]" ;;
    *)   hint="[y/n]"; default="" ;;
  esac
  if [[ "${AFK_NONINTERACTIVE:-0}" == "1" ]]; then
    [[ "$default" =~ ^[Yy]$ ]] && return 0 || return 1
  fi
  while true; do
    printf "%b?%b %s %s " "$AFK_C_CYAN" "$AFK_C_RESET" "$prompt" "$hint"
    read -r reply || reply=""
    reply="${reply:-$default}"
    case "$reply" in
      Y|y|yes|YES) return 0 ;;
      N|n|no|NO)   return 1 ;;
      *) printf "Please answer y or n.\n" ;;
    esac
  done
}
