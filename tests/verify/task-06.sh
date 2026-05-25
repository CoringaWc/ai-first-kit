#!/usr/bin/env bash
set -euo pipefail

# Skip the clone step (override AFK_KIT_DIR to a fixture) and test only the
# symlink logic. Covers: create, idempotency, safe-default preserve on divergence.
tests/sandbox/run.sh '
  set -e
  source /kit/scripts/lib/log.sh
  source /kit/scripts/lib/install_kit.sh

  mkdir -p $HOME/fake-kit/skills/ai-first-bootstrap
  mkdir -p $HOME/fake-kit/skills/ai-first-init
  mkdir -p $HOME/fake-kit/commands
  echo "# bootstrap" > $HOME/fake-kit/skills/ai-first-bootstrap/SKILL.md
  echo "# init"      > $HOME/fake-kit/skills/ai-first-init/SKILL.md
  echo "# cmd"       > $HOME/fake-kit/commands/ai-first-init.md

  export AFK_KIT_DIR=$HOME/fake-kit
  export AFK_OPENCODE_SKILLS_DIR=$HOME/.config/opencode/skills
  export AFK_OPENCODE_COMMANDS_DIR=$HOME/.config/opencode/commands
  export AFK_NONINTERACTIVE=1

  install_kit_symlinks

  test -L $AFK_OPENCODE_SKILLS_DIR/ai-first-bootstrap && echo SKILL1_OK
  test -L $AFK_OPENCODE_SKILLS_DIR/ai-first-init      && echo SKILL2_OK
  test -L $AFK_OPENCODE_COMMANDS_DIR/ai-first-init.md && echo CMD_OK
  # Resolvable targets (follow link).
  test -e $AFK_OPENCODE_SKILLS_DIR/ai-first-bootstrap/SKILL.md && echo TARGET_OK

  # Idempotency: second run must be silent and not break links.
  install_kit_symlinks
  test -L $AFK_OPENCODE_SKILLS_DIR/ai-first-bootstrap && echo IDEMPOTENT_OK

  # Divergent link must be preserved in NONINTERACTIVE mode (safe default).
  ln -sfn /tmp/elsewhere $AFK_OPENCODE_SKILLS_DIR/ai-first-init
  install_kit_symlinks
  [[ "$(readlink $AFK_OPENCODE_SKILLS_DIR/ai-first-init)" == "/tmp/elsewhere" ]] && echo PRESERVED_OK
' 2>&1 | tee /tmp/task-06.out

grep -q '^SKILL1_OK$'     /tmp/task-06.out
grep -q '^SKILL2_OK$'     /tmp/task-06.out
grep -q '^CMD_OK$'        /tmp/task-06.out
grep -q '^TARGET_OK$'     /tmp/task-06.out
grep -q '^IDEMPOTENT_OK$' /tmp/task-06.out
grep -q '^PRESERVED_OK$'  /tmp/task-06.out

echo "[verify task-06] PASS"
