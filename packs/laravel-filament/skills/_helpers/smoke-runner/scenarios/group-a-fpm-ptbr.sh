#!/usr/bin/env bash
# Scenario: Group A (A1->A8) with fpm profile and pt_BR locale.
# A6 (enable-octane-swoole) is intentionally skipped (opt-in only).
#
# Stages:
#   1.   A1 init-project (composer create-project on EMPTY dir — must run first)
#   1.1. Copy kit to project (overlay on top of Laravel skeleton)
#   2.   A2 docker-stack-fpm
#   3.   A3 ssl-local-dev
#   3.5. sail up -d --build  (prerequisite for A4-A8 which invoke sail commands)
#   4.   A4 composer-dep-install
#   5.   A5 npm-dep-install
#   6.   (A6 skipped)
#   7.   A7 translation
#   8.   A8 ci-github-actions
#   9.   healthcheck + migrate + test  (stack stays up from 3.5)
#  10.   Idempotency: sail down -v, re-run skills, diff file tree (no re-up)
#
# SMOKE_SKIP_BOOT=1 skips Stage 3.5 AND Stage 9 (no stack lifecycle at all).
# SMOKE_SKIP_IDEM=1 skips Stage 10.
set -euo pipefail

source /harness/lib/assert.sh
source /harness/lib/extract.sh
source /harness/lib/report.sh

SCENARIO_NAME="group-a-fpm-ptbr"
TS="$(date +%Y%m%d-%H%M%S)"
PROJECT_NAME="smoke-${SCENARIO_NAME}-${TS}"
WORK_CONTAINER_DIR="${WORK_CONTAINER_DIR:-/work}"
PROJECT_DIR="${WORK_CONTAINER_DIR}/${PROJECT_NAME}"
REPORT="/out/${SCENARIO_NAME}-report.md"

export LOCALE_SHORT="pt_BR"
export LOCALE_FULL="pt_BR.UTF-8"
export LOCALE="pt_BR"
export PROFILE="fpm"
export PROJECT_NAME
export DOMAIN="${PROJECT_NAME}.test"
export ALLOW_SAIL_COMPOSE_REPLACE=1

mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

report_init "$SCENARIO_NAME" "$REPORT"
report_note "PROFILE=${PROFILE}, LOCALE_SHORT=${LOCALE_SHORT}, project=${PROJECT_NAME}"

# Cleanup trap — runs even on failure. Idempotent. Skipped if no project dir yet.
cleanup() {
    local rc=$?
    if [[ -f "${PROJECT_DIR}/vendor/bin/sail" ]] && [[ -f "${PROJECT_DIR}/docker-compose.yml" ]]; then
        ( cd "$PROJECT_DIR" && vendor/bin/sail down -v >/dev/null 2>&1 || true )
    fi
    docker ps -a --filter "label=com.docker.compose.project=${PROJECT_NAME}" -q \
        | xargs -r docker rm -f >/dev/null 2>&1 || true
    docker network ls --filter "label=com.docker.compose.project=${PROJECT_NAME}" -q \
        | xargs -r docker network rm >/dev/null 2>&1 || true
    return $rc
}
trap cleanup EXIT

run_skill_workflow() {
    local skill_name="$1"
    local skill_path="${PROJECT_DIR}/.agents/skills/_shared/${skill_name}/SKILL.md"
    [[ -f "$skill_path" ]] || { echo "missing skill: $skill_path"; return 1; }
    local script
    script="$(extract_workflow_bash "$skill_path")"
    bash -c "set -eo pipefail; $script"
}

stage() {
    local label="$1"; shift
    local start=$SECONDS
    if "$@"; then
        report_stage "$label" "PASS" "$((SECONDS - start))s"
        return 0
    else
        report_stage "$label" "FAIL" "$((SECONDS - start))s"
        report_finalize
        exit 1
    fi
}

# Find the app container (Sail names it <project>-laravel.test-1 by default).
locate_app_container() {
    docker ps --filter "label=com.docker.compose.project=${PROJECT_NAME}" \
              --format '{{.Names}}' | grep -E '(-app-1|-laravel\.test-1)$' | head -1
}

# ---------------- Stage 1: A1 init-project ----------------
# IMPORTANT: composer create-project REQUIRES an empty target directory.
# Stage 1 must run BEFORE Stage 1.1 (kit copy) — otherwise create-project
# bails with "Project directory is not empty", produces a stub composer.json,
# and the rest of the scenario silently runs against a broken project (no
# artisan, no app/, no routes/) — which is what caused the original
# Stage 3.5 reverb crash-loop ("Could not open input file: artisan").
stage1_a1() {
    composer create-project laravel/laravel . --prefer-dist --no-interaction
    if [[ ! -f vendor/bin/sail ]]; then
        composer require laravel/sail --dev
        php artisan sail:install --with=pgsql,redis --no-interaction
    fi
    [[ -d .git ]] || { git init -q; git add . >/dev/null; git -c user.email=smoke@test -c user.name=smoke commit -q -m "chore: initial laravel skeleton"; }

    composer require laravel/boost --dev

    if ! grep -q "gerenciado por init-project" .env.example 2>/dev/null; then
        {
            echo "# === init-project (A1) — gerenciado por init-project (A1) ==="
            echo "APP_LOCALE=${LOCALE_SHORT}"
            cat .env.example 2>/dev/null || true
        } > .env.example.new
        mv .env.example.new .env.example
    fi
    cp -n .env.example .env 2>/dev/null || true
    grep -q "^APP_LOCALE=" .env || echo "APP_LOCALE=${LOCALE_SHORT}" >> .env

    # Sentinel: catches silent create-project failures (without this, a stub
    # composer.json + sail-via-require can fake a PASS).
    assert_file artisan
    assert_file vendor/bin/sail
    assert_file composer.json
    assert_grep "APP_LOCALE=${LOCALE_SHORT}" .env
    assert_grep "gerenciado por init-project" .env.example
    assert_grep "laravel/boost" composer.json
}
stage "Stage 1: A1 init-project (skeleton+boost+env)" stage1_a1

# ---------------- Stage 1.1: kit copy (after skeleton exists) ----------------
stage1_1_kit() {
    mkdir -p .agents/skills/_shared
    cp -r /kit/. .agents/skills/_shared/
    assert_file .agents/skills/_shared/init-project/SKILL.md
}
stage "Stage 1.1: kit copy" stage1_1_kit

# Pre-populate alt ports BEFORE A2, so kit's idempotent .env append picks them up.
stage "Stage 1.5: alt ports (avoid host stack collision)" pre_populate_env_alt_ports .env

stage "Stage 1.6: normalize permissions for Sail" normalize_project_permissions_for_sail

# ---------------- Stage 2: A2 docker-stack-fpm ----------------
stage "Stage 2: A2 docker-stack-fpm" run_skill_workflow docker-stack-fpm

# ---------------- Stage 3: A3 ssl-local-dev ----------------
stage3_ssl() {
    run_skill_workflow ssl-local-dev
    assert_ssl_stack_ready
}
stage "Stage 3: A3 ssl-local-dev" stage3_ssl

# ---------------- Stage 3.5: bring stack up ----------------
# Prerequisite for A4-A8: those skills invoke `vendor/bin/sail composer/npm/artisan ...`
# which require the Sail stack to be running.
stage35_stack_up() {
    vendor/bin/sail up -d --build app
    # Wait for the app container to be reachable. Healthcheck happens in Stage 9;
    # here we just need it to be up enough to accept exec calls.
    local tries=0 app_container=""
    while (( tries < 30 )); do
        app_container="$(locate_app_container)"
        if [[ -n "$app_container" ]] && docker exec "$app_container" true >/dev/null 2>&1; then
            echo "  stack up (app container: $app_container, after ${tries}s)"
            return 0
        fi
        sleep 1
        tries=$((tries + 1))
    done
    echo "ERROR: stack failed to come up within 30s" >&2
    docker ps >&2
    [[ -n "$app_container" ]] && docker logs --tail=80 "$app_container" >&2 || true
    return 1
}
if [[ "${SMOKE_SKIP_BOOT:-0}" = "1" ]]; then
    report_stage "Stage 3.5: stack up" "SKIPPED" "0s"
    report_note "Stack up skipped via SMOKE_SKIP_BOOT=1 (Stages 4-9 will likely fail since they need sail running)"
else
    stage "Stage 3.5: stack up (sail up -d --build)" stage35_stack_up
fi

# ---------------- Stage 4: A4 composer-dep-install ----------------
stage "Stage 4: A4 composer-dep-install" run_skill_workflow composer-dep-install

# ---------------- Stage 5: A5 npm-dep-install ----------------
stage "Stage 5: A5 npm-dep-install" run_skill_workflow npm-dep-install

# ---------------- Stage 7: A7 translation ----------------
stage "Stage 7: A7 translation (A6 skipped)" run_skill_workflow translation

# ---------------- Stage 8: A8 ci-github-actions ----------------
stage "Stage 8: A8 ci-github-actions" run_skill_workflow ci-github-actions

# ---------------- Stage 9: healthcheck + migrate + test ----------------
stage9_validate() {
    vendor/bin/sail up -d --build

    local app_container
    app_container="$(locate_app_container)"
    if [[ -z "$app_container" ]]; then
        echo "ERROR: app container not found (stack should be up from Stage 3.5)" >&2
        docker ps >&2
        return 1
    fi
    echo "  app container: $app_container"

    docker exec "$app_container" sh -c "curl -k -s -o /dev/null -w '%{http_code}' https://nginx/up || curl -s -o /dev/null -w '%{http_code}' http://nginx/up" \
        | grep -qE '^(200|302)$' \
        || { echo "healthcheck failed"; docker logs --tail=50 "$app_container" >&2; return 1; }

    vendor/bin/sail artisan migrate --force --no-interaction
    vendor/bin/sail artisan test --compact
}
if [[ "${SMOKE_SKIP_BOOT:-0}" = "1" ]]; then
    report_stage "Stage 9: healthcheck + migrate + test" "SKIPPED" "0s"
else
    stage "Stage 9: healthcheck + migrate + test" stage9_validate
fi

# ---------------- Stage 10: Idempotency ----------------
# Re-running A2 while the stack is up causes conflicts (port bindings, container names),
# so we tear down first. Idempotency check is purely on the generated file tree.
stage10_idempotency() {
    if [[ -f vendor/bin/sail ]] && [[ -f docker-compose.yml ]]; then
        vendor/bin/sail down -v >/dev/null 2>&1 || true
    fi
    snapshot_tree "$PROJECT_DIR" /tmp/snap-before.txt
    run_skill_workflow docker-stack-fpm
    run_skill_workflow ssl-local-dev
    # A4/A5 need the stack to install deps; skip them in idempotency (we already validated they ran once).
    # i18n + ci are pure file generation, safe to re-run with stack down.
    run_skill_workflow translation
    run_skill_workflow ci-github-actions
    snapshot_tree "$PROJECT_DIR" /tmp/snap-after.txt
    assert_idempotent /tmp/snap-before.txt /tmp/snap-after.txt
}
if [[ "${SMOKE_SKIP_IDEM:-0}" = "1" ]]; then
    report_stage "Stage 10: idempotency" "SKIPPED" "0s"
else
    stage "Stage 10: idempotency" stage10_idempotency
fi

# ---------------- Wrap-up ----------------
report_finalize

if [[ "${KEEP_ARTIFACTS:-false}" = "true" ]]; then
    tar czf "/out/${SCENARIO_NAME}-artifacts.tar.gz" \
        -C /work \
        --exclude='*/vendor' --exclude='*/node_modules' --exclude='*/.git' \
        "${PROJECT_NAME}" 2>/dev/null || true
    echo "==> Artifacts: /out/${SCENARIO_NAME}-artifacts.tar.gz"
fi

echo "==> Done: ${SCENARIO_NAME}"
