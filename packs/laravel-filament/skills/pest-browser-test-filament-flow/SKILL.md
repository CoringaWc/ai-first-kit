---
name: pest-browser-test-filament-flow
description: "Aplicar quando criar ou revisar testes Pest Browser para fluxos críticos Filament com login real, modais, Alpine, Livewire, asserts de console, JavaScript e acessibilidade."
license: MIT
metadata:
  author: coringawc
  version: 2.0.0
  requires:
    - laravel-best-practices
    - spatie-laravel-php-standards
  related:
    - npm-dep-install
    - composer-dep-install
    - testcase-modular
    - static-analysis-larastan-pint
    - verify-before-commit
---

# Pest Browser Test Filament Flow

## Consistency First

Fluxos críticos exigem teste de navegador real via `pestphp/pest-plugin-browser` (Pest 4). Não use Laravel Dusk, Playwright TS isolado, HTTP smoke ou Livewire unit test para validar Alpine, modais, dropdowns ou drag-and-drop. O fluxo canônico é `login → criar → editar → excluir` no Resource alvo, autenticando pelo formulário real.

Pest Browser roda dentro do container Sail `app`. O container já tem Node, libs do Chromium, `playwright` em `package.json` e browsers instalados via setup do projeto. Não suba container Playwright separado, não use servidor remoto e não defina `PW_TEST_CONNECT_WS_ENDPOINT`.

Login compartilhado vem do helper global `loginAsAdmin($page)` definido em `tests/Support/browser.php` (autoloadado via `composer.json` → `autoload-dev.files`). Use-o em todo browser test em vez de duplicar `fill('email')`/`fill('password')`. Para selectors, use `__('texto inglês')` no clique — a chave inglesa é estável no código e Laravel resolve para a tradução pt_BR em runtime.

Se `pestphp/pest-plugin-browser` não está em `composer.json` ou `playwright` não está em `package.json`, pare e peça aprovação antes de instalar dependências.

## Quick Reference

- Arquivo padrão: `tests/Browser/<Fluxo>Test.php`.
- Screenshots/traces: `tests/Browser/Screenshots/` em `.gitignore`.
- Suite `Browser` em `tests/Pest.php`: `pest()->extend(TestCase::class)->use(LazilyRefreshDatabase::class)->in('Browser')` + `pest()->browser()->inChrome()->timeout(10000)`.
- Helper global: `loginAsAdmin($page)` em `tests/Support/browser.php` — autoloadado via `composer.json` (`autoload-dev.files`). Cria `User::factory()->admin()->create()` e autentica via formulário real.
- Asserts obrigatórios por página: `assertNoConsoleLogs()`, `assertNoJavaScriptErrors()`, `assertNoAccessibilityIssues()`.
- Selectors de botão: `__('Sign in')`, `__('Create')`, `__('Save')`, `__('Delete')` — chave inglesa.
- Selectors de input: nome do campo (`fill('email', ...)`).
- Rodar: `vendor/bin/sail artisan test --compact tests/Browser/<Fluxo>Test.php`.
- Debug manual: `vendor/bin/sail php vendor/bin/pest tests/Browser/<Fluxo>Test.php --debug` ou `--headed` (nunca commitar `headed()` no config).

## Workflow

- [ ] Consultar docs via Laravel Boost `search-docs` com queries `pest browser testing`, `browser visit`, `assert no javascript errors`, `assert no accessibility issues` e `packages: ['pestphp/pest', 'filament/filament', 'laravel/framework']`. Se a tool não estiver exposta, registre o bloqueio e use docs oficiais.

- [ ] Preflight de ambiente antes de escrever o teste:

| Check | Ação |
| --- | --- |
| `composer.json` tem `pestphp/pest-plugin-browser` | continue; se faltar, peça aprovação |
| `package.json` tem `playwright` | continue; se faltar, peça aprovação |
| Browsers Chromium instalados no `app` | `vendor/bin/sail npx playwright install chromium` apenas em setup aprovado |
| `.gitignore` cobre `tests/Browser/Screenshots/` | adicione se faltar |
| `tests/Pest.php` tem suite `Browser` e `tests/Support/browser.php` tem helper `loginAsAdmin` | configure antes do primeiro browser test |

- [ ] Configurar suite `Browser` em `tests/Pest.php` e helper `loginAsAdmin()` em `tests/Support/browser.php` — uma única vez por projeto. Procedimento completo (config, helper, registro no `composer.json` `autoload-dev.files`): ver `rules/bootstrap.md`.

- [ ] Criar `tests/Browser/<Fluxo>Test.php`. Use o helper `loginAsAdmin($page)` no início e foque no fluxo:

```php
use App\Filament\Admin\Resources\Records\RecordResource;

use function Pest\Laravel\assertDatabaseHas;
use function Pest\Laravel\assertDatabaseMissing;

it('cria, edita e exclui um registro pelo painel admin', function (): void {
    $page = loginAsAdmin();

    $page->navigate(RecordResource::getUrl(panel: 'admin'))
        ->click(__('Create'))
        ->fill(__('Name'), 'Registro de teste')
        // Preencha todo campo obrigatório do Resource real antes de submeter.
        ->click(__('Create'))
        ->assertSee('Registro de teste')
        ->assertNoJavaScriptErrors()
        ->assertNoConsoleLogs()
        ->assertNoAccessibilityIssues();

    assertDatabaseHas('records', [
        'name' => 'Registro de teste',
    ]);

    $page->click(__('Edit'))
        ->fill(__('Name'), 'Registro editado')
        ->click(__('Save'))
        ->assertSee('Registro editado');

    assertDatabaseHas('records', [
        'name' => 'Registro editado',
    ]);

    $page->click(__('Delete'))
        ->click(__('Confirm'))
        ->assertDontSee('Registro editado')
        ->assertNoJavaScriptErrors()
        ->assertNoConsoleLogs()
        ->assertNoAccessibilityIssues();

    assertDatabaseMissing('records', [
        'name' => 'Registro editado',
    ]);
});
```

Troque `RecordResource`, tabela, factories e campos pelo Resource real. Para múltiplas linhas, escope por texto único da linha ou por `data-testid` adicionado via `extraAttributes()` no componente.

- [ ] Cobrir interações que só o browser prova:

| UI real | Como testar |
| --- | --- |
| Modal Filament | clique a ação, assert heading traduzido, preencha, confirme |
| Dropdown / user menu | clique menu, assert item visível, navegue |
| Repeater drag/reorder | use `drag()` e assert ordem persistida |
| Upload de arquivo | `attach()` com `Storage::fake()` quando aplicável |
| Alpine / Livewire reativo | assert texto/estado após ação sem chamar método Livewire direto |

- [ ] Rodar o teste alvo e os checks de PHP quando houver edição em arquivo PHP:

```bash
vendor/bin/sail artisan test --compact tests/Browser/<Fluxo>Test.php
vendor/bin/sail bin pint --dirty --format agent
vendor/bin/sail php vendor/bin/phpstan analyse tests/Browser/<Fluxo>Test.php
```

## Anti-Patterns

| Racionalização | Realidade |
| --- | --- |
| "Playwright TS é mais comum." | Pest Browser integra com factories, DB e asserts Laravel sem ponte. |
| "Vamos subir container Playwright separado." | O container `app` já roda Pest Browser; serviço extra é dívida. |
| "HTTP smoke já cobre." | HTTP não executa Alpine, Livewire, modal, dropdown nem drag. |
| "Login por `actingAs()` é mais rápido." | Fluxo crítico exige login real pelo formulário. |
| "Console log pequeno não importa." | Corrija a UI ou documente decisão; não remova `assertNoConsoleLogs()`. |
| "Texto traduzido vai quebrar." | A chave em `__()` é inglês; Laravel resolve para pt_BR em runtime. |

- Não criar browser test em `tests/Feature` quando o objetivo é navegador real.
- Não instalar dependências sem aprovação.
- Não usar `PW_TEST_CONNECT_WS_ENDPOINT`.
- Não commitar screenshots, vídeos ou traces — rode `git status --short` antes de finalizar.
- Não usar `wait(2)` como sincronização padrão; prefira assert visível ou ação que aguarde estado.
- Não omitir asserts de DB em create/edit/delete.
- Não esconder falha de acessibilidade ou JS com skip sem decisão registrada.
- Não duplicar fluxo de login em cada teste — use `loginAsAdmin($page)`.

Sinais de teste fraco: `visit('/admin')->assertSee(...)` único, ausência de `assertNoJavaScriptErrors()`, browser test com `actingAs()` substituindo login, novo serviço Docker Playwright, screenshots rastreados no Git, ou `tests/Pest.php` sem suite `Browser`.

## Verification

- [ ] `./.agents/skills/_helpers/verify-skill.sh .agents/skills/pest-browser-test-filament-flow/SKILL.md`
- [ ] `git diff --check -- .agents/skills/pest-browser-test-filament-flow/SKILL.md`
- [ ] Preflight: `composer.json` inclui `pestphp/pest-plugin-browser`; `package.json` inclui `playwright`; `.gitignore` ignora `tests/Browser/Screenshots/`.
- [ ] `tests/Pest.php` tem suite `Browser` e `pest()->browser()->inChrome()->timeout(10000)`; `tests/Support/browser.php` tem helper `loginAsAdmin()` registrado em `composer.json` (`autoload-dev.files`).
- [ ] Teste alvo: `vendor/bin/sail artisan test --compact tests/Browser/<Fluxo>Test.php`.
- [ ] PHP editado: `vendor/bin/sail bin pint --dirty --format agent` e Larastan no slice.
- [ ] Confirmar `assertNoConsoleLogs()`, `assertNoJavaScriptErrors()` e `assertNoAccessibilityIssues()` em cada página.
- [ ] Confirmar que create/edit/delete têm asserts de DB e que screenshots/artifacts não foram versionados.

## Related

- `rules/bootstrap.md` - Setup único de `tests/Pest.php` e `tests/Support/browser.php`.
- `npm-dep-install` - Instala Node, Playwright e Chromium no container `app`.
- `composer-dep-install` - Instala `pestphp/pest-plugin-browser` na stack canônica.
- `testcase-modular` - Helpers compartilhados como `loginAsAdmin($page)` em `tests/Support/browser.php`.
- `static-analysis-larastan-pint` - Rode Pint/Larastan depois de criar browser tests.
- `verify-before-commit` - Inclui browser tests no pipeline final antes de commit/release.
