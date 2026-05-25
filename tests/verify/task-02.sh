#!/usr/bin/env bash
set -euo pipefail

tests/sandbox/run.sh '
  set -e
  source /kit/scripts/lib/log.sh
  log_info  "hello-info"
  log_warn  "hello-warn"
  log_error "hello-error"
  log_step  "hello-step"
  AFK_NONINTERACTIVE=1 ask_yes_no "default yes works" Y && echo YES_OK
  AFK_NONINTERACTIVE=1 ask_yes_no "default no works"  N || echo NO_OK
  # Implicit default is N → ask_yes_no returns 1.
  # Shell semantics note: in `cmd && A || B`, if cmd fails A is skipped AND B runs.
  # To assert "A must NOT run, B MUST run" we put SHOULD_NOT_REACH in the && branch.
  AFK_NONINTERACTIVE=1 ask_yes_no "implicit default is N" && echo SHOULD_NOT_REACH || echo IMPLICIT_NO_OK
' 2>&1 | tee /tmp/task-02.out

grep -q 'hello-info'        /tmp/task-02.out
grep -q 'hello-warn'        /tmp/task-02.out
grep -q 'hello-error'       /tmp/task-02.out
grep -q 'hello-step'        /tmp/task-02.out
grep -q '^YES_OK$'          /tmp/task-02.out
grep -q '^NO_OK$'           /tmp/task-02.out
# Implicit default is N → ask_yes_no returns 1 → first branch skipped → echo IMPLICIT_NO_OK runs via ||
grep -q '^IMPLICIT_NO_OK$'  /tmp/task-02.out
! grep -q '^SHOULD_NOT_REACH$' /tmp/task-02.out

echo "[verify task-02] PASS"
