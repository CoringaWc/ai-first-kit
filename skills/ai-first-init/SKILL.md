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
