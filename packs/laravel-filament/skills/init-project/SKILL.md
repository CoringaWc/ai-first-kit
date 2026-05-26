---
name: init-project
description: "Aplicar quando o usuário pedir para criar um projeto Laravel + Filament do zero num diretório vazio, exceto pelo kit de skills."
license: MIT
metadata:
  author: coringawc
  version: 2.0.0
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

- Diretório alvo está vazio exceto pelo kit `.agents/skills/` e `.git/`. Se houver `composer.json`, `vendor/` ou qualquer artefato Laravel, **abortar** e instruir o usuário — esta skill é só para projetos novos. Para migrar projeto FPM existente para Octane, ver `enable-octane-swoole`.
- Locale do projeto é **fixo `pt_BR`** (fallback `en`). Sem pergunta de idioma — quem alterna locale viola a filosofia documentada em `.agents/skills/translation/rules/translation-rules.md`.
- Autorização padrão é **nativa Laravel** (gates + policies sob autodiscovery). `spatie/laravel-permission` é opt-in via skill separada (`policy-with-spatie-permission`), nunca instalado por default.
- Passos 0–1 rodam **no host** (Sail ainda não existe). Pré-requisitos em `rules/prerequisites.md`: PHP ≥ 8.4, Composer 2.x, Docker + docker-compose, git, mkcert (opcional, para HTTPS local).

## Quick Reference

- Skill mestra orquestra 7 skills downstream em ordem estrita: containers → SSL → composer → npm → traduções → CI.
- Pergunta única ao usuário: runtime PHP (`fpm` ou `octane`).
- Marcar **apenas `opencode`** no prompt do `boost:install` (Copilot/Codex/Gemini = não).
- Idempotente parcial: se travar no Boost, retomar via `init-project --skip-boost`.
- Smoke test final **obrigatório**: `curl -k https://${DOMAIN}/up` retorna 200; falha aborta a skill.
- Domínio derivado de `$(basename "$PWD").test`.
- Gera `.env.example` inicial; skills downstream fazem **append idempotente** das suas chaves.
- Locale fixo: `APP_LOCALE=pt_BR`, `APP_FALLBACK_LOCALE=en`, `APP_FAKER_LOCALE=pt_BR` são gravados pela skill `translation`.

## Workflow

### Passo 0 — Instalar Laravel base

- [ ] Verificar pré-requisitos do host (ver `rules/prerequisites.md`).

- [ ] Verificar diretório vazio (exceto kit e `.git`):

```bash
LEFTOVERS=$(ls -A | grep -v -E '^(\.agents|\.git)$' || true)
[[ -z "$LEFTOVERS" ]] || { echo "Diretório não-vazio (encontrado: $LEFTOVERS). Aborte."; exit 1; }
```

- [ ] Se há vestígios de tentativa anterior (`composer.json` presente mas `vendor/` incompleto), listar conteúdo e **pedir confirmação explícita do usuário** antes de qualquer `rm`. Detalhes em `rules/partial-install-recovery.md`.

- [ ] Instalar Laravel via Composer:

```bash
composer create-project laravel/laravel . --prefer-dist
```

- [ ] Instalar Sail explicitamente (Laravel 13 não traz Sail por padrão):

```bash
if [[ ! -f vendor/bin/sail ]]; then
  composer require laravel/sail --dev
  php artisan sail:install --with=pgsql,redis --no-interaction
fi
```

- [ ] Inicializar git e commit inicial:

```bash
if [[ ! -d .git ]]; then git init; fi
git add . && git commit -m "chore: initial laravel skeleton"
```

### Passo 1 — Instalar Laravel Boost

- [ ] Executar (idempotente — pula se `boost.json` já existe):

```bash
composer require laravel/boost --dev
if [[ ! -f boost.json ]]; then
  printf "opencode\n\n\n" | php artisan boost:install || {
    echo "boost:install falhou em modo não-interativo. Rode interativo:"
    echo "    php artisan boost:install"
    echo "    Marque APENAS 'opencode' (espaço para selecionar)"
    echo "    NÃO marque Copilot, Codex, ou Gemini"
    exit 1
  }
fi
```

- [ ] Se o usuário marcou harness errado: ler `rules/boost-install-fallback.md`.

### Passo 2 — Perguntar runtime PHP

- [ ] Perguntar ao usuário:

`Runtime PHP do projeto: 1) fpm (default, estável) 2) octane (Swoole, exige cuidado com state-leak)`

- [ ] Guardar resposta em `PROFILE` (`fpm` ou `octane`).

### Passo 3 — Criar `.env.example` inicial

- [ ] Garantir header de ownership idempotente e criar `.env.testing`; detalhes em `rules/env-example-bootstrap.md`.

### Passo 4 — Despachar skills downstream

Cada skill é invocada via tool `Skill` (ex.: `Skill(name="docker-stack-fpm")`).

**Ordem estrita**: containers → SSL → subir Sail → composer → npm → traduções → CI. Justificativa em `rules/dispatch-order.md`.

- [ ] Exportar `ALLOW_SAIL_COMPOSE_REPLACE=1`. Se `PROFILE=fpm`, invocar `docker-stack-fpm`; se `PROFILE=octane`, invocar `docker-stack-octane-swoole`. Esse opt-in só vale porque o passo anterior gerou o compose padrão do Sail.
- [ ] Invocar `ssl-local-dev`.
- [ ] Subir o container `app` antes das skills que rodam Composer/Artisan via Sail:

```bash
vendor/bin/sail up -d --build app
```

- [ ] Invocar em sequência: `composer-dep-install` → `npm-dep-install` → `translation` → `ci-github-actions`.

### Passo 5 — Smoke test final

- [ ] Subir stack completo:

```bash
vendor/bin/sail up -d
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
```

- [ ] Commit final:

```bash
git add -A
git commit -m "feat: bootstrap projeto laravel + filament via init-project (profile=$PROFILE)"
```

## Anti-Patterns

- ❌ **Não marcar todos os harnesses no `boost:install`.** Marcar Copilot/Codex/Gemini cria `.github/instructions/`, `.cursorrules` e similares, violando o princípio de source-of-truth único (`AGENTS.md`). Marque apenas `opencode`.
- ❌ **Não perguntar idioma.** Locale é fixo `pt_BR` com fallback `en` (D2). Perguntar idioma cria divergência entre projetos e leva a workarounds proibidos como `laravel-lang/lang` ou troca de locale em runtime.
- ❌ **Não pular o smoke test.** Sem `curl 200` confirmado, a skill não terminou. O healthcheck do Passo 5 deve abortar (`exit 1`) se não vier 200 em 60s — qualquer skill rodando sobre stack quebrada produz falhas em cascata difíceis de diagnosticar.
- ❌ **Não rodar `composer-dep-install` antes de subir o container `app`.** Composer install precisa do container rodando. Ordem assumida pelas skills downstream: containers → SSL → composer → npm → traduções → CI.
- ❌ **Não instalar `spatie/laravel-permission` automaticamente.** Autorização padrão é nativa Laravel. Spatie Permission é opt-in via `policy-with-spatie-permission` em PR separado, com policies migradas explicitamente.
- ❌ **Não usar `composer` ou `npm` do host após a stack subir.** Toda chamada passa por `vendor/bin/sail composer ...` e `vendor/bin/sail npm ...` — instalar pelo host produz `vendor/` e `node_modules/` com extensões/binários incompatíveis com a imagem PHP 8.4 do container.

## Verification

- [ ] `.agents/skills/_helpers/verify-skill.sh .agents/skills/init-project/SKILL.md` retorna `OK`
- [ ] `curl -sk https://$(basename "$PWD").test/up` retorna 200
- [ ] `vendor/bin/sail bin pest --version` imprime versão
- [ ] `[[ -f boost.json ]]` retorna verdadeiro
- [ ] `grep -q "gerenciado por init-project" .env.example` retorna 0
- [ ] `git log --oneline | wc -l` retorna ≥ 3 (skeleton, boost, bootstrap)

## Related

- Skills Boost: `laravel-best-practices`, `spatie-laravel-php-standards`
- Skills downstream (ordem de invocação): `docker-stack-fpm` ou `docker-stack-octane-swoole`, `ssl-local-dev`, `composer-dep-install`, `npm-dep-install`, `translation`, `ci-github-actions`
- Fonte única de base do container: `_shared/docker-base-deps.md` (SO, Node 22, libs Chromium, extensões PHP) — consumida por `docker-stack-fpm`, `docker-stack-octane-swoole` e `enable-octane-swoole`.
- Autorização: `policy-native-laravel` (default), `policy-with-spatie-permission` (opt-in)
- Migração de runtime: `enable-octane-swoole` (FPM → Octane em projeto existente)
- Rules: `rules/prerequisites.md`, `rules/partial-install-recovery.md`, `rules/boost-install-fallback.md`, `rules/env-example-bootstrap.md`, `rules/dispatch-order.md`, `rules/smoke-test-checklist.md`
- Doutrina i18n: `.agents/skills/translation/rules/translation-rules.md`
- Doc Boost: https://boost.laravel.com/docs/installation
