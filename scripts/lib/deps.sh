#!/usr/bin/env bash
# deps.sh — idempotent dependency installers. Source, do not execute.
# Requires log.sh and detect.sh sourced first.

AFK_NODE_MIN_MAJOR=22
AFK_MISE_SHIMS="$HOME/.local/share/mise/shims"

# ensure_apt_pkg <pkg> [pkg...]
ensure_apt_pkg() {
  local missing=()
  local pkg
  for pkg in "$@"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      missing+=("$pkg")
    fi
  done
  if (( ${#missing[@]} == 0 )); then
    log_debug "apt: all present (${*})"
    return 0
  fi
  log_step "Installing apt packages: ${missing[*]}"
  sudo apt-get update -y
  sudo apt-get install -y --no-install-recommends "${missing[@]}"
}

# ensure_mise — installs mise to ~/.local/bin if missing and ensures shims on PATH.
ensure_mise() {
  if ! command -v mise >/dev/null 2>&1; then
    log_step "Installing mise (https://mise.jdx.dev)"
    ensure_apt_pkg curl ca-certificates
    curl -fsSL https://mise.run | sh
  fi
  # Make mise itself discoverable for the rest of this shell.
  export PATH="$HOME/.local/bin:$AFK_MISE_SHIMS:$PATH"
  hash -r
  log_debug "mise: $(mise --version 2>/dev/null || echo 'not on PATH yet')"
}

# ensure_node_lts — guarantees node >= AFK_NODE_MIN_MAJOR via mise.
# Always exports the mise shims dir so subsequent commands see node/npm.
ensure_node_lts() {
  # Existing node already satisfies?
  if command -v node >/dev/null 2>&1; then
    local major
    major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
    if (( major >= AFK_NODE_MIN_MAJOR )); then
      log_debug "node $(node --version) >= ${AFK_NODE_MIN_MAJOR}"
      return 0
    fi
    log_warn "node $(node --version) is older than ${AFK_NODE_MIN_MAJOR}; installing newer via mise"
  fi
  ensure_mise
  # Explicit install + use so shims and binary both exist immediately.
  mise install -y "node@lts"
  mise use --global "node@lts"
  export PATH="$AFK_MISE_SHIMS:$PATH"
  hash -r
  # Hard sanity check: refuse to continue if node/npm are still not on PATH.
  command -v node >/dev/null 2>&1 || { log_error "node not on PATH after mise install"; return 1; }
  command -v npm  >/dev/null 2>&1 || { log_error "npm not on PATH after mise install"; return 1; }
  log_info "node $(node --version) ready (via mise)"
}

# ensure_gh
ensure_gh() {
  if command -v gh >/dev/null 2>&1; then
    log_debug "gh present: $(gh --version | head -n1)"
    return 0
  fi
  log_step "Installing gh"
  ensure_apt_pkg curl ca-certificates gnupg
  sudo install -dm 0755 /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y --no-install-recommends gh
}

# ensure_git_crypt
ensure_git_crypt() {
  if command -v git-crypt >/dev/null 2>&1; then
    log_debug "git-crypt present"
    return 0
  fi
  ensure_apt_pkg git-crypt
}

# ensure_opencode — installs opencode via the official curl installer.
# We deliberately do NOT use `npm i -g opencode-ai` (the user wants the canonical method).
ensure_opencode() {
  if command -v opencode >/dev/null 2>&1; then
    log_debug "opencode present: $(opencode --version 2>/dev/null || echo unknown)"
    return 0
  fi
  ensure_apt_pkg curl ca-certificates
  log_step "Installing opencode (https://opencode.ai/install)"
  curl -fsSL https://opencode.ai/install | bash
  # The installer drops the binary in ~/.opencode/bin or ~/.local/bin depending on version;
  # both are typically added to PATH via the user's shell rc on next login.
  # For the current shell, prepend the known candidates and rehash.
  export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$PATH"
  hash -r
  command -v opencode >/dev/null 2>&1 || {
    log_error "opencode not on PATH after install. Open a new shell or add ~/.opencode/bin (or ~/.local/bin) to PATH."
    return 1
  }
  log_info "opencode $(opencode --version 2>/dev/null || echo installed)"
}

# ensure_openspec — npm global package `@fission-ai/openspec`.
ensure_openspec() {
  if command -v openspec >/dev/null 2>&1; then
    log_debug "openspec present: $(openspec --version 2>/dev/null || echo unknown)"
    return 0
  fi
  ensure_node_lts
  log_step "Installing openspec (npm global)"
  npm install -g @fission-ai/openspec
  hash -r
}
