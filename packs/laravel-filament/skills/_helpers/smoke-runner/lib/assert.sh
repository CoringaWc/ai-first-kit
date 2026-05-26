#!/usr/bin/env bash
# shellcheck shell=bash
# Assertion library for scenario scripts. Sourced; do not execute directly.
# All assertions log to stderr and exit 1 on failure (set -e in scenarios takes over).

assert_file() {
    local path="$1"
    if [[ ! -f "$path" ]]; then
        echo "  ASSERT FAIL: expected file present: $path" >&2
        return 1
    fi
    echo "  ok: file present: $path"
}

assert_no_file() {
    local path="$1"
    if [[ -e "$path" ]]; then
        echo "  ASSERT FAIL: expected NOT present: $path" >&2
        return 1
    fi
    echo "  ok: not present: $path"
}

assert_grep() {
    local pattern="$1"; local path="$2"
    if [[ ! -f "$path" ]]; then
        echo "  ASSERT FAIL: file missing for grep: $path" >&2
        return 1
    fi
    if ! grep -qE "$pattern" "$path"; then
        echo "  ASSERT FAIL: pattern not found '$pattern' in $path" >&2
        return 1
    fi
    echo "  ok: pattern '$pattern' in $path"
}

assert_container_running() {
    local name="$1"
    if ! docker ps --format '{{.Names}}' | grep -qx "$name"; then
        echo "  ASSERT FAIL: container not running: $name" >&2
        echo "  --- docker ps ---" >&2
        docker ps >&2 || true
        return 1
    fi
    echo "  ok: container running: $name"
}

assert_ssl_stack_ready() {
    assert_file docker/nginx/certs/cert.pem
    assert_file docker/nginx/certs/cert.key
    assert_grep "docker/nginx/certs" docker-compose.yml

    if grep -q "siasgfacil" docker/nginx/default.conf; then
        echo "  ASSERT FAIL: nginx config contains hard-coded legacy domain" >&2
        return 1
    fi

    echo "  ok: nginx SSL artifacts/config aligned"
}

# Snapshot file tree (sha256 of relative path + mtime + size). Used for idempotency.
snapshot_tree() {
    local dir="$1"; local out="$2"
    (
        cd "$dir"
        find . \
            -path ./vendor -prune -o \
            -path ./node_modules -prune -o \
            -path ./.git -prune -o \
            -path ./storage/logs -prune -o \
            -path ./storage/framework -prune -o \
            -type f -print 2>/dev/null \
            | sort \
            | xargs -I{} sha256sum {} 2>/dev/null
    ) > "$out"
}

pre_populate_env_alt_ports() {
    # Pre-populate .env with alternative ports BEFORE A2 (docker-stack-*) runs.
    # The kit appends FORWARD_*_PORT/APP_PORT/etc. with `grep -q ... || echo`,
    # so if these keys already exist, the kit skips them and our values win.
    # Avoids collision with a host stack already binding 5432/6379/9000/9001/80/etc.
    local env_file="${1:-.env}"
    if [[ ! -f "$env_file" ]]; then
        echo "  ASSERT FAIL: $env_file missing; cannot pre-populate alt ports" >&2
        return 1
    fi
    local key val
    while IFS='=' read -r key val; do
        [[ -z "$key" || "$key" == \#* ]] && continue
        grep -q "^${key}=" "$env_file" || echo "${key}=${val}" >> "$env_file"
    done <<'EOF'
FORWARD_DB_PORT=15432
FORWARD_REDIS_PORT=16379
FORWARD_MINIO_PORT=19000
FORWARD_MINIO_CONSOLE_PORT=19001
APP_PORT=18000
VITE_PORT=15173
APP_SERVICE=app
APP_HTTP_PORT=18080
APP_HTTPS_PORT=18443
OLLAMA_PORT=21434
QDRANT_HTTP_PORT=16333
QDRANT_GRPC_PORT=16334
MAILPIT_SMTP_PORT=11026
MAILPIT_DASHBOARD_PORT=18026
EOF
    echo "  ok: alt ports populated in $env_file (DB=15432 REDIS=16379 APP=18000 ...)"
}

normalize_project_permissions_for_sail() {
    # The harness creates files as root, while the generated app containers run
    # as the Sail user (1000:1000). Without this, composer/reverb cannot write
    # composer.lock, vendor/, or storage/logs through the bind mount.
    chown -R 1000:1000 .
    if [ -d .git ]; then
        git config --global --add safe.directory "$(pwd)"
    fi
    echo "  ok: project files chowned to Sail UID/GID 1000:1000"
}

assert_idempotent() {
    local before="$1"; local after="$2"
    if diff -u "$before" "$after" > /tmp/idempotency.diff; then
        echo "  ok: idempotent (no file changes on second run)"
        return 0
    fi
    echo "  ASSERT FAIL: second run mutated files. Diff:" >&2
    head -40 /tmp/idempotency.diff >&2
    return 1
}
