#!/usr/bin/env bash
# Scenario: Group A with octane profile and en locale. A6 n/a (octane is the starting point).
# See group-a-fpm-ptbr.sh for full stage rationale.
set -euo pipefail
source /harness/lib/assert.sh
source /harness/lib/extract.sh
source /harness/lib/report.sh

SCENARIO_NAME="group-a-octane-en"
TS="$(date +%Y%m%d-%H%M%S)"
PROJECT_NAME="smoke-${SCENARIO_NAME}-${TS}"
WORK_CONTAINER_DIR="${WORK_CONTAINER_DIR:-/work}"
PROJECT_DIR="${WORK_CONTAINER_DIR}/${PROJECT_NAME}"
REPORT="/out/${SCENARIO_NAME}-report.md"

export LOCALE_SHORT="en"
export LOCALE_FULL="en_US.UTF-8"
export LOCALE="en"
export PROFILE="octane"
export PROJECT_NAME
export DOMAIN="${PROJECT_NAME}.test"
export ALLOW_SAIL_COMPOSE_REPLACE=1

mkdir -p "$PROJECT_DIR" && cd "$PROJECT_DIR"

report_init "$SCENARIO_NAME" "$REPORT"
report_note "PROFILE=${PROFILE}, LOCALE_SHORT=${LOCALE_SHORT}, project=${PROJECT_NAME}"

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
    bash -c "set -eo pipefail; $(extract_workflow_bash "$skill_path")"
}

stage() {
    local label="$1"; shift
    local start=$SECONDS
    if "$@"; then
        report_stage "$label" "PASS" "$((SECONDS - start))s"
    else
        report_stage "$label" "FAIL" "$((SECONDS - start))s"
        report_finalize; exit 1
    fi
}

locate_app_container() {
    docker ps --filter "label=com.docker.compose.project=${PROJECT_NAME}" \
              --format '{{.Names}}' | grep -E '(-app-1|-laravel\.test-1)$' | head -1
}

is_smoke_secret_path() {
    local path="${1,,}"

    case "$path" in
        .env|.env.testing|.env.local|.env.*.local|.npmrc|auth.json|.cert/*|.git-crypt-keys/*|*.key|*.pem|*credential*|*credentials*|*secret*|*secrets*) return 0 ;;
        *) return 1 ;;
    esac
}

unstage_smoke_secrets() {
    while IFS= read -r path; do
        if is_smoke_secret_path "$path"; then
            git reset -q -- "$path" 2>/dev/null || true
        fi
    done < <(git diff --cached --name-only)
}

exclude_smoke_secret_paths() {
    [[ -d .git/info ]] || return 0

    for pattern in '.env' '.env.*' '.npmrc' 'auth.json' '.cert/*' '.git-crypt-keys/*' '*.key' '*.pem' '*credential*' '*credentials*' '*secret*' '*secrets*'; do
        grep -qxF "$pattern" .git/info/exclude 2>/dev/null || printf '%s\n' "$pattern" >> .git/info/exclude
    done
}

stage_smoke_files() {
    exclude_smoke_secret_paths
    unstage_smoke_secrets

    while IFS= read -r path; do
        if is_smoke_secret_path "$path"; then
            continue
        fi

        git add -- "$path"
    done < <(git ls-files --others --modified --deleted --exclude-standard)

    unstage_smoke_secrets
}

stage1() {
    composer create-project laravel/laravel . --prefer-dist --no-interaction
    [[ -f vendor/bin/sail ]] || { composer require laravel/sail --dev; php artisan sail:install --with=pgsql,redis --no-interaction; }
    [[ -d .git ]] || { git init -q; stage_smoke_files; git -c user.email=smoke@test -c user.name=smoke commit -q -m "chore: initial laravel skeleton"; }
    composer require laravel/boost --dev
    if ! grep -q "gerenciado por init-project" .env.example 2>/dev/null; then
        { echo "# === init-project (A1) — gerenciado por init-project (A1) ==="
          echo "APP_LOCALE=${LOCALE_SHORT}"
          cat .env.example 2>/dev/null || true; } > .env.example.new
        mv .env.example.new .env.example
    fi
    cp -n .env.example .env 2>/dev/null || true
    grep -q "^APP_LOCALE=" .env || echo "APP_LOCALE=${LOCALE_SHORT}" >> .env
    # Sentinel: catches silent create-project failures (see group-a-fpm-ptbr.sh).
    assert_file artisan
    assert_file vendor/bin/sail
    assert_grep "APP_LOCALE=${LOCALE_SHORT}" .env
}
stage "Stage 1: A1 init-project" stage1

# Stage 1.1: kit copy (must run AFTER create-project; empty-dir requirement).
stage1_1() {
    mkdir -p .agents/skills/_shared
    cp -r /kit/. .agents/skills/_shared/
    assert_file .agents/skills/_shared/init-project/SKILL.md
}
stage "Stage 1.1: kit copy" stage1_1

stage "Stage 1.5: alt ports (avoid host stack collision)" pre_populate_env_alt_ports .env

stage "Stage 1.6: normalize permissions for Sail" normalize_project_permissions_for_sail

stage "Stage 2: A2 docker-stack-octane-swoole" run_skill_workflow docker-stack-octane-swoole
stage3_ssl() {
    run_skill_workflow ssl-local-dev
    assert_ssl_stack_ready
}
stage "Stage 3: A3 ssl-local-dev" stage3_ssl

stage35_stack_up() {
    vendor/bin/sail up -d --build app
    local tries=0 app_container=""
    while (( tries < 30 )); do
        app_container="$(locate_app_container)"
        if [[ -n "$app_container" ]] && docker exec "$app_container" true >/dev/null 2>&1; then
            echo "  stack up (app container: $app_container, after ${tries}s)"
            return 0
        fi
        sleep 1; tries=$((tries + 1))
    done
    echo "ERROR: stack failed to come up within 30s" >&2
    docker ps >&2
    [[ -n "$app_container" ]] && docker logs --tail=80 "$app_container" >&2 || true
    return 1
}
if [[ "${SMOKE_SKIP_BOOT:-0}" = "1" ]]; then
    report_stage "Stage 3.5: stack up" "SKIPPED" "0s"
else
    stage "Stage 3.5: stack up (sail up -d --build)" stage35_stack_up
fi

stage "Stage 4: A4 composer-dep-install" run_skill_workflow composer-dep-install
stage "Stage 5: A5 npm-dep-install"      run_skill_workflow npm-dep-install
stage "Stage 7: A7 translation"       run_skill_workflow translation
stage "Stage 8: A8 ci-github-actions"    run_skill_workflow ci-github-actions

stage9_validate() {
    vendor/bin/sail up -d --build

    local app_container
    app_container="$(locate_app_container)"
    [[ -n "$app_container" ]] || { echo "no container"; docker ps; return 1; }
    docker exec "$app_container" sh -c "curl -k -s -o /dev/null -w '%{http_code}' https://nginx/up || curl -s -o /dev/null -w '%{http_code}' http://nginx/up" \
        | grep -qE '^(200|302)$' \
        || { docker logs --tail=50 "$app_container"; return 1; }
    vendor/bin/sail artisan migrate --force --no-interaction
    vendor/bin/sail artisan test --compact
}
if [[ "${SMOKE_SKIP_BOOT:-0}" = "1" ]]; then
    report_stage "Stage 9: healthcheck + migrate + test" "SKIPPED" "0s"
else
    stage "Stage 9: healthcheck + migrate + test" stage9_validate
fi

stage10() {
    if [[ -f vendor/bin/sail ]] && [[ -f docker-compose.yml ]]; then
        vendor/bin/sail down -v >/dev/null 2>&1 || true
    fi
    snapshot_tree "$PROJECT_DIR" /tmp/snap-before.txt
    run_skill_workflow docker-stack-octane-swoole
    run_skill_workflow ssl-local-dev
    run_skill_workflow translation
    run_skill_workflow ci-github-actions
    snapshot_tree "$PROJECT_DIR" /tmp/snap-after.txt
    assert_idempotent /tmp/snap-before.txt /tmp/snap-after.txt
}
if [[ "${SMOKE_SKIP_IDEM:-0}" = "1" ]]; then
    report_stage "Stage 10: idempotency" "SKIPPED" "0s"
else
    stage "Stage 10: idempotency" stage10
fi

report_finalize

if [[ "${KEEP_ARTIFACTS:-false}" = "true" ]]; then
    tar czf "/out/${SCENARIO_NAME}-artifacts.tar.gz" -C /work \
        --exclude='*/vendor' --exclude='*/node_modules' --exclude='*/.git' "${PROJECT_NAME}" 2>/dev/null || true
fi

echo "==> Done: ${SCENARIO_NAME}"
