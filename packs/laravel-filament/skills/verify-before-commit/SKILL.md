---
name: verify-before-commit
description: "Aplicar quando o agente precisar rodar o gate local final antes de commit, PR, release ou handoff num projeto Laravel Filament deste kit."
license: MIT
metadata:
  author: coringawc
  version: 2.0.0
  requires:
    - laravel-best-practices
    - pest-testing
    - spatie-laravel-php-standards
  related:
    - static-analysis-larastan-pint
    - pest-browser-test-filament-flow
    - ci-github-actions
---

# Verify Before Commit — Gate Local Manual

## Consistency First

Gate local final equivalente à CI. Executado manualmente via `vendor/bin/sail composer verify` — **sem hook git automático** (decisão fixada). O agente roda o comando, lê o resumo e só então decide se está pronto para commit/PR/release.

`composer verify` é o single entry-point definido em `composer.json` deste kit e encadeia, na ordem, Pint, Larastan, Pest Unit, Pest Feature, Pest Browser e `npm run build`. Cada etapa depende da anterior; falha em qualquer gate aborta a sequência (`composer` para no primeiro script com saída ≠ 0).

Comandos focados (rodar só o teste alterado, só Pint, só Larastan) pertencem ao ciclo de implementação. Esta skill cobre o fechamento. Não confie em "passou antes"; não pule browser ou build por parecerem lentos; não rode no host — sempre via Sail.

## Quick Reference

### Comando único

```bash
vendor/bin/sail composer verify
```

### Script `composer.json` (contrato canônico)

```json
"scripts": {
    "verify": [
        "@pint",
        "@stan",
        "@test:unit",
        "@test:feature",
        "@test:browser",
        "@build"
    ],
    "pint": "pint --dirty --format agent",
    "stan": "phpstan analyse",
    "test:unit": "@php artisan test --compact --testsuite=Unit",
    "test:feature": "@php artisan test --compact --testsuite=Feature",
    "test:browser": "@php artisan test --compact tests/Browser",
    "build": "npm run build"
}
```

`@pint`, `@stan`, etc. referenciam scripts irmãos. `composer` aborta no primeiro retorno ≠ 0. Browser e build entram no contrato porque ambos rodam na CI (`ci-github-actions`).

### Gates encadeados

| Gate | Script | Falha bloqueia |
| --- | --- | --- |
| Pint | `@pint` | qualquer erro de formato |
| Larastan | `@stan` | qualquer erro de análise estática |
| Pest Unit | `@test:unit` | qualquer teste vermelho |
| Pest Feature | `@test:feature` | qualquer teste vermelho |
| Pest Browser | `@test:browser` | qualquer teste vermelho ou setup quebrado |
| Vite build | `@build` | manifest inválido, asset faltando, erro de bundle |

### Coverage (opcional, fora do gate canônico)

```bash
vendor/bin/sail php vendor/bin/pest tests/Unit tests/Feature \
    --coverage --coverage-clover=coverage.xml
```

Roda só quando PCOV/Xdebug está disponível no container. Se driver faltar, registre erro exato e marque cobertura como indisponível — nunca declare cobertura verificada sem evidência.

## Workflow

### Passo 1 — Consultar docs versionadas

- [ ] Via Laravel Boost MCP `search-docs`: `composer scripts`, `artisan test compact`, `pint format agent`, `phpstan analyse`, `vite build`, com `packages: ['laravel/framework', 'pestphp/pest', 'laravel/pint', 'larastan/larastan']`. Sem MCP, use `composer.json`, `phpstan.neon`, `phpunit.xml` e docs oficiais.

### Passo 2 — Garantir que `composer verify` existe

- [ ] Confirmar que `composer.json` tem o script `verify` definido no contrato da Quick Reference. Se faltar, esta é a primeira correção antes de declarar gate.
- [ ] Confirmar via `vendor/bin/sail composer list --scripts | grep -E 'verify|pint|stan|test|build'`.

### Passo 3 — Registrar estado inicial

```bash
git status --short
{
    git diff --name-only --diff-filter=ACMRTUXB
    git diff --cached --name-only --diff-filter=ACMRTUXB
} | sort -u
```

A lista combinada vira referência para checar artifacts não versionados depois.

### Passo 4 — Rodar gate único

```bash
vendor/bin/sail composer verify
```

- [ ] Não rode os scripts individualmente neste passo; o ponto do gate é ter um único comando reproduzível idêntico ao da CI.
- [ ] Se Pint reformatar arquivos, revise o diff, re-stage o que faz parte da mudança e rode `composer verify` de novo do zero. Não tente "continuar do Larastan".
- [ ] Se um gate falhar, corrija a causa raiz e rode `composer verify` inteiro de novo. Não pule etapas já verdes — elas precisam continuar verdes no próximo run.

### Passo 5 — Decidir explicitamente sobre browser

Browser entra no gate sempre que **todas** as condições abaixo forem verdadeiras:

- `composer.json` contém `pestphp/pest-plugin-browser`.
- `package.json` contém `playwright`.
- `tests/Pest.php` configura `pest()->browser()`.
- `tests/Browser/` contém ao menos um `*Test.php`.

| Estado | Ação |
| --- | --- |
| Deps + suite presentes | gate roda normal via `@test:browser` |
| UI/Filament/Blade/JS mudou e suite falta | bloqueie como verificação incompleta e peça setup browser |
| Projeto já deveria ter suite browser e ela falta | reporte `BLOCKED`, não `N/A` |
| Pre-D5 explícito com aprovação de verificação parcial | reporte browser como `N/A`, nunca como `PASS` |
| Deps browser quebradas | reporte erro exato — não substitua por HTTP smoke |

### Passo 6 — Rodar diagnostics do editor quando disponível

- [ ] Arquivos PHP, Blade, Markdown e JSON tocados devem passar por `get_errors`/Problems panel quando a tool existir. Corrija diagnósticos do slice antes do resumo final.

### Passo 7 — Produzir resumo final com evidência

```text
Pint: PASS/FAIL
Larastan: PASS/FAIL
Pest Unit: PASS/FAIL
Pest Feature: PASS/FAIL
Pest Browser: PASS/FAIL/N/A/BLOCKED (motivo)
Vite build: PASS/FAIL/BLOCKED (motivo)
Coverage: arquivo→percentual, N/A, BLOCKED ou unavailable (driver)
Artifacts: limpo ou listar sobras
```

Só diga "pronto para commit" se todos os gates aplicáveis passaram **no mesmo run** de `composer verify` e coverage/artifacts foram reportados honestamente.

### Passo 8 — Conferir artifacts não versionados

```bash
git status --short -- coverage.xml \
    tests/Browser/Screenshots tests/Browser/Videos tests/Browser/Traces \
    public/build .phpunit.cache .phpunit.result.cache
```

Nenhum desses paths deve aparecer no resultado a menos que haja decisão explícita em contrário.

## Anti-Patterns

| Racionalização | Realidade |
| --- | --- |
| "Vou rodar Pint, Stan e testes separados." | Gate canônico é `composer verify` único; rodadas separadas escondem regressões entre etapas. |
| "Browser é lento, pulo dessa vez." | Se a suite existe ou UI mudou, browser é gate obrigatório. |
| "Sem frontend alterado, `npm run build` não precisa." | Build valida manifest/Vite/assets e fica no gate final mesmo. |
| "Crio um pre-commit hook que roda tudo." | Decisão do kit: gate é manual via `composer verify`. Hook automático fica fora deste contrato. |
| "Coverage driver faltou, marco como verificada." | Coverage indisponível ≠ coverage verde. Reporte indisponibilidade com erro exato. |
| "Pint mudou arquivos, sigo direto pro Larastan." | Reinicie `composer verify` — gates precisam estar todos verdes no mesmo run. |
| "Rodei no host porque é mais rápido." | Gate roda dentro do Sail, igual à CI. Host não conta como verificação. |

Red flags:

- Comando sem `vendor/bin/sail`.
- `composer verify` ausente do `composer.json` deste kit.
- Trocar Pest browser por HTTP smoke ou `curl`.
- Substituir Pest Unit+Feature por "só o teste alterado" no fechamento.
- Resumo final sem listar comandos e resultados.
- Afirmar que `get_errors` passou quando a tool não está disponível.
- Commitar `coverage.xml`, screenshots, traces, vídeos, `public/build` ou caches sem decisão explícita.

## Verification

- [ ] `.agents/skills/_helpers/verify-skill.sh .agents/skills/verify-before-commit/SKILL.md` retorna `OK`
- [ ] `git diff --check -- .agents/skills/verify-before-commit/SKILL.md` limpo
- [ ] `composer.json` define `verify`, `pint`, `stan`, `test:unit`, `test:feature`, `test:browser`, `build`
- [ ] `vendor/bin/sail composer verify` executa todos os gates aplicáveis e termina verde
- [ ] Resumo final produzido com PASS/FAIL/N/A/BLOCKED por gate
- [ ] `git status --short` revisado para artifacts gerados
- [ ] `git status --short -- coverage.xml tests/Browser/Screenshots tests/Browser/Videos tests/Browser/Traces public/build .phpunit.cache .phpunit.result.cache` não mostra artifact inesperado

## Related

- `static-analysis-larastan-pint` — detalha Pint/Larastan, baseline e stubs usados pelo gate.
- `pest-browser-test-filament-flow` — define setup e critérios do gate browser.
- `ci-github-actions` — workflow remoto que espelha `composer verify`.
