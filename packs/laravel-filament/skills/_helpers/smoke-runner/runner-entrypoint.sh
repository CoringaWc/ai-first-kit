#!/usr/bin/env bash
# Container entrypoint. Dispatches to a scenario script.
set -euo pipefail

SCENARIO="${SCENARIO:-group-a-fpm-ptbr}"
SCRIPT="/harness/scenarios/${SCENARIO}.sh"

if [[ ! -x "$SCRIPT" ]]; then
    echo "ERROR: scenario script not executable: $SCRIPT" >&2
    exit 2
fi

WORK_CONTAINER_DIR="${WORK_CONTAINER_DIR:-${WORK_HOST_DIR:-/work}}"
export GIT_CONFIG_GLOBAL="${GIT_CONFIG_GLOBAL:-/tmp/smoke-runner-gitconfig}"
git config --global user.email "smoke-runner@example.invalid"
git config --global user.name "Smoke Runner"

# The host Docker daemon resolves Compose bind mounts using host paths. The
# project must therefore live at the same absolute path inside the harness.
if ! touch "${WORK_CONTAINER_DIR}/.write-test" 2>/dev/null; then
    echo "ERROR: ${WORK_CONTAINER_DIR} is not writable inside the harness." >&2
    exit 2
fi
if [[ ! -f /work/.write-test ]]; then
    echo "ERROR: /work is not an alias of ${WORK_CONTAINER_DIR}; nested Sail mounts will be wrong." >&2
    rm -f "${WORK_CONTAINER_DIR}/.write-test"
    exit 2
fi
rm -f "${WORK_CONTAINER_DIR}/.write-test" /work/.write-test

echo "================================================================"
echo " Smoke harness: scenario=${SCENARIO}"
echo " work dir (host=container): ${WORK_CONTAINER_DIR}"
echo " work alias: /work"
echo " git config: ${GIT_CONFIG_GLOBAL}"
echo " composer cache: ${COMPOSER_CACHE_DIR:-<default>}"
echo " kit (ro): /kit"
echo " out: /out"
echo "================================================================"

exec "$SCRIPT"
