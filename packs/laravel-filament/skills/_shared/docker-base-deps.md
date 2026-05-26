# Docker Base Deps (compartilhado)

Lista canônica de dependências de SO, locale, Node e extensões PHP usadas por `docker-stack-fpm` e `docker-stack-octane-swoole`. Quando atualizar Node ou Chromium libs, mude **aqui** e propague para os Dockerfiles das duas skills.

## SO base

- Distro: `debian:bookworm` (FPM via `php:8.4-fpm-bookworm`; Octane via `phpswoole/swoole:php8.4`, também Debian-based).
- Locale: gerado a partir de `{{LOCALE}}` (default `pt_BR.UTF-8`).
- Timezone: `America/Recife` no `php.ini`; sobrescritível via env `TZ`.

## Pacotes APT obrigatórios

```
ca-certificates curl git unzip zip gnupg \
libpq-dev libzip-dev libpng-dev libjpeg-dev libfreetype6-dev \
libicu-dev libonig-dev libxml2-dev \
locales tzdata
```

## Libs Chromium para Playwright (Pest Browser)

```
libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdbus-1-3 \
libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 \
libxrandr2 libgbm1 libasound2 libpangocairo-1.0-0 libpango-1.0-0 \
libcairo2 fonts-liberation
```

Não trocar para imagem `mcr.microsoft.com/playwright` como base: não traz PHP, multi-stage incha em ~1,5 GB.

## Node

- Canal: NodeSource.
- Versão pinada: **Node 22** (LTS atual; alinhada com CI).
- Instalação:

```dockerfile
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/*
```

Não usar `lts/*` nem `latest`: quebra reprodutibilidade entre CI e local.

## Extensões PHP

Comuns nos dois perfis:

```
pdo_pgsql pgsql bcmath gd intl mbstring opcache pcntl redis zip
```

Exclusivas Octane: `swoole` já vem na base `phpswoole/swoole:php8.4`. **Não** rodar `pecl install swoole` em cima — duplica a extensão e quebra o boot do worker.

Exclusivas FPM: nenhuma além das comuns.

## Composer

```dockerfile
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
```

Não usar `curl | php` para instalar; pin via imagem oficial garante checksum.

## Healthcheck genérico do `app`

- FPM: `php -r "exit(@fsockopen('127.0.0.1', 9000) ? 0 : 1);"`
- Octane: `php -r "exit(@fsockopen('127.0.0.1', 8000) ? 0 : 1);"`

## Usuário não-root

```dockerfile
ARG WWWUSER=1000
ARG WWWGROUP=1000
RUN groupadd --force --gid $WWWGROUP sail \
 && useradd -ms /bin/bash --no-user-group -g $WWWGROUP -u $WWWUSER sail
USER sail
```

`docker-compose.yml` lê `${WWWUSER}` e `${WWWGROUP}` do `.env`. Sem essas vars no `.env`, build falha em `groupadd --gid ''`.
