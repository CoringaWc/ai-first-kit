# asController() — Action como HTTP endpoint

A trait `AsAction` permite que a mesma classe sirva HTTP requests sem criar Controller separado.

## Uso básico

```php
<?php

declare(strict_types=1);

namespace App\Actions\Project;

use App\Models\Project;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Lorisleiva\Actions\ActionRequest;
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
        return DB::transaction(fn (): Project => Project::query()->create([
            'company_id' => $actor->company_id,
            'name' => $data['name'],
        ])->refresh());
    }

    /**
     * @return array<string, array<int, string>>
     */
    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
        ];
    }

    public function authorize(ActionRequest $request): bool
    {
        return $request->user()?->can('create', Project::class) ?? false;
    }

    public function asController(ActionRequest $request): JsonResponse
    {
        $project = $this->handle($request->user(), $request->validated());

        return response()->json($project, 201);
    }
}
```

## Rotas

```php
use App\Actions\Project\CreateProjectAction;

Route::post('/projects', CreateProjectAction::class);
```

A action vira automaticamente um invokable controller. Não precisa criar Controller separado.

## jsonResponse() / htmlResponse()

Alternativas a `asController()` quando a action retorna model/DTO e o response varia por content negotiation:

```php
public function jsonResponse(Project $project, ActionRequest $request): JsonResponse
{
    return response()->json($project, 201);
}

public function htmlResponse(Project $project, ActionRequest $request): RedirectResponse
{
    return redirect()->route('projects.show', $project)
        ->with('success', __('Project created.'));
}
```

## Anti-Patterns

- Não duplicar `rules()` em FormRequest + action. Action vira fonte única de validação HTTP.
- Não passar `Request` para `handle()`. `asController()` extrai dados validados antes.
- Não usar `asController()` quando a action só serve UI Filament. Filament chama `Action::run(...)` direto.
- Não retornar `view()` de `asController()` em fluxo SPA Filament.

## Verification

- [ ] `rules()` definido cobre os campos esperados.
- [ ] `authorize()` retorna `bool` baseado em policy.
- [ ] Rota usa `Action::class` como invokable, não método nomeado.
- [ ] `handle()` recebe dados primitivos, não `Request`.
