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

  # 0. Sandbox env setup (git identity needed for init-project commit)
  git config --global user.email "tester@example.com"
  git config --global user.name "AFK Tester"

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
  NAME="test-$(head -c4 /dev/urandom | od -An -tx1 | tr -d "[:space:]")"
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
