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
