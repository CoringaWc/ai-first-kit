---
name: testcase-modular
description: "Aplicar quando `tests/TestCase.php` começar a acumular helpers de auth, painel Filament, permissões, faker ou storage, ou quando o mesmo bloco de setup se repetir em três ou mais arquivos de teste."
license: MIT
metadata:
  author: coringawc
  version: 2.0.0
  requires:
    - laravel-best-practices
    - pest-testing
    - spatie-laravel-php-standards
  related:
    - pest-feature-test-filament-resource
    - pest-feature-test-livewire-page
    - pest-unit-test-action
    - pest-browser-test-filament-flow
    - verify-before-commit
---

# TestCase Modular — `tests/TestCase.php` Enxuto + Helpers Reutilizáveis

## Consistency First

Mantém `tests/TestCase.php` enxuto. Neste repo, `tests/TestCase.php` está reservado para invariantes globais inevitáveis (atualmente o guard de banco de teste isolado em `guardAgainstUnsafeTestingDatabase()`). Setup reutilizável vai para helpers funcionais em `tests/Support/*.php` (preferido) ou traits opt-in em `tests/Concerns/<Topic>.php` (somente quando o helper precisar de `setUp()` ou estado interno).

`tests/Pest.php` deve permanecer fino: `pest()->extend(TestCase::class)->use(LazilyRefreshDatabase::class)->in(...)` + `require_once` dos helpers em `tests/Support/`. Lógica concreta nunca mora em `tests/Pest.php`.

Extraia quando o setup tiver responsabilidade distinta e reutilizável, ou quando o mesmo bloco se repetir em 3+ arquivos. **Não extraia por estética após um único uso**; também não jogue tudo num helper genérico só porque é rápido.

Snippets detalhados de helpers, traits e registro estão em `rules/extraction-patterns.md`.

## Quick Reference

### Hierarquia de responsabilidades

| Local | Conteúdo |
| --- | --- |
| `tests/TestCase.php` | Bootstrap global e invariantes de segurança (guard de DB de teste). Nada mais. |
| `tests/Pest.php` | `extend(TestCase::class)`, `use(LazilyRefreshDatabase::class)`, `require_once` dos `tests/Support/*.php`. |
| `tests/Support/auth.php` | Helpers funcionais de autenticação (`loginAsAdmin`, `actingAsCompanyAdmin`). |
| `tests/Support/browser.php` | Helpers de browser tests Pest 4 (`loginAsAdmin($page)`, seletores `__('texto')`). |
| `tests/Support/faker.php` | Configuração `fake()` BR e provider custom se necessário. |
| `tests/Support/storage.php`, `tests/Support/queue.php` | Helpers de fakes Laravel reutilizáveis. |
| `tests/Concerns/<Topic>.php` | Trait opt-in quando o setup exige `setUp()` ou estado interno (raro). |

### Padrões

- Helper funcional em `tests/Support/*.php` usa funções no namespace `Tests\Support` e é importado via `use function Tests\Support\<helper>`.
- Trait em `tests/Concerns/<Topic>.php` usa método `protected` com retorno tipado, registrado por `uses(...)` em arquivo Pest ou em `tests/Pest.php` quando o escopo for global.
- Um helper por responsabilidade: auth, browser, panel, permissions, faker, storage, queue.
- Nomes canônicos de traits: `CreatesAuthenticatedUsers`, `RegistersTestPanels`, `SeedsDefaultPermissions`, `UsesBrazilianFaker`.
- Nomes canônicos de helpers funcionais: `loginAsAdmin()`, `actingAsCompanyAdmin()`, `setFilamentPanel()`.
- Limiar quantitativo: 3+ usos do mesmo bloco em arquivos distintos, ou responsabilidade clara já demandada por skill Pest.
- Concerns vão em `tests/Concerns/` (nunca em `app/Traits/` ou `tests/Support/Concerns/`).
- Browser tests usam seletores via `__('texto')` (D33), nunca strings hardcoded em pt_BR.
- Depois de extrair: Pint, PHPStan e os testes afetados.

## Workflow

### Passo 1 — Consultar docs versionadas

- [ ] Via Laravel Boost MCP `search-docs`: `pest uses traits`, `pest global helpers`, `laravel testing helpers`, `filament testing`, com `packages: ['pestphp/pest', 'laravel/framework', 'filament/filament']`. Sem MCP, use testes existentes do repo e docs oficiais.

### Passo 2 — Auditar `tests/TestCase.php`

- [ ] Antes de adicionar método novo, responda:

| Pergunta | Decisão |
| --- | --- |
| Vale para absolutamente todos os testes (ex.: guard de segurança)? | pode ficar em `TestCase` |
| É auth, panel, permissions, faker, queue, storage ou browser? | helper em `tests/Support/` |
| Mistura 2+ responsabilidades num único helper? | dividir em helpers separados |
| Precisa de estado interno ou `setUp()`? | trait em `tests/Concerns/` |
| `TestCase` já tem 3+ responsabilidades? | extrair antes de adicionar mais |

### Passo 3 — Inventariar duplicação

- [ ] Procurar blocos repetidos: `actingAs(...)`, `Filament::setCurrentPanel(...)`, seed de permissões, factories de usuário/painel, `Queue::fake()`, `Storage::fake()`, configuração de faker BR. Conte usos em arquivos distintos.

### Passo 4 — Criar helper funcional em `tests/Support/`

- [ ] Preferir helper funcional quando não precisar de estado. Snippet completo (auth + browser) em `rules/extraction-patterns.md`.

### Passo 5 — Registrar em `tests/Pest.php`

- [ ] Carregar helpers via `require_once`; eles continuam opt-in via `use function` em cada teste. Snippet em `rules/extraction-patterns.md`.

### Passo 6 — Usar nos testes

- [ ] Importar com `use function Tests\Support\loginAsAdmin;` no topo do arquivo de teste.

### Passo 7 — Trait apenas quando exige estado

- [ ] `tests/Concerns/<Topic>.php` com método `protected`. Snippet em `rules/extraction-patterns.md`.

### Passo 8 — Migrar duplicação sem esconder comportamento

- [ ] Tabela de migração antes/depois em `rules/extraction-patterns.md`. Nunca extraia se o teste perder clareza sobre qual guard, panel ou regra de autorização está em jogo.

### Passo 9 — Verificar slice alterado

```bash
vendor/bin/sail bin pint --dirty --format agent
vendor/bin/sail php -d sys_temp_dir=/var/www/html/storage/framework/cache/phpstan \
    vendor/bin/phpstan analyse tests/Support tests/Concerns tests/Feature tests/Unit
vendor/bin/sail artisan test --compact --filter=<AffectedTestOrConcernUsage>
```

## Anti-Patterns

| Racionalização | Realidade |
| --- | --- |
| "É só um helper rápido no TestCase." | Helper de auth+panel+permissions já mistura responsabilidades; extraia. |
| "Um trait `TestHelpers` resolve tudo." | God-trait repete o problema do TestCase gigante. Use um helper por responsabilidade. |
| "Vamos registrar todo helper globalmente." | Helpers globais escondem pré-condições do teste; prefira `use function` por arquivo. |
| "Duplicou duas linhas, extrai agora." | Extração cedo demais cria abstração errada; espere 3+ usos ou responsabilidade clara. |
| "Trait é mais idiomático que função." | Em Pest 4, helpers funcionais em `tests/Support/` são preferidos. Trait só quando precisar de `setUp()` ou estado. |
| "Vou guardar fixtures no `tests/Pest.php`." | `tests/Pest.php` é só configuração da suite. Fixtures e helpers vão para `tests/Support/`. |

Red flags:

- `TestCase.php` crescendo a cada nova suite.
- Helper chamado `setupEverything`, `bootstrapTest` ou similar.
- Trait com mais de uma família de responsabilidades.
- `uses(...)->in('Feature')` para helper que só um arquivo precisa.
- Teste que não mostra mais qual guard ou panel está em uso.
- `tests/Support/Concerns/` (path inexistente neste kit).
- Concerns em `app/Traits/` (concerns de teste ficam em `tests/Concerns/`).
- Browser test com seletor hardcoded em pt_BR em vez de `__('texto')`.

## Verification

- [ ] `.agents/skills/_helpers/verify-skill.sh .agents/skills/testcase-modular/SKILL.md` retorna `OK`
- [ ] `git diff --check -- .agents/skills/testcase-modular/SKILL.md` limpo
- [ ] PHP editado: `vendor/bin/sail bin pint --dirty --format agent` passa
- [ ] Larastan: `vendor/bin/sail php -d sys_temp_dir=/var/www/html/storage/framework/cache/phpstan vendor/bin/phpstan analyse tests/Support tests/Concerns tests/Feature tests/Unit` passa
- [ ] Testes afetados: `vendor/bin/sail artisan test --compact --filter=<AffectedTestOrConcernUsage>` passa
- [ ] `tests/TestCase.php` não ganhou responsabilidade que poderia ser helper/concern
- [ ] Cada helper em `tests/Support/` tem responsabilidade única e usos reais
- [ ] Cada trait em `tests/Concerns/` justifica `setUp()` ou estado interno

## Related

- `pest-feature-test-filament-resource` — invoca esta skill quando testes de Resource duplicarem auth/panel.
- `pest-feature-test-livewire-page` — invoca esta skill quando pages repetirem mount/auth/panel.
- `pest-unit-test-action` — invoca esta skill quando testes de Action repetirem fakes, fixtures ou actors.
- `pest-browser-test-filament-flow` — usa `loginAsAdmin($page)` de `tests/Support/browser.php`.
- `verify-before-commit` — gate final depois de refatorar `TestCase` ou helpers.
