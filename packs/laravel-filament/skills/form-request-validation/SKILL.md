---
name: form-request-validation
description: "Aplicar quando criar endpoint HTTP de domínio fora do painel Filament."
license: MIT
metadata:
  author: coringawc
  version: 2.0.0
  requires:
    - laravel-best-practices
    - spatie-laravel-php-standards
  related:
    - action-class
    - translation
    - filament-schema-class
---

# Form Request Validation

## Consistency First

FormRequest é sob demanda. Dentro do painel Filament, validação vive no Schema (`->required()`, `->unique()`, `->rules()`). Para endpoint HTTP de domínio, o caminho preferido é **action invocável** via `lorisleiva/laravel-actions` com `asController()` + `rules()` — ver `action-class/rules/as-controller.md`.

FormRequest separado só vale a pena quando:

- A mesma validação precisa ser reutilizada por múltiplos controllers/actions sem `AsAction`.
- O time decidiu organizar regras de payload HTTP fora da action por razão de leitura.
- Existe legado HTTP que já usa o padrão FormRequest e o novo endpoint deve seguir o mesmo estilo.

Sem nenhum desses motivos, prefira `asController()` na action.

## Quick Reference

- Criar: `vendor/bin/sail artisan make:request <Domain>/<Verb><Subject>Request --no-interaction`.
- Path: `app/Http/Requests/<Domain>/<Verb><Subject>Request.php`.
- Não criar FormRequest para formulário que vive só em Filament.
- Não criar FormRequest para rotas vendor/auto (`filament/`, `livewire/`, `telescope/`, `horizon/`, `sanctum/`, `passport/`, `_ignition/`, `health`, `up`, `storage/`, `broadcasting/auth`).
- `authorize()` retorna `bool` baseado em policy. `true` só quando outra camada (middleware, signed URL com validação de vínculo) garante autorização.
- `rules()` espelha migration/model.
- `messages()` usa chave-frase em **inglês** dentro de `__()` (locale fixo pt_BR via JSON).

## Workflow

- [ ] Verificar se o caso de uso é HTTP de domínio fora do Filament. Se não, parar.

- [ ] Considerar `asController()` na action antes de criar FormRequest separado. Se action via lorisleiva já cobre, use-a e pule esta skill.

- [ ] Criar request:

```bash
vendor/bin/sail artisan make:request Project/StoreProjectRequest --no-interaction
```

- [ ] Implementar `authorize()` via policy:

```php
use App\Models\Project;

public function authorize(): bool
{
    return $this->user()?->can('create', Project::class) ?? false;
}
```

- [ ] Implementar `rules()`:

```php
/**
 * @return array<string, array<int, string>>
 */
public function rules(): array
{
    return [
        'name' => ['required', 'string', 'max:255'],
        'status' => ['required', 'string', 'max:32'],
        'planned_starts_at' => ['nullable', 'date'],
        'is_active' => ['sometimes', 'boolean'],
    ];
}
```

- [ ] Implementar `messages()` apenas quando a mensagem padrão de `lang/pt_BR/validation.php` não basta:

```php
/**
 * @return array<string, string>
 */
public function messages(): array
{
    return [
        'name.required' => __('The project name is required.'),
    ];
}
```

- [ ] Injetar FormRequest no controller/endpoint HTTP e delegar para action:

```php
use App\Actions\Project\CreateProjectAction;
use Illuminate\Http\RedirectResponse;

public function store(StoreProjectRequest $request): RedirectResponse
{
    CreateProjectAction::run($request->user(), $request->validated());

    return redirect()->route('projects.index');
}
```

## Anti-Patterns

- Não criar FormRequest para formulário Filament. Validação vive no Schema.
- Não usar `app(StoreXRequest::class)->rules()` para reaproveitar regras em campo Filament — quebra o ciclo de validação do Schema.
- Não tratar rotas vendor (`filament/`, `livewire/`, `_ignition`, `health`, `up`) como endpoint de domínio.
- Não duplicar regras entre FormRequest e action. Escolha um caminho: ou `asController()` na action (com `rules()` lá), ou FormRequest separado consumido pelo controller.
- Não retornar `true` direto de `authorize()` sem documentar a camada externa que autoriza.
- Não escrever strings em pt_BR direto no `messages()`. Use `__('English key')` e traduza via `lang/pt_BR.json`.

## Verification

- [ ] `./.agents/skills/_helpers/verify-skill.sh .agents/skills/form-request-validation/SKILL.md`
- [ ] `vendor/bin/sail bin pint --dirty --format agent`
- [ ] `vendor/bin/sail bin phpstan analyse`
- [ ] `vendor/bin/sail artisan test --compact --filter=Request`
- [ ] Confirmar que nenhum Schema/Resource Filament depende do FormRequest.
- [ ] Confirmar que mensagens custom usam `__()` com chave em inglês.

## Related

- `action-class` — caminho preferido para endpoint HTTP via `asController()` na própria action.
- `translation` — `messages()` usa chave-frase em inglês resolvida por `lang/pt_BR.json`.
- `filament-schema-class` — validação dentro do painel vive aqui, não em FormRequest.
