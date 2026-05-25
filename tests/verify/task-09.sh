#!/usr/bin/env bash
set -euo pipefail

# End-to-end: run bootstrap with AFK_SKIP_TOOLS=1 (deps already validated in
# task-04) and AFK_SKIP_CLONE=1 (network would be needed). Point AFK_KIT_DIR
# at /kit so install_kit_symlinks finds the skeletons we created.
tests/sandbox/run.sh '
  set -e
  export AFK_NONINTERACTIVE=1
  export AFK_SKIP_TOOLS=1
  export AFK_SKIP_CLONE=1
  export AFK_KIT_DIR=/kit
  export AFK_OPENCODE_SKILLS_DIR=$HOME/.config/opencode/skills
  export AFK_OPENCODE_COMMANDS_DIR=$HOME/.config/opencode/commands

  bash /kit/scripts/bootstrap.sh

  test -L $AFK_OPENCODE_SKILLS_DIR/ai-first-bootstrap     && echo S1_OK
  test -L $AFK_OPENCODE_SKILLS_DIR/ai-first-init          && echo S2_OK
  test -L $AFK_OPENCODE_SKILLS_DIR/ai-first-update        && echo S3_OK
  test -L $AFK_OPENCODE_SKILLS_DIR/ai-first-manage-skills && echo S4_OK
  test -L $AFK_OPENCODE_COMMANDS_DIR/ai-first-init.md     && echo C1_OK
  test -L $AFK_OPENCODE_COMMANDS_DIR/ai-first-update.md   && echo C2_OK
  # Targets resolvable inside the container (/kit is mounted).
  test -f $AFK_OPENCODE_SKILLS_DIR/ai-first-bootstrap/SKILL.md && echo T_OK
' 2>&1 | tee /tmp/task-09.out

for tag in S1_OK S2_OK S3_OK S4_OK C1_OK C2_OK T_OK; do
  grep -q "^${tag}\$" /tmp/task-09.out
done

echo "[verify task-09] PASS"
