#!/usr/bin/env bash
# Scenario: A1-A5+A7+A8 fpm, then A6 (enable-octane-swoole) migrates the stack to Octane in place.
#
# Stage ordering rationale:
#   0/1/2/3:  kit, A1, A2(fpm), A3
#   3.5:      sail up (fpm) — needed by A4/A5
#   4/5:      A4 composer, A5 npm
#   5.5:      commit FPM baseline — A6 intentionally refuses dirty worktrees
#   6:        A6 enable-octane-swoole (migration)
#   6b:       verify octane artifacts on disk
#   7/8:      A7 i18n, A8 ci (pure file gen, stack state irrelevant)
#   8.5:      sail up (octane) — bring the migrated stack up
#   9:        healthcheck + migrate (on octane stack)
set -euo pipefail
source /harness/lib/assert.sh
source /harness/lib/extract.sh
source /harness/lib/report.sh

SCENARIO_NAME="group-a-fpm-then-a6"
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

mkdir -p "$PROJECT_DIR" && cd "$PROJECT_DIR"

report_init "$SCENARIO_NAME" "$REPORT"
report_note "PROFILE=${PROFILE} (then migrated to octane via A6), LOCALE_SHORT=${LOCALE_SHORT}"

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

wait_stack_up() {
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

stage1() {
    composer create-project laravel/laravel . --prefer-dist --no-interaction
    [[ -f vendor/bin/sail ]] || { composer require laravel/sail --dev; php artisan sail:install --with=pgsql,redis --no-interaction; }
    [[ -d .git ]] || { git init -q; stage_smoke_files; git -c user.email=smoke@test -c user.name=smoke commit -q -m "chore: initial"; }
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
}
stage "Stage 1: A1 init-project" stage1

# Stage 1.1: kit copy (must run AFTER create-project; empty-dir requirement).
stage1_1() {
    mkdir -p .agents/skills/_shared
    cp -r /kit/. .agents/skills/_shared/
    assert_file .agents/skills/_shared/enable-octane-swoole/SKILL.md
}
stage "Stage 1.1: kit copy" stage1_1

stage "Stage 1.5: alt ports (avoid host stack collision)" pre_populate_env_alt_ports .env

stage "Stage 1.6: normalize permissions for Sail" normalize_project_permissions_for_sail

stage "Stage 2: A2 docker-stack-fpm" run_skill_workflow docker-stack-fpm
stage3_ssl() {
    run_skill_workflow ssl-local-dev
    assert_ssl_stack_ready
}
stage "Stage 3: A3 ssl-local-dev" stage3_ssl

stage35_fpm_up() {
    vendor/bin/sail up -d --build app
    wait_stack_up
}
if [[ "${SMOKE_SKIP_BOOT:-0}" = "1" ]]; then
    report_stage "Stage 3.5: fpm stack up" "SKIPPED" "0s"
else
    stage "Stage 3.5: fpm stack up (sail up -d --build)" stage35_fpm_up
fi

stage "Stage 4: A4 composer-dep-install"  run_skill_workflow composer-dep-install
stage "Stage 5: A5 npm-dep-install"       run_skill_workflow npm-dep-install

stage55_commit_fpm_baseline() {
    stage_smoke_files
    if git diff --cached --quiet; then
        echo "  fpm baseline already committed"
    else
        git commit -q -m "chore: baseline before octane migration"
        echo "  committed fpm baseline before A6"
    fi

    if [[ -n "$(git status --short)" ]]; then
        git status --short
        return 1
    fi
}
stage "Stage 5.5: commit fpm baseline before A6" stage55_commit_fpm_baseline

# A6: migrate fpm -> octane. This skill is the whole point of this scenario.
stage "Stage 6: A6 enable-octane-swoole (migration)" run_skill_workflow enable-octane-swoole

verify_octane_artifacts() {
    if grep -rqi "octane\|swoole" docker-compose.yml docker/ 2>/dev/null; then
        echo "  ok: octane/swoole referenced post-A6"
    else
        echo "  ASSERT FAIL: no octane/swoole reference after A6" >&2
        return 1
    fi
}
stage "Stage 6b: verify octane artifacts post-A6" verify_octane_artifacts

stage "Stage 7: A7 translation"    run_skill_workflow translation
stage "Stage 8: A8 ci-github-actions" run_skill_workflow ci-github-actions

# Stage 8.5: bring the migrated (octane) stack up.
stage85_octane_up() {
    vendor/bin/sail up -d --build
    wait_stack_up
}
if [[ "${SMOKE_SKIP_BOOT:-0}" = "1" ]]; then
    report_stage "Stage 8.5: octane stack up" "SKIPPED" "0s"
else
    stage "Stage 8.5: octane stack up (sail up -d --build)" stage85_octane_up
fi

stage9_validate() {
    local app_container
    app_container="$(locate_app_container)"
    [[ -n "$app_container" ]] || { docker ps; return 1; }
    docker exec "$app_container" sh -c "curl -k -s -o /dev/null -w '%{http_code}' https://nginx/up || curl -s -o /dev/null -w '%{http_code}' http://nginx/up" \
        | grep -qE '^(200|302)$' || { docker logs --tail=50 "$app_container"; return 1; }
    vendor/bin/sail artisan migrate --force --no-interaction
}
if [[ "${SMOKE_SKIP_BOOT:-0}" = "1" ]]; then
    report_stage "Stage 9: healthcheck + migrate (octane)" "SKIPPED" "0s"
else
    stage "Stage 9: healthcheck + migrate (octane)" stage9_validate
fi

report_finalize

if [[ "${KEEP_ARTIFACTS:-false}" = "true" ]]; then
    tar czf "/out/${SCENARIO_NAME}-artifacts.tar.gz" -C /work \
        --exclude='*/vendor' --exclude='*/node_modules' --exclude='*/.git' "${PROJECT_NAME}" 2>/dev/null || true
fi

echo "==> Done: ${SCENARIO_NAME}"
