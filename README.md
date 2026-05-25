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

Requires Docker (only for verification — not for using the kit at runtime).

## License

[MIT](./LICENSE).
