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
