# ai-first-kit

Bootstrap and harness for AI-first development on top of [opencode](https://opencode.ai). Prepares your host once, then adapts individual projects to a consistent workflow (Superpowers + OpenSpec + curated skills/MCPs).

## Status — v0.1 (in progress)

This release ships **only** the host bootstrap and the kit skeleton.

**Implemented:**
- `scripts/bootstrap.sh`: installs host tools (Node ≥22 via [`mise`](https://mise.jdx.dev), `gh`, `git-crypt`, `opencode` via the [official installer](https://opencode.ai/install), `openspec` via npm) and clones the kit to `~/.config/opencode/ai-first-kit`.
- `scripts/sync-global-opencode.sh`: captures and installs the maintainer's complete global OpenCode workflow snapshot (`templates/opencode-global`) including skills, commands, agents, prompts, plugins, hooks, scripts, manifests, CCG/ECC/GSD/OpenSpec runtime files, and docs.
- `/ai-first-pt-br-metadata`: applies the optional pt_BR command metadata overlay by enabling `plugins/pt-br-metadata.js` and `plugins/plugin-display-names.js` through a reproducible command instead of manual config edits.
- Symlinks the kit's own skills (`ai-first-*`) and commands into opencode's discovery paths.
- Merges baseline MCPs (Context7 + GitHub Copilot MCP with OAuth) into `~/.config/opencode/opencode.jsonc` non-destructively.
- `/ai-first-init` (skill + `scripts/init-project.sh`): scaffolds a brand-new AI-first project from a stack pack under `packs/`.
- `/create-pack` (project-local skill + `scripts/create-pack.sh`, maintainers only): scaffolds a new pack under `packs/`.
- Sandboxed per-task verification via Docker (`tests/verify/all.sh`, plus `tests/verify/init.sh` end-to-end).

**Not yet implemented (planned for v0.2+):**
- External skill sync via a single CLI (`npx skills add`-style). **Dropped:** there is no universal installer for the heterogeneous set of skills we use (git symlinks, `uv tool install`, npx CLIs, manual clones, wrapper SKILLs). The supported reproducibility flow is the per-skill recipe under [`registry/global-skills.json`](./registry/global-skills.json) (schema v2, `method.kind` discriminator). See [`docs/known-issues-v0.1.md`](./docs/known-issues-v0.1.md#global-skills-install-plan--npx-skills-add-cancelled).
- Bodies of `ai-first-update`, `ai-first-manage-skills`.
- `ai-first-adopt` skill (initialize the kit inside an existing project — current `/ai-first-init` only creates fresh projects).
- Real project packs shipped in `packs/` (e.g. Laravel + Filament). `packs/` is empty in v0.1; maintainers create local packs via `/create-pack`.
- `bash <(curl ...)` one-liner install.
- Script hardening: cleanup-on-failure traps in `init-project.sh` / `create-pack.sh`, README heredoc input sanitization, `git init` error surface.

See [`docs/known-issues-v0.1.md`](./docs/known-issues-v0.1.md) for deferred review findings.

## Supported hosts

Ubuntu, Debian, WSL Ubuntu. Other Linux distros and Windows native are not supported.

## Prerequisites

Before running `bootstrap.sh` you need:

- **sudo access** — used to `apt install` baseline packages (`git`, `curl`, `ca-certificates`, `python3`, `python3-json5`). The script will prompt for your password.
- **`git`** — used to fetch the kit itself. If not installed, the bootstrap installs it via apt on first run, but you need git to do `git clone` of this repo in the first place. Install with `sudo apt install git` if missing.
- **`curl`** — same as git; needed to fetch the bootstrap or to clone over HTTPS.
- **A working internet connection** — fetches `mise`, `opencode`, `gh`, and npm packages.

Docker is **only** required if you want to run the verification suite (`tests/verify/all.sh`). It is not needed to use the kit at runtime.

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

## After install

The bootstrap modifies your shell environment (`mise` shims, `~/.local/bin`). To pick up the changes:

```bash
exec $SHELL -l
```

Or just open a new terminal.

Then complete one-time auth steps that the bootstrap cannot do for you:

- **GitHub MCP (OAuth):**
  ```bash
  opencode mcp auth github
  ```
  Follow the device-code flow. opencode caches the token under `~/.local/share/opencode/`.

- **Context7 MCP (API key, optional but recommended):**
  Get a key at <https://context7.com>, then export it (add to your shell rc to persist):
  ```bash
  export CONTEXT7_API_KEY=ctx7sk-...
  ```
  Without a key, Context7 still works for public docs but is rate-limited.

- **GitHub CLI (`gh`):**
  ```bash
  gh auth login
  ```
  Used by future kit commands that create repos / open PRs.

Verify everything is wired up:

```bash
opencode --version
mise current node
gh auth status
```

## Troubleshooting

**`bash: opencode: command not found` after bootstrap finished cleanly**
The `mise` shims are not on your `PATH` in the current shell. Run `exec $SHELL -l` or open a new terminal.

**`bootstrap.sh: line N: log_info: command not found`**
You invoked `bootstrap.sh` without its sibling `scripts/lib/` directory. Don't `curl | bash` it — `git clone` the repo first, then run the script from inside the checkout.

**`apply_global_mcps` warns "original config had comments; backed up to ..."**
Expected on first run if you already had a hand-edited `~/.config/opencode/opencode.jsonc` with `//` or `/* */` comments. We rewrite the file as pure JSON; your original is safe at `opencode.jsonc.bak-<timestamp>`. Re-runs on the freshly-written (commentless) file produce no further backups.

**`Symlink summary: N entries were skipped`**
You already had files or symlinks at `~/.config/opencode/skills/ai-first-*` or `~/.config/opencode/commands/ai-first-*` pointing somewhere else. The bootstrap preserved them (won't clobber your customizations). To accept the kit's versions, remove the offending entries and re-run.

**Docker required only for tests** — the verify suite (`tests/verify/all.sh`) builds a sandbox image. If you only want to *use* the kit, you can skip Docker entirely.

## Structure

```
scripts/        # bootstrap.sh, init-project.sh, create-pack.sh, and lib/
registry/       # global skills / MCPs / tools manifests (data)
skills/         # ai-first-* skills (own)
commands/       # /ai-first-* commands (own)
.agents/skills/ # project-local skills visible only when opencode opens this clone (e.g. create-pack)
packs/          # per-stack packs (empty in v0.1; maintainers add via /create-pack)
templates/      # reusable snippets and opencode-global workflow snapshot
tests/          # sandbox image + per-task verifiers
docs/           # plans and design notes
```

## Mirroring The Global OpenCode Workflow

To refresh the snapshot from the current machine:

```bash
scripts/sync-global-opencode.sh capture ~/.config/opencode
```

To install the snapshot on another machine after inspecting/backing up its current state:

```bash
AFK_YES=1 scripts/sync-global-opencode.sh install ~/.config/opencode
```

The installer backs up the previous config to `~/.config/opencode.bak-ai-first-kit-<timestamp>`, replaces the target tree, and installs packages with `npm ci` in every snapshot subdirectory with a lockfile. It intentionally does **not** copy `node_modules`; dependencies are always installed on the target. Restart opencode after installation because config, plugins, agents, and skills are loaded at process start.

To enable the optional Portuguese command-description overlay after installing the snapshot:

```bash
bash scripts/apply-pt-br-metadata-command.sh ~/.config/opencode/opencode.jsonc
```

This is intentionally a command, not an ad-hoc patch: the translation metadata remains centralized in `plugins/pt-br-metadata.js` and can be reapplied consistently on every host.

## Development

Each task in the implementation plan is verified in an ephemeral Docker container. Run the full suite:

```bash
tests/verify/all.sh
```

Requires Docker (only for verification — not for using the kit at runtime).

## License

[MIT](./LICENSE).
