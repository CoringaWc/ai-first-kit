# Bootstrap + Kit Skeleton Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `scripts/bootstrap.sh` that, executed from a local checkout, prepares an Ubuntu/Debian/WSL host (Node ≥22, gh, git-crypt, opencode, openspec), installs the kit globally at `~/.config/opencode/ai-first-kit`, and symlinks the kit's own skills and commands into opencode's discovery paths.

**Architecture:** Bash entrypoint `scripts/bootstrap.sh` orchestrates small composable libs under `scripts/lib/` (log, detect, deps, install_kit). The kit is git-cloned to `~/.config/opencode/ai-first-kit`; per-skill folders under `skills/ai-first-*` and per-command files under `commands/*.md` are symlinked into `~/.config/opencode/skills/<name>` and `~/.config/opencode/commands/<name>.md` respectively (plural names — canonical per opencode docs). Manifests under `registry/` declare which external skills/MCPs/tools the kit manages globally (sync logic comes in a later plan). Every task is verified by running it inside an ephemeral Docker Ubuntu container (`tests/sandbox/`) so the host stays clean.

**Tech Stack:** Bash 5+, GNU coreutils, git, curl, Docker (required on host — pre-checked, not installed by the kit), Node.js ≥22 (installed via `mise` when missing), `gh`, `git-crypt`, `opencode` (installed via the official `https://opencode.ai/install` script — not via npm), `openspec` (npm global `@fission-ai/openspec`).

**Out of scope (deferred to later plans):** the one-liner `bash <(curl ...)` install (this v0.1 requires `git clone && bash scripts/bootstrap.sh`); external-skill sync via `npx skills add`; Superpowers/OpenSpec post-install; `ai-first-init` and `ai-first-update` bodies; packs; GitHub repo creation/push.

**In scope for v0.1 (added after initial draft):** baseline MCP configuration in `~/.config/opencode/opencode.jsonc` for Context7 (HTTP) and GitHub Copilot MCP (HTTP, OAuth — user runs `opencode mcp auth github` post-install). Merged non-destructively into any existing config.

---

## File Structure

Files this plan creates (all paths relative to repo root `~/ai-first-kit`):

- `LICENSE` — MIT.
- `README.md` — expanded with Status section listing what is and is not implemented in v0.1.
- `scripts/bootstrap.sh` — single user-facing entrypoint; sources libs and runs phases.
- `scripts/lib/log.sh` — logging helpers and interactive prompts (`log_info`, `log_warn`, `log_error`, `log_step`, `ask_yes_no`).
- `scripts/lib/detect.sh` — OS/distro/WSL detection (`detect_os`, `require_ubuntu_like`, `is_wsl`).
- `scripts/lib/deps.sh` — idempotent dependency installers (`ensure_apt_pkg`, `ensure_mise`, `ensure_node_lts`, `ensure_gh`, `ensure_git_crypt`, `ensure_opencode`, `ensure_openspec`).
- `scripts/lib/install_kit.sh` — clones/updates kit at `~/.config/opencode/ai-first-kit`, creates symlinks for skills and commands.
- `scripts/lib/mcps.sh` — idempotently merges the MCP entries from `registry/global-mcps.json` into `~/.config/opencode/opencode.jsonc` (preserves existing config; never overwrites non-managed keys).
- `registry/global-skills.json` — declarative list of external skills the kit syncs into `~/.config/opencode/skills` (data only this plan; sync logic later). Sources verified against `npx skills find` output.
- `registry/global-mcps.json` — declarative list of MCPs the kit manages globally (data only this plan).
- `registry/global-tools.json` — declarative list of host tools the kit ensures (mirrors what `deps.sh` enforces).
- `skills/ai-first-bootstrap/SKILL.md` — skeleton skill (frontmatter + TODO body).
- `skills/ai-first-init/SKILL.md` — skeleton.
- `skills/ai-first-update/SKILL.md` — skeleton.
- `skills/ai-first-manage-skills/SKILL.md` — skeleton.
- `commands/ai-first-init.md` — opencode command (frontmatter `description:` + body template).
- `commands/ai-first-update.md` — opencode command.
- `tests/sandbox/Dockerfile` — minimal Ubuntu 24.04 image with `bash`, `curl`, `git`, `python3`, `sudo` preinstalled.
- `tests/sandbox/run.sh` — helper that builds the image (tagged by Dockerfile hash) and runs an arbitrary command inside a fresh container with the repo bind-mounted read-only at `/kit`. Fails fast if `docker` is missing.
- `tests/verify/task-NN.sh` — one verification script per task; each is the last step of its task.
- `tests/verify/all.sh` — aggregate verification script.

---

## Task 0: License + README with Status section

**Files:**
- Create: `LICENSE`
- Modify: `README.md` (rewrite)
- Create: `tests/verify/task-00.sh`

- [ ] **Step 1: Write `LICENSE` (MIT)**

Create `LICENSE` with exactly this content (replace year if needed; copyright holder is the GitHub user):

```
MIT License

Copyright (c) 2026 coringawc

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 2: Rewrite `README.md`**

Replace `README.md` with exactly this content:

````markdown
# ai-first-kit

Bootstrap and harness for AI-first development on top of [opencode](https://opencode.ai). Prepares your host once, then adapts individual projects to a consistent workflow (Superpowers + OpenSpec + curated skills/MCPs).

## Status — v0.1 (in progress)

This release ships **only** the host bootstrap and the kit skeleton.

**Implemented:**
- `scripts/bootstrap.sh`: installs host tools (Node ≥22 via [`mise`](https://mise.jdx.dev), `gh`, `git-crypt`, `opencode` via the [official installer](https://opencode.ai/install), `openspec` via npm) and clones the kit to `~/.config/opencode/ai-first-kit`.
- Symlinks the kit's own skills (`ai-first-*`) and commands into opencode's discovery paths.
- Merges baseline MCPs (Context7 + GitHub Copilot MCP with OAuth) into `~/.config/opencode/opencode.jsonc` non-destructively.
- Sandboxed per-task verification via Docker (`tests/verify/all.sh`).

**Not yet implemented (planned for v0.2+):**
- External skill sync via `npx skills add` (registry exists but is data-only).
- Bodies of `ai-first-init`, `ai-first-update`, `ai-first-manage-skills`.
- Project packs (e.g. Laravel + Filament).
- `bash <(curl ...)` one-liner install.

## Supported hosts

Ubuntu, Debian, WSL Ubuntu. Other Linux distros and Windows native are not supported.

## Install

```bash
git clone https://github.com/coringawc/ai-first-kit.git
bash ai-first-kit/scripts/bootstrap.sh
```

Re-running is safe: every step is idempotent.

### Environment knobs

| Variable                     | Effect                                                            |
|------------------------------|-------------------------------------------------------------------|
| `AFK_NONINTERACTIVE=1`       | Accept safe defaults instead of prompting.                        |
| `AFK_DEBUG=1`                | Verbose logs.                                                     |
| `AFK_KIT_REPO_URL=<url>`     | Override the kit's git URL (development / forks).                 |
| `AFK_KIT_BRANCH=<name>`      | Override the branch to clone/track (default: `main`).             |
| `AFK_SKIP_TOOLS=1`           | Skip host tool installers (used by sandbox tests).                |
| `AFK_SKIP_CLONE=1`           | Skip cloning the kit (used by sandbox tests).                     |

## Structure

```
scripts/        # bootstrap.sh and lib/
registry/       # global skills / MCPs / tools manifests (data)
skills/         # ai-first-* skills (own)
commands/       # /ai-first-* commands (own)
packs/          # per-stack packs (placeholder)
templates/      # reusable snippets (placeholder)
tests/          # sandbox image + per-task verifiers
docs/           # plans and design notes
```

## Development

Each task in the implementation plan is verified in an ephemeral Docker container. Run the full suite:

```bash
tests/verify/all.sh
```

Requires Docker.

## License

[MIT](./LICENSE).
````

- [ ] **Step 3: Write verification**

Create `tests/verify/task-00.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

test -f LICENSE
grep -q "MIT License" LICENSE
grep -q "ai-first-kit" README.md
grep -q "## Status" README.md
grep -q "Not yet implemented" README.md
grep -q "git clone https://github.com/coringawc/ai-first-kit.git" README.md

echo "[verify task-00] PASS"
```

Make executable:

```bash
chmod +x tests/verify/task-00.sh
```

- [ ] **Step 4: Run verification**

Run: `tests/verify/task-00.sh`
Expected last line: `[verify task-00] PASS`

- [ ] **Step 5: Commit**

```bash
git add LICENSE README.md tests/verify/task-00.sh
git commit -m "docs: add MIT license and expand README with v0.1 status"
```

---

## Task 1: Sandbox infrastructure (Dockerfile + runner)

**Rationale:** Every subsequent task verifies behavior inside this sandbox. Build it first so later tasks have a stable target.

**Files:**
- Create: `tests/sandbox/Dockerfile`
- Create: `tests/sandbox/run.sh`
- Create: `tests/verify/task-01.sh`

- [ ] **Step 1: Write the Dockerfile**

Create `tests/sandbox/Dockerfile` with exactly this content:

```dockerfile
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash ca-certificates curl git python3 sudo \
 && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash tester \
 && echo "tester ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/tester

USER tester
WORKDIR /home/tester

CMD ["bash"]
```

`python3` is preinstalled because Tasks 5 and 7 use it for JSON/frontmatter validation; including it in the image avoids reinstalling per run.

- [ ] **Step 2: Write the runner**

Create `tests/sandbox/run.sh` with exactly this content:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Usage: tests/sandbox/run.sh <command...>
# Builds (if needed) and runs a command inside a fresh sandbox container.
# The repo is bind-mounted read-only at /kit. $HOME inside the container is /home/tester.
# Image tag includes a hash of the Dockerfile so changes invalidate the cache automatically.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if ! command -v docker >/dev/null 2>&1; then
  echo "[err] docker is required for sandbox tests." >&2
  echo "      Install: https://docs.docker.com/engine/install/" >&2
  exit 127
fi

DOCKERFILE="$REPO_ROOT/tests/sandbox/Dockerfile"
HASH="$(sha256sum "$DOCKERFILE" | cut -c1-12)"
IMAGE_TAG="ai-first-kit-sandbox:${HASH}"

if ! docker image inspect "$IMAGE_TAG" >/dev/null 2>&1; then
  docker build -t "$IMAGE_TAG" "$REPO_ROOT/tests/sandbox" >&2
fi

docker run --rm \
  -v "$REPO_ROOT:/kit:ro" \
  -w /home/tester \
  "$IMAGE_TAG" \
  bash -c "$*"
```

Then make it executable:

```bash
chmod +x tests/sandbox/run.sh
```

- [ ] **Step 3: Write the verification script**

Create `tests/verify/task-01.sh` with exactly this content:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "[verify task-01] Building sandbox image..."
tests/sandbox/run.sh 'echo SANDBOX_OK && python3 --version' 2>&1 | tee /tmp/task-01.out

grep -q '^SANDBOX_OK$' /tmp/task-01.out
grep -q '^Python 3'   /tmp/task-01.out
echo "[verify task-01] PASS"
```

Then make it executable:

```bash
chmod +x tests/verify/task-01.sh
```

- [ ] **Step 4: Run verification**

Run: `tests/verify/task-01.sh`

Expected output (last line):

```
[verify task-01] PASS
```

- [ ] **Step 5: Commit**

```bash
git add tests/sandbox/Dockerfile tests/sandbox/run.sh tests/verify/task-01.sh
git commit -m "feat(sandbox): add ephemeral Ubuntu 24.04 sandbox and runner"
```

---

## Task 2: Logging and prompt helpers (`scripts/lib/log.sh`)

**Files:**
- Create: `scripts/lib/log.sh`
- Create: `tests/verify/task-02.sh`

- [ ] **Step 1: Write `log.sh`**

Create `scripts/lib/log.sh` with exactly this content:

```bash
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
```

Note: the default for `ask_yes_no` is now `N` (safe default) when not specified, and callers must pass the safe default explicitly when behavior matters.

- [ ] **Step 2: Write verification**

Create `tests/verify/task-02.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

tests/sandbox/run.sh '
  set -e
  source /kit/scripts/lib/log.sh
  log_info  "hello-info"
  log_warn  "hello-warn"
  log_error "hello-error"
  log_step  "hello-step"
  AFK_NONINTERACTIVE=1 ask_yes_no "default yes works" Y && echo YES_OK
  AFK_NONINTERACTIVE=1 ask_yes_no "default no works"  N || echo NO_OK
  # Implicit default is N → ask_yes_no returns 1.
  # Shell semantics note: in `cmd && A || B`, if cmd fails A is skipped AND B runs.
  # To assert "A must NOT run, B MUST run" we put SHOULD_NOT_REACH in the && branch.
  AFK_NONINTERACTIVE=1 ask_yes_no "implicit default is N" && echo SHOULD_NOT_REACH || echo IMPLICIT_NO_OK
' 2>&1 | tee /tmp/task-02.out

grep -q 'hello-info'        /tmp/task-02.out
grep -q 'hello-warn'        /tmp/task-02.out
grep -q 'hello-error'       /tmp/task-02.out
grep -q 'hello-step'        /tmp/task-02.out
grep -q '^YES_OK$'          /tmp/task-02.out
grep -q '^NO_OK$'           /tmp/task-02.out
grep -q '^IMPLICIT_NO_OK$'  /tmp/task-02.out
! grep -q '^SHOULD_NOT_REACH$' /tmp/task-02.out

echo "[verify task-02] PASS"
```

Make executable: `chmod +x tests/verify/task-02.sh`

- [ ] **Step 3: Run verification**

Run: `tests/verify/task-02.sh`
Expected last line: `[verify task-02] PASS`

- [ ] **Step 4: Commit**

```bash
git add scripts/lib/log.sh tests/verify/task-02.sh
git commit -m "feat(lib): add log.sh with logging helpers and ask_yes_no"
```

---

## Task 3: OS/distro detection (`scripts/lib/detect.sh`)

**Files:**
- Create: `scripts/lib/detect.sh`
- Create: `tests/verify/task-03.sh`

- [ ] **Step 1: Write `detect.sh`**

Create `scripts/lib/detect.sh`:

```bash
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
```

- [ ] **Step 2: Write verification**

Create `tests/verify/task-03.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

tests/sandbox/run.sh '
  set -e
  source /kit/scripts/lib/log.sh
  source /kit/scripts/lib/detect.sh
  detect_os
  echo "ID=$AFK_OS_ID"
  echo "WSL=$AFK_IS_WSL"
  require_ubuntu_like
  echo REQUIRE_OK
' 2>&1 | tee /tmp/task-03.out

grep -q '^ID=ubuntu$'  /tmp/task-03.out
grep -q '^WSL=0$'      /tmp/task-03.out
grep -q '^REQUIRE_OK$' /tmp/task-03.out

echo "[verify task-03] PASS"
```

Make executable: `chmod +x tests/verify/task-03.sh`

- [ ] **Step 3: Run verification**

Run: `tests/verify/task-03.sh`
Expected last line: `[verify task-03] PASS`

- [ ] **Step 4: Commit**

```bash
git add scripts/lib/detect.sh tests/verify/task-03.sh
git commit -m "feat(lib): add detect.sh with OS/WSL detection"
```

---

## Task 4: Dependency installers (`scripts/lib/deps.sh`)

**Files:**
- Create: `scripts/lib/deps.sh`
- Create: `tests/verify/task-04.sh`

- [ ] **Step 1: Write `deps.sh`**

Create `scripts/lib/deps.sh`:

```bash
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
```

- [ ] **Step 2: Write verification**

Create `tests/verify/task-04.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# We do not actually download Node/mise here (heavyweight). We verify:
#  - ensure_apt_pkg is idempotent for an installed package (no sudo needed).
#  - ensure_node_lts returns 0 when a satisfying `node` is already on PATH.
#  - The bail-out logic respects PATH, not just `command -v`.
tests/sandbox/run.sh '
  set -e
  source /kit/scripts/lib/log.sh
  source /kit/scripts/lib/detect.sh
  source /kit/scripts/lib/deps.sh

  ensure_apt_pkg bash
  echo APT_NOOP_OK

  mkdir -p /tmp/fakebin
  cat > /tmp/fakebin/node <<EOS
#!/usr/bin/env bash
case "\$1" in
  --version) echo v22.0.0 ;;
  -p) echo 22 ;;
esac
EOS
  chmod +x /tmp/fakebin/node
  PATH="/tmp/fakebin:$PATH" ensure_node_lts
  echo NODE_OK
' 2>&1 | tee /tmp/task-04.out

grep -q '^APT_NOOP_OK$' /tmp/task-04.out
grep -q '^NODE_OK$'     /tmp/task-04.out

echo "[verify task-04] PASS"
```

Make executable: `chmod +x tests/verify/task-04.sh`

- [ ] **Step 3: Run verification**

Run: `tests/verify/task-04.sh`
Expected last line: `[verify task-04] PASS`

- [ ] **Step 4: Commit**

```bash
git add scripts/lib/deps.sh tests/verify/task-04.sh
git commit -m "feat(lib): add deps.sh with idempotent installers"
```

---

## Task 5: Registry manifests (data only)

**Files:**
- Create: `registry/global-skills.json`
- Create: `registry/global-mcps.json`
- Create: `registry/global-tools.json`
- Create: `tests/verify/task-05.sh`

Sources for `global-skills.json` were verified against `npx skills find <name>` on 2026-05-25 (highest-install entry per skill, cross-checked against installed `SKILL.md` content).

- [ ] **Step 1: Write `global-skills.json`**

Create `registry/global-skills.json` with exactly this content:

```json
{
  "version": 1,
  "skills": [
    { "name": "agent-browser",         "source": "vercel-labs/agent-browser@agent-browser" },
    { "name": "caveman",               "source": "juliusbrussee/caveman@caveman" },
    { "name": "find-skills",           "source": "vercel-labs/skills@find-skills" },
    { "name": "frontend-design",       "source": "anthropics/skills@frontend-design" },
    { "name": "grill-me",              "source": "mattpocock/skills@grill-me" },
    { "name": "grill-with-docs",       "source": "mattpocock/skills@grill-with-docs" },
    { "name": "impeccable",            "source": "pbakaus/impeccable@impeccable" },
    { "name": "skill-creator",         "source": "anthropics/skills@skill-creator" },
    { "name": "web-design-guidelines", "source": "vercel-labs/agent-skills@web-design-guidelines" }
  ]
}
```

- [ ] **Step 2: Write `global-mcps.json`**

Create `registry/global-mcps.json` with exactly this content:

```json
{
  "version": 1,
  "mcps": [
    {
      "name": "context7",
      "transport": "http",
      "url": "https://mcp.context7.com/mcp",
      "needs": ["CONTEXT7_API_KEY"],
      "note": "If CONTEXT7_API_KEY is missing, bootstrap prompts to provide it or skip."
    },
    {
      "name": "github",
      "transport": "http",
      "url": "https://api.githubcopilot.com/mcp/",
      "auth": "oauth",
      "note": "Authenticate after restart with: opencode mcp auth github"
    }
  ]
}
```

- [ ] **Step 3: Write `global-tools.json`**

Create `registry/global-tools.json` with exactly this content:

```json
{
  "version": 1,
  "tools": [
    { "name": "node",      "min": "22",  "installer": "ensure_node_lts",  "source": "mise (node@lts)" },
    { "name": "gh",                       "installer": "ensure_gh",        "source": "apt (cli.github.com)" },
    { "name": "git-crypt",                "installer": "ensure_git_crypt", "source": "apt" },
    { "name": "opencode",                 "installer": "ensure_opencode",  "source": "curl https://opencode.ai/install" },
    { "name": "openspec",                 "installer": "ensure_openspec",  "source": "npm @fission-ai/openspec" }
  ]
}
```

- [ ] **Step 4: Write verification**

Create `tests/verify/task-05.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

tests/sandbox/run.sh '
  set -e
  python3 - <<PY
import json
for path, key in [
  ("/kit/registry/global-skills.json", "skills"),
  ("/kit/registry/global-mcps.json",   "mcps"),
  ("/kit/registry/global-tools.json",  "tools"),
]:
  with open(path) as f: data = json.load(f)
  assert key in data and isinstance(data[key], list) and data[key], f"missing {key} in {path}"
  print(f"OK {path} {len(data[key])} entries")

# Validate skill source format: <owner>/<repo>@<skill>
import re
with open("/kit/registry/global-skills.json") as f:
  skills = json.load(f)["skills"]
pat = re.compile(r"^[\w.-]+/[\w.-]+@[\w.-]+$")
for s in skills:
  assert pat.match(s["source"]), f"bad source: {s}"
print(f"OK skill sources match <owner>/<repo>@<skill>")
PY
' 2>&1 | tee /tmp/task-05.out

grep -q 'OK /kit/registry/global-skills.json' /tmp/task-05.out
grep -q 'OK /kit/registry/global-mcps.json'   /tmp/task-05.out
grep -q 'OK /kit/registry/global-tools.json'  /tmp/task-05.out
grep -q 'OK skill sources match'              /tmp/task-05.out

echo "[verify task-05] PASS"
```

Make executable: `chmod +x tests/verify/task-05.sh`

- [ ] **Step 5: Run verification**

Run: `tests/verify/task-05.sh`
Expected last line: `[verify task-05] PASS`

- [ ] **Step 6: Commit**

```bash
git add registry/ tests/verify/task-05.sh
git commit -m "feat(registry): add global skills/mcps/tools manifests"
```

---

## Task 6: Kit installer (`scripts/lib/install_kit.sh`)

**Files:**
- Create: `scripts/lib/install_kit.sh`
- Create: `tests/verify/task-06.sh`

- [ ] **Step 1: Write `install_kit.sh`**

Create `scripts/lib/install_kit.sh`:

```bash
#!/usr/bin/env bash
# install_kit.sh — clone/update kit and symlink its skills/commands.
# Requires log.sh sourced first.

AFK_KIT_REPO_URL="${AFK_KIT_REPO_URL:-https://github.com/coringawc/ai-first-kit.git}"
AFK_KIT_BRANCH="${AFK_KIT_BRANCH:-main}"
AFK_KIT_DIR="${AFK_KIT_DIR:-$HOME/.config/opencode/ai-first-kit}"
AFK_OPENCODE_SKILLS_DIR="${AFK_OPENCODE_SKILLS_DIR:-$HOME/.config/opencode/skills}"
AFK_OPENCODE_COMMANDS_DIR="${AFK_OPENCODE_COMMANDS_DIR:-$HOME/.config/opencode/commands}"

# install_kit_clone — clones the kit if missing, otherwise fast-forwards.
# Does NOT hardcode --branch on clone (works even if remote default differs);
# checks out AFK_KIT_BRANCH after clone if that branch exists.
install_kit_clone() {
  mkdir -p "$(dirname "$AFK_KIT_DIR")"
  if [[ -d "$AFK_KIT_DIR/.git" ]]; then
    log_step "Updating kit at $AFK_KIT_DIR"
    git -C "$AFK_KIT_DIR" fetch --quiet origin
    if git -C "$AFK_KIT_DIR" rev-parse --verify --quiet "origin/$AFK_KIT_BRANCH" >/dev/null; then
      git -C "$AFK_KIT_DIR" checkout --quiet "$AFK_KIT_BRANCH"
      git -C "$AFK_KIT_DIR" pull --ff-only --quiet
    else
      log_warn "Remote branch '$AFK_KIT_BRANCH' not found; staying on current branch."
    fi
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
      log_warn "Kept existing symlink: $link -> $current"
    fi
    return 0
  fi
  if [[ -e "$link" ]]; then
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
}
```

- [ ] **Step 2: Write verification**

Create `tests/verify/task-06.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Skip the clone step (override AFK_KIT_DIR to a fixture) and test only the
# symlink logic. Covers: create, idempotency, safe-default preserve on divergence.
tests/sandbox/run.sh '
  set -e
  source /kit/scripts/lib/log.sh
  source /kit/scripts/lib/install_kit.sh

  mkdir -p $HOME/fake-kit/skills/ai-first-bootstrap
  mkdir -p $HOME/fake-kit/skills/ai-first-init
  mkdir -p $HOME/fake-kit/commands
  echo "# bootstrap" > $HOME/fake-kit/skills/ai-first-bootstrap/SKILL.md
  echo "# init"      > $HOME/fake-kit/skills/ai-first-init/SKILL.md
  echo "# cmd"       > $HOME/fake-kit/commands/ai-first-init.md

  export AFK_KIT_DIR=$HOME/fake-kit
  export AFK_OPENCODE_SKILLS_DIR=$HOME/.config/opencode/skills
  export AFK_OPENCODE_COMMANDS_DIR=$HOME/.config/opencode/commands
  export AFK_NONINTERACTIVE=1

  install_kit_symlinks

  test -L $AFK_OPENCODE_SKILLS_DIR/ai-first-bootstrap && echo SKILL1_OK
  test -L $AFK_OPENCODE_SKILLS_DIR/ai-first-init      && echo SKILL2_OK
  test -L $AFK_OPENCODE_COMMANDS_DIR/ai-first-init.md && echo CMD_OK
  # Resolvable targets (follow link).
  test -e $AFK_OPENCODE_SKILLS_DIR/ai-first-bootstrap/SKILL.md && echo TARGET_OK

  # Idempotency: second run must be silent and not break links.
  install_kit_symlinks
  test -L $AFK_OPENCODE_SKILLS_DIR/ai-first-bootstrap && echo IDEMPOTENT_OK

  # Divergent link must be preserved in NONINTERACTIVE mode (safe default).
  ln -sfn /tmp/elsewhere $AFK_OPENCODE_SKILLS_DIR/ai-first-init
  install_kit_symlinks
  [[ "$(readlink $AFK_OPENCODE_SKILLS_DIR/ai-first-init)" == "/tmp/elsewhere" ]] && echo PRESERVED_OK
' 2>&1 | tee /tmp/task-06.out

grep -q '^SKILL1_OK$'     /tmp/task-06.out
grep -q '^SKILL2_OK$'     /tmp/task-06.out
grep -q '^CMD_OK$'        /tmp/task-06.out
grep -q '^TARGET_OK$'     /tmp/task-06.out
grep -q '^IDEMPOTENT_OK$' /tmp/task-06.out
grep -q '^PRESERVED_OK$'  /tmp/task-06.out

echo "[verify task-06] PASS"
```

Make executable: `chmod +x tests/verify/task-06.sh`

- [ ] **Step 3: Run verification**

Run: `tests/verify/task-06.sh`
Expected last line: `[verify task-06] PASS`

- [ ] **Step 4: Commit**

```bash
git add scripts/lib/install_kit.sh tests/verify/task-06.sh
git commit -m "feat(lib): add install_kit.sh with clone and symlink logic"
```

---

## Task 7: Skeleton skills (`skills/ai-first-*`)

**Files:**
- Create: `skills/ai-first-bootstrap/SKILL.md`
- Create: `skills/ai-first-init/SKILL.md`
- Create: `skills/ai-first-update/SKILL.md`
- Create: `skills/ai-first-manage-skills/SKILL.md`
- Create: `tests/verify/task-07.sh`

- [ ] **Step 1: Write `ai-first-bootstrap/SKILL.md`**

Create `skills/ai-first-bootstrap/SKILL.md`:

```markdown
---
name: ai-first-bootstrap
description: Prepare the host (Ubuntu/Debian/WSL) for AI-first development by installing required tools and the ai-first-kit globally. Use when the user wants to "set up ai-first", "install the kit", "bootstrap opencode", or runs scripts/bootstrap.sh.
---

# ai-first-bootstrap

> Status: skeleton. Implementation lives in `scripts/bootstrap.sh`; this skill documents the contract and will hold the interactive logic in a later plan.

## Contract

- Idempotent: re-running the bootstrap must not break a healthy install.
- Interactive by default; honors `AFK_NONINTERACTIVE=1` for CI with safe defaults.
- Supported hosts: Ubuntu, Debian, WSL Ubuntu. Other OSes exit with a clear message.

## TODO

- Implement MCP merge logic (separate plan).
- Implement external skill sync via `npx skills add` (separate plan).
```

- [ ] **Step 2: Write `ai-first-init/SKILL.md`**

Create `skills/ai-first-init/SKILL.md`:

```markdown
---
name: ai-first-init
description: Adapt the current project (new or existing) to the AI-first workflow — AGENTS.md, OpenSpec, Superpowers integration, optional git-crypt, and initial commit/push. Use when the user runs `/ai-first-init` or asks to "initialize this project for ai-first".
---

# ai-first-init

> Status: skeleton. Full behavior is designed but not yet implemented.

## TODO

- Detect existing stack (composer/package.json/etc.).
- Merge `AGENTS.md` non-destructively.
- Run `openspec init` or `openspec update`.
- Optional git-crypt setup with `.git-crypt-keys/project.key`.
- Confirm commit + push.
```

- [ ] **Step 3: Write `ai-first-update/SKILL.md`**

Create `skills/ai-first-update/SKILL.md`:

```markdown
---
name: ai-first-update
description: Update the ai-first-kit globally (git pull + re-validate) or reapply the project pack and OpenSpec. Use when the user runs `/ai-first-update` or asks to "update the kit" or "refresh ai-first in this project".
---

# ai-first-update

> Status: skeleton.

## TODO

- `global` mode: `git pull --ff-only` on the kit, re-run installers and symlinks.
- `project` mode: reapply pack and run `openspec update`.
```

- [ ] **Step 4: Write `ai-first-manage-skills/SKILL.md`**

Create `skills/ai-first-manage-skills/SKILL.md`:

```markdown
---
name: ai-first-manage-skills
description: Manage the ai-first-kit skill/MCP/tool registry — add, remove, or list entries in registry/global-*.json. Use when the user asks to "add a skill to the kit", "register an MCP", or "list managed skills".
---

# ai-first-manage-skills

> Status: skeleton.

## TODO

- Edit `registry/global-skills.json`, `global-mcps.json`, `global-tools.json` with validation.
- Trigger re-sync via `ai-first-update global` when entries change.
```

- [ ] **Step 5: Write verification**

Create `tests/verify/task-07.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

tests/sandbox/run.sh '
  set -e
  python3 - <<PY
import os, re, sys
ROOT = "/kit/skills"
expected = ["ai-first-bootstrap","ai-first-init","ai-first-update","ai-first-manage-skills"]
for name in expected:
    path = os.path.join(ROOT, name, "SKILL.md")
    assert os.path.isfile(path), f"missing {path}"
    body = open(path).read()
    m = re.search(r"^---\s*\nname:\s*(\S+)\s*\ndescription:\s*(.+?)\n---", body, re.S|re.M)
    assert m, f"no frontmatter in {path}"
    assert m.group(1) == name, f"name mismatch in {path}: got {m.group(1)}"
    assert len(m.group(2).strip()) > 20, f"description too short in {path}"
    print(f"OK {name}")
PY
' 2>&1 | tee /tmp/task-07.out

grep -q '^OK ai-first-bootstrap$'      /tmp/task-07.out
grep -q '^OK ai-first-init$'           /tmp/task-07.out
grep -q '^OK ai-first-update$'         /tmp/task-07.out
grep -q '^OK ai-first-manage-skills$'  /tmp/task-07.out

echo "[verify task-07] PASS"
```

Make executable: `chmod +x tests/verify/task-07.sh`

- [ ] **Step 6: Run verification**

Run: `tests/verify/task-07.sh`
Expected last line: `[verify task-07] PASS`

- [ ] **Step 7: Commit**

```bash
git add skills/ tests/verify/task-07.sh
git commit -m "feat(skills): add skeletons for ai-first-* skills"
```

---

## Task 8: Skeleton commands (`commands/ai-first-*.md`)

opencode commands use **filename** as command name and the **body** as prompt template. Frontmatter only carries metadata (`description`, optional `agent`/`model`).

**Files:**
- Create: `commands/ai-first-init.md`
- Create: `commands/ai-first-update.md`
- Create: `tests/verify/task-08.sh`

- [ ] **Step 1: Write `commands/ai-first-init.md`**

Create `commands/ai-first-init.md`:

```markdown
---
description: Initialize the current project for the AI-first workflow.
---

Invoke the `ai-first-init` skill and follow its instructions to adapt this project to the AI-first workflow (AGENTS.md, OpenSpec, Superpowers, optional git-crypt).
```

- [ ] **Step 2: Write `commands/ai-first-update.md`**

Create `commands/ai-first-update.md`:

```markdown
---
description: Update the ai-first-kit globally or reapply it to the current project.
---

Invoke the `ai-first-update` skill. Ask the user whether to run in `global` mode (refresh the kit installation) or `project` mode (reapply the pack and OpenSpec in this repo).
```

- [ ] **Step 3: Write verification**

Create `tests/verify/task-08.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

tests/sandbox/run.sh '
  set -e
  test -f /kit/commands/ai-first-init.md   && echo INIT_OK
  test -f /kit/commands/ai-first-update.md && echo UPDATE_OK
  grep -q "^description:" /kit/commands/ai-first-init.md   && echo INIT_FM_OK
  grep -q "^description:" /kit/commands/ai-first-update.md && echo UPDATE_FM_OK
' 2>&1 | tee /tmp/task-08.out

grep -q '^INIT_OK$'      /tmp/task-08.out
grep -q '^UPDATE_OK$'    /tmp/task-08.out
grep -q '^INIT_FM_OK$'   /tmp/task-08.out
grep -q '^UPDATE_FM_OK$' /tmp/task-08.out

echo "[verify task-08] PASS"
```

Make executable: `chmod +x tests/verify/task-08.sh`

- [ ] **Step 4: Run verification**

Run: `tests/verify/task-08.sh`
Expected last line: `[verify task-08] PASS`

- [ ] **Step 5: Commit**

```bash
git add commands/ tests/verify/task-08.sh
git commit -m "feat(commands): add /ai-first-init and /ai-first-update commands"
```

---

## Task 9: Orchestrator (`scripts/bootstrap.sh`)

**Files:**
- Create: `scripts/bootstrap.sh`
- Create: `tests/verify/task-09.sh`

- [ ] **Step 1: Write `bootstrap.sh`**

Create `scripts/bootstrap.sh`:

```bash
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
else
  echo "[err ] bootstrap.sh must be executed from a checkout of ai-first-kit (cannot find scripts/lib)." >&2
  echo "       Run: git clone https://github.com/coringawc/ai-first-kit.git && bash ai-first-kit/scripts/bootstrap.sh" >&2
  exit 1
fi

main() {
  log_step "ai-first-kit bootstrap starting"
  require_ubuntu_like

  if [[ "${AFK_SKIP_TOOLS:-0}" != "1" ]]; then
    ensure_apt_pkg git curl ca-certificates
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

  log_step "ai-first-kit bootstrap complete"
  log_info "Next: open opencode and run /ai-first-init inside a project."
}

main "$@"
```

Make executable: `chmod +x scripts/bootstrap.sh`

- [ ] **Step 2: Write verification (end-to-end in sandbox)**

Create `tests/verify/task-09.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# End-to-end: run bootstrap with AFK_SKIP_TOOLS=1 (deps already validated in
# task-04) and AFK_SKIP_CLONE=1 (network would be needed). Point AFK_KIT_DIR
# at /kit so install_kit_symlinks finds the skeletons we created.
tests/sandbox/run.sh '
  set -e
  export AFK_NONINTERACTIVE=1
  export AFK_SKIP_TOOLS=1
  export AFK_SKIP_CLONE=1
  export AFK_KIT_DIR=/kit
  export AFK_OPENCODE_SKILLS_DIR=$HOME/.config/opencode/skills
  export AFK_OPENCODE_COMMANDS_DIR=$HOME/.config/opencode/commands

  bash /kit/scripts/bootstrap.sh

  test -L $AFK_OPENCODE_SKILLS_DIR/ai-first-bootstrap     && echo S1_OK
  test -L $AFK_OPENCODE_SKILLS_DIR/ai-first-init          && echo S2_OK
  test -L $AFK_OPENCODE_SKILLS_DIR/ai-first-update        && echo S3_OK
  test -L $AFK_OPENCODE_SKILLS_DIR/ai-first-manage-skills && echo S4_OK
  test -L $AFK_OPENCODE_COMMANDS_DIR/ai-first-init.md     && echo C1_OK
  test -L $AFK_OPENCODE_COMMANDS_DIR/ai-first-update.md   && echo C2_OK
  # Targets resolvable inside the container (/kit is mounted).
  test -f $AFK_OPENCODE_SKILLS_DIR/ai-first-bootstrap/SKILL.md && echo T_OK
' 2>&1 | tee /tmp/task-09.out

for tag in S1_OK S2_OK S3_OK S4_OK C1_OK C2_OK T_OK; do
  grep -q "^${tag}\$" /tmp/task-09.out
done

echo "[verify task-09] PASS"
```

Make executable: `chmod +x tests/verify/task-09.sh`

- [ ] **Step 3: Run verification**

Run: `tests/verify/task-09.sh`
Expected last line: `[verify task-09] PASS`

- [ ] **Step 4: Commit**

```bash
git add scripts/bootstrap.sh tests/verify/task-09.sh
git commit -m "feat(bootstrap): add scripts/bootstrap.sh orchestrator"
```

---

## Task 9b: MCP merge into global opencode.jsonc (`scripts/lib/mcps.sh`)

**Rationale:** v0.1 ships Context7 + GitHub MCP as managed baseline. Merge must be **non-destructive** (preserve any existing `mcp` entries the user has) and **idempotent** (re-running produces no diff).

**Files:**
- Create: `scripts/lib/mcps.sh`
- Modify: `scripts/bootstrap.sh` (call `apply_global_mcps` after symlinks)
- Create: `tests/verify/task-09b.sh`

- [ ] **Step 1: Write `scripts/lib/mcps.sh`**

Create `scripts/lib/mcps.sh` with exactly this content:

```bash
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
```

- [ ] **Step 2: Wire it into `scripts/bootstrap.sh`**

Edit `scripts/bootstrap.sh`: source `mcps.sh` after `install_kit.sh`, and call `apply_global_mcps` after `install_kit_symlinks`.

Add this source line (after the existing `source "$_lib_dir/install_kit.sh"` line):

```bash
  # shellcheck disable=SC1091
  source "$_lib_dir/mcps.sh"
```

And after the `install_kit_symlinks` call inside `main()`, add:

```bash
  apply_global_mcps
```

- [ ] **Step 3: Write verification**

Create `tests/verify/task-09b.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

tests/sandbox/run.sh '
  set -e
  source /kit/scripts/lib/log.sh
  source /kit/scripts/lib/mcps.sh

  export AFK_KIT_DIR=/kit
  export AFK_OPENCODE_CONFIG=$HOME/.config/opencode/opencode.jsonc
  export AFK_MCP_REGISTRY=/kit/registry/global-mcps.json

  # First apply: file does not exist → must be created with both MCPs.
  apply_global_mcps
  test -f $AFK_OPENCODE_CONFIG && echo CREATED_OK
  python3 -c "
import json
cfg = json.load(open(\"$AFK_OPENCODE_CONFIG\"))
assert \"context7\" in cfg[\"mcp\"], cfg
assert \"github\"   in cfg[\"mcp\"], cfg
assert cfg[\"mcp\"][\"github\"].get(\"auth\") == \"oauth\", cfg[\"mcp\"][\"github\"]
print(\"MCPS_PRESENT\")
"

  # Second apply: idempotent (no change).
  before=$(sha256sum $AFK_OPENCODE_CONFIG | cut -d" " -f1)
  apply_global_mcps
  after=$(sha256sum $AFK_OPENCODE_CONFIG | cut -d" " -f1)
  [[ "$before" == "$after" ]] && echo IDEMPOTENT_OK

  # Third apply: pre-existing user key must survive.
  python3 -c "
import json
p=\"$AFK_OPENCODE_CONFIG\"
cfg=json.load(open(p))
cfg[\"theme\"]=\"opencode\"
cfg[\"mcp\"][\"my-custom\"]={\"type\":\"http\",\"url\":\"http://x\",\"enabled\":True}
json.dump(cfg, open(p, \"w\"), indent=2, sort_keys=True)
"
  apply_global_mcps
  python3 -c "
import json
cfg=json.load(open(\"$AFK_OPENCODE_CONFIG\"))
assert cfg[\"theme\"]==\"opencode\", \"user key lost\"
assert \"my-custom\" in cfg[\"mcp\"], \"user mcp lost\"
assert \"context7\" in cfg[\"mcp\"] and \"github\" in cfg[\"mcp\"], \"managed mcps lost\"
print(\"PRESERVED_OK\")
"
' 2>&1 | tee /tmp/task-09b.out

grep -q '^CREATED_OK$'     /tmp/task-09b.out
grep -q '^MCPS_PRESENT$'   /tmp/task-09b.out
grep -q '^IDEMPOTENT_OK$'  /tmp/task-09b.out
grep -q '^PRESERVED_OK$'   /tmp/task-09b.out

echo "[verify task-09b] PASS"
```

Make executable: `chmod +x tests/verify/task-09b.sh`

- [ ] **Step 4: Run verification**

Run: `tests/verify/task-09b.sh`
Expected last line: `[verify task-09b] PASS`

- [ ] **Step 5: Commit**

```bash
git add scripts/lib/mcps.sh scripts/bootstrap.sh tests/verify/task-09b.sh
git commit -m "feat(mcp): merge Context7 and GitHub MCPs into opencode global config"
```

---

## Task 10: Aggregate verification script

**Files:**
- Create: `tests/verify/all.sh`

- [ ] **Step 1: Write `all.sh`**

Create `tests/verify/all.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

for v in tests/verify/task-*.sh; do
  echo
  echo "===== $v ====="
  "$v"
done

echo
echo "[verify all] ALL TASKS PASS"
```

Make executable: `chmod +x tests/verify/all.sh`

- [ ] **Step 2: Run it**

Run: `tests/verify/all.sh`
Expected last line: `[verify all] ALL TASKS PASS`

- [ ] **Step 3: Commit**

```bash
git add tests/verify/all.sh
git commit -m "test: add aggregate verification script"
```

---

## Self-Review

**Spec coverage:**
- LICENSE + README with explicit Status section → Task 0.
- Sandbox infrastructure with docker pre-check and Dockerfile-hash cache → Task 1.
- Logging + safe interactive prompts (default N) → Task 2.
- OS guard Ubuntu/Debian/WSL → Task 3.
- Idempotent host tool installers with proper PATH wiring for mise; opencode installed via the official curl script (not npm) → Task 4.
- Manifests with verified `<owner>/<repo>@<skill>` sources → Task 5.
- Kit installer with non-destructive symlinks + branch-agnostic clone → Task 6.
- Skeletons of 4 own skills + 2 commands (plural `commands/` dir) → Tasks 7 & 8.
- End-to-end bootstrap exercised in sandbox → Task 9.
- Baseline MCPs (Context7 + GitHub OAuth) merged non-destructively → Task 9b.
- Aggregate runner → Task 10.

**Note on Docker:** Docker is required only for running the verification suite (`tests/verify/all.sh`). It is NOT required at runtime for using the kit. End-users without Docker can still install and use the kit.

**Critical issues from review addressed:**
- C1 `commands/` (plural): every path corrected; default `AFK_OPENCODE_COMMANDS_DIR=$HOME/.config/opencode/commands`.
- C2 Registry sources: rewritten as `<owner>/<repo>@<skill>` and verified against `npx skills find` on 2026-05-25; per-skill choice documented.
- C3 One-liner: removed from README; install path is `git clone && bash scripts/bootstrap.sh`.
- C4 Docker pre-check: `tests/sandbox/run.sh` exits 127 with install hint when docker is missing.
- I1 Safe default: `ask_yes_no` defaults to `N`; `_afk_symlink` passes `N` for the divergent-link prompt → NONINTERACTIVE preserves existing.
- I2 mise PATH: `ensure_node_lts` runs `mise install` then `mise use` then exports `~/.local/share/mise/shims` and asserts `node` + `npm` on PATH.
- I3 Branch handling: `install_kit_clone` no longer hardcodes `--branch`; checks out target branch only when it exists in `origin`.
- I5 README declares deferred scope.
- B3 `python3` baked into the Dockerfile.
- B8 `$schema` key removed from registry JSONs.
- B1 Sandbox image tagged with Dockerfile sha256 → automatic rebuild on change.

**Placeholder scan:** no TBDs; every code block complete; every command has expected output.

**Type/name consistency:**
- Function names referenced in `bootstrap.sh` exist verbatim in libs.
- Env vars use the single `AFK_` namespace.
- Skill names in `skills/` match the `name:` frontmatter field (verified by Task 7).
- Plural `commands/` used everywhere (path constant, fixtures, verifications).

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-25-bootstrap-and-kit-skeleton.md`. Two execution options:

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks. Faster, more rigorous.
2. **Inline Execution** — I execute tasks in this session via `executing-plans`, batch with checkpoints.
