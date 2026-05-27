#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "php" && "${2:-}" == "artisan" && "${3:-}" == "octane:start" ]]; then
    if [[ ! -f artisan || ! -f vendor/autoload.php ]] || ! php artisan list --raw 2>/dev/null | grep -qx 'octane:start'; then
        exec php artisan serve --host=0.0.0.0 --port=8000
    fi

    if [[ "${OCTANE_WATCH:-false}" == "true" ]]; then
        exec "$@" --watch
    fi
fi

exec "$@"
