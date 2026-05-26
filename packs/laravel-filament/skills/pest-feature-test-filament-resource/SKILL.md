---
name: pest-feature-test-filament-resource
description: "Aplicar quando criar ou revisar testes Pest de Resource Filament v5 com list, search, create, edit, validação e ações modais."
license: MIT
metadata:
  author: coringawc
  version: 2.0.0
  requires:
    - laravel-best-practices
    - spatie-laravel-php-standards
  related:
    - filament-resource-scaffold
    - filament-table-defaults
    - testcase-modular
---

# Pest Feature Test Filament Resource

## Consistency First

Cada Resource Filament tem um arquivo Pest único cobrindo listagem, busca, criação, edição e validação. Use factories pt_BR, autentique antes de montar qualquer Page Filament e selecione o panel correto explicitamente.

Teste a superfície real do Resource. Se existem `Create<Model>` e `Edit<Model>` pages, use `fillForm()->call('create')` e `fillForm()->call('save')`. Se o Resource cria/edita por actions modais na `List<Model>`, use `callAction()` com `CreateAction` e `TestAction::make('edit')->table($record)`.

Neste repositório, `composer.json` não inclui `pestphp/pest-plugin-livewire`. Use `Livewire\Features\SupportTesting\Testable::create()`, salvo se o projeto adotar e padronizar `Pest\Livewire\livewire()`.

## Quick Reference

- Criar teste: `vendor/bin/sail artisan make:test --pest <Modelo>ResourceTest --no-interaction`.
- Arquivo: `tests/Feature/<Modelo>ResourceTest.php`; um único arquivo por Resource.
- Database reset já vem de `tests/Pest.php` com `LazilyRefreshDatabase`.
- Auth painel app: `actingAs($user, 'web')` + `Filament::setCurrentPanel(Filament::getPanel('app'))`.
- Auth painel admin: `actingAs($admin, 'admin')` + `Filament::setCurrentPanel(Filament::getPanel('admin'))`.
- Helper local: `Testable::create(Page::class, $parameters)`.
- List: `assertOk()`, `assertCanSeeTableRecords([...])`, `assertCanNotSeeTableRecords([...])`.
- Search: `searchTable($record->name)` é obrigatório quando a table tem colunas pesquisáveis.
- Create page: `fillForm([...])->call('create')->assertNotified()->assertHasNoFormErrors()->assertRedirect()`.
- Create modal action: `callAction(CreateAction::class, [...])->assertHasNoFormErrors()`.
- Edit page: `Testable::create(EditModel::class, ['record' => $record->getRouteKey()])->fillForm([...])->call('save')`; não use `assertRedirect()`.
- Edit modal action: `callAction(TestAction::make('edit')->table($record), [...])->assertHasNoFormErrors()`.
- Delete page action: `callAction(DeleteAction::class)` na `Edit<Model>` (sem payload, com confirmação implícita do Filament). Para delete em tabela: `callAction(TestAction::make('delete')->table($record))`.
- Validation: payload inválido + `assertHasFormErrors(['campo' => 'required'])`.
- Helpers reutilizáveis (auth, fillForm canônico) ficam em `tests/Support/filament.php` autoloadado via `composer.json` `autoload-dev.files` (D38), nunca no `Pest.php`.

## Workflow

- [ ] Consultar docs via Laravel Boost `search-docs` com queries `test resource table`, `test form create`, `test edit resource`, `test table action`, `assertHasFormErrors` e `packages: ['filament/filament', 'pestphp/pest']`. Se a tool não estiver exposta, registre o bloqueio.

- [ ] Inspecionar Resource e Pages antes de escrever o teste. Use Grep para `class .*Resource|class List|class Create|class Edit|CreateAction::make|EditAction::make` em `app/Filament`.

- [ ] Criar usuário com factory e setar guard/painel antes de qualquer page:

```php
use App\Models\Company;
use App\Models\User;
use Filament\Facades\Filament;
use Illuminate\Contracts\Auth\Authenticatable;

use function Pest\Laravel\actingAs;

$company = Company::factory()->create();
$user = User::factory()->for($company)->create();

/** @var User&Authenticatable $authenticatedUser */
$authenticatedUser = $user;

actingAs($authenticatedUser, 'web');
Filament::setCurrentPanel(Filament::getPanel('app'));
```

- [ ] Testar listagem e escopo da tabela:

```php
use App\Filament\App\Resources\Projects\Pages\ListProjects;
use App\Models\CompanyProject;
use Livewire\Features\SupportTesting\Testable;

$projetoProprio = CompanyProject::factory()->for($company)->create();
$projetoOutro = CompanyProject::factory()->create();

$listProjects = Testable::create(ListProjects::class);

$listProjects
    ->assertOk()
    ->assertCanSeeTableRecords([$projetoProprio])
    ->assertCanNotSeeTableRecords([$projetoOutro]);
```

- [ ] Se a table tem search em coluna visível, testar busca. Se não tiver, registrar no teste por que essa capability não se aplica:

```php
$listProjects
    ->searchTable($projetoProprio->title)
    ->assertCanSeeTableRecords([$projetoProprio])
    ->assertCanNotSeeTableRecords([$projetoOutro]);
```

- [ ] Para Resource com Create/Edit pages, testar create, edit e validação no mesmo arquivo:

```php
use App\Filament\App\Resources\Projects\Pages\CreateProject;
use App\Filament\App\Resources\Projects\Pages\EditProject;

use function Pest\Laravel\assertDatabaseHas;

Testable::create(CreateProject::class)
    ->fillForm(['title' => 'Serviço operacional'])
    ->call('create')
    ->assertNotified()
    ->assertHasNoFormErrors()
    ->assertRedirect();

assertDatabaseHas('company_projects', ['title' => 'Serviço operacional']);

$project = CompanyProject::factory()->for($company)->create();

Testable::create(EditProject::class, ['record' => $project->getRouteKey()])
    ->fillForm(['title' => 'Serviço atualizado'])
    ->call('save')
    ->assertNotified()
    ->assertHasNoFormErrors();

assertDatabaseHas('company_projects', ['id' => $project->getKey(), 'title' => 'Serviço atualizado']);
```

- [ ] Para Resource modal-only, testar actions na List page em vez de inventar pages:

```php
use Filament\Actions\CreateAction;
use Filament\Actions\Testing\TestAction;

$project = CompanyProject::factory()->for($company)->create();

$listProjects
    ->callAction(CreateAction::class, ['title' => 'Serviço operacional'])
    ->assertHasNoFormErrors();

assertDatabaseHas('company_projects', [
    'company_id' => $company->getKey(),
    'title' => 'Serviço operacional',
]);

$listProjects
    ->callAction(TestAction::make('edit')->table($project), ['title' => 'Serviço atualizado'])
    ->assertHasNoFormErrors();

assertDatabaseHas('company_projects', [
    'id' => $project->getKey(),
    'title' => 'Serviço atualizado',
]);
```

- [ ] Testar validação com o menor payload inválido que prova a regra:

```php
Testable::create(CreateProject::class)
    ->fillForm(['title' => null])
    ->call('create')
    ->assertHasFormErrors(['title' => 'required']);
```

## Anti-Patterns

| Racionalização | Realidade |
| --- | --- |
| "Vou copiar `livewire()` da doc." | Confira `composer.json`; sem `pest-plugin-livewire`, use `Testable::create()`. |
| "Edit é parecido com create." | Edit page chama `save`, recebe `record` e não deve assertar redirect. |
| "Tem create/edit em modal, mas vou testar CreatePage." | Teste a superfície real: List page + actions modais. |
| "Listar já prova o Resource." | Exija list/search, create, edit e validation quando a capability existe. |

- Não montar Page Filament sem `actingAs()` e `Filament::setCurrentPanel()`.
- Não usar `call('create')` em Edit page.
- Não usar `assertRedirect()` depois de `call('save')` em Edit page.
- Não criar dados manualmente quando factory/state cobre o caso.
- Não testar apenas banco; também confira erros de form e records visíveis na table.
- Não quebrar o single-file-per-Resource; exceção exige decisão registrada no plano.
- Não usar namespace antigo de actions; v5 usa `Filament\Actions`.

Sinais de teste fraco: `Pest\Livewire\livewire` sem plugin instalado, page test sem panel setado, `assertRedirect()` em edit, `CreateResource` inexistente sendo testada, ou validação sem `assertHasFormErrors()`.

## Verification

- [ ] `./.agents/skills/_helpers/verify-skill.sh .agents/skills/pest-feature-test-filament-resource/SKILL.md`
- [ ] `git diff --check -- .agents/skills/pest-feature-test-filament-resource/SKILL.md`
- [ ] Em teste criado/editado: `vendor/bin/sail bin pint --dirty --format agent`
- [ ] Rodar o teste alvo: `vendor/bin/sail artisan test --compact --filter=<Modelo>ResourceTest`
- [ ] Confirmar que cada Resource testado autentica guard correto e seta panel correto.
- [ ] Confirmar que create/edit usam page ou modal action conforme o Resource real.
- [ ] Confirmar cobertura de list/search/create/edit/validation ou justificar capability ausente no próprio teste.

## Related

- `filament-resource-scaffold` - Define Pages e actions que o teste cobre.
- `filament-table-defaults` - Search, filtros e sort guiam asserts de list/search.
- `pest-feature-test-livewire-page` - Para Page Livewire/Filament custom fora de Resource CRUD.
- `testcase-modular` - Extraia concerns quando auth/panel setup duplicar em vários Resource tests.
