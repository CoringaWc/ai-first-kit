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
