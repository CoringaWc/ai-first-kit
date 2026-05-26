# syntax=docker/dockerfile:1.7
# Harness container: orchestrates skill kit smoke tests.
# - Builds NO Laravel stack inside itself. Talks to host Docker daemon via /var/run/docker.sock.
# - PHP/Composer/Node only used by the skills' `composer create-project` / `npm install` steps.
# - python3 + PyYAML for SKILL.md frontmatter validation (mirrors _helpers/verify-skill.sh).
# - docker-ce-cli to invoke `docker`/`docker compose` against host daemon.

FROM php:8.4.12-cli-bookworm AS base

ENV DEBIAN_FRONTEND=noninteractive \
    COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_NO_INTERACTION=1 \
    PATH="/usr/local/composer/vendor/bin:${PATH}"

# OS deps + Docker CLI + Compose plugin (from Docker apt repo, pinned to bookworm)
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg lsb-release \
        git unzip zip bash jq \
        python3 python3-yaml \
        libicu-dev libpq-dev libzip-dev \
        procps less; \
    install -m 0755 -d /etc/apt/keyrings; \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg; \
    chmod a+r /etc/apt/keyrings/docker.gpg; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" \
        > /etc/apt/sources.list.d/docker.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        docker-ce-cli=5:27.* docker-compose-plugin=2.29.* docker-buildx-plugin; \
    rm -rf /var/lib/apt/lists/*

# PHP extensions required by composer create-project laravel/laravel (and downstream).
RUN docker-php-ext-install -j"$(nproc)" intl pdo_pgsql zip bcmath pcntl

# Composer 2.x (pinned)
COPY --from=composer:2.8.4 /usr/bin/composer /usr/local/bin/composer

# Node 22 LTS (pinned tarball)
ARG NODE_VERSION=22.11.0
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
        amd64) nodearch="x64";; \
        arm64) nodearch="arm64";; \
        *) echo "unsupported arch $arch"; exit 1;; \
    esac; \
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${nodearch}.tar.xz" -o /tmp/node.tar.xz; \
    tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 --no-same-owner; \
    rm /tmp/node.tar.xz; \
    node --version; npm --version

# Layout: /harness (scripts), /kit (mounted ro), /work (mounted rw, must match host path), /out (reports)
RUN mkdir -p /harness /kit /work /out
COPY runner-entrypoint.sh /harness/runner-entrypoint.sh
COPY lib/ /harness/lib/
COPY scenarios/ /harness/scenarios/
RUN chmod +x /harness/runner-entrypoint.sh /harness/scenarios/*.sh

# Sanity print for first-time debug
RUN php --version | head -1 && composer --version && node --version && docker --version

WORKDIR /work
ENTRYPOINT ["/harness/runner-entrypoint.sh"]
