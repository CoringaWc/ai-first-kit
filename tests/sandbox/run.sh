#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 '<bash snippet as single argument>'" >&2
  exit 64
fi

# Usage: tests/sandbox/run.sh <command...>
# Builds (if needed) and runs a command inside a fresh sandbox container.
# The repo is bind-mounted read-only at /kit. $HOME inside the container is /home/tester.
# Image tag includes a hash of the Dockerfile so changes invalidate the cache automatically.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if ! command -v docker >/dev/null 2>&1; then
  echo "[err] docker is required for sandbox tests." >&2
  echo "      Install: https://docs.docker.com/engine/install/" >&2
  exit 127
fi

DOCKERFILE="$REPO_ROOT/tests/sandbox/Dockerfile"
HASH="$(sha256sum "$DOCKERFILE" | cut -c1-12)"
IMAGE_TAG="ai-first-kit-sandbox:${HASH}"

if ! docker image inspect "$IMAGE_TAG" >/dev/null 2>&1; then
  docker build -t "$IMAGE_TAG" "$REPO_ROOT/tests/sandbox" >&2
fi

docker run --rm \
  -v "$REPO_ROOT:/kit:ro" \
  -w /home/tester \
  "$IMAGE_TAG" \
  bash -c "$1"
