---
name: action-class
description: "Aplicar quando extrair regra de negócio Laravel para app/Actions."
license: MIT
metadata:
  author: coringawc
  version: 2.0.0
  requires:
    - laravel-best-practices
    - spatie-laravel-php-standards
  related:
    - translation
    - model-with-factory-and-seeder
    - pest-unit-test-action
    - filament-action-with-modal-heading
---

# Action Class

## Consistency First

Toda action deste kit usa **`lorisleiva/laravel-actions`** com a trait `AsAction` e representa um único caso de uso com método `handle()` tipado. Camadas adicionais (controller, job, listener, command) são opt-in via traits da própria biblioteca, sem duplicar lógica.

Não adicione método novo em manager class legada com vários verbos. Comportamento novo vira action nova.

Densidade extra mora em `rules/`:

- `rules/as-controller.md` — `asController()`, `rules()`, `authorize()`, `jsonResponse()`, `htmlResponse()`.
- `rules/as-job.md` — `asJob()`, `getJobConnection()`, `getJobQueue()`, `getJobTries()`, `getJobMiddleware()`.
- `rules/as-listener.md` — `asListener()`, mapping de evento para parâmetros.
- `rules/as-command.md` — `asCommand()`, signature, output, scheduling.

## Quick Reference

- Pacote: `lorisleiva/laravel-actions` (instalado via `composer-dep-install` Grupo 6).
- Trait base: `Lorisleiva\Actions\Concerns\AsAction`.
- Path: `app/Actions/<Domain>/<Verb><Subject>Action.php`.
- Convenção: classe `final`, sufixo `Action`, um único método público `handle()` com parâmetros e retorno tipados.
- Retorno: model, DTO ou valor de domínio. Não retornar `bool` genérico para mutações.
- Falhas: `ValidationException`, `AuthorizationException`, exception de domínio.
- Invocação: `CreateProjectAction::run($actor, $data)` ou `CreateProjectAction::make()->handle($actor, $data)`.
- Camadas adicionais via traits opt-in: `asController()`, `asJob()`, `asListener()`, `asCommand()` — só implementar quando o caso de uso real exigir.

## Workflow

- [ ] Criar a classe:

```bash
vendor/bin/sail artisan make:class "Actions/Project/CreateProjectAction" --no-interaction
```

- [ ] Escrever action single-purpose com `AsAction`:

```php
<?php

declare(strict_types=1);

namespace App\Actions\Project;

use App\Models\Project;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Lorisleiva\Actions\Concerns\AsAction;

final class CreateProjectAction
{
    use AsAction;

    /**
     * @param  array<string, mixed>  $data
     *
     * @throws ValidationException
     */
    public function handle(User $actor, array $data): Project
    {
        $name = trim((string) ($data['name'] ?? ''));

        if ($name === '') {
            throw ValidationException::withMessages([
                'name' => __('The project name is required.'),
            ]);
        }

        return DB::transaction(function () use ($actor, $name): Project {
            return Project::query()->create([
                'company_id' => $actor->company_id,
                'name' => $name,
            ])->refresh();
        });
    }
}
```

- [ ] Invocar a partir de Filament/Resource:

```php
use App\Actions\Project\CreateProjectAction;

$project = CreateProjectAction::run($actor, $data);
```

- [ ] Autorização antes de mutar:

```php
use Illuminate\Auth\Access\AuthorizationException;

if (! $actor->can('create', Project::class)) {
    throw new AuthorizationException(__('You are not allowed to create projects.'));
}
```

- [ ] Usar `DB::transaction()` apenas para múltiplas mutações dependentes, locks ou invariantes entre registros.

- [ ] Para virar HTTP endpoint, adicionar `asController()` — ver `rules/as-controller.md`.

- [ ] Para despachar como job, usar `CreateProjectAction::dispatch($actor, $data)` — ver `rules/as-job.md`.

- [ ] Para reagir a evento, adicionar `asListener()` — ver `rules/as-listener.md`.

- [ ] Para expor como artisan command, adicionar `asCommand()` — ver `rules/as-command.md`.

- [ ] Criar teste com `pest-unit-test-action` no mesmo ciclo.

## Anti-Patterns

- Não colocar regra de negócio grande dentro de closure de Filament Action ou Resource Page; extraia para action e chame `Action::run(...)`.
- Não criar action nova em `app/Services`, `app/UseCases` ou pasta plana. Greenfield padroniza `app/Actions/<Domain>/`.
- Não importar traits Filament/UI em action. Action é camada de domínio.
- Não engolir exceções nem converter falha em `false`/`null`; UI/teste precisa do motivo real.
- Não adicionar `asController()`/`asJob()`/`asListener()` "preventivamente" — só quando o caso de uso real demanda.
- Não chamar `handle()` direto via `new CreateProjectAction()->handle(...)`. Use `CreateProjectAction::run(...)` ou `::make()->handle(...)`.
- Não passar Request inteiro como argumento de `handle()`; extraia dados primitivos antes (a trait `asController()` cuida do mapping HTTP→handle).
- Não criar manager class com múltiplos verbos. Comportamento novo vira action nova.

## Verification

- [ ] `./.agents/skills/_helpers/verify-skill.sh .agents/skills/action-class/SKILL.md`
- [ ] `git diff --check -- .agents/skills/action-class/SKILL.md`
- [ ] `vendor/bin/sail bin pint --dirty --format agent`
- [ ] `vendor/bin/sail bin phpstan analyse`
- [ ] `vendor/bin/sail artisan test --compact --filter=Action`
- [ ] Conferir que a classe tem `use AsAction;` e um único método público `handle()` tipado.
- [ ] Conferir invocação via `Action::run(...)` ou `::dispatch(...)`, nunca `new Action()->handle(...)`.
- [ ] Conferir ausência de traits Filament/UI na action.

## Related

- `translation` — mensagens de validação/autorização lançadas pela action usam chave-frase em inglês via `__()`.
- `model-with-factory-and-seeder` — model retornado pela action precisa de factory/casts coerentes para testar.
- `pest-unit-test-action` — cobre happy path e falha principal de cada action.
- `filament-action-with-modal-heading` — UI Filament chama `Action::run(...)`, não carrega regra de negócio.
