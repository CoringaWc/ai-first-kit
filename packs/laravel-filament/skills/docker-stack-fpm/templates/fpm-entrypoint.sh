#!/usr/bin/env bash
set -euo pipefail

AUTO_INSTALL_DEPS="${AUTO_INSTALL_DEPS:-true}"
INSTALL_LOCK_PATH="${DEPENDENCY_INSTALL_LOCK:-storage/framework/cache/dependency-install.lock}"
NODE_INSTALL_MARKER="node_modules/.install-complete"

log() {
    printf '[entrypoint] %s\n' "$*"
}

fail_missing_dependencies() {
    local missing="$1"

    cat >&2 <<EOF
[entrypoint] Missing dependencies: ${missing}
[entrypoint] AUTO_INSTALL_DEPS is disabled, so dependencies must be installed before the container starts.
[entrypoint] Run with AUTO_INSTALL_DEPS=true locally or install manually inside the container.
EOF
    exit 1
}

auto_install_deps_enabled() {
    local value="${AUTO_INSTALL_DEPS,,}"

    [[ "$value" == "true" || "$value" == "1" || "$value" == "yes" ]]
}

composer_uses_private_filament_repository() {
    [[ -f composer.json ]] && grep -q 'packages.filamentphp.com/composer' composer.json
}

assert_composer_auth_available() {
    local composer_home="${COMPOSER_HOME:-${HOME:-/tmp}/.composer}"

    if composer_uses_private_filament_repository && [[ -z "${COMPOSER_AUTH:-}" && ! -f auth.json && ! -f "$composer_home/auth.json" ]]; then
        cat >&2 <<'EOF'
[entrypoint] Missing auth.json required by the private Filament Composer repository.
[entrypoint] Unlock protected files before bootstrapping:
[entrypoint]   git-crypt unlock .git-crypt-keys/<nome-da-chave>.key
EOF
        exit 1
    fi
}

install_dependencies_if_needed() {
    [[ -f composer.json || -f package.json ]] || return 0

    local missing=()

    if [[ -f composer.json && ! -f vendor/autoload.php ]]; then
        missing+=("vendor")
    fi

    if [[ -f package.json && ! -f "$NODE_INSTALL_MARKER" ]]; then
        missing+=("node_modules")
    fi

    [[ ${#missing[@]} -gt 0 ]] || return 0

    if ! auto_install_deps_enabled; then
        fail_missing_dependencies "${missing[*]}"
    fi

    mkdir -p "$(dirname "$INSTALL_LOCK_PATH")"

    (
        flock -x 200

        if [[ -f composer.json && ! -f vendor/autoload.php ]]; then
            assert_composer_auth_available
            log 'Installing Composer dependencies...'
            composer install --no-interaction --prefer-dist --optimize-autoloader
        fi

        if [[ -f package.json && ! -f "$NODE_INSTALL_MARKER" ]]; then
            rm -f "$NODE_INSTALL_MARKER"
            log 'Installing npm dependencies...'
            npm install
            mkdir -p "$(dirname "$NODE_INSTALL_MARKER")"
            touch "$NODE_INSTALL_MARKER"
        fi
    ) 200>"$INSTALL_LOCK_PATH"
}

install_dependencies_if_needed

exec "$@"
