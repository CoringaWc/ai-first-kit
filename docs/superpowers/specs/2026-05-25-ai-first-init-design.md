# Spec: `ai-first-init` v0.1 + `create-pack` skill

- Date: 2026-05-25
- Status: Approved (design phase, revised)
- Author: brainstorming session with user (PT-BR interaction)
- Related: `docs/superpowers/plans/2026-05-25-bootstrap-and-kit-skeleton.md` (v0.1 host bootstrap, already shipped)

## Background

The v0.1 host bootstrap + kit skeleton is shipped and validated end-to-end (25 commits on `main`, HEAD `bab00a2`). The `ai-first-init` skill currently exists only as a 16-line placeholder. The original placeholder's TODO described initializing an *existing* project; the user has decided the v0.1 behavior should instead **create a brand-new project from scratch**.

This spec covers two artifacts plus repo cleanup:

1. The full body of the `ai-first-init` skill (replaces the current skeleton).
2. A new `create-pack` skill that lives in `<kit>/.agents/skills/create-pack/` — used **inside** the kit clone itself by the kit maintainer.
3. Remove the empty `packs/laravel-filament/` placeholder; ship an empty `packs/.gitkeep` directory. Packs are created on-demand by `create-pack`.

The user is independently designing/implementing a separate `init-project` skill that lives inside each generated project's `.agents/skills/` directory and handles stack setup (composer install, docker up, git-crypt init, migrations, etc.). **That work is out of scope for this spec.**

## Mental model

| Skill | Lives in | Surfaced as | Who runs it | Purpose |
|---|---|---|---|---|
| `create-pack` | `<kit>/.agents/skills/create-pack/` | only inside the kit project (opencode opened at the kit clone) | kit maintainer | scaffold a new `packs/<name>/` inside the kit |
| `ai-first-init` | `<kit>/skills/ai-first-init/` | globally via `~/.config/opencode/skills/` symlink | any user with the kit installed | create a brand-new project folder with the AI-first scaffold |
| `init-project` | `<project>/.agents/skills/init-project/` | only inside the generated project | end user, after running ai-first-init | run stack-specific setup (out of scope) |

`ai-first-init` ends by **suggesting** the user open opencode inside the new project and run `/init-project`. It does not invoke that skill itself.

### Why `create-pack` is project-local (not global)

Maintaining the kit (adding packs) is a kit-maintainer activity, not an end-user activity. Placing it in `<kit>/.agents/skills/` means:

- It is only discoverable when opencode is opened *at the kit clone* — matches the audience.
- End users who clone/install the kit don't see clutter in their global slash commands.
- The pattern mirrors `~/siasgfacil-filament/.agents/skills/` (the reference template).

## Reference template

`~/siasgfacil-filament/` is the real-world reference. Inspected fields:

- `.cert/` — versioned, with internal `.gitignore` controlling which cert files commit.
- `.git-crypt-keys/` — versioned, with internal `.gitignore` rule `*.key` to keep secrets out.
- `.gitattributes` — contains `filter=git-crypt diff=git-crypt` for `.env` and `.cert/cert.{key,pem}`.
- `.agents/skills/` — populated with stack-specific skills (41 entries in the reference project).
- `README.md` — ~6 KB, structured (Stack/Prereqs/Setup/Operations/Troubleshooting).

The v0.1 scaffold mirrors this layout in structure but **does not** activate git-crypt or write a rich README — that is `init-project`'s job once the stack is known.

## Goals

1. Allow a user inside opencode to run `/ai-first-init` and end up with a new, git-initialized project folder on disk containing the AI-first scaffold and the chosen stack's skills.
2. Provide a `create-pack` skill inside the kit project so the kit can grow new packs using the kit's own conventions.
3. Keep behavior idempotent-safe: never overwrite or destroy user data; abort on any conflict with a clear message.
4. Be testable in CI sandbox via env-var overrides for all interactive prompts.

## Non-goals (deferred)

- Stack-specific setup (composer/npm/docker/migrate) — handled by `init-project`.
- Running `git-crypt init` or generating the symmetric key — handled by `init-project`.
- Adding real `filter=git-crypt` lines to `.gitattributes` — handled by `init-project`.
- A "famous README" generator skill (`write-readme`, standard-readme style) — deferred to v0.2.
- Shipping any pre-made packs (`generic`, `laravel-filament`) — the kit starts with zero packs; the maintainer creates them via `create-pack`.
- Updating an *existing* project to AI-first standards — deferred to a future `ai-first-adopt` skill.

## Component 1 — Skill `ai-first-init`

### Location
`skills/ai-first-init/SKILL.md` (replaces current 16-line skeleton).

### Frontmatter

```yaml
---
name: ai-first-init
description: Create a new project folder scaffolded for the AI-first workflow — picks a stack pack from the installed ai-first-kit, lays out .cert/, .git-crypt-keys/, .agents/skills/, README, .gitignore, .gitattributes, runs `git init`, makes an initial commit, and optionally pushes to GitHub. Does NOT run stack-specific setup (that is `init-project`'s job inside the new project). Use when the user runs `/ai-first-init` or asks to "create a new AI-first project".
---
```

### Discovering the kit root

The skill must locate the kit clone (`$AFK_KIT_DIR`) without depending on the user's CWD. Resolution order:

1. If env var `AFK_KIT_DIR` is set and points to a valid kit, use it.
2. Otherwise auto-discover by resolving the symlink that opencode used to load the skill:
   ```bash
   skill_link="$HOME/.config/opencode/skills/ai-first-init"
   skill_target="$(readlink -f "$skill_link")"     # -> .../ai-first-kit/skills/ai-first-init
   kit_dir="$(cd "$skill_target/../.." && pwd)"    # -> .../ai-first-kit
   ```
3. Validate: `$kit_dir/registry/global-mcps.json` and `$kit_dir/packs` must both exist. Otherwise abort with a clear message instructing the user to run `ai-first-bootstrap` first.

The resolution logic lives in a new helper `scripts/lib/kit-dir.sh`, sourced by both `init-project.sh` and `create-pack.sh`.

### Inputs (interactive prompts)

| # | Prompt | Validation | Default | Env override |
|---|---|---|---|---|
| 1 | Which stack pack? | must exist as `<kit>/packs/*/manifest.json` | first alphabetically | `AFK_INIT_PACK` |
| 2 | Project name (slug) | `^[a-z0-9][a-z0-9-]*$`, length 2–40 | none, required | `AFK_INIT_NAME` |
| 3 | Parent directory | absolute path, exists or creatable | `$HOME/Projects` | `AFK_INIT_PARENT_DIR` |
| 4 | Create initial commit? | yes/no | yes | `AFK_INIT_COMMIT` (`1`/`0`) |
| 5 | Create GitHub repo and push now? | yes/no (only asked if #4 = yes) | no | `AFK_INIT_PUSH` (`1`/`0`) |

If all five env vars are set, the skill runs fully non-interactive (used by `tests/verify/init.sh`).

### Discovering packs

```bash
shopt -s nullglob
for manifest in "$kit_dir"/packs/*/manifest.json; do
  name=$(python3 -c "import json;print(json.load(open('$manifest'))['name'])")
  desc=$(python3 -c "import json;print(json.load(open('$manifest')).get('description',''))")
done
```

A pack folder without `manifest.json` is **ignored silently**.

**If zero packs are found**, the skill aborts with:
> No packs available in `<kit_dir>/packs/`. To create one, open opencode at the ai-first-kit clone and run `/create-pack`.

### Execution model

The skill is a **thin markdown wrapper**: it gathers the 5 inputs interactively (or from env vars), then delegates filesystem work to `scripts/init-project.sh` (new, in the kit). The script does all `mkdir`, `cp`, `git init`, and `gh repo create` calls.

Rationale: keeps heavy logic in a shell-testable script (`tests/verify/init.sh` invokes the script directly with env vars, bypassing the LLM). The skill instructs the agent to call the script with the right env vars.

The script accepts inputs **only via env vars** (no positional args):

| Env var | Required | Notes |
|---|---|---|
| `AFK_KIT_DIR` | yes | Resolved by the skill before calling. |
| `AFK_INIT_PACK` | yes | Pack name (folder under `packs/`). |
| `AFK_INIT_NAME` | yes | Project slug. |
| `AFK_INIT_PARENT_DIR` | yes | Absolute parent dir. |
| `AFK_INIT_COMMIT` | yes | `1` or `0`. |
| `AFK_INIT_PUSH` | yes | `1` or `0`. Ignored if commit=0. |

The script exits 0 on success and prints a JSON summary on the last stdout line:
```json
{"dest":"/home/user/Projects/foo","pack":"laravel-filament","skills_copied":12,"commit":"abc1234","remote":"https://github.com/user/foo"}
```

This lets the skill report back to the user cleanly.

### Execution flow (skill perspective)

1. Print banner: `ai-first-init v0.1 — new AI-first project scaffold`.
2. Resolve `$AFK_KIT_DIR`. Abort on failure.
3. Discover and list packs from `<kit>/packs/*/manifest.json`. Abort if zero (see above).
4. Prompt #1 — stack pack.
5. Prompt #2 — project name (validate; reprompt up to 3 times; abort if still invalid).
6. Prompt #3 — parent directory (default `$HOME/Projects`, always confirm).
7. Compute `dest="$parent/$name"`. If `dest` exists and is non-empty → abort, no side effects.
8. Prompt #4 — commit?
9. If commit=yes, prompt #5 — push to GitHub?
10. Set all `AFK_INIT_*` env vars and call `bash "$AFK_KIT_DIR/scripts/init-project.sh"`.
11. Parse the JSON summary line from the script's stdout.
12. Print human-readable summary:
    - Path created
    - Pack chosen
    - Number of skills copied
    - Commit SHA (if any)
    - Remote URL (if any)
    - **Next step:** `cd <dest> && opencode` then `/init-project`.

### Execution flow (script perspective)

1. Validate all required env vars are set; exit 2 on missing.
2. Validate `$AFK_KIT_DIR/packs/$AFK_INIT_PACK/manifest.json` exists; exit 3 if not.
3. Compute `dest="$AFK_INIT_PARENT_DIR/$AFK_INIT_NAME"`. Exit 4 if exists and non-empty.
4. `mkdir -p "$dest"`. From here on, paths relative to `dest`.
5. Create scaffold files (see "Scaffold layout" below).
6. If `<kit>/packs/<pack>/skills/` exists and is non-empty: `cp -R "<kit>/packs/<pack>/skills/." ".agents/skills/"`. Count files for summary.
7. `git init -b main` (suppress noisy output).
8. If commit=1: `git add -A && git commit -m "chore: initial scaffold from ai-first-kit (pack=<pack>)"`. Capture short SHA.
9. If push=1 and commit was made: try `gh repo create "<name>" --private --source . --push --remote origin`. Capture remote URL. On failure, keep local commit, log warning, set `remote=null`.
10. Emit JSON summary to stdout; exit 0.

### Scaffold layout

```
<dest>/
├── .agents/
│   └── skills/         # contents of <kit>/packs/<stack>/skills/ if any
├── .cert/
│   └── .gitignore      # keeps cert.key, cert.pem, cert.csr; ignores *.local, *.tmp
├── .git-crypt-keys/
│   └── .gitignore      # ignores *.key
├── .gitattributes      # header + COMMENTED template lines for git-crypt
├── .gitignore          # minimal
└── README.md           # minimal hardcoded template
```

#### `.cert/.gitignore`
```gitignore
# Keep certs versioned (encrypted via git-crypt once init-project enables it).
# Ignore local-only and temporary files.
*.local
*.tmp
*~
```

#### `.git-crypt-keys/.gitignore`
```gitignore
# Symmetric keys must NEVER be committed.
# Keep this directory tracked so collaborators know where to drop their key.
*.key
```

#### `.gitattributes`
```gitattributes
# AI-first scaffold — git-crypt filter lines are TEMPLATES, commented out.
# Uncomment after running `git-crypt init` (handled by /init-project).

# .env       filter=git-crypt diff=git-crypt
# .cert/cert.key filter=git-crypt diff=git-crypt
# .cert/cert.pem filter=git-crypt diff=git-crypt

* text=auto eol=lf
```

#### `.gitignore`
```gitignore
# Dependencies
node_modules/
vendor/

# Environment
.env.local
.env.*.local

# OS
.DS_Store
Thumbs.db

# Logs
*.log
```

#### `README.md`
```markdown
# <project-name>

> Scaffolded from [`ai-first-kit`](https://github.com/CoringaWc/ai-first-kit) — pack `<stack>`.

## Stack

<stack pack manifest description, or "TBD — populate after running /init-project">

## Prerequisites

See your stack pack's documentation. The AI-first host bootstrap (`ai-first-bootstrap`) installs the common baseline.

## Next steps

This project has the AI-first scaffold but no stack-specific setup yet.

1. Open opencode in this directory: `opencode`
2. Run `/init-project` to install dependencies, configure git-crypt, and prepare the stack.

## Layout

- `.agents/skills/` — opencode skills bundled with this project
- `.cert/` — TLS / signing certificates (encrypted in git once git-crypt is enabled)
- `.git-crypt-keys/` — directory for the symmetric key (keys themselves are gitignored)
- `.gitattributes` — git-crypt filter templates (commented)
```

### Error handling

| Condition | Behavior |
|---|---|
| `AFK_KIT_DIR` cannot be resolved | Abort, instruct: "Run `/ai-first-bootstrap` first." |
| Zero packs in `<kit>/packs/` | Abort, instruct to run `/create-pack` inside the kit. |
| `git` not on PATH | Abort early, instruct: "Run `/ai-first-bootstrap` first." |
| `gh` not on PATH, user said yes to push | Skip push, keep commit, instruct manual remedy. |
| Invalid slug after 3 retries | Abort, no side effects. |
| `dest` exists and is non-empty | Abort, no side effects. |
| Pack has no `skills/` dir | Continue, copy 0 skills. |
| `gh repo create` fails | Print error, keep local commit, instruct manual retry. |
| Any subprocess error during scaffold | Print error and current state; do NOT auto-rollback (let user inspect). |

## Component 2 — Skill `create-pack`

### Location
`<kit>/.agents/skills/create-pack/SKILL.md`.

This skill is **only visible** when opencode is opened at the kit clone (because opencode loads project-local skills from `<cwd>/.agents/skills/`). End users with the kit installed via `ai-first-bootstrap` do NOT see this command — that's by design.

### Frontmatter

```yaml
---
name: create-pack
description: Scaffold a new pack inside ai-first-kit. Creates packs/<name>/ with manifest.json, README.md, and an empty skills/ directory. Use when the user (kit maintainer) runs `/create-pack` or asks to "create a new pack". Must be run from inside an ai-first-kit clone.
---
```

### Precondition check

The skill resolves `$AFK_KIT_DIR` using the same logic as `ai-first-init` (env var first, then symlink auto-discovery). When `create-pack` runs as a project-local skill its symlink chain is different, so it falls back to validating that **the current working directory** contains `registry/global-mcps.json` and `packs/`.

If neither resolution path produces a valid kit dir → abort.

### Inputs

| # | Prompt | Validation | Env override |
|---|---|---|---|
| 1 | Pack name (slug) | `^[a-z0-9][a-z0-9-]*$`, length 2–40 | `AFK_PACK_NAME` |
| 2 | One-line description | non-empty, ≤200 chars | `AFK_PACK_DESC` |

### Action

The skill delegates to `scripts/create-pack.sh` (env-var driven, like `init-project.sh`).

1. Resolve `$AFK_KIT_DIR`. Compute `dest="$AFK_KIT_DIR/packs/<name>"`. Abort if it exists.
2. `mkdir -p "$dest/skills"`.
3. Write `$dest/manifest.json`:
   ```json
   {"name": "<name>", "description": "<desc>"}
   ```
4. Write `$dest/README.md`:
   ```markdown
   # <name>

   <desc>

   ## Skills

   TODO: document the skills bundled with this pack and how they fit together.

   ## Usage

   Selected from `ai-first-init`'s pack list. Skills under `skills/` are copied into
   `<project>/.agents/skills/` when a user scaffolds a project with this pack.
   ```
5. Write `$dest/skills/.gitkeep`.
6. Emit JSON summary: `{"dest":"<path>","name":"<name>"}` and exit 0.

The skill prints a human summary including "next: `cd $AFK_KIT_DIR && git add packs/<name> && git commit -m 'feat(packs): add <name> pack'`".

## Component 3 — Repo cleanup

| Action | Path |
|---|---|
| **Remove** | `packs/laravel-filament/` (currently has only `.gitkeep`) |
| **Keep** | `packs/.gitkeep` (so the directory ships empty but tracked) |
| **No-op** | `registry/global-skills.json` (governs external skill installs, not kit internals) |

After this change `packs/` ships empty. The first thing the kit maintainer does after install is run `/create-pack` to add packs.

## Component 4 — Test `tests/verify/init.sh`

New test, **not** added to `tests/verify/all.sh` automatic suite (kept manual for now; can be promoted later).

### Behavior
- Runs in the existing Docker sandbox (Ubuntu 24.04, bind-mounted kit at `/kit:ro`).
- **Setup phase**: since the kit ships empty packs, the test first creates a test pack:
  ```bash
  export AFK_KIT_DIR=/tmp/kit-rw   # writable copy of /kit
  cp -R /kit /tmp/kit-rw
  AFK_PACK_NAME=fixture AFK_PACK_DESC="test fixture" bash "$AFK_KIT_DIR/scripts/create-pack.sh"
  # add a sentinel skill file
  echo "stub" > "$AFK_KIT_DIR/packs/fixture/skills/sentinel.md"
  ```
- **Init phase**: drives the skill with env vars:
  ```bash
  AFK_INIT_PACK=fixture
  AFK_INIT_NAME=test-$(head -c4 /dev/urandom | xxd -p)
  AFK_INIT_PARENT_DIR=/tmp/afk-test
  AFK_INIT_COMMIT=1
  AFK_INIT_PUSH=0
  ```
- After the script runs, asserts:
  - Directory `/tmp/afk-test/test-*/` exists.
  - All scaffold files present and contain the expected canonical content (checks comment markers).
  - `.agents/skills/sentinel.md` exists (copied from the fixture pack).
  - `git log --oneline` shows exactly one commit with message starting `chore: initial scaffold`.
  - `git rev-parse --abbrev-ref HEAD` returns `main`.
  - JSON summary line is valid JSON with the expected keys.
- Exits non-zero on any assertion failure.

### Out of scope for the test
- `gh repo create` (no auth in sandbox).
- Interactive prompts (env vars override everything).
- Symlink-based kit-dir auto-discovery (test uses `AFK_KIT_DIR` directly).

## Component 5 — Updates to existing artifacts

| File | Change |
|---|---|
| `skills/ai-first-init/SKILL.md` | Full rewrite per Component 1. |
| `scripts/init-project.sh` | **New file.** Filesystem work for `ai-first-init`. |
| `scripts/create-pack.sh` | **New file.** Filesystem work for `create-pack`. |
| `scripts/lib/kit-dir.sh` | **New file.** Shared `resolve_kit_dir` helper. |
| `.agents/skills/create-pack/SKILL.md` | **New file.** Project-local skill (Component 2). |
| `tests/verify/init.sh` | **New file.** (Component 4) |
| `commands/ai-first-init.md` | No change (already invokes the skill). |
| `tests/verify/discovery.sh` | No change. |
| `packs/laravel-filament/` | **Removed.** |
| `packs/.gitkeep` | **New file.** Keeps `packs/` tracked but empty. |
| `README.md` (kit root) | Add mention of `/ai-first-init` (and `/create-pack` for maintainers). |
| `docs/known-issues-v0.1.md` | Add entry: "ai-first-init does not adopt existing projects (deferred to ai-first-adopt)." |

## Implementation order (for planning phase)

1. **Component 3** (repo cleanup) — remove `packs/laravel-filament/`, add `packs/.gitkeep`.
2. **`scripts/lib/kit-dir.sh`** — shared helper.
3. **`scripts/create-pack.sh`** + **`.agents/skills/create-pack/SKILL.md`** — Component 2.
4. **`scripts/init-project.sh`** — heavy lifting for Component 1.
5. **`skills/ai-first-init/SKILL.md`** — wrapper that calls the script.
6. **`tests/verify/init.sh`** — exercises both scripts.
7. **Component 5 doc updates** — README and known-issues.

One commit per logical unit (typically per implementation-order step), conventional commits in English.

## Verification checklist (for post-implementation review)

- [ ] `ls packs/` shows only `.gitkeep`.
- [ ] `.agents/skills/create-pack/SKILL.md` exists.
- [ ] `skills/ai-first-init/SKILL.md` no longer contains "Status: skeleton".
- [ ] `scripts/init-project.sh` and `scripts/create-pack.sh` are executable.
- [ ] Running `bash tests/verify/init.sh` from a clean sandbox passes.
- [ ] Running `bash tests/verify/all.sh` still passes (no regressions).
- [ ] Opening opencode at the kit clone surfaces `/create-pack` as a slash command.
- [ ] Opening opencode anywhere else with the kit installed surfaces `/ai-first-init` but NOT `/create-pack`.
- [ ] `discovery.sh` still confirms the expected commands and skills (no regression).

## Open questions

None as of this writing.
