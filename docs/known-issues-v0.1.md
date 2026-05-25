# Known issues — v0.1

Findings from the formal code review that were intentionally **deferred** to v0.2+. They are not blockers for v0.1: each has a known workaround or low real-world impact. Tracked here so we don't lose them.

## #5 — `ensure_node_lts` short-circuits without exporting npm shims

**File:** `scripts/lib/deps.sh`

When `mise` already has a Node LTS installed and active, `ensure_node_lts` returns early without re-running `mise reshim` or re-evaluating `mise activate`. In a fresh shell after a partial install, `npm` may not yet be on `PATH` even though Node is.

**Workaround:** `exec $SHELL -l` (or open a new terminal) after `bootstrap.sh`. The next shell picks up `mise` activation cleanly. This is already covered in the README's *Post-install* section.

**Fix idea (v0.2):** unconditionally run `mise reshim` and `eval "$(mise activate bash)"` at the end of `ensure_node_lts`, regardless of short-circuit.

---

## #6 — README's `bash <(curl ...)` one-liner does not exist yet

**File:** `README.md` (current install section)

The current install path requires `git clone` first because `bootstrap.sh` `source`s sibling files under `scripts/lib/`. A naked `bash <(curl ...)` would run with no neighbors and break.

**Workaround:** the documented `git clone && bash ai-first-kit/scripts/bootstrap.sh` works today.

**Fix idea (v0.2):** ship a self-contained `install.sh` at the repo root that does the clone + invokes bootstrap. Then a one-liner becomes safe.

---

## #11 — `detect_os` does not flag podman rootless or LXC

**File:** `scripts/lib/detect.sh`

Container detection looks for `/.dockerenv` and `/run/.containerenv`. Podman rootless on some configurations exposes neither; LXC exposes `/proc/1/environ` with `container=lxc` but we don't read it.

**Impact:** low. The only thing container-awareness gates is WSL detection (so we don't think a container is WSL). Worst case on an undetected container: WSL-specific paths get probed; they just don't exist, so the probes fail silently.

**Fix idea (v0.2):** also check `/proc/1/cgroup` for `docker|containerd|lxc|podman` and parse `/proc/1/environ` for `container=`.

---

## #12 — `open()` calls in `mcps.sh` not wrapped in `with` context

**File:** `scripts/lib/mcps.sh`

A few `open()` calls in the embedded Python heredoc don't use `with open(...) as f:`. They leak file descriptors on the short-lived process. The process exits within milliseconds, so the FDs are reclaimed by the kernel anyway. Pure style.

**Fix idea (v0.2):** wrap them. Trivial.

---

## #13 — `local var=$(cmd)` masks command exit codes

**Files:** `scripts/lib/install_kit.sh`, `scripts/lib/deps.sh` (a few sites)

The bash idiom `local var=$(cmd)` evaluates `local` first, which always returns 0, hiding any failure of `cmd` from `set -e`. The current call sites all check the resulting value before using it, so the bug is latent, not active.

**Fix idea (v0.2):** split into two statements:
```bash
local var
var="$(cmd)"
```

---

## Not a bug — #10 (color escape codes)

The review listed `printf '\033[...'` as a potential issue. We verified it's correct ANSI; rendered fine across all tested terminals. No action.

---

## Upstream — opencode silently drops MCP entries with unknown `type`

**Not a kit issue, but worth knowing.** opencode 1.15.10 accepts only
`"type": "local"` or `"type": "remote"` for MCP entries in
`~/.config/opencode/opencode.jsonc`. Any other value (including the
plausible-sounding `"http"`) causes opencode to silently drop the
entry. `opencode mcp list` reports "No MCP servers configured" and no
warning is emitted — not even with `--log-level DEBUG`.

This bug masked a defect in this kit's v0.1 prior to commit c10df48.
If you maintain a fork of the kit or hand-edit your opencode.jsonc,
double-check that every MCP entry has `"type": "remote"` (HTTP/SSE)
or `"type": "local"` (stdio). A draft upstream bug report is in the
project's issue notes.

---

## ai-first-init v0.1 does not adopt existing projects

`/ai-first-init` v0.1 creates a brand-new project folder from scratch. It does not initialize or modify an existing project. A future `ai-first-adopt` skill (v0.2+) will handle that case.

**Workaround:** for existing repos, manually copy the files `ai-first-init` would create (`.cert/.gitignore`, `.git-crypt-keys/.gitignore`, `.gitattributes`, `.agents/skills/` from the desired pack) into the project root.

**Fix idea (v0.2):** new skill `ai-first-adopt` + `scripts/adopt-project.sh` that detects existing scaffolding, merges non-destructively, and offers a dry-run mode.

---

## v0.1 script hardening deferred

Code review of `scripts/create-pack.sh` (commit a816830) and `scripts/init-project.sh` (commit 4bb195d) flagged the following as v0.2 work. None block v0.1 happy path; all are surfaced here so they're not lost.

**`scripts/init-project.sh` and `scripts/create-pack.sh`:**
- No cleanup-on-failure trap. If the script aborts mid-scaffold (e.g. after `mkdir` but before `git init`), the partial destination directory is left behind. User must `rm -rf` manually.
- README heredoc expands `$` inside the user-supplied `PACK_DESC` / project name. A description containing `$(command)` would execute that command at scaffold time. Real-world impact is low (the user is scaffolding their own project), but the heredoc should be quoted (`<<'EOF'`) and values substituted via explicit placeholders.
- `git init -b main >/dev/null 2>&1` swallows stderr. If `git init` fails for an unexpected reason (e.g. corrupt template dir), the user sees a generic "git commit failed" downstream instead of the real cause.

**`scripts/create-pack.sh`:**
- Embedded Python interpreter (`python3 -c "..."`) is not pre-checked. On a host without `python3`, the script dies with a confusing "python3: command not found" instead of a friendly "missing prerequisite" message. `scripts/lib/deps.sh` already has `require_cmd` patterns we should adopt.

**Fix idea (v0.2):** add `trap 'cleanup_on_failure' ERR EXIT` patterns, quote heredocs, route `git init` stderr through `log_warn`, and add a `require_cmd python3` gate at the top of `create-pack.sh`.
