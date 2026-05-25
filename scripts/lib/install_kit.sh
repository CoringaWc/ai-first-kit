#!/usr/bin/env bash
# install_kit.sh — clone/update kit and symlink its skills/commands.
# Requires log.sh sourced first.

AFK_KIT_REPO_URL="${AFK_KIT_REPO_URL:-https://github.com/coringawc/ai-first-kit.git}"
AFK_KIT_BRANCH="${AFK_KIT_BRANCH:-main}"
AFK_KIT_DIR="${AFK_KIT_DIR:-$HOME/.config/opencode/ai-first-kit}"
AFK_OPENCODE_SKILLS_DIR="${AFK_OPENCODE_SKILLS_DIR:-$HOME/.config/opencode/skills}"
AFK_OPENCODE_COMMANDS_DIR="${AFK_OPENCODE_COMMANDS_DIR:-$HOME/.config/opencode/commands}"

AFK_SYMLINK_SKIPPED=0

# install_kit_clone — clones the kit if missing, otherwise fast-forwards.
# Does NOT hardcode --branch on clone (works even if remote default differs);
# checks out AFK_KIT_BRANCH after clone if that branch exists.
install_kit_clone() {
  mkdir -p "$(dirname "$AFK_KIT_DIR")"
  if [[ -d "$AFK_KIT_DIR/.git" ]]; then
    log_step "Updating kit at $AFK_KIT_DIR"
    git -C "$AFK_KIT_DIR" fetch --quiet origin
    if ! git -C "$AFK_KIT_DIR" rev-parse --verify --quiet "origin/$AFK_KIT_BRANCH" >/dev/null; then
      log_warn "Remote branch '$AFK_KIT_BRANCH' not found; staying on current branch."
      return 0
    fi
    # Refuse to fast-forward if working tree is dirty.
    if ! git -C "$AFK_KIT_DIR" diff --quiet HEAD 2>/dev/null; then
      log_warn "Local changes detected in $AFK_KIT_DIR — skipping update."
      log_warn "  Stash or reset them, then re-run bootstrap to refresh."
      return 0
    fi
    git -C "$AFK_KIT_DIR" checkout --quiet "$AFK_KIT_BRANCH"
    # Refuse to fast-forward if HEAD has commits not in origin/<branch>.
    local local_ahead
    local_ahead="$(git -C "$AFK_KIT_DIR" rev-list --count "origin/$AFK_KIT_BRANCH..HEAD" 2>/dev/null || echo 0)"
    if (( local_ahead > 0 )); then
      log_warn "Local branch is $local_ahead commit(s) ahead of origin/$AFK_KIT_BRANCH — skipping pull."
      return 0
    fi
    git -C "$AFK_KIT_DIR" pull --ff-only --quiet
  else
    log_step "Cloning kit into $AFK_KIT_DIR"
    git clone --quiet "$AFK_KIT_REPO_URL" "$AFK_KIT_DIR"
    if git -C "$AFK_KIT_DIR" rev-parse --verify --quiet "origin/$AFK_KIT_BRANCH" >/dev/null \
       && [[ "$(git -C "$AFK_KIT_DIR" rev-parse --abbrev-ref HEAD)" != "$AFK_KIT_BRANCH" ]]; then
      git -C "$AFK_KIT_DIR" checkout --quiet "$AFK_KIT_BRANCH"
    fi
  fi
}

# _afk_symlink <target> <link_path>
# Creates link_path -> target.
# If link already points at target: silent OK.
# If link points elsewhere: ask (default N = preserve). NONINTERACTIVE => preserve.
# If path exists and is not a symlink: warn and skip.
_afk_symlink() {
  local target="$1" link="$2"
  mkdir -p "$(dirname "$link")"
  if [[ -L "$link" ]]; then
    local current
    current="$(readlink "$link")"
    if [[ "$current" == "$target" ]]; then
      log_debug "symlink ok: $link -> $target"
      return 0
    fi
    if ask_yes_no "Replace existing symlink $link (-> $current) with link to $target?" N; then
      ln -sfn "$target" "$link"
      log_info "Updated symlink: $link -> $target"
    else
      AFK_SYMLINK_SKIPPED=$((AFK_SYMLINK_SKIPPED + 1))
      log_warn "Kept existing symlink: $link -> $current"
    fi
    return 0
  fi
  if [[ -e "$link" ]]; then
    AFK_SYMLINK_SKIPPED=$((AFK_SYMLINK_SKIPPED + 1))
    log_warn "Path exists and is not a symlink: $link — skipping. Resolve manually."
    return 0
  fi
  ln -s "$target" "$link"
  log_info "Created symlink: $link -> $target"
}

# install_kit_symlinks — symlinks every ai-first-* skill folder and command file.
install_kit_symlinks() {
  local skill_src
  for skill_src in "$AFK_KIT_DIR"/skills/ai-first-*/; do
    [[ -d "$skill_src" ]] || continue
    local name
    name="$(basename "$skill_src")"
    _afk_symlink "${skill_src%/}" "$AFK_OPENCODE_SKILLS_DIR/$name"
  done

  local cmd_src
  for cmd_src in "$AFK_KIT_DIR"/commands/*.md; do
    [[ -f "$cmd_src" ]] || continue
    local name
    name="$(basename "$cmd_src")"
    _afk_symlink "$cmd_src" "$AFK_OPENCODE_COMMANDS_DIR/$name"
  done

  if (( AFK_SYMLINK_SKIPPED > 0 )); then
    log_warn "Symlink summary: $AFK_SYMLINK_SKIPPED entries were skipped (see warnings above)."
  fi
}
