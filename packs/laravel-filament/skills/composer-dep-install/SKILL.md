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
- Comandos manuais para adição, remoção, recuperação e validação ficam em `rules/manual-commands.md`.
- Antes de handoff, aplique `verify-before-commit` e siga `verify-before-commit/rules/verify-gate.md`: `vendor/bin/sail composer verify` é o gate obrigatório.

## Workflow

Execute o workflow completo em `rules/install-workflow.md`. O resumo operacional é:

- [ ] Validar que o container `app` está rodando via `vendor/bin/sail ps --status=running`.
- [ ] Instalar Grupo 1 UI (`filament/filament`, `livewire/livewire`) e rodar `filament:install --panels`.
- [ ] Instalar Grupo 2 Realtime (`laravel/reverb`), configurar `.env`/`.env.example`, rodar broadcasting/Reverb e ajustar configs de origem e broadcast interno.
- [ ] Se `OCTANE_SERVER=swoole`, instalar `laravel/octane`, rodar `octane:install --server=swoole` e reiniciar `app`.
- [ ] Instalar Grupos 3 a 6 conforme `rules/package-list.md`: dev-tools, testing, i18n e action pattern.
- [ ] Publicar configs essenciais com `vendor:publish --tag=filament-config`.
- [ ] Para comandos manuais fora do bootstrap canônico, seguir `rules/manual-commands.md`.

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
