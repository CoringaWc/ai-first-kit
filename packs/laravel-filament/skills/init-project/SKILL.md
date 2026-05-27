---
name: init-project
description: "Aplicar quando o usuário pedir para criar um projeto Laravel + Filament do zero num diretório vazio ou scaffold ai-first ainda sem Laravel."
license: MIT
metadata:
  author: coringawc
  version: 2.1.0
  requires:
    - laravel-best-practices
    - spatie-laravel-php-standards
  related:
    - docker-stack-fpm
    - docker-stack-octane-swoole
    - ssl-local-dev
    - composer-dep-install
    - npm-dep-install
    - translation
    - ci-github-actions
    - policy-native-laravel
---

# Init Project — Bootstrap Laravel + Filament

## Consistency First

Antes de iniciar, esta skill **assume**:

- Bootstrap **Docker-first obrigatório**. O host não precisa e não deve fornecer PHP, Composer, Artisan, Node, npm ou npx. Mesmo que existam no host, ignore; todos os comandos da stack rodam dentro do container `app`.
- Host só precisa de Docker Engine acessível, Docker Compose e git. `mkcert`/`openssl` são opcionais para HTTPS local. Ver `rules/prerequisites.md`.
- Diretório alvo pode estar vazio ou conter apenas o scaffold ai-first: `.agents/`, `.git/`, `.cert/`, `.git-crypt-keys/`, `.gitattributes`, `.gitignore`, `README.md`. Se houver `composer.json`, `vendor/` ou artefato Laravel, tratar como instalação parcial e seguir `rules/partial-install-recovery.md` antes de continuar. Se o usuário pedir segredos versionados, seguir `rules/git-crypt-secrets.md` antes de stagear `.env`, `auth.json` ou `.cert/*`.
- Locale do projeto é **fixo `pt_BR`** (fallback `en`). Sem pergunta de idioma — quem alterna locale viola a filosofia documentada em `.agents/skills/translation/rules/translation-rules.md`.
- Autorização padrão é **nativa Laravel** (gates + policies sob autodiscovery). `spatie/laravel-permission` é opt-in via skill separada (`policy-with-spatie-permission`), nunca instalado por default.

## Quick Reference

- Primeira ação técnica: gerar e construir a stack Docker (`docker-stack-fpm` ou `docker-stack-octane-swoole`).
- Pré-Sail: use `docker compose ...` porque `vendor/bin/sail` ainda não existe.
- Pós-Sail: use `vendor/bin/sail ...`; continua sendo Docker. Nunca use `php`, `composer`, `npm` ou `npx` do host.
- Skill mestra orquestra em ordem estrita: env mínimo → containers → Laravel dentro do container → Sail helper → Boost → SSL → composer → npm → traduções → CI.
- Pergunta única ao usuário: runtime PHP (`fpm` ou `octane`) antes de gerar Docker.
- Marcar **apenas `opencode`** no prompt do `boost:install` (Copilot/Codex/Gemini = não).
- Smoke test final **obrigatório**: `curl -k https://${DOMAIN}/up` e `curl -kI https://${DOMAIN}/` retornam 200; falha aborta a skill.
- Domínio derivado de `$(basename "$PWD").test`.
- Locale fixo: `APP_LOCALE=pt_BR`, `APP_FALLBACK_LOCALE=en`, `APP_FAKER_LOCALE=pt_BR` são gravados pela skill `translation`.
- Endpoints públicos de dev ficam atrás do Nginx/443: Vite em `/vite/` e Reverb em `/ws/`. Não exponha `5173` no browser e não reserve `/app`, pois esse path fica livre para Filament.
- Para alterar esse padrão, aplicar `vite-reverb-nginx-routing` antes das skills Docker/npm/composer.

## Workflow

### Passo 0 — Validar host Docker-first

- [ ] Verificar pré-requisitos do host (ver `rules/prerequisites.md`). Não testar PHP, Composer ou Node do host.

```bash
docker compose version >/dev/null 2>&1 || docker-compose --version >/dev/null 2>&1 || { echo "ERRO: docker compose ausente"; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERRO: Docker daemon indisponível. Inicie Docker Desktop/Engine e habilite integração WSL se aplicável."; exit 1; }
git --version >/dev/null 2>&1 || { echo "ERRO: git ausente"; exit 1; }
```

- [ ] Verificar diretório novo/scaffold ai-first:

```bash
LEFTOVERS=$(ls -A | grep -v -E '^(\.agents|\.git|\.cert|\.git-crypt-keys|\.gitattributes|\.gitignore|README\.md)$' || true)
[[ -z "$LEFTOVERS" ]] || { echo "Diretório não-vazio ou tentativa parcial (encontrado: $LEFTOVERS). Consulte rules/partial-install-recovery.md."; exit 1; }
```

- [ ] Se há vestígios de tentativa anterior (`composer.json` presente mas `vendor/laravel/framework` ausente, `docker-compose.yml` parcial, `docker/` parcial), listar conteúdo e **pedir confirmação explícita do usuário** antes de qualquer `rm`. Detalhes em `rules/partial-install-recovery.md`.

### Passo 1 — Perguntar runtime PHP

- [ ] Perguntar ao usuário:

`Runtime PHP do projeto: 1) fpm (default, estável) 2) octane (Swoole, exige cuidado com state-leak)`

- [ ] Guardar resposta em `PROFILE` (`fpm` ou `octane`).

### Passo 2 — Criar `.env` mínimo para Docker

- [ ] Criar `.env`, `.env.example` e `.env.testing` antes do Laravel existir, com ownership idempotente. Detalhes em `rules/env-example-bootstrap.md`.

- [ ] Garantir no mínimo:

```bash
PROJECT_NAME="$(basename "$PWD")"
DOMAIN="${PROJECT_NAME}.test"

touch .env .env.example

set_env_entry() {
  local ENV_FILE="$1" ENTRY="$2" KEY_NAME="${ENTRY%%=*}"
  if grep -q "^${KEY_NAME}=" "$ENV_FILE"; then
    sed -i "s|^${KEY_NAME}=.*|${ENTRY}|" "$ENV_FILE"
  else
    echo "$ENTRY" >> "$ENV_FILE"
  fi
}

for ENV_FILE in .env .env.example; do
  for ENTRY in \
    "APP_NAME=Laravel" \
    "APP_ENV=local" \
    "APP_DEBUG=true" \
    "APP_URL=https://${DOMAIN}" \
    "APP_SERVICE=app" \
    "WWWUSER=1000" \
    "WWWGROUP=1000" \
    "DB_CONNECTION=pgsql" \
    "DB_HOST=postgres" \
    "DB_PORT=5432" \
    "DB_DATABASE=laravel" \
    "DB_USERNAME=sail" \
    "DB_PASSWORD=password" \
    "FORWARD_DB_PORT=5432" \
    "FORWARD_REDIS_PORT=6379"; do
    set_env_entry "$ENV_FILE" "$ENTRY"
  done
done

[ -f .env.testing ] || cp .env.example .env.testing
sed -i 's/^APP_ENV=.*/APP_ENV=testing/' .env.testing
sed -i 's/^DB_DATABASE=.*/DB_DATABASE=testing/' .env.testing
if grep -q '^APP_KEY=' .env.testing; then
  sed -i 's#^APP_KEY=.*#APP_KEY=base64:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=#' .env.testing
else
  printf 'APP_KEY=base64:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\n' >> .env.testing
fi
```

### Passo 3 — Gerar e construir Docker antes do Laravel

Cada skill downstream é invocada via tool `Skill` (ex.: `Skill(name="docker-stack-fpm")`).

- [ ] Se `PROFILE=fpm`, invocar `docker-stack-fpm`; se `PROFILE=octane`, invocar `docker-stack-octane-swoole`.
- [ ] Como `vendor/bin/sail` ainda não existe, executar o build inicial com Docker Compose direto:

```bash
docker compose build app
```

### Passo 4 — Instalar Laravel dentro do container `app`

- [ ] Instalar Laravel em diretório temporário dentro do container e copiar para o workspace. Isso evita exigir diretório host vazio absoluto e preserva o kit `.agents/`.

```bash
docker compose run --rm --no-deps app bash -lc '
  set -euo pipefail
  rm -rf /tmp/laravel-bootstrap
  composer create-project laravel/laravel /tmp/laravel-bootstrap --prefer-dist
  shopt -s dotglob
  for path in /tmp/laravel-bootstrap/*; do
    name="$(basename "$path")"
    case "$name" in
      .git|.agents|.cert|.git-crypt-keys|.gitattributes) continue ;;
    esac
    cp -a "$path" /var/www/html/
  done
'
```

- [ ] Instalar Sail apenas como helper CLI. **Não rodar `sail:install`**, porque ele gera compose padrão e conflita com a stack canônica do kit.

```bash
docker compose run --rm --no-deps app composer require laravel/sail --dev
docker compose run --rm --no-deps app php artisan key:generate --force
```

- [ ] Reaplicar header de ownership no `.env.example` e normalização de `.env`/`.env.testing` (ver `rules/env-example-bootstrap.md`), porque o skeleton Laravel pode ter recriado arquivos env.

- [ ] Commit inicial:

```bash
if [[ ! -d .git ]]; then git init; fi
stage_safe_project_files() {
  while IFS= read -r path; do
    lower_path="${path,,}"
    case "$lower_path" in
      .env|.env.*|.npmrc|auth.json|.cert/*|.git-crypt-keys/*|*.key|*.pem|*credential*|*credentials*|*secret*|*secrets*) continue ;;
    esac
    git add -- "$path"
  done < <(git ls-files --others --modified --deleted --exclude-standard)
}
stage_safe_project_files
git commit -m "chore: bootstrap laravel skeleton via docker"
```

### Passo 5 — Subir container `app` via Sail

- [ ] A partir deste ponto, `vendor/bin/sail` existe e deve ser usado para PHP/Composer/Artisan/Node:

```bash
vendor/bin/sail up -d --build app
```

### Passo 6 — Instalar Laravel Boost via Docker

- [ ] Executar. Criar `boost.json` antes do installer evita o prompt de agentes em modo não-interativo; ainda assim rode `boost:install`, porque `AGENTS.md`, MCP e skills podem não existir ainda:

```bash
vendor/bin/sail composer require laravel/boost --dev
if [[ ! -f boost.json ]]; then
  cat > boost.json <<'JSON'
{
    "agents": [
        "opencode"
    ],
    "cloud": false,
    "guidelines": true,
    "mcp": true,
    "nightwatch": false,
    "sail": true,
    "skills": [
        "laravel-best-practices"
    ]
}
JSON
fi
vendor/bin/sail artisan boost:install --guidelines --skills --mcp --no-interaction || {
  echo "boost:install falhou em modo não-interativo. Rode interativo dentro do container:"
  echo "    vendor/bin/sail artisan boost:install"
  echo "    Marque APENAS 'opencode' (espaço para selecionar)"
  echo "    NÃO marque Copilot, Codex, ou Gemini"
  exit 1
}
```

- [ ] Se o usuário marcou harness errado: ler `rules/boost-install-fallback.md`.

### Passo 7 — SSL e dependências downstream

**Ordem estrita**: SSL → composer → npm → traduções → CI. Justificativa em `rules/dispatch-order.md`.

- [ ] Invocar `ssl-local-dev`.
- [ ] Invocar em sequência: `composer-dep-install` → `npm-dep-install` → `translation` → `ci-github-actions`.

### Passo 8 — Smoke test final

- [ ] Subir stack completo:

```bash
vendor/bin/sail up -d
vendor/bin/sail artisan migrate --force --no-interaction
```

- [ ] Aguardar healthcheck (até 60s) **falhando em voz alta** se não retornar 200 — aborta a skill:

```bash
DOMAIN="$(basename "$PWD").test"
healthcheck_ok=false
for i in $(seq 1 60); do
  status=$(curl -ks -o /dev/null -w "%{http_code}" "https://${DOMAIN}/up" || echo "000")
  if [ "$status" = "200" ]; then
    healthcheck_ok=true; echo "Healthcheck OK em ${i}s (${DOMAIN})"; break
  fi
  sleep 1
done
if [ "$healthcheck_ok" = "false" ]; then
  echo "ERRO: healthcheck https://${DOMAIN}/up falhou após 60s. Consulte rules/smoke-test-checklist.md e rode: vendor/bin/sail logs --tail=100"
  exit 1
fi

root_status=$(curl -ks -o /dev/null -w "%{http_code}" "https://${DOMAIN}/" || echo "000")
if [ "$root_status" != "200" ]; then
  echo "ERRO: raiz https://${DOMAIN}/ retornou HTTP ${root_status}. Consulte rules/smoke-test-checklist.md."
  exit 1
fi
```

- [ ] Commit final:

```bash
stage_safe_project_files() {
  while IFS= read -r path; do
    lower_path="${path,,}"
    case "$lower_path" in
      .env|.env.*|.npmrc|auth.json|.cert/*|.git-crypt-keys/*|*.key|*.pem|*credential*|*credentials*|*secret*|*secrets*) continue ;;
    esac
    git add -- "$path"
  done < <(git ls-files --others --modified --deleted --exclude-standard)
}
stage_safe_project_files
git commit -m "feat: bootstrap projeto laravel + filament via init-project (profile=$PROFILE)"
```

## Anti-Patterns

- ❌ **Não abortar por falta de PHP/Composer/Node no host.** Esse foi o bug real que motivou esta revisão: o projeto é Docker-first; essas ferramentas pertencem ao container `app`.
- ❌ **Não usar PHP, Composer, Artisan, npm ou npx do host mesmo se existirem.** Rodar fora do container produz `vendor/`, `node_modules/`, caches e binários incompatíveis com a imagem canônica.
- ❌ **Não chamar `vendor/bin/sail` antes de instalar Laravel + `laravel/sail`.** No bootstrap inicial, use `docker compose run/build`; após instalar Sail, use `vendor/bin/sail`.
- ❌ **Não rodar `php artisan sail:install`.** Ele gera o compose padrão do Sail e pode sobrescrever a stack canônica do kit. Instale apenas o pacote `laravel/sail` para ter o helper `vendor/bin/sail`.
- ❌ **Não marcar todos os harnesses no `boost:install`.** Marcar Copilot/Codex/Gemini cria `.github/instructions/`, `.cursorrules` e similares, violando o princípio de source-of-truth único (`AGENTS.md`). Marque apenas `opencode`.
- ❌ **Não perguntar idioma.** Locale é fixo `pt_BR` com fallback `en` (D2). Perguntar idioma cria divergência entre projetos e leva a workarounds proibidos como `laravel-lang/lang` ou troca de locale em runtime.
- ❌ **Não pular o smoke test.** Sem `curl 200` confirmado, a skill não terminou.
- ❌ **Não validar apenas `/up`.** O healthcheck não usa sessão web; com `SESSION_DRIVER=database`, a raiz pode falhar por migrations pendentes enquanto `/up` passa.
- ❌ **Não instalar `spatie/laravel-permission` automaticamente.** Autorização padrão é nativa Laravel. Spatie Permission é opt-in via `policy-with-spatie-permission` em PR separado.
- ❌ **Não stagear segredos antes de ativar `git-crypt`.** `.gitattributes` precisa existir e `git-crypt status -e` não pode emitir `WARNING: staged/committed version is NOT ENCRYPTED!`.

## Verification

- [ ] `.agents/skills/_helpers/verify-skill.sh .agents/skills/init-project/SKILL.md` retorna `OK`
- [ ] `docker compose build app` termina sem erro antes do Laravel existir
- [ ] `vendor/bin/sail php -v` imprime PHP 8.4 dentro do container
- [ ] `vendor/bin/sail composer --version` imprime Composer 2.x dentro do container
- [ ] `vendor/bin/sail node --version` imprime `v22.*` dentro do container
- [ ] `curl -sk https://$(basename "$PWD").test/up` retorna 200
- [ ] `curl -skI https://$(basename "$PWD").test/` retorna 200 e `content-type: text/html; charset=utf-8`
- [ ] `vendor/bin/sail bin pest --version` imprime versão
- [ ] `[[ -f boost.json ]]` retorna verdadeiro
- [ ] `grep -q "gerenciado por init-project" .env.example` retorna 0
- [ ] `git log --oneline | wc -l` retorna ≥ 2 (skeleton, bootstrap)

## Related

- Skills Boost: `laravel-best-practices`, `spatie-laravel-php-standards`
- Skills downstream (ordem de invocação): `docker-stack-fpm` ou `docker-stack-octane-swoole`, `ssl-local-dev`, `composer-dep-install`, `npm-dep-install`, `translation`, `ci-github-actions`
- Fonte única de base do container: `_shared/docker-base-deps.md` (SO, Node 22, libs Chromium, extensões PHP) — consumida por `docker-stack-fpm`, `docker-stack-octane-swoole` e `enable-octane-swoole`.
- Autorização: `policy-native-laravel` (default), `policy-with-spatie-permission` (opt-in)
- Migração de runtime: `enable-octane-swoole` (FPM → Octane em projeto existente)
- Rules: `rules/prerequisites.md`, `rules/partial-install-recovery.md`, `rules/boost-install-fallback.md`, `rules/env-example-bootstrap.md`, `rules/git-crypt-secrets.md`, `rules/dispatch-order.md`, `rules/smoke-test-checklist.md`
- Roteamento Vite/Reverb: `vite-reverb-nginx-routing`
- Doutrina i18n: `.agents/skills/translation/rules/translation-rules.md`
- Doc Boost: https://boost.laravel.com/docs/installation
