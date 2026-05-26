---
name: pest-feature-test-livewire-page
description: "Aplicar quando criar ou revisar testes Pest para página Livewire 4 ou Filament Page com mount, route params, métodos públicos, estado aninhado, asserts e fakes."
license: MIT
metadata:
  author: coringawc
  version: 2.0.0
  requires:
    - laravel-best-practices
    - spatie-laravel-php-standards
  related:
    - filament-page-with-inline-blade
    - pest-feature-test-filament-resource
    - testcase-modular
---

# Pest Feature Test Livewire Page

## Consistency First

Este teste cobre comportamento de páginas Livewire 4 e Filament Pages, não apenas se a rota abre. Cubra mount/autorização, estado inicial, métodos públicos, eventos Livewire e side effects persistidos.

Escolha o test helper pela superfície real. Use `Livewire::test()` para componentes/pages sem parâmetros de rota complexos. Use `Livewire\Features\SupportTesting\Testable::create()` quando a page Filament precisa de parâmetros de rota, schema/action helpers ou já segue esse padrão no repo.

Eventos Livewire não são eventos Laravel. Use `assertDispatched()` para eventos do componente; use `Event::fake()`/`Event::assertDispatched()` somente para eventos Laravel reais.

Se o fluxo testado for CRUD de Resource Filament, esta não é a skill correta — use `pest-feature-test-filament-resource`.

## Quick Reference

- Arquivo: `tests/Feature/<PageName>Test.php`; agrupe mount, methods, events e authorization da mesma page.
- Sempre autenticar antes da page protegida: `actingAs(User::factory()->create())`, ou `actingAs($user, 'web')` quando precisar de guard/escopo específico.
- Page Filament app: `Filament::setCurrentPanel(Filament::getPanel('app'))`; admin: panel `admin`.
- HTTP smoke com Vite: `withoutVite(); get(Page::getUrl(panel: 'app'))->assertOk()`.
- Plain Livewire: `Livewire::test(Page::class)->set(...)->call(...)->assertSet(...)`.
- Filament page com params: `Testable::create(Page::class, ['record' => $model->getKey()])`.
- Método público: `->set('formData.field', 'value')->call('save')->assertHasNoErrors()`.
- Estado aninhado: use o `statePath()` real, como `addressDetailsData.postal_code`.
- Livewire event: `->call('next')->assertDispatched('next-wizard-step')` ou callback para params.
- Livewire dispatches agregados: prefira `assertDispatched()`; se precisar contar/inspecionar payloads, leia `data_get($testable->effects, 'dispatches', [])`.
- Laravel dispatched events agregados: depois de `Event::fake()`, use `Event::dispatchedEvents()` quando quantidade/lista de eventos importar.
- Laravel side effects: fake antes da ação: `Queue::fake()`, `Event::fake()`, `Storage::fake()`, `Http::fake()`.
- Persistência: depois de `call()`, use `assertDatabaseHas()` ou `expect($model->refresh()->field)`.

## Workflow

- [ ] Consultar docs via Laravel Boost `search-docs`: queries `livewire test component`, `assert dispatched`, `set component state`, `filament page test`, com `packages: ['livewire/livewire', 'filament/filament', 'pestphp/pest']`. Se a tool não estiver exposta, registre o bloqueio.

- [ ] Identificar a page e seu modo de mount:

| Tipo de page | Helper padrão | O que testar |
| --- | --- | --- |
| Livewire simples ou Filament page sem params | `Livewire::test()` | state, methods, validation, redirects |
| Filament page com `record`, `draft`, nested resource ou schema complexo | `Testable::create()` | mount params, schema state, methods, actions |
| Apenas renderização/autorização visual | HTTP `get()` complementar | `assertOk`, `assertForbidden`, textos visíveis |

- [ ] Montar usuário, escopo e panel antes de chamar a page:

```php
use App\Models\Company;
use App\Models\User;
use Filament\Facades\Filament;
use Illuminate\Contracts\Auth\Authenticatable;

use function Pest\Laravel\actingAs;

$company = Company::factory()->create();
$user = User::factory()->companyAdmin()->for($company)->create();

/** @var User&Authenticatable $authenticatedUser */
$authenticatedUser = $user;

actingAs($authenticatedUser, 'web');
Filament::setCurrentPanel(Filament::getPanel('app'));
```

- [ ] Para page sem params complexos, testar método público e persistência:

```php
use App\Filament\App\Pages\CompanyProfile;
use Livewire\Livewire;

Livewire::test(CompanyProfile::class)
    ->set('companyDetailsData.legal_name', 'Empresa Atualizada LTDA')
    ->call('saveCompanyDetails')
    ->assertHasNoErrors();

expect($company->refresh()->legal_name)->toBe('Empresa Atualizada LTDA');
```

- [ ] Para page com route params, passar todos os parâmetros exigidos por `mount()`:

```php
use App\Filament\App\Resources\Projects\Pages\StartProjectMigratoryProcess;
use Livewire\Features\SupportTesting\Testable;

$page = Testable::create(StartProjectMigratoryProcess::class, [
    'record' => $project->getKey(),
    'draft' => $draft->getKey(),
]);

$page
    ->set('stepOneData.raw_documents', ['upload-front' => $frontPath])
    ->call('submitStepOne')
    ->assertHasNoErrors();
```

- [ ] Testar eventos Livewire com `assertDispatched()` no próprio testable:

```php
$page
    ->call('goToNextStep')
    ->assertDispatched('next-wizard-step');

$dispatches = data_get($page->effects, 'dispatches', []);

expect($dispatches)->toHaveCount(1);
```

- [ ] Testar eventos/jobs externos com fakes Laravel antes da ação:

```php
use App\Jobs\MigratoryControl\ProcessIntakeBatchJob;
use Illuminate\Support\Facades\Queue;

use function Pest\Laravel\assertDatabaseHas;

Queue::fake();

$page->call('submitStepOne')->assertHasNoErrors();

Queue::assertPushed(ProcessIntakeBatchJob::class);
assertDatabaseHas('process_intake_batches', [
    'company_id' => $company->getKey(),
]);
```

- [ ] Cobrir acesso negado quando a page tem `canAccess()` ou abort em `mount()`:

```php
use function Pest\Laravel\get;
use function Pest\Laravel\withoutVite;

withoutVite();

get(CompanyProfile::getUrl(panel: 'app'))->assertForbidden();
```

## Anti-Patterns

| Racionalização | Realidade |
| --- | --- |
| "HTTP get renderizou, então está testado." | HTTP smoke não cobre métodos públicos, estado aninhado nem eventos Livewire. |
| "Todo evento usa `Event::assertDispatched`." | Eventos Livewire usam `assertDispatched()` no testable; eventos Laravel usam `Event::assertDispatched()`. |
| "Posso montar sem params e setar depois." | Se `mount()` exige `record`/`draft`, passe params reais na criação do testable. |
| "Side effect pequeno não precisa fake." | Queue, Storage, Event e Http devem ser fakeados antes do método público. |

- Não testar page protegida sem `actingAs()` e panel correto.
- Não chamar método público sem assert de erro, estado, banco ou evento observável.
- Não usar caminhos de estado inventados; leia o `statePath()` real da page/schema.
- Não confundir `assertDispatched()` Livewire com `Event::assertDispatched()` Laravel.
- Não chamar `dispatchedEvents()` em testable Livewire; esse helper é do fake de eventos Laravel.
- Não deixar teste de autorização apenas em nível de componente quando a regra real é rota/panel.
- Não cobrir CRUD de Resource aqui; isso pertence a `pest-feature-test-filament-resource`.

Sinais de teste fraco: teste só com `get()`, `Livewire::test(Page::class)` sem params obrigatórios, `Event::fake()` para evento browser, queue real disparada em teste, ou `set('data...')` sem conferir o state path da page.

## Verification

- [ ] `./.agents/skills/_helpers/verify-skill.sh .agents/skills/pest-feature-test-livewire-page/SKILL.md`
- [ ] `git diff --check -- .agents/skills/pest-feature-test-livewire-page/SKILL.md`
- [ ] Em teste criado/editado: `vendor/bin/sail composer pint`
- [ ] Rodar o teste alvo: `vendor/bin/sail artisan test --compact --filter=<PageName>Test`
- [ ] Confirmar cobertura de mount/autorização, método público, estado, evento Livewire e side effect persistido quando existirem.
- [ ] Quando o comportamento depender da quantidade/lista de eventos, conferir `data_get($testable->effects, 'dispatches', [])` para Livewire ou `Event::dispatchedEvents()` para eventos Laravel fakeados.
- [ ] Confirmar que fakes de Queue/Event/Storage/Http são chamados antes do método que dispara side effects.

## Related

- `filament-page-with-inline-blade` - Pages Filament custom com markup inline precisam de teste por esta skill.
- `pest-feature-test-filament-resource` - Use para CRUD de Resource, table e actions.
- `testcase-modular` - Extraia setup de auth/panel quando duplicar em várias page tests.
