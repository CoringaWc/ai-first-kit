# Install Workflow

## Passo 1 — Validar pré-condições

- [ ] Confirmar stack up: `vendor/bin/sail ps --status=running` mostra container `app`.

## Passo 2 — Instalar Grupo 1: UI (Filament + Livewire)

- [ ] Rodar (ver `rules/package-list.md` para versões):

```bash
vendor/bin/sail composer require filament/filament:^5.0 livewire/livewire:^4.0
```

- [ ] Inicializar painel Filament (**não pular**):

```bash
vendor/bin/sail artisan filament:install --panels --no-interaction
```

## Passo 3 — Instalar Grupo 2: Realtime (Reverb)

- [ ] Rodar:

```bash
vendor/bin/sail composer require laravel/reverb:^1.0
APP_HOST="$(vendor/bin/sail php -r '$env = parse_ini_file(".env"); echo parse_url($env["APP_URL"] ?? "https://localhost", PHP_URL_HOST) ?: "localhost";')"

if ! grep -q "^REVERB_APP_ID=" .env; then
  REVERB_APP_ID="$(vendor/bin/sail php -r 'echo random_int(100000, 999999);')"
  REVERB_APP_KEY="$(vendor/bin/sail php -r 'echo strtolower(bin2hex(random_bytes(10)));')"
  REVERB_APP_SECRET="$(vendor/bin/sail php -r 'echo strtolower(bin2hex(random_bytes(10)));')"
  {
    printf '\nREVERB_APP_ID=%s\n' "$REVERB_APP_ID"
    printf 'REVERB_APP_KEY=%s\n' "$REVERB_APP_KEY"
    printf 'REVERB_APP_SECRET=%s\n' "$REVERB_APP_SECRET"
    printf 'REVERB_HOST=%s\n' "$APP_HOST"
    printf 'REVERB_PORT=443\n'
    printf 'REVERB_SCHEME=https\n'
    printf 'REVERB_ALLOWED_ORIGINS=%s\n' "$APP_HOST"
    printf 'REVERB_BROADCAST_HOST=reverb\n'
    printf 'REVERB_BROADCAST_PORT=8080\n'
    printf 'REVERB_BROADCAST_SCHEME=http\n'
  } >> .env
fi

vendor/bin/sail artisan install:broadcasting --reverb --without-node --without-reverb --no-interaction
vendor/bin/sail artisan reverb:install --no-interaction
```

- [ ] **Append idempotente em `.env.example`**:

```bash
if ! grep -q "^REVERB_APP_ID=" .env.example; then
  {
    printf '\n# --- Reverb (gerenciado por composer-dep-install / A4) ---\n'
    printf 'REVERB_APP_ID=\n'
    printf 'REVERB_APP_KEY=\n'
    printf 'REVERB_APP_SECRET=\n'
    printf 'REVERB_HOST=\n'
    printf 'REVERB_PORT=443\n'
    printf 'REVERB_SCHEME=https\n'
    printf 'REVERB_ALLOWED_ORIGINS=\n'
    printf 'REVERB_BROADCAST_HOST=reverb\n'
    printf 'REVERB_BROADCAST_PORT=8080\n'
    printf 'REVERB_BROADCAST_SCHEME=http\n'
  } >> .env.example
fi
```

- [ ] Ajustar configs Reverb para separar endereço público (`REVERB_HOST`, `REVERB_PORT`, `REVERB_SCHEME`) do destino interno usado pelo Laravel para publicar mensagens:

```bash
vendor/bin/sail php <<'PHP'
$path = "config/broadcasting.php";
$content = file_get_contents($path);
$content = str_replace("'host' => env('REVERB_HOST'),", "'host' => env('REVERB_BROADCAST_HOST', env('REVERB_HOST')),", $content);
$content = str_replace("'port' => env('REVERB_PORT', 443),", "'port' => env('REVERB_BROADCAST_PORT', env('REVERB_PORT', 443)),", $content);
$content = str_replace("'scheme' => env('REVERB_SCHEME', 'https'),", "'scheme' => env('REVERB_BROADCAST_SCHEME', env('REVERB_SCHEME', 'https')),", $content);
$content = str_replace("'useTLS' => env('REVERB_SCHEME', 'https') === 'https',", "'useTLS' => env('REVERB_BROADCAST_SCHEME', env('REVERB_SCHEME', 'https')) === 'https',", $content);
file_put_contents($path, $content);
PHP
```

- [ ] Restringir origens permitidas do Reverb ao domínio configurado em `REVERB_ALLOWED_ORIGINS`:

```bash
vendor/bin/sail php <<'PHP'
$path = "config/reverb.php";
$content = file_get_contents($path);
$search = "'allowed_origins' => ['*'],";
$replace = "'allowed_origins' => array_values(array_filter(array_map(\n                    'trim',\n                    explode(',', env('REVERB_ALLOWED_ORIGINS', env('REVERB_HOST', ''))),\n                ))),";
$updated = str_replace($search, $replace, $content);

if ($updated === $content || str_contains($updated, $search)) {
    fwrite(STDERR, "Nao encontrei allowed_origins padrao em config/reverb.php ou wildcard permaneceu.\n");
    exit(1);
}

file_put_contents($path, $updated);
PHP
```

## Passo 3.5 — Instalar Octane quando profile=octane

- [ ] Se A2-octane marcou `OCTANE_SERVER=swoole`, instalar Octane e reiniciar `app` para sair do bootstrap `php-fpm` e entrar em `octane:start`:

```bash
if grep -q "^OCTANE_SERVER=swoole" .env 2>/dev/null; then
  vendor/bin/sail composer require laravel/octane
  vendor/bin/sail artisan octane:install --server=swoole --no-interaction
  vendor/bin/sail restart app
fi
```

## Passo 4 — Instalar Grupo 3: Dev tools (Larastan + Pint + Pail)

- [ ] Rodar:

```bash
vendor/bin/sail composer require --dev \
  larastan/larastan:^3.0 \
  laravel/pint:^1.0 \
  laravel/pail:^1.0
```

## Passo 5 — Instalar Grupo 4: Testing (Pest + plugins + Faker)

- [ ] Rodar:

```bash
vendor/bin/sail composer require --dev -W \
  pestphp/pest:^4.6 \
  pestphp/pest-plugin-laravel:^4.1 \
  pestphp/pest-plugin-livewire:4.x-dev \
  pestphp/pest-plugin-browser:4.x-dev \
  fakerphp/faker:^1.23
```

- [ ] Inicializar Pest (idempotente — só roda se `tests/Pest.php` ainda não existe):

```bash
[[ -f tests/Pest.php ]] || vendor/bin/sail bin pest --init
```

## Passo 6 — Instalar Grupo 5: i18n (Lucascudo)

- [ ] Rodar (único pacote de tradução permitido — ver `rules/package-list.md` Grupo 5):

```bash
vendor/bin/sail composer require --dev lucascudo/laravel-pt-br-localization:^3.0
```

A publicação de `lang/pt_BR/validation.php` é feita por A7 (`translation`), não aqui.

## Passo 7 — Instalar Grupo 6: Action Pattern (lorisleiva/laravel-actions)

- [ ] Rodar (padrão canônico para `app/Actions/<Domain>/` — ver skill `action-class`):

```bash
vendor/bin/sail composer require lorisleiva/laravel-actions:^2.0
```

O trait `AsAction` permite que a mesma classe sirva como controller, job, listener e command via opt-in (`asController()`, `asJob()`, `asListener()`, `asCommand()`).

## Passo 8 — Publicar configs essenciais

- [ ] Rodar:

```bash
vendor/bin/sail artisan vendor:publish --tag=filament-config --no-interaction
```
