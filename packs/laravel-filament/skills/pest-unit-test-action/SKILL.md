---
name: pest-unit-test-action
description: "Aplicar quando criar ou revisar testes Pest para actions em app/Actions com handle(), happy path, failure path e asserts de DB ou side effects."
license: MIT
metadata:
  author: coringawc
  version: 2.0.0
  requires:
    - laravel-best-practices
    - spatie-laravel-php-standards
  related:
    - action-class
    - composer-dep-install
    - static-analysis-larastan-pint
    - testcase-modular
---

# Pest Unit Test Action

## Consistency First

Toda action canônica do projeto usa `lorisleiva/laravel-actions` com a trait `AsAction` e expõe um único `handle()`. O teste deve invocar a action via API pública da biblioteca (`Action::run(...)` ou `Action::dispatch(...)`), nunca via `new Action()` ou `app(Action::class)->handle()`.

O nome da skill diz unit, mas neste repositório actions que tocam DB, storage, jobs ou eventos vivem em `tests/Feature/Actions/*ActionTest.php`. Use `tests/Unit/Actions/*Test.php` somente para action pura (sem DB, sem facade, sem container). Cobertura mínima por action: 1 happy path + 1 failure path com asserts de retorno e side effects.

Actions legadas que ainda exponham `create`/`update`/`archive` em vez de `handle()` devem ser testadas no método público real, sem refatorar escopo dentro desta skill — a migração para `AsAction` é responsabilidade da skill `action-class`.

## Quick Reference

- Criar teste: `vendor/bin/sail artisan make:test --pest Actions/<Domínio>/<Verbo><Substantivo>ActionTest --no-interaction`.
- Local padrão (DB/side effects): `tests/Feature/Actions/<Domínio>/<Verbo><Substantivo>ActionTest.php`.
- Local para action pura: `tests/Unit/Actions/<Domínio>/<Verbo><Substantivo>ActionTest.php`.
- Invocar action: `CreateProjectAction::run($actor, $payload)`; nunca `new CreateProjectAction()->handle(...)`.
- Invocar como job: `CreateProjectAction::dispatch($payload)` após `Queue::fake()` e assert `Queue::assertPushed(CreateProjectAction::class)`.
- Mínimo: 1 happy path + 1 failure path por action.
- Fakes antes do `run()`: `Queue::fake()`, `Event::fake()`, `Notification::fake()`, `Storage::fake()`, `Http::fake()`.
- Asserts de persistência: `assertDatabaseHas()` / `assertDatabaseMissing()` da Pest.
- Rodar alvo: `vendor/bin/sail artisan test --compact --filter=<Verbo><Substantivo>ActionTest`.

## Workflow

- [ ] Consultar docs versionadas via Laravel Boost `search-docs` com queries `laravel actions run`, `laravel testing queues`, `event fake`, `database assertions` e `packages: ['lorisleiva/laravel-actions', 'laravel/framework', 'pestphp/pest']`. Se a tool não estiver exposta, registre o bloqueio e siga padrão dos testes existentes em `tests/Feature/Actions/`.

- [ ] Ler a action e identificar contrato público:

| Forma da action | Como testar |
| --- | --- |
| `AsAction` canônica com `handle()` | invocar `Action::run(...)` |
| `AsAction` despachada como job | `Queue::fake()` antes; `Action::dispatch(...)` depois; `Queue::assertPushed()` |
| Action legada com `create`/`update`/`archive` | chamar o método público real até migração para `AsAction` |
| Orquestrador com dependências externas | mockar somente a dependência cara/instável |

- [ ] Escrever o happy path com factories pt_BR e asserts de retorno + persistência:

```php
use App\Actions\Projects\CreateCompanyProjectAction;
use App\Enums\CompanyProjectType;
use App\Models\Company;
use App\Models\CompanyProject;
use App\Models\User;

use function Pest\Laravel\assertDatabaseHas;

it('cria projeto da empresa autenticada', function (): void {
    $company = Company::factory()->create();
    $actor = User::factory()->for($company)->create();

    $project = CreateCompanyProjectAction::run($actor, [
        'title' => 'Serviço operacional',
        'project_type' => CompanyProjectType::Service,
        'execution_location' => 'Vila dos Remédios',
        'documents' => [],
    ]);

    expect($project)->toBeInstanceOf(CompanyProject::class)
        ->and($project->company_id)->toBe($company->getKey());

    assertDatabaseHas('company_projects', [
        'id' => $project->getKey(),
        'company_id' => $company->getKey(),
        'title' => 'Serviço operacional',
    ]);
});
```

- [ ] Escrever o failure path provando regra de domínio e ausência de side effect parcial:

```php
use Illuminate\Auth\Access\AuthorizationException;

it('bloqueia atualização de projeto de outra empresa', function (): void {
    $company = Company::factory()->create();
    $outraEmpresa = Company::factory()->create();
    $actor = User::factory()->for($company)->create();
    $project = CompanyProject::factory()->for($outraEmpresa)->create([
        'title' => 'Título original',
    ]);

    expect(fn () => UpdateCompanyProjectAction::run($actor, $project, [
        'title' => 'Tentativa bloqueada',
    ]))->toThrow(AuthorizationException::class);

    expect($project->refresh()->title)->toBe('Título original');
});
```

- [ ] Para action com jobs/eventos/storage, fake antes e assert depois:

```php
use App\Actions\MigratoryControl\CreateProcessIntakeBatchAction;
use App\Jobs\MigratoryControl\ProcessIntakeBatchJob;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Facades\Storage;

Queue::fake();
Storage::fake('local');

$batch = CreateProcessIntakeBatchAction::run($actor, $draft, $filePaths);

expect($batch->files)->toHaveCount(1);
Queue::assertPushed(ProcessIntakeBatchJob::class);
```

- [ ] Para action despachada como job (não invocada inline), use `dispatch`:

```php
Queue::fake();

SyncCompanyDocumentsAction::dispatch($company->getKey());

Queue::assertPushed(SyncCompanyDocumentsAction::class, function (SyncCompanyDocumentsAction $job) use ($company): bool {
    return $job->companyId === $company->getKey();
});
```

- [ ] Para dependência externa difícil de reproduzir, mocke pelo container:

```php
use App\Services\IntegracaoExterna;
use Mockery;

$dependencia = Mockery::mock(IntegracaoExterna::class);
$dependencia->shouldReceive('sincronizar')->once()->andThrow($excecaoIntegracao);

app()->instance(IntegracaoExterna::class, $dependencia);

expect(fn () => SyncWithExternalAction::run($payload))
    ->toThrow(DomainException::class);
```

Use subclasse anônima somente como último recurso para branch protegido sem dependência injetável, chamando o método público real e mantendo asserts de DB/retorno que provem comportamento de produção.

## Anti-Patterns

| Racionalização | Realidade |
| --- | --- |
| "Um happy path basta." | Mínimo é happy path + uma falha significativa com assert de estado. |
| "Unit test nunca toca DB." | Action com DB/queue/storage é feature test em `tests/Feature/Actions/`. |
| "Vou mockar tudo." | Mockar Eloquent/DB esconde constraints, transações e side effects que a action promete. |
| "Exception já basta." | A falha também deve provar que side effects parciais não ocorreram. |
| "`app(Action::class)->handle()` é igual." | Quebra contrato `AsAction`: a biblioteca decora `handle()` em runtime e a forma canônica é `::run()`/`::dispatch()`. |
| "Vou instanciar com `new`." | Bypassa container, eventos e decoradores da `AsAction`. |

- Não testar action pela UI Filament; cobertura de UI vive em `pest-feature-test-filament-resource`.
- Não chamar método legado errado só para encaixar `handle()`; teste a API pública existente.
- Não deixar job/event/http real disparar em teste — sempre fake antes.
- Não assertar apenas `not->toBeNull()` quando o contrato tem model/estado específico.
- Não capturar exception e continuar sem `toThrow()` ou assert equivalente.
- Não criar fixture manual quando factory/state cobre o caso.

Sinais de teste fraco: arquivo só com happy path, `Queue::assertPushed()` sem `Queue::fake()`, mock de Model/Eloquent sem motivo, action com side effects em `tests/Unit` sem isolamento, ou failure path sem assert de estado final.

## Verification

- [ ] `./.agents/skills/_helpers/verify-skill.sh .agents/skills/pest-unit-test-action/SKILL.md`
- [ ] `git diff --check -- .agents/skills/pest-unit-test-action/SKILL.md`
- [ ] Em teste criado/editado: `vendor/bin/sail bin pint --dirty --format agent`
- [ ] Rodar o teste alvo: `vendor/bin/sail artisan test --compact --filter=<Verbo><Substantivo>ActionTest`
- [ ] Confirmar invocação via `Action::run(...)` ou `Action::dispatch(...)`; nenhum `new Action()` nem `app(Action::class)->handle()`.
- [ ] Confirmar happy path + failure path com asserts de retorno e side effects.
- [ ] Confirmar fakes (`Queue`, `Event`, `Storage`, `Http`) antes da chamada à action.

## Related

- `action-class` - Define o contrato canônico `AsAction`/`handle()`.
- `composer-dep-install` - Instala `lorisleiva/laravel-actions` no Grupo 6.
- `static-analysis-larastan-pint` - Rode Pint/PHPStan após criar ou alterar testes/actions.
- `testcase-modular` - Extraia setup de action tests quando duplicar responsabilidades.
