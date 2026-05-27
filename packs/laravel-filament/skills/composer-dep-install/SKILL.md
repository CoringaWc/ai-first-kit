---
name: composer-dep-install
description: "Aplicar quando init-project (A4) executar instalação da stack PHP ou quando o usuário pedir adição da stack composer canônica em projeto recém-criado."
license: MIT
metadata:
  author: coringawc
  version: 2.0.0
  requires:
    - laravel-best-practices
    - spatie-laravel-php-standards
  related:
    - init-project
    - docker-stack-fpm
    - docker-stack-octane-swoole
    - npm-dep-install
    - translation
---

# Composer Dep Install — Stack PHP Canônica

## Consistency First

A4 **assume**:

- Stack Sail rodando (A2 já executou `sail up -d`). Verificar antes:

```bash
vendor/bin/sail ps --status=running | grep -q '\bapp\b' || { echo "A2 não executado (container 'app' não rodando) — abortar"; exit 1; }
```

- SSL/hosts prontos (A3) — `composer require` pode validar URLs HTTPS.
- Locale do projeto é fixo `pt_BR` (ver `.agents/skills/translation/rules/translation-rules.md`). A skill **não recebe variável de locale** — quem alterna locale viola a filosofia.

A4 **não**:

- não roda no host — toda chamada é via `vendor/bin/sail composer ...`.
- não publica `lang/pt_BR/validation.php` — quem faz é A7 (`translation`), depois que o pacote `lucascudo` já está instalado por aqui.
- não configura `fake()` em runtime — `fake()` lê de `APP_FAKER_LOCALE` no `.env`, fixado pela `translation`.

## Quick Reference

- Para Reverb, `REVERB_ALLOWED_ORIGINS`, `REVERB_BROADCAST_*` ou paths públicos de WebSocket, seguir `vite-reverb-nginx-routing` antes de editar.
- 5 grupos de `composer require` (UI, realtime, dev-tools, testing, i18n), mais Octane opcional quando `OCTANE_SERVER=swoole`. Detalhes em `rules/package-list.md`.
- 1 `filament:install --panels` **obrigatório** após Grupo 1.
- 1 `install:broadcasting --reverb --without-node --without-reverb` + `reverb:install` após Grupo 2.
- Append idempotente em `.env.example` das chaves Reverb.
- Em profile Octane, A4 instala `laravel/octane`, roda `octane:install --server=swoole` e reinicia `app`.
- Grupo 5 instala `lucascudo/laravel-pt-br-localization` — único pacote de i18n permitido pela filosofia do projeto.
- **Não instala** `spatie/laravel-permission` nem `laravel-lang/lang` — ver Anti-Patterns.
- Em projetos com entrypoint canônico, a instalação inicial pode ser disparada automaticamente no primeiro `docker compose up -d --build`. Use comandos manuais de Composer quando estiver adicionando/removendo pacotes, recuperando falhas ou validando instalação parcial.
- Exemplos manuais: adicionar pacote com `vendor/bin/sail composer require vendor/package`; remover pacote com `vendor/bin/sail composer remove vendor/package`; recuperar falha com `vendor/bin/sail composer install`; validar instalação parcial com `vendor/bin/sail composer validate && vendor/bin/sail composer check-platform-reqs`.
- Antes de handoff, aplique `verify-before-commit` e siga `verify-before-commit/rules/verify-gate.md`: `vendor/bin/sail composer verify` é o gate obrigatório.

## Workflow

### Passo 1 — Validar pré-condições

- [ ] Confirmar stack up: `vendor/bin/sail ps --status=running` mostra container `app`.

### Passo 2 — Instalar Grupo 1: UI (Filament + Livewire)

- [ ] Rodar (ver `rules/package-list.md` para versões):

```bash
vendor/bin/sail composer require filament/filament:^5.0 livewire/livewire:^4.0
```

- [ ] Inicializar painel Filament (**não pular**):

```bash
vendor/bin/sail artisan filament:install --panels --no-interaction
```

### Passo 3 — Instalar Grupo 2: Realtime (Reverb)

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

### Passo 3.5 — Instalar Octane quando profile=octane

- [ ] Se A2-octane marcou `OCTANE_SERVER=swoole`, instalar Octane e reiniciar `app` para sair do bootstrap `php-fpm` e entrar em `octane:start`:

```bash
if grep -q "^OCTANE_SERVER=swoole" .env 2>/dev/null; then
  vendor/bin/sail composer require laravel/octane
  vendor/bin/sail artisan octane:install --server=swoole --no-interaction
  vendor/bin/sail restart app
fi
```

### Passo 4 — Instalar Grupo 3: Dev tools (Larastan + Pint + Pail)

- [ ] Rodar:

```bash
vendor/bin/sail composer require --dev \
  larastan/larastan:^3.0 \
  laravel/pint:^1.0 \
  laravel/pail:^1.0
```

### Passo 5 — Instalar Grupo 4: Testing (Pest + plugins + Faker)

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

### Passo 6 — Instalar Grupo 5: i18n (Lucascudo)

- [ ] Rodar (único pacote de tradução permitido — ver `rules/package-list.md` Grupo 5):

```bash
vendor/bin/sail composer require --dev lucascudo/laravel-pt-br-localization:^3.0
```

A publicação de `lang/pt_BR/validation.php` é feita por A7 (`translation`), não aqui.

### Passo 7 — Instalar Grupo 6: Action Pattern (lorisleiva/laravel-actions)

- [ ] Rodar (padrão canônico para `app/Actions/<Domain>/` — ver skill `action-class`):

```bash
vendor/bin/sail composer require lorisleiva/laravel-actions:^2.0
```

O trait `AsAction` permite que a mesma classe sirva como controller, job, listener e command via opt-in (`asController()`, `asJob()`, `asListener()`, `asCommand()`).

### Passo 8 — Publicar configs essenciais

- [ ] Rodar:

```bash
vendor/bin/sail artisan vendor:publish --tag=filament-config --no-interaction
```

## Anti-Patterns

- ❌ **Não instalar tudo numa linha só** (`composer require A B C D E F`). Conflito em qualquer um aborta o grupo inteiro e dificulta diagnóstico. Agrupar por domínio (UI, realtime, dev-tools, testing, i18n) como em `rules/package-list.md`.
- ❌ **Não remover `-W` nem trocar os plugins Pest 4.x-dev no Laravel 13.** O skeleton traz `laravel/pao` (`composer.json` deste projeto, `require-dev`) e PHPUnit travados; `-W` permite reconciliar transitivas. Plugins `4.x-dev` declaram L13 antes dos tags estáveis.
- ❌ **Não esquecer `php artisan filament:install --panels`** após `composer require filament/filament`. Sem isso o painel não tem `AdminPanelProvider` registrado e rotas não existem — sintoma é 404 em `/admin`, com `composer.json` aparentemente correto (debug confuso).
- ❌ **Não instalar `laravel-lang/lang`.** Filosofia i18n do projeto proíbe (locale fixo, sem alternância). Único pacote permitido é `lucascudo/laravel-pt-br-localization` instalado no Grupo 5. Ver `.agents/skills/translation/rules/translation-rules.md` §1.
- ❌ **Não instalar `spatie/laravel-permission` automaticamente.** O projeto atual usa autorização nativa Laravel + policies, não Spatie Permission (confirmar em `composer.json` deste repo — não consta em `require`). Adicionar apenas sob demanda explícita do usuário, em PR separado, com policies migradas.
- ❌ **Não estampar `$GLOBALS['__fake_locale']` em `tests/Pest.php`.** `fake()` lê de `config('app.faker_locale')` que vem de `APP_FAKER_LOCALE` no `.env`, fixado por A7. Stub manual mascara configuração quebrada e cria divergência entre runtime e testes.
- ❌ **Não usar `composer` do host.** A2 já criou o stack; rodar `composer` fora do container produz `vendor/` com extensões do host (não do `php:8.4-cli` do container) — quebra em runtime via `sail`.
- ❌ **Não assumir que `octane:start` existe antes da A4.** A2-octane só prepara a imagem com ext-swoole; o package `laravel/octane` é instalado aqui, depois que o container bootstrap já está executável.

## Verification

- [ ] `.agents/skills/_helpers/verify-skill.sh .agents/skills/composer-dep-install/SKILL.md` retorna `OK`
- [ ] `vendor/bin/sail composer show filament/filament livewire/livewire laravel/reverb >/dev/null` retorna `0`
- [ ] `vendor/bin/sail composer show lucascudo/laravel-pt-br-localization >/dev/null` retorna `0`
- [ ] `vendor/bin/sail composer show lorisleiva/laravel-actions >/dev/null` retorna `0`
- [ ] `vendor/bin/sail composer show spatie/laravel-permission >/dev/null 2>&1; [[ $? -ne 0 ]]` (confirmar **ausência**)
- [ ] `vendor/bin/sail composer show laravel-lang/lang >/dev/null 2>&1; [[ $? -ne 0 ]]` (confirmar **ausência**)
- [ ] `vendor/bin/sail bin pest --version` imprime versão
- [ ] `vendor/bin/sail bin pint --version` imprime versão
- [ ] `vendor/bin/sail artisan route:list --path=admin` lista rotas Filament (≥1 rota)
- [ ] `grep -c "^REVERB_" .env.example` ≥ 6

## Related

- Skills Boost: `laravel-best-practices`, `spatie-laravel-php-standards`
- Skills upstream/downstream: `docker-stack-fpm`, `docker-stack-octane-swoole`, `ssl-local-dev`, `npm-dep-install`, `translation`
- Orquestradora: `init-project`
- Rules: `rules/package-list.md`
- Roteamento Vite/Reverb: `vite-reverb-nginx-routing`
- Doutrina i18n: `.agents/skills/translation/rules/translation-rules.md`
