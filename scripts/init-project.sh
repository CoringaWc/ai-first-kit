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
