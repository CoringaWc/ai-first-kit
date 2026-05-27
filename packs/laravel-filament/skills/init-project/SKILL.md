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
- Antes de handoff, aplique `verify-before-commit` e siga `verify-before-commit/rules/verify-gate.md`: `vendor/bin/sail composer verify` é o gate obrigatório.

## Workflow

Execute o bootstrap completo em `rules/docker-first-bootstrap.md`. O resumo operacional é:

- [ ] Validar host Docker-first e diretório alvo; use `rules/prerequisites.md` e `rules/partial-install-recovery.md`.
- [ ] Perguntar o runtime PHP (`fpm` ou `octane`) e guardar em `PROFILE`.
- [ ] Criar `.env`, `.env.example` e `.env.testing` mínimos antes do Laravel existir; use `rules/env-example-bootstrap.md`.
- [ ] Invocar `docker-stack-fpm` ou `docker-stack-octane-swoole`, então construir `app` via Docker Compose direto.
- [ ] Instalar Laravel dentro do container `app`, instalar `laravel/sail` apenas como helper CLI e fazer commit inicial seguro.
- [ ] Subir `app` via `vendor/bin/sail`, instalar Boost marcando apenas `opencode` e aplicar `rules/boost-install-fallback.md` se o harness errado for marcado.
- [ ] Invocar downstream em ordem estrita: `ssl-local-dev` → `composer-dep-install` → `npm-dep-install` → `translation` → `ci-github-actions`; justificativa em `rules/dispatch-order.md`.
- [ ] Rodar smoke test final obrigatório de `/up` e `/`; checklist em `rules/smoke-test-checklist.md`.
- [ ] Fazer commit final seguro sem stagear segredos.

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
