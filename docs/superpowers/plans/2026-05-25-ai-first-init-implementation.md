# ai-first-init v0.1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement `ai-first-init` skill that creates a new AI-first project from scratch, plus a maintainer-only `create-pack` skill that scaffolds new packs inside the kit clone.

**Architecture:** Two thin markdown skills delegate to env-var-driven bash scripts. `ai-first-init` (global skill, surfaced everywhere) gathers user input then calls `scripts/init-project.sh` which writes the scaffold and runs git. `create-pack` (project-local skill, only surfaced when opencode opens at the kit clone) calls `scripts/create-pack.sh`. A shared `scripts/lib/kit-dir.sh` resolves `$AFK_KIT_DIR` via env-var or symlink auto-discovery.

**Tech Stack:** Bash 5+, `python3` (for JSON parsing — already a sandbox dep), `git`, optional `gh` for GitHub push, Docker sandbox for tests.

**Spec:** `docs/superpowers/specs/2026-05-25-ai-first-init-design.md`

---

## File Structure

**New files:**
- `scripts/lib/kit-dir.sh` — `resolve_kit_dir` helper (sourced).
- `scripts/init-project.sh` — env-var driven; creates project scaffold.
- `scripts/create-pack.sh` — env-var driven; creates pack scaffold under `<kit>/packs/`.
- `.agents/skills/create-pack/SKILL.md` — project-local skill wrapping `create-pack.sh`.
- `tests/verify/init.sh` — sandbox test exercising both scripts.
- `packs/.gitkeep` — keeps `packs/` tracked while empty.

**Modified files:**
- `skills/ai-first-init/SKILL.md` — full rewrite from skeleton to thin wrapper around `init-project.sh`.
- `README.md` (root) — add 2-line mention of `/ai-first-init` and `/create-pack`.
- `docs/known-issues-v0.1.md` — add entry about deferred existing-project adoption.

**Removed files/dirs:**
- `packs/laravel-filament/` (and its `.gitkeep`).

**Unchanged:**
- `commands/ai-first-init.md` (already invokes the skill by name).
- `tests/verify/all.sh` (new test stays manual for now).
- `tests/verify/discovery.sh` (no skill/command list changes that affect it).
- `registry/global-skills.json` (governs external installs only).

---

## Task 1: Repo cleanup — remove laravel-filament placeholder, keep packs/ tracked

**Files:**
- Remove: `packs/laravel-filament/.gitkeep` (and the directory)
- Create: `packs/.gitkeep`

- [ ] **Step 1: Verify current state**

Run: `ls -la packs/`
Expected output includes: `laravel-filament/` directory.

Run: `ls -la packs/laravel-filament/`
Expected output: only `.gitkeep` (no other files).

- [ ] **Step 2: Remove laravel-filament**

Run: `git rm -r packs/laravel-filament`

Expected: `rm 'packs/laravel-filament/.gitkeep'`.

- [ ] **Step 3: Add packs/.gitkeep**

Create empty file: `packs/.gitkeep`

```bash
touch packs/.gitkeep
git add packs/.gitkeep
```

- [ ] **Step 4: Verify**

Run: `ls -la packs/`
Expected: shows `.gitkeep` only (besides `.` and `..`).

Run: `git status`
Expected: shows deletion of `packs/laravel-filament/.gitkeep` and new `packs/.gitkeep`.

- [ ] **Step 5: Commit**

```bash
git commit -m "chore(packs): remove laravel-filament placeholder, ship empty packs/"
```

---

## Task 2: Create shared kit-dir resolver

**Files:**
- Create: `scripts/lib/kit-dir.sh`

- [ ] **Step 1: Write the helper**

Create `scripts/lib/kit-dir.sh` with this exact content:

```bash
#!/usr/bin/env bash
# kit-dir.sh — resolve_kit_dir helper. Source, do not execute.
#
# Resolution order:
#   1. $AFK_KIT_DIR env var (if set and validates).
#   2. Auto-discover via ~/.config/opencode/skills/ai-first-init symlink target.
#   3. Current working directory (if it looks like a kit clone).
#
# Validation: a "kit dir" must contain both registry/global-mcps.json and packs/.
#
# On success: sets AFK_KIT_DIR and exports it. Returns 0.
# On failure: prints error to stderr. Returns 1.

_kit_dir_validate() {
  local d="$1"
  [[ -n "$d" && -d "$d" ]] || return 1
  [[ -f "$d/registry/global-mcps.json" ]] || return 1
  [[ -d "$d/packs" ]] || return 1
  return 0
}

resolve_kit_dir() {
  # 1. env var
  if [[ -n "${AFK_KIT_DIR:-}" ]]; then
    if _kit_dir_validate "$AFK_KIT_DIR"; then
      export AFK_KIT_DIR
      return 0
    fi
    printf "[err] AFK_KIT_DIR is set to '%s' but it is not a valid kit clone.\n" "$AFK_KIT_DIR" >&2
    return 1
  fi

  # 2. symlink auto-discovery
  local link="${HOME}/.config/opencode/skills/ai-first-init"
  if [[ -L "$link" ]]; then
    local target
    target="$(readlink -f "$link")" || target=""
    if [[ -n "$target" ]]; then
      local candidate
      candidate="$(cd "$target/../.." 2>/dev/null && pwd)" || candidate=""
      if _kit_dir_validate "$candidate"; then
        AFK_KIT_DIR="$candidate"
        export AFK_KIT_DIR
        return 0
      fi
    fi
  fi

  # 3. cwd fallback (useful for create-pack when run inside the kit clone)
  local cwd
  cwd="$(pwd)"
  if _kit_dir_validate "$cwd"; then
    AFK_KIT_DIR="$cwd"
    export AFK_KIT_DIR
    return 0
  fi

  printf "[err] Could not resolve AFK_KIT_DIR. Set it explicitly or run 'ai-first-bootstrap' first.\n" >&2
  return 1
}
```

- [ ] **Step 2: Write a quick smoke test inline**

Run:

```bash
cd /home/coringawc/ai-first-kit
unset AFK_KIT_DIR
bash -c 'source scripts/lib/kit-dir.sh && resolve_kit_dir && echo "RESOLVED=$AFK_KIT_DIR"'
```

Expected: prints `RESOLVED=/home/coringawc/ai-first-kit` (because cwd fallback works — this repo IS a kit).

Run:

```bash
AFK_KIT_DIR=/nonexistent bash -c 'source scripts/lib/kit-dir.sh && resolve_kit_dir; echo "rc=$?"'
```

Expected: prints `[err] AFK_KIT_DIR is set to '/nonexistent' but it is not a valid kit clone.` and `rc=1`.

- [ ] **Step 3: Commit**

```bash
git add scripts/lib/kit-dir.sh
git commit -m "feat(scripts): add shared resolve_kit_dir helper"
```

---

## Task 3: Implement scripts/create-pack.sh

**Files:**
- Create: `scripts/create-pack.sh`

- [ ] **Step 1: Write the script**

Create `scripts/create-pack.sh` with this exact content:

```bash
#!/usr/bin/env bash
# create-pack.sh — scaffold a new pack inside ai-first-kit.
#
# Inputs (all required, env vars only):
#   AFK_PACK_NAME  — slug, ^[a-z0-9][a-z0-9-]*$, length 2-40
#   AFK_PACK_DESC  — one-line description, non-empty, <=200 chars
#
# Optional:
#   AFK_KIT_DIR    — kit root. If unset, resolved via scripts/lib/kit-dir.sh.
#
# Exit codes:
#   0  — success (last stdout line is JSON: {"dest":"...","name":"..."})
#   2  — missing/invalid input
#   3  — pack already exists
#   4  — could not resolve kit dir

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/kit-dir.sh
source "$SCRIPT_DIR/lib/kit-dir.sh"

# Validate inputs.
NAME="${AFK_PACK_NAME:-}"
DESC="${AFK_PACK_DESC:-}"

if [[ -z "$NAME" ]]; then
  printf "[err] AFK_PACK_NAME is required.\n" >&2
  exit 2
fi
if [[ ! "$NAME" =~ ^[a-z0-9][a-z0-9-]*$ ]] || (( ${#NAME} < 2 || ${#NAME} > 40 )); then
  printf "[err] AFK_PACK_NAME '%s' invalid (must match [a-z0-9][a-z0-9-]*, length 2-40).\n" "$NAME" >&2
  exit 2
fi
if [[ -z "$DESC" ]]; then
  printf "[err] AFK_PACK_DESC is required.\n" >&2
  exit 2
fi
if (( ${#DESC} > 200 )); then
  printf "[err] AFK_PACK_DESC too long (%d chars, max 200).\n" "${#DESC}" >&2
  exit 2
fi

# Resolve kit dir.
if ! resolve_kit_dir; then
  exit 4
fi

DEST="$AFK_KIT_DIR/packs/$NAME"
if [[ -e "$DEST" ]]; then
  printf "[err] Pack '%s' already exists at %s\n" "$NAME" "$DEST" >&2
  exit 3
fi

# Create scaffold.
mkdir -p "$DEST/skills"

# manifest.json — use python3 to safely encode the description.
python3 - "$NAME" "$DESC" <<'PY' > "$DEST/manifest.json"
import json, sys
name, desc = sys.argv[1], sys.argv[2]
json.dump({"name": name, "description": desc}, sys.stdout, indent=2)
sys.stdout.write("\n")
PY

# README.md
cat > "$DEST/README.md" <<EOF
# $NAME

$DESC

## Skills

TODO: document the skills bundled with this pack and how they fit together.

## Usage

Selected from \`ai-first-init\`'s pack list. Skills under \`skills/\` are copied into
\`<project>/.agents/skills/\` when a user scaffolds a project with this pack.
EOF

touch "$DEST/skills/.gitkeep"

# Emit JSON summary on the last stdout line.
python3 - "$DEST" "$NAME" <<'PY'
import json, sys
print(json.dumps({"dest": sys.argv[1], "name": sys.argv[2]}))
PY
```

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/create-pack.sh
```

- [ ] **Step 3: Smoke test — success path**

```bash
cd /home/coringawc/ai-first-kit
AFK_KIT_DIR="$(pwd)" AFK_PACK_NAME=smoketest AFK_PACK_DESC="smoke test pack" \
  bash scripts/create-pack.sh
```

Expected last line of stdout: `{"dest": "/home/coringawc/ai-first-kit/packs/smoketest", "name": "smoketest"}`

Verify:
```bash
ls packs/smoketest/
cat packs/smoketest/manifest.json
```

Expected: `manifest.json README.md skills` listed; manifest contains `"name": "smoketest"` and `"description": "smoke test pack"`.

- [ ] **Step 4: Smoke test — error paths**

```bash
# missing name
AFK_KIT_DIR="$(pwd)" bash scripts/create-pack.sh; echo "rc=$?"
```
Expected: error message about missing AFK_PACK_NAME, `rc=2`.

```bash
# invalid slug
AFK_KIT_DIR="$(pwd)" AFK_PACK_NAME="Bad Name" AFK_PACK_DESC="x" bash scripts/create-pack.sh; echo "rc=$?"
```
Expected: error about invalid slug, `rc=2`.

```bash
# already exists
AFK_KIT_DIR="$(pwd)" AFK_PACK_NAME=smoketest AFK_PACK_DESC=x bash scripts/create-pack.sh; echo "rc=$?"
```
Expected: error "Pack 'smoketest' already exists", `rc=3`.

- [ ] **Step 5: Clean up smoke artifacts**

```bash
rm -rf packs/smoketest
```

Verify `git status` shows no untracked files under `packs/`.

- [ ] **Step 6: Commit**

```bash
git add scripts/create-pack.sh
git commit -m "feat(scripts): add create-pack.sh for scaffolding new packs"
```

---

## Task 4: Add the project-local create-pack skill

**Files:**
- Create: `.agents/skills/create-pack/SKILL.md`

- [ ] **Step 1: Verify .agents/ doesn't exist yet**

Run: `ls -la .agents 2>&1 || echo "missing — good"`
Expected: "missing — good" (we're creating it fresh).

- [ ] **Step 2: Write the skill**

Create `.agents/skills/create-pack/SKILL.md` with this exact content:

````markdown
---
name: create-pack
description: Scaffold a new pack inside ai-first-kit. Creates packs/<name>/ with manifest.json, README.md, and an empty skills/ directory. Use when the kit maintainer runs `/create-pack` or asks to "create a new pack". Must be run from inside an ai-first-kit clone.
---

# create-pack

Maintainer-only skill: scaffolds a new pack folder under `<kit>/packs/<name>/`.
End users with the kit installed do NOT see this skill — it lives in
`<kit>/.agents/skills/` and is only surfaced when opencode is opened at the kit
clone itself.

## When to use

The user asks to "create a new pack", "scaffold a pack", or runs `/create-pack`.

## Inputs

Ask the user, one at a time:

1. **Pack name (slug):** must match `^[a-z0-9][a-z0-9-]*$`, length 2-40.
   - Reprompt up to 3 times on invalid input; abort if still invalid.
2. **One-line description:** non-empty, ≤200 chars.

Allow env-var overrides (used by tests): `AFK_PACK_NAME`, `AFK_PACK_DESC`.

## Action

Run the kit script with the gathered inputs:

```bash
AFK_PACK_NAME="<name>" AFK_PACK_DESC="<desc>" bash "$AFK_KIT_DIR/scripts/create-pack.sh"
```

If `$AFK_KIT_DIR` is not set in the environment, the script auto-resolves it
via `scripts/lib/kit-dir.sh` (env var → symlink → cwd fallback).

## On success

The script prints a JSON line on its last stdout. Parse `dest` and `name`,
then tell the user:

- Created: `<dest>`
- Files: `manifest.json`, `README.md`, `skills/.gitkeep`
- Next: add skills under `packs/<name>/skills/`, then commit:

  ```bash
  cd "$AFK_KIT_DIR"
  git add packs/<name>
  git commit -m "feat(packs): add <name> pack"
  ```

## On failure

| Exit code | Meaning | Action |
|---|---|---|
| 2 | invalid input | Show the error; reprompt if interactive. |
| 3 | pack already exists | Show the path; do not overwrite. |
| 4 | could not resolve kit dir | Instruct the user to run `/ai-first-bootstrap` or open opencode at the kit clone. |
````

- [ ] **Step 3: Verify file exists and frontmatter parses**

Run: `head -5 .agents/skills/create-pack/SKILL.md`
Expected: starts with `---`, then `name: create-pack`, then `description: ...`, then `---`.

- [ ] **Step 4: Commit**

```bash
git add .agents/skills/create-pack/SKILL.md
git commit -m "feat(skills): add project-local create-pack skill"
```

---

## Task 5: Implement scripts/init-project.sh

**Files:**
- Create: `scripts/init-project.sh`

- [ ] **Step 1: Write the script**

Create `scripts/init-project.sh` with this exact content:

```bash
#!/usr/bin/env bash
# init-project.sh — create a new AI-first project from scratch.
#
# Inputs (env vars only; all required unless noted):
#   AFK_INIT_PACK         — pack name (folder under <kit>/packs/)
#   AFK_INIT_NAME         — project slug ^[a-z0-9][a-z0-9-]*$, length 2-40
#   AFK_INIT_PARENT_DIR   — absolute parent dir (created if missing)
#   AFK_INIT_COMMIT       — "1" or "0"
#   AFK_INIT_PUSH         — "1" or "0" (ignored if AFK_INIT_COMMIT=0)
#
# Optional:
#   AFK_KIT_DIR           — kit root. If unset, resolved via kit-dir.sh.
#
# Exit codes:
#   0  — success (last stdout line is a JSON summary)
#   2  — missing/invalid input
#   3  — destination exists and is non-empty
#   4  — could not resolve kit dir
#   5  — pack not found
#   6  — git or required tool not on PATH

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/kit-dir.sh
source "$SCRIPT_DIR/lib/kit-dir.sh"

# --- Input validation -----------------------------------------------------

PACK="${AFK_INIT_PACK:-}"
NAME="${AFK_INIT_NAME:-}"
PARENT="${AFK_INIT_PARENT_DIR:-}"
COMMIT="${AFK_INIT_COMMIT:-}"
PUSH="${AFK_INIT_PUSH:-}"

for var in PACK NAME PARENT COMMIT PUSH; do
  if [[ -z "${!var}" ]]; then
    printf "[err] AFK_INIT_%s is required.\n" "$var" >&2
    exit 2
  fi
done

if [[ ! "$NAME" =~ ^[a-z0-9][a-z0-9-]*$ ]] || (( ${#NAME} < 2 || ${#NAME} > 40 )); then
  printf "[err] AFK_INIT_NAME '%s' invalid (must match [a-z0-9][a-z0-9-]*, length 2-40).\n" "$NAME" >&2
  exit 2
fi
if [[ "$PARENT" != /* ]]; then
  printf "[err] AFK_INIT_PARENT_DIR must be absolute (got '%s').\n" "$PARENT" >&2
  exit 2
fi
if [[ "$COMMIT" != "0" && "$COMMIT" != "1" ]]; then
  printf "[err] AFK_INIT_COMMIT must be '0' or '1' (got '%s').\n" "$COMMIT" >&2
  exit 2
fi
if [[ "$PUSH" != "0" && "$PUSH" != "1" ]]; then
  printf "[err] AFK_INIT_PUSH must be '0' or '1' (got '%s').\n" "$PUSH" >&2
  exit 2
fi

# --- Resolve kit + pack ---------------------------------------------------

if ! resolve_kit_dir; then
  exit 4
fi

PACK_DIR="$AFK_KIT_DIR/packs/$PACK"
if [[ ! -f "$PACK_DIR/manifest.json" ]]; then
  printf "[err] Pack '%s' not found at %s (no manifest.json).\n" "$PACK" "$PACK_DIR" >&2
  exit 5
fi

# --- Tooling checks -------------------------------------------------------

if ! command -v git >/dev/null 2>&1; then
  printf "[err] 'git' not on PATH. Run /ai-first-bootstrap first.\n" >&2
  exit 6
fi

PUSH_EFFECTIVE="$PUSH"
if [[ "$PUSH" == "1" ]] && ! command -v gh >/dev/null 2>&1; then
  printf "[warn] 'gh' not on PATH; will skip GitHub repo creation.\n" >&2
  PUSH_EFFECTIVE="0"
fi

# --- Destination check ----------------------------------------------------

DEST="$PARENT/$NAME"
if [[ -e "$DEST" ]]; then
  if [[ -d "$DEST" ]] && [[ -z "$(ls -A "$DEST" 2>/dev/null)" ]]; then
    : # empty dir is fine, reuse it
  else
    printf "[err] Destination '%s' exists and is not empty. Aborting.\n" "$DEST" >&2
    exit 3
  fi
fi

mkdir -p "$DEST"

# --- Read pack description ------------------------------------------------

PACK_DESC="$(python3 -c "import json;print(json.load(open('$PACK_DIR/manifest.json')).get('description',''))")"

# --- Scaffold layout ------------------------------------------------------

mkdir -p "$DEST/.agents/skills"
mkdir -p "$DEST/.cert"
mkdir -p "$DEST/.git-crypt-keys"

cat > "$DEST/.cert/.gitignore" <<'EOF'
# Keep certs versioned (encrypted via git-crypt once init-project enables it).
# Ignore local-only and temporary files.
*.local
*.tmp
*~
EOF

cat > "$DEST/.git-crypt-keys/.gitignore" <<'EOF'
# Symmetric keys must NEVER be committed.
# Keep this directory tracked so collaborators know where to drop their key.
*.key
EOF

cat > "$DEST/.gitattributes" <<'EOF'
# AI-first scaffold — git-crypt filter lines are TEMPLATES, commented out.
# Uncomment after running `git-crypt init` (handled by /init-project).

# .env       filter=git-crypt diff=git-crypt
# .cert/cert.key filter=git-crypt diff=git-crypt
# .cert/cert.pem filter=git-crypt diff=git-crypt

* text=auto eol=lf
EOF

cat > "$DEST/.gitignore" <<'EOF'
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
EOF

# README — interpolate name, pack, and pack description.
README_PACK_DESC="$PACK_DESC"
if [[ -z "$README_PACK_DESC" ]]; then
  README_PACK_DESC="TBD — populate after running /init-project."
fi

cat > "$DEST/README.md" <<EOF
# $NAME

> Scaffolded from [\`ai-first-kit\`](https://github.com/CoringaWc/ai-first-kit) — pack \`$PACK\`.

## Stack

$README_PACK_DESC

## Prerequisites

See your stack pack's documentation. The AI-first host bootstrap (\`ai-first-bootstrap\`) installs the common baseline.

## Next steps

This project has the AI-first scaffold but no stack-specific setup yet.

1. Open opencode in this directory: \`opencode\`
2. Run \`/init-project\` to install dependencies, configure git-crypt, and prepare the stack.

## Layout

- \`.agents/skills/\` — opencode skills bundled with this project
- \`.cert/\` — TLS / signing certificates (encrypted in git once git-crypt is enabled)
- \`.git-crypt-keys/\` — directory for the symmetric key (keys themselves are gitignored)
- \`.gitattributes\` — git-crypt filter templates (commented)
EOF

# --- Copy pack skills -----------------------------------------------------

SKILLS_COPIED=0
if [[ -d "$PACK_DIR/skills" ]]; then
  # Count regular files under the pack's skills dir (excluding .gitkeep)
  shopt -s nullglob dotglob
  if [[ -n "$(ls -A "$PACK_DIR/skills" 2>/dev/null | grep -v '^\.gitkeep$' || true)" ]]; then
    cp -R "$PACK_DIR/skills/." "$DEST/.agents/skills/"
    # Remove .gitkeep markers we don't want polluting the project
    find "$DEST/.agents/skills" -name '.gitkeep' -delete 2>/dev/null || true
    SKILLS_COPIED="$(find "$DEST/.agents/skills" -type f | wc -l | tr -d ' ')"
  fi
  shopt -u nullglob dotglob
fi

# --- Git init -------------------------------------------------------------

cd "$DEST"
git init -b main >/dev/null 2>&1

COMMIT_SHA=""
REMOTE_URL=""

if [[ "$COMMIT" == "1" ]]; then
  git add -A
  git commit -m "chore: initial scaffold from ai-first-kit (pack=$PACK)" >/dev/null
  COMMIT_SHA="$(git rev-parse --short HEAD)"

  if [[ "$PUSH_EFFECTIVE" == "1" ]]; then
    if gh repo create "$NAME" --private --source . --push --remote origin >/dev/null 2>&1; then
      REMOTE_URL="$(git remote get-url origin 2>/dev/null || true)"
    else
      printf "[warn] gh repo create failed; keeping local commit. Retry manually with:\n  cd %s && gh repo create %s --private --source . --push\n" "$DEST" "$NAME" >&2
    fi
  fi
fi

# --- Emit summary ---------------------------------------------------------

python3 - "$DEST" "$PACK" "$SKILLS_COPIED" "$COMMIT_SHA" "$REMOTE_URL" <<'PY'
import json, sys
dest, pack, skills, commit, remote = sys.argv[1:6]
print(json.dumps({
    "dest": dest,
    "pack": pack,
    "skills_copied": int(skills),
    "commit": commit or None,
    "remote": remote or None,
}))
PY
```

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/init-project.sh
```

- [ ] **Step 3: Smoke test — success path with fixture pack**

Set up a fixture pack in the local kit:

```bash
cd /home/coringawc/ai-first-kit
AFK_KIT_DIR="$(pwd)" AFK_PACK_NAME=fixture AFK_PACK_DESC="fixture for init-project smoke test" \
  bash scripts/create-pack.sh
echo "stub skill" > packs/fixture/skills/sentinel.md
```

Run the init script:

```bash
rm -rf /tmp/afk-smoke
AFK_KIT_DIR="$(pwd)" \
  AFK_INIT_PACK=fixture \
  AFK_INIT_NAME=demo-proj \
  AFK_INIT_PARENT_DIR=/tmp/afk-smoke \
  AFK_INIT_COMMIT=1 \
  AFK_INIT_PUSH=0 \
  bash scripts/init-project.sh
```

Expected last stdout line is JSON like:
```json
{"dest": "/tmp/afk-smoke/demo-proj", "pack": "fixture", "skills_copied": 1, "commit": "...", "remote": null}
```

Verify:
```bash
ls -la /tmp/afk-smoke/demo-proj
cat /tmp/afk-smoke/demo-proj/.gitattributes
cat /tmp/afk-smoke/demo-proj/.agents/skills/sentinel.md
cd /tmp/afk-smoke/demo-proj && git log --oneline
```

Expected:
- All scaffold files present (`.cert/.gitignore`, `.git-crypt-keys/.gitignore`, `.gitattributes`, `.gitignore`, `README.md`, `.agents/skills/sentinel.md`)
- `.gitattributes` contains commented `# .env filter=git-crypt`
- `.agents/skills/sentinel.md` content is `stub skill`
- One commit, message starts with `chore: initial scaffold`
- Branch is `main`

- [ ] **Step 4: Smoke test — destination already non-empty**

```bash
cd /home/coringawc/ai-first-kit
AFK_KIT_DIR="$(pwd)" \
  AFK_INIT_PACK=fixture \
  AFK_INIT_NAME=demo-proj \
  AFK_INIT_PARENT_DIR=/tmp/afk-smoke \
  AFK_INIT_COMMIT=0 \
  AFK_INIT_PUSH=0 \
  bash scripts/init-project.sh; echo "rc=$?"
```

Expected: error "Destination ... exists and is not empty", `rc=3`.

- [ ] **Step 5: Smoke test — missing pack**

```bash
cd /home/coringawc/ai-first-kit
rm -rf /tmp/afk-smoke
AFK_KIT_DIR="$(pwd)" \
  AFK_INIT_PACK=does-not-exist \
  AFK_INIT_NAME=foo \
  AFK_INIT_PARENT_DIR=/tmp/afk-smoke \
  AFK_INIT_COMMIT=0 \
  AFK_INIT_PUSH=0 \
  bash scripts/init-project.sh; echo "rc=$?"
```

Expected: error "Pack 'does-not-exist' not found", `rc=5`.

- [ ] **Step 6: Clean up smoke artifacts**

```bash
cd /home/coringawc/ai-first-kit
rm -rf packs/fixture /tmp/afk-smoke
git status
```

Expected: working tree clean except for the new `scripts/init-project.sh`.

- [ ] **Step 7: Commit**

```bash
git add scripts/init-project.sh
git commit -m "feat(scripts): add init-project.sh for new AI-first project scaffolds"
```

---

## Task 6: Rewrite skills/ai-first-init/SKILL.md

**Files:**
- Modify: `skills/ai-first-init/SKILL.md` (full rewrite, replaces skeleton)

- [ ] **Step 1: Verify current placeholder**

Run: `cat skills/ai-first-init/SKILL.md`
Expected: contains "Status: skeleton" and "TODO".

- [ ] **Step 2: Write the new skill body**

Overwrite `skills/ai-first-init/SKILL.md` with this exact content:

````markdown
---
name: ai-first-init
description: Create a new project folder scaffolded for the AI-first workflow — picks a stack pack from the installed ai-first-kit, lays out .cert/, .git-crypt-keys/, .agents/skills/, README, .gitignore, .gitattributes, runs `git init`, makes an initial commit, and optionally pushes to GitHub. Does NOT run stack-specific setup (that is `init-project`'s job inside the new project). Use when the user runs `/ai-first-init` or asks to "create a new AI-first project".
---

# ai-first-init

Create a brand-new project on disk with the AI-first scaffold. Does **not**
modify any existing project (that's a future `ai-first-adopt` skill).

## What this skill produces

A new directory at `<parent>/<name>/` containing:

- `.agents/skills/` — populated with skills copied from the chosen pack
- `.cert/` with `.gitignore` (versioned, ready for git-crypt)
- `.git-crypt-keys/` with `.gitignore` (ignores `*.key`)
- `.gitattributes` — commented git-crypt filter templates
- `.gitignore` — minimal sensible defaults
- `README.md` — minimal template referencing the chosen pack
- `git init` on `main`, optional initial commit, optional GitHub push

It does **not** run `git-crypt init`, install dependencies, run migrations,
or any stack-specific setup. That is `init-project`'s job, run from inside
the generated project.

## When to use

The user runs `/ai-first-init` or asks to "create a new AI-first project",
"scaffold a new project", or similar.

## Inputs (ask one at a time)

1. **Stack pack.** List the packs available in the installed kit (see
   "Discovering packs" below). Show name and description. Ask the user to
   pick one. Env override: `AFK_INIT_PACK`.

2. **Project name.** Must be a slug matching `^[a-z0-9][a-z0-9-]*$`, length
   2-40. Reprompt up to 3 times on invalid input, then abort. Env override:
   `AFK_INIT_NAME`.

3. **Parent directory.** Default `$HOME/Projects`. Always confirm with the
   user (even if accepting default). Must be absolute. Env override:
   `AFK_INIT_PARENT_DIR`.

4. **Create initial commit?** Default yes. Env override: `AFK_INIT_COMMIT`
   (`1` or `0`).

5. **Create GitHub repo and push now?** Default no. Only ask if commit=yes.
   Env override: `AFK_INIT_PUSH` (`1` or `0`).

If ALL five env vars are set, skip prompts entirely (non-interactive mode
used by tests).

## Resolving the kit directory

Before listing packs, resolve `$AFK_KIT_DIR`:

1. If env var `AFK_KIT_DIR` is set, use it (after validation).
2. Otherwise, run:
   ```bash
   readlink -f "$HOME/.config/opencode/skills/ai-first-init"
   ```
   Then go up two directories from the resolved path. That's the kit root.
3. Validate: the directory must contain `registry/global-mcps.json` and
   `packs/`. If not, abort with: "Could not locate ai-first-kit. Run
   /ai-first-bootstrap first."

The script `scripts/init-project.sh` performs the same resolution
internally, so you can also just call the script and let it fail with exit
code 4 if the kit is missing.

## Discovering packs

```bash
shopt -s nullglob
for manifest in "$AFK_KIT_DIR"/packs/*/manifest.json; do
  name=$(python3 -c "import json;print(json.load(open('$manifest'))['name'])")
  desc=$(python3 -c "import json;print(json.load(open('$manifest')).get('description',''))")
  printf "  - %s — %s\n" "$name" "$desc"
done
```

Folders without `manifest.json` are silently ignored.

**If zero packs are found**, abort with:
> No packs available in `<AFK_KIT_DIR>/packs/`. To create one, open opencode at the ai-first-kit clone and run `/create-pack`.

## Action

After gathering all inputs, call the script:

```bash
AFK_KIT_DIR="$AFK_KIT_DIR" \
AFK_INIT_PACK="$pack" \
AFK_INIT_NAME="$name" \
AFK_INIT_PARENT_DIR="$parent" \
AFK_INIT_COMMIT="$commit" \
AFK_INIT_PUSH="$push" \
bash "$AFK_KIT_DIR/scripts/init-project.sh"
```

Capture the last stdout line — it's a JSON summary:
```json
{"dest":"...","pack":"...","skills_copied":N,"commit":"sha or null","remote":"url or null"}
```

## On success

Tell the user:

- Project created at `<dest>`
- Pack used: `<pack>`
- Skills copied: `<skills_copied>`
- Commit: `<commit or "none">`
- Remote: `<remote or "none — pushed locally only">`
- **Next:** `cd <dest> && opencode`, then run `/init-project` to install
  dependencies and configure git-crypt for the stack.

## Error handling

| Script exit code | Meaning | How to surface |
|---|---|---|
| 2 | invalid input | Show the error from the script, reprompt if interactive. |
| 3 | destination exists | Show the path; tell user to pick a different name or remove the existing dir manually. |
| 4 | kit dir missing | Instruct: "Run /ai-first-bootstrap first." |
| 5 | pack not found | List available packs and reprompt. |
| 6 | missing required tool | Instruct: "Run /ai-first-bootstrap first." |

If `gh` is missing but the user asked for push, the script warns and skips
push automatically — the local commit is preserved. Tell the user how to
push manually:

```bash
cd <dest> && gh repo create <name> --private --source . --push
```
````

- [ ] **Step 3: Verify rewrite**

Run: `head -3 skills/ai-first-init/SKILL.md`
Expected: starts with `---` frontmatter line.

Run: `grep -c "Status: skeleton" skills/ai-first-init/SKILL.md`
Expected: `0`.

Run: `grep -c "^# ai-first-init" skills/ai-first-init/SKILL.md`
Expected: `1`.

- [ ] **Step 4: Commit**

```bash
git add skills/ai-first-init/SKILL.md
git commit -m "feat(skills): implement ai-first-init body (creates new project from pack)"
```

---

## Task 7: Add tests/verify/init.sh

**Files:**
- Create: `tests/verify/init.sh`

- [ ] **Step 1: Write the test**

Create `tests/verify/init.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

# End-to-end test for scripts/init-project.sh + scripts/create-pack.sh.
#
# Strategy:
#   1. Sandbox bind-mounts the repo at /kit (read-only).
#   2. Test copies /kit to /tmp/kit-rw (writable) so it can create a fixture pack.
#   3. Runs create-pack.sh to add a 'fixture' pack with a sentinel skill.
#   4. Runs init-project.sh to scaffold /tmp/afk-test/test-<rand>/.
#   5. Asserts scaffold contents, sentinel skill copy, single git commit, branch=main,
#      and that the JSON summary line is valid and contains expected keys.

tests/sandbox/run.sh '
  set -euo pipefail
  export AFK_KIT_DIR=/tmp/kit-rw

  # 1. Writable copy of the kit
  cp -R /kit /tmp/kit-rw

  # 2. Create fixture pack
  AFK_PACK_NAME=fixture \
  AFK_PACK_DESC="fixture pack for init test" \
    bash "$AFK_KIT_DIR/scripts/create-pack.sh" > /tmp/cp.out
  echo "stub skill" > "$AFK_KIT_DIR/packs/fixture/skills/sentinel.md"

  # Verify create-pack summary
  tail -n1 /tmp/cp.out | python3 -c "import json,sys;d=json.loads(sys.stdin.read());assert d[\"name\"]==\"fixture\";print(\"CP_OK\")"

  # 3. Run init-project
  NAME="test-$(head -c4 /dev/urandom | xxd -p)"
  AFK_INIT_PACK=fixture \
  AFK_INIT_NAME="$NAME" \
  AFK_INIT_PARENT_DIR=/tmp/afk-test \
  AFK_INIT_COMMIT=1 \
  AFK_INIT_PUSH=0 \
    bash "$AFK_KIT_DIR/scripts/init-project.sh" > /tmp/ip.out

  DEST="/tmp/afk-test/$NAME"

  # 4. Assertions
  test -d "$DEST"                              && echo D_OK
  test -f "$DEST/.cert/.gitignore"             && echo CERT_OK
  test -f "$DEST/.git-crypt-keys/.gitignore"   && echo GCK_OK
  test -f "$DEST/.gitattributes"               && echo GA_OK
  test -f "$DEST/.gitignore"                   && echo GI_OK
  test -f "$DEST/README.md"                    && echo RM_OK
  test -f "$DEST/.agents/skills/sentinel.md"   && echo SK_OK
  grep -q "filter=git-crypt" "$DEST/.gitattributes" && echo GAFILT_OK
  grep -q "^# .env" "$DEST/.gitattributes"     && echo GACOMMENT_OK
  grep -q "^# $NAME$" "$DEST/README.md"        && echo RMNAME_OK

  cd "$DEST"
  test "$(git rev-parse --abbrev-ref HEAD)" = "main" && echo BR_OK
  test "$(git log --oneline | wc -l | tr -d \  )" = "1" && echo LOG_OK
  git log -1 --pretty=%s | grep -q "^chore: initial scaffold" && echo MSG_OK

  # 5. JSON summary
  tail -n1 /tmp/ip.out | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
assert d[\"pack\"] == \"fixture\"
assert d[\"skills_copied\"] == 1
assert d[\"commit\"] is not None
assert d[\"remote\"] is None
print(\"JSON_OK\")
"
' 2>&1 | tee /tmp/init-verify.out

for tag in CP_OK D_OK CERT_OK GCK_OK GA_OK GI_OK RM_OK SK_OK GAFILT_OK GACOMMENT_OK RMNAME_OK BR_OK LOG_OK MSG_OK JSON_OK; do
  grep -q "^${tag}\$" /tmp/init-verify.out || { echo "[verify init] missing tag: $tag" >&2; exit 1; }
done

echo "[verify init] PASS"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x tests/verify/init.sh
```

- [ ] **Step 3: Pre-flight — verify sandbox image still builds**

Run:
```bash
docker image inspect ai-first-kit-sandbox:$(sha256sum tests/sandbox/Dockerfile | cut -c1-12) >/dev/null 2>&1 && echo "image cached" || echo "will build"
```

Either output is acceptable; if it will build, the test will trigger a build automatically.

- [ ] **Step 4: Run the test**

```bash
bash tests/verify/init.sh
```

Expected last line: `[verify init] PASS`.

Expected: every tag (CP_OK, D_OK, CERT_OK, GCK_OK, GA_OK, GI_OK, RM_OK, SK_OK, GAFILT_OK, GACOMMENT_OK, RMNAME_OK, BR_OK, LOG_OK, MSG_OK, JSON_OK) appears in the output.

- [ ] **Step 5: Commit**

```bash
git add tests/verify/init.sh
git commit -m "test(verify): end-to-end test for init-project and create-pack scripts"
```

---

## Task 8: Documentation updates

**Files:**
- Modify: `README.md` (root)
- Modify: `docs/known-issues-v0.1.md`

- [ ] **Step 1: Locate the right spot in README**

Run: `grep -n "ai-first-bootstrap\|/ai-first-" README.md | head -20`

Find the existing usage/commands section. We add two lines documenting the new commands.

- [ ] **Step 2: Update README**

Find the section in `README.md` that lists existing slash commands (likely a "Usage" or "Commands" section). Add two entries:

- `/ai-first-init` — scaffold a brand-new AI-first project from a stack pack.
- `/create-pack` — (maintainers only, run from inside a kit clone) scaffold a new pack under `packs/`.

If the README does not have such a section, add a short "Slash commands" section near the top (after the introduction) with all four commands: `/ai-first-bootstrap`, `/ai-first-init`, `/ai-first-update`, `/ai-first-manage-skills`, plus `/create-pack` noted as maintainer-only.

The exact placement depends on the current README structure. Make a minimal, non-disruptive addition.

- [ ] **Step 3: Update known-issues**

Append a new entry to `docs/known-issues-v0.1.md` (at the end, before any closing fence):

```markdown

## ai-first-init does not adopt existing projects

`ai-first-init` v0.1 creates a brand-new project folder from scratch. It does
not initialize or modify an existing project. A future `ai-first-adopt` skill
(v0.2+) will handle that case.
```

- [ ] **Step 4: Verify**

Run: `grep -c "ai-first-init" README.md`
Expected: at least 2 (the existing description plus the new line).

Run: `tail -10 docs/known-issues-v0.1.md`
Expected: shows the new "ai-first-adopt" entry.

- [ ] **Step 5: Commit**

```bash
git add README.md docs/known-issues-v0.1.md
git commit -m "docs: mention /ai-first-init, /create-pack, and ai-first-adopt deferral"
```

---

## Task 9: Final verification

**Files:** none modified; verification only.

- [ ] **Step 1: Run discovery test (no regressions)**

```bash
bash tests/verify/discovery.sh
```

Expected: passes (this test requires network and ~2 minutes; if running offline, document the skip).

Note: if network unavailable, log this and continue — the test was not in the automatic suite before this plan started.

- [ ] **Step 2: Run the new init test**

```bash
bash tests/verify/init.sh
```

Expected: `[verify init] PASS`.

- [ ] **Step 3: Run the standard suite**

```bash
bash tests/verify/all.sh
```

Expected: every task verification passes.

- [ ] **Step 4: Manual checklist**

Run each check and verify the expected outcome:

```bash
ls packs/                                         # only .gitkeep
ls .agents/skills/create-pack/SKILL.md            # exists
ls scripts/init-project.sh scripts/create-pack.sh # both exist
ls scripts/lib/kit-dir.sh                         # exists
test -x scripts/init-project.sh && echo X_INIT_OK
test -x scripts/create-pack.sh && echo X_CP_OK
grep -L "Status: skeleton" skills/ai-first-init/SKILL.md   # should print path (=> no skeleton marker)
git log --oneline -10                             # shows new commits
git status                                        # clean
```

- [ ] **Step 5: Summary report**

No commit needed for this task. Report: all checks passed, total N commits added, ready for review.

---

## Self-review notes (for plan author)

Reviewed against `docs/superpowers/specs/2026-05-25-ai-first-init-design.md`:

- Spec Component 1 (ai-first-init skill) → Task 6 (skill rewrite) + Task 5 (script).
- Spec Component 2 (create-pack skill) → Task 4 (skill) + Task 3 (script).
- Spec Component 3 (repo cleanup) → Task 1.
- Spec Component 4 (init.sh test) → Task 7.
- Spec Component 5 (doc updates) → Task 8.
- Shared kit-dir helper called out in spec → Task 2.
- Final verification not in spec but standard practice → Task 9.

Type/method consistency: env var names match across tasks (`AFK_INIT_PACK`, `AFK_INIT_NAME`, `AFK_INIT_PARENT_DIR`, `AFK_INIT_COMMIT`, `AFK_INIT_PUSH`, `AFK_PACK_NAME`, `AFK_PACK_DESC`, `AFK_KIT_DIR`). Exit codes consistent (2=input, 3=dest-exists for init / pack-exists for create-pack, 4=kit-dir, 5=pack-not-found in init only, 6=missing-tool in init only). JSON summary key names: `dest`, `pack`, `skills_copied`, `commit`, `remote` (init) and `dest`, `name` (create-pack).

No placeholders detected.
