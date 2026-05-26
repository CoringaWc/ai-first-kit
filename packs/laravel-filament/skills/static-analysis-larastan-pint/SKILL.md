---
name: static-analysis-larastan-pint
description: "Aplicar quando houver código PHP ou Blade tocado em qualquer arquivo dentro de `app/`, `config/`, `database/factories/`, `routes/` ou `tests/`, antes de concluir uma alteração."
license: MIT
metadata:
  author: coringawc
  version: 2.0.0
  requires:
    - laravel-best-practices
    - spatie-laravel-php-standards
  related:
    - verify-before-commit
    - pest-feature-test-filament-resource
    - pest-feature-test-livewire-page
    - pest-unit-test-action
---

# Static Analysis — Larastan + Pint

## Consistency First

Verificação estática local é obrigatória para qualquer código PHP ou Blade gerado ou editado neste repo. Rode tudo via Sail, formate com Pint em modo fix e valide tipos com Larastan/PHPStan respeitando `phpstan.neon` e `phpstan-baseline.neon` exatamente como estão no repositório.

Leia `phpstan.neon` antes de decidir o escopo da análise — ele é a fonte canônica do contrato estático. **Não adicione erro novo ao baseline para "fazer passar"**; o baseline só representa dívida explicitamente aceita.

Esta skill cobre estilo e tipos estáticos. Ela **não substitui** Pest nem browser tests; depois da análise estática, rode o teste funcional focado pela skill Pest correspondente ou o pipeline completo via `verify-before-commit`.

## Quick Reference

### Contrato canônico do repo

`pint.json`:

```json
{
    "preset": "laravel",
    "rules": {
        "phpdoc_types": false
    }
}
```

`phpstan.neon` (contrato estático imutável sem ADR):

```neon
includes:
    - vendor/larastan/larastan/extension.neon
    - vendor/nesbot/carbon/extension.neon
    - phpstan-baseline.neon

parameters:
    paths:
        - app/
        - config/
        - database/factories/
        - routes/
        - tests/

    scanFiles:
        - phpstan-ide-helper-mixins.php

    level: 8
    treatPhpDocTypesAsCertain: false

    noEnvCallsOutsideOfConfig: true
    checkConfigTypes: true
    databaseMigrationsPath:
        - database/migrations
    configDirectories:
        - config
    viewDirectories:
        - resources/views
    translationDirectories:
        - lang
```

`phpstan-baseline.neon` **deve permanecer vazio** (`parameters.ignoreErrors: []`) — qualquer adição exige decisão registrada.

### Comandos

- Pint local (auto-fix): `vendor/bin/sail composer pint`
- Pint check-only (CI/gate): `vendor/bin/sail composer pint -- --test --format agent`
- PHPStan full: `vendor/bin/sail composer stan`
- PHPStan slice com cache no projeto: `vendor/bin/sail php -d sys_temp_dir=/var/www/html/storage/framework/cache/phpstan vendor/bin/phpstan analyse app/<slice> tests/<related>.php`
- Gate consolidado (Pint test + Stan + Pest unit/feature + browser): `vendor/bin/sail composer verify`

### Regras de escopo

- **Slice seguro**: arquivos tocados + dependentes diretos (ex.: Model + Resource + teste).
- **Full obrigatório**: mudanças em `config/`, providers, helpers, traits, base classes, factories compartilhadas, mais de 5 arquivos PHP tocados, antes de concluir feature ampla, ou quando o slice falhar por autoload/dependência.
- Erro em arquivo tocado ou dependente direto → corrija antes de finalizar.
- Erro fora do escopo → reporte como residual só depois de confirmar que não foi causado pela mudança.
- Stubs/helpers desatualizados → rode `ide-helper:generate` e `ide-helper:models` antes de criar workaround.

## Workflow

### Passo 1 — Consultar docs versionadas

- [ ] Via Laravel Boost MCP `search-docs` com queries: `pint format`, `phpstan larastan`, `static analysis` e `packages: ['laravel/pint', 'larastan/larastan', 'laravel/framework']`. Sem MCP, use `phpstan.neon`, `AGENTS.md`, vendor e docs oficiais.

### Passo 2 — Classificar escopo

- [ ] Identificar arquivos tocados e mapear para escopo mínimo:

| Mudança | Escopo mínimo |
| --- | --- |
| Action, Policy, Resource, Page, Schema ou Component | arquivo PHP + testes relacionados |
| Model, cast, enum, factory, seeder ou migration | model/factory/migration + testes e consumidores diretos |
| `config/`, provider, helper, trait ou base class | **full** `phpstan analyse` |
| Apenas Markdown/JSON sem PHP | Pint/PHPStan não exigidos; rode validações de skill/diff se aplicável |

### Passo 3 — Rodar Pint antes de PHPStan

- [ ] Sempre Pint primeiro (pode alterar imports, spacing ou PHPDoc que PHPStan reanalisaria):

```bash
vendor/bin/sail composer pint
```

### Passo 4 — Rodar Larastan/PHPStan

- [ ] Slice quando aplicável:

```bash
vendor/bin/sail php -d sys_temp_dir=/var/www/html/storage/framework/cache/phpstan \
    vendor/bin/phpstan analyse app/<slice> tests/<related-test>.php
```

- [ ] Full quando o escopo exige (ver regras acima):

```bash
vendor/bin/sail composer stan
```

### Passo 5 — Regenerar IDE Helper se stubs estiverem stale

- [ ] Quando PHPStan apontar propriedade dinâmica, relation, factory, mixin ou helper que parece existir no app, regenere antes de mudar o código de domínio:

```bash
vendor/bin/sail artisan ide-helper:generate --no-interaction
vendor/bin/sail artisan ide-helper:models --nowrite --no-interaction
vendor/bin/sail php -d sys_temp_dir=/var/www/html/storage/framework/cache/phpstan \
    vendor/bin/phpstan analyse <slice>
```

Se IDE Helper alterar arquivos gerados, revise o diff antes de continuar.

### Passo 6 — Tratar falhas por ordem

| Falha | Ação |
| --- | --- |
| Pint alterou arquivos | revise diff e siga para PHPStan |
| PHPStan em arquivo tocado | corrija o tipo, PHPDoc, generics ou API chamada |
| PHPStan em dependente direto da mudança | corrija junto; faz parte do slice |
| PHPStan por stub/helper stale | regenere IDE Helper e reexecute antes de workaround |
| PHPStan fora do escopo | não baselineie; registre residual com caminho/linha |

### Passo 7 — Diagnostics do editor

- [ ] Quando `get_errors` ou diagnostics estiver disponível, rode nos arquivos PHP, Blade, Markdown ou JSON tocados e trate diagnósticos claros do slice antes de concluir.

## Anti-Patterns

| Racionalização | Realidade |
| --- | --- |
| "Vou usar `pint --test` no fluxo local para economizar." | O fluxo local exige `composer pint` (auto-fix `--dirty --format agent`). `--test` é para CI/gate sem auto-fix. |
| "PHPStan no host é mais rápido." | Este projeto roda comandos operacionais pelo Sail; host pode ter PHP, extensões ou config divergentes. |
| "Erro novo? Joga no baseline." | Baseline não é lixeira; erro novo no slice deve ser corrigido. Baseline vazio é o contrato. |
| "Rodar só o teste Pest já basta." | Pest prova comportamento; análise estática prova estilo e tipos. Ambos podem ser necessários. |
| "Vou baixar o `level` ou virar `treatPhpDocTypesAsCertain` pra true." | `level: 8` + `treatPhpDocTypesAsCertain: false` é o contrato. Mudança exige ADR aprovado, não edição pontual para passar. |
| "`env()` no service é mais fácil que `config()`." | `noEnvCallsOutsideOfConfig: true` proíbe `env()` fora de `config/`. Use `config(...)` e cache de config em produção. |

Red flags:

- Comando sem `vendor/bin/sail` em fluxo local.
- Pint com `--test` no loop de desenvolvimento.
- Baseline editado para esconder erro novo.
- PHPStan ignorado porque Pest passou.
- Slice que exclui arquivo tocado.
- Workaround com `mixed`, `@phpstan-ignore-next-line` ou casts amplos sem explicar a invariante real.
- Mudar `phpstan.neon` ou `pint.json` para silenciar erro pontual.

## Verification

- [ ] `.agents/skills/_helpers/verify-skill.sh .agents/skills/static-analysis-larastan-pint/SKILL.md` retorna `OK`
- [ ] `git diff --check -- .agents/skills/static-analysis-larastan-pint/SKILL.md` limpo
- [ ] Em PHP/Blade editado: `vendor/bin/sail composer pint` rodado sem erros remanescentes
- [ ] Em PHP editado: `vendor/bin/sail php -d sys_temp_dir=/var/www/html/storage/framework/cache/phpstan vendor/bin/phpstan analyse <slice>` ou `vendor/bin/sail composer stan` passa
- [ ] `phpstan.neon` e `pint.json` inalterados (a menos que a tarefa seja explicitamente alterar contrato estático com ADR)
- [ ] `phpstan-baseline.neon` permanece vazio
- [ ] Erros do slice alterado foram **corrigidos**, não apenas reportados

## Related

- `verify-before-commit` — pipeline completo (Pint, Larastan, Pest, browser e build) antes de commit/release.
- `pest-feature-test-filament-resource` — testes funcionais de Resource Filament após análise estática.
- `pest-feature-test-livewire-page` — testes funcionais de Page Livewire/Filament após análise estática.
- `pest-unit-test-action` — testes unitários de Actions após análise estática.
