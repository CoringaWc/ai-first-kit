#!/usr/bin/env bash
# Host entrypoint: build harness image, run scenario, surface report.
# Refer to README.md for usage.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../../.." &>/dev/null && pwd)"
KIT_DIR="${REPO_ROOT}/.agents/skills/_shared"

WORK_HOST_DIR="${SMOKE_WORK_DIR:-/tmp/smoke-runner}"
OUT_HOST_DIR="${SMOKE_OUT_DIR:-/tmp/smoke-out}"
COMPOSER_CACHE_HOST_DIR="${SMOKE_COMPOSER_CACHE_DIR:-/tmp/smoke-composer-cache}"
IMAGE_TAG="${SMOKE_IMAGE_TAG:-smoke-runner:latest}"
SMOKE_RESOURCE_PREFIX="${SMOKE_RESOURCE_PREFIX:-smoke-group-a-}"

SCENARIO="group-a-fpm-ptbr"
KEEP_ARTIFACTS=false
NO_CACHE=false
DROP_SHELL=false
LIST_ONLY=false
CLEAN_WORK=false

fail_setup() {
    echo "ERROR: $*" >&2
    exit 2
}

validate_cleanup_scope() {
    if [[ ! "$SMOKE_RESOURCE_PREFIX" =~ ^smoke-group-a-[A-Za-z0-9_.-]*$ ]]; then
        fail_setup "unsafe SMOKE_RESOURCE_PREFIX for --clean: '${SMOKE_RESOURCE_PREFIX}'. Expected prefix beginning with smoke-group-a-."
    fi

    WORK_HOST_DIR="$(resolve_cleanup_dir 'SMOKE_WORK_DIR' "$WORK_HOST_DIR" '/tmp/smoke-runner')"
    OUT_HOST_DIR="$(resolve_cleanup_dir 'SMOKE_OUT_DIR' "$OUT_HOST_DIR" '/tmp/smoke-out')"
}

resolve_cleanup_dir() {
    local label="$1"
    local dir="$2"
    local allowed_root="$3"
    local resolved

    resolved="$(realpath -m -- "$dir")" || fail_setup "invalid ${label} for --clean: '${dir}'"

    case "$resolved" in
        "$allowed_root"|"$allowed_root"/*|"$allowed_root"-*) printf '%s\n' "$resolved" ;;
        *) fail_setup "unsafe ${label} for --clean: '${dir}' resolves to '${resolved}'. Expected ${allowed_root}, ${allowed_root}/*, or ${allowed_root}-*" ;;
    esac
}

usage() {
    cat <<'USAGE'
Usage: ./run.sh [OPTIONS]
  --scenario=<name>     scenario to run (default: group-a-fpm-ptbr)
  --keep-artifacts      tar /work/<project> to /tmp/smoke-out/artifacts.tar.gz
  --no-cache            docker build with --no-cache
  --shell                drop into bash inside the harness instead of running a scenario
  --list-scenarios      print available scenarios and exit
  --clean               wipe this harness' smoke-group-a-* Docker resources plus work/out dirs, then exit; keeps composer cache
  --help                this message

Exit codes:
  0 = all stages passed
  1 = a scenario stage failed
  2 = harness setup error (image build, mount, missing scenario, etc.)
USAGE
}

for arg in "$@"; do
    case "$arg" in
        --scenario=*) SCENARIO="${arg#*=}";;
        --keep-artifacts) KEEP_ARTIFACTS=true;;
        --no-cache) NO_CACHE=true;;
        --shell) DROP_SHELL=true;;
        --list-scenarios) LIST_ONLY=true;;
        --clean) CLEAN_WORK=true;;
        --help|-h) usage; exit 0;;
        *) echo "Unknown arg: $arg" >&2; usage >&2; exit 2;;
    esac
done

if $CLEAN_WORK; then
    validate_cleanup_scope

    mkdir -p "$WORK_HOST_DIR" "$OUT_HOST_DIR"
    echo "==> Removing lingering ${SMOKE_RESOURCE_PREFIX}* Docker resources"
    mapfile -t SMOKE_CONTAINERS < <(
        docker ps -a --format '{{.ID}} {{.Names}}' |
            while read -r id name; do
                [[ "$name" == "${SMOKE_RESOURCE_PREFIX}"* ]] && printf '%s\n' "$id"
            done
    )
    if ((${#SMOKE_CONTAINERS[@]})); then
        docker rm -f "${SMOKE_CONTAINERS[@]}" >/dev/null
    fi

    mapfile -t SMOKE_VOLUMES < <(
        docker volume ls --format '{{.Name}}' |
            while read -r name; do
                [[ "$name" == "${SMOKE_RESOURCE_PREFIX}"* ]] && printf '%s\n' "$name"
            done
    )
    if ((${#SMOKE_VOLUMES[@]})); then
        docker volume rm -f "${SMOKE_VOLUMES[@]}" >/dev/null
    fi

    mapfile -t SMOKE_NETWORKS < <(
        docker network ls --format '{{.ID}} {{.Name}}' |
            while read -r id name; do
                [[ "$name" == "${SMOKE_RESOURCE_PREFIX}"* ]] && printf '%s\n' "$id"
            done
    )
    if ((${#SMOKE_NETWORKS[@]})); then
        docker network rm "${SMOKE_NETWORKS[@]}" >/dev/null
    fi

    mapfile -t SMOKE_IMAGES < <(
        docker image ls --format '{{.Repository}}:{{.Tag}} {{.ID}}' |
            while read -r ref id; do
                [[ "$ref" == "${SMOKE_RESOURCE_PREFIX}"* ]] && printf '%s\n' "$id"
            done | sort -u
    )
    if ((${#SMOKE_IMAGES[@]})); then
        docker image rm -f "${SMOKE_IMAGES[@]}" >/dev/null || true
    fi

    echo "==> Cleaning ${WORK_HOST_DIR} and ${OUT_HOST_DIR} (using container root)"
    docker run --rm -v "${WORK_HOST_DIR}:/work" alpine:3.21 sh -c 'rm -rf /work/* /work/.[!.]* 2>/dev/null || true'
    docker run --rm -v "${OUT_HOST_DIR}:/out" alpine:3.21 sh -c 'rm -rf /out/* 2>/dev/null || true'
    echo "==> Clean complete. Exiting (cleanup-only)."
    exit 0
fi

if $LIST_ONLY; then
    echo "Available scenarios:"
    for f in "${SCRIPT_DIR}/scenarios"/*.sh; do
        basename "$f" .sh
    done
    exit 0
fi

if [[ ! -f "${SCRIPT_DIR}/scenarios/${SCENARIO}.sh" ]]; then
    echo "ERROR: scenario '${SCENARIO}' not found in ${SCRIPT_DIR}/scenarios/" >&2
    exit 2
fi

if [[ ! -d "$KIT_DIR" ]]; then
    echo "ERROR: kit dir not found at ${KIT_DIR}" >&2
    exit 2
fi

if ! docker info >/dev/null 2>&1; then
    echo "ERROR: docker daemon not reachable from host" >&2
    exit 2
fi

case "$WORK_HOST_DIR" in
    /*) ;;
    *) echo "ERROR: SMOKE_WORK_DIR must be an absolute path for nested Docker bind mounts" >&2; exit 2;;
esac

mkdir -p "$WORK_HOST_DIR" "$OUT_HOST_DIR" "$COMPOSER_CACHE_HOST_DIR"

echo "==> Building harness image (${IMAGE_TAG})..."
BUILD_ARGS=(--tag "$IMAGE_TAG")
$NO_CACHE && BUILD_ARGS+=(--no-cache)
DOCKER_BUILDKIT=1 docker build "${BUILD_ARGS[@]}" "$SCRIPT_DIR" || {
    echo "ERROR: harness image build failed" >&2
    exit 2
}

RUN_ARGS=(
    --rm
    -v "/var/run/docker.sock:/var/run/docker.sock"
    -v "${KIT_DIR}:/kit:ro"
    -v "${WORK_HOST_DIR}:/work"
    -v "${WORK_HOST_DIR}:${WORK_HOST_DIR}"
    -v "${OUT_HOST_DIR}:/out"
    -v "${COMPOSER_CACHE_HOST_DIR}:/tmp/composer-cache"
    -e "SCENARIO=${SCENARIO}"
    -e "KEEP_ARTIFACTS=${KEEP_ARTIFACTS}"
    -e "WORK_HOST_DIR=${WORK_HOST_DIR}"
    -e "WORK_CONTAINER_DIR=${WORK_HOST_DIR}"
    -e "COMPOSER_CACHE_DIR=/tmp/composer-cache"
    -e "COMPOSER_MAX_PARALLEL_HTTP=${COMPOSER_MAX_PARALLEL_HTTP:-4}"
    -w "${WORK_HOST_DIR}"
)

if $DROP_SHELL; then
    echo "==> Dropping into harness shell (Ctrl+D to exit)"
    exec docker run -it "${RUN_ARGS[@]}" --entrypoint /bin/bash "$IMAGE_TAG"
fi

echo "==> Running scenario: ${SCENARIO}"
echo "    work:    ${WORK_HOST_DIR} (same absolute path inside harness; /work is an alias)"
echo "    reports: ${OUT_HOST_DIR}"
echo "    composer cache: ${COMPOSER_CACHE_HOST_DIR}"
set +e
docker run "${RUN_ARGS[@]}" "$IMAGE_TAG"
RC=$?
set -e

echo
echo "==> Report(s) at: ${OUT_HOST_DIR}"
ls -la "$OUT_HOST_DIR" || true

exit "$RC"
