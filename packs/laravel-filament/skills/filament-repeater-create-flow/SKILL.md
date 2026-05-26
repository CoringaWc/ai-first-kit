---
name: filament-repeater-create-flow
description: "Aplicar quando criar fluxo Filament v5 que salva registro pai e filhos juntos por Repeater."
license: MIT
metadata:
  author: coringawc
  version: 2.0.0
  requires:
    - laravel-best-practices
    - spatie-laravel-php-standards
  related:
    - filament-schema-class
    - filament-resource-scaffold
    - filament-action-with-modal-heading
    - filament-form-component-reusable
    - translation
    - model-with-factory-and-seeder
    - migration-with-conventions
---

# Filament Repeater Create Flow

## Consistency First

Fluxo Filament v5 que cria pai + filhos juntos usa `Repeater::make('<relationship>')->relationship()->schema([...])`. **Repeater v5 usa `->schema()`, NUNCA `->fields()`** (regra crítica do AGENTS.md "Common Mistakes"). `->fields()` não existe na API v5 e quebra silenciosamente. Quando `relationship()` está ativo, o Filament cria o pai e persiste os filhos `HasMany` numa transação implícita. Toda string visível usa chave-frase em inglês via `__()` resolvida em `lang/pt_BR.json` conforme `.agents/skills/translation/rules/translation-rules.md`.

Para `BelongsToMany`, criar model pivô explícito com `HasMany` no pai e usar o Repeater no relacionamento intermediário. Para bulk operation sem pai persistido (ex.: import), use Action manual em `app/Actions` e documente — não force Repeater.

## Quick Reference

- Repeater v5 usa `->schema(...)`. **Nunca `->fields()`** — não existe na API v5.
- Relacionamento default usa o nome do campo: `Repeater::make('collaborators')->relationship()` binda `collaborators()`.
- Quando o nome do campo difere do relacionamento, passe explícito: `->relationship('items')`.
- Repeater com `relationship()` exige `HasMany`. Para `BelongsToMany`, use pivot model com `HasMany`.
- Filament salva pai e filhos em **transação implícita** quando `relationship()` está ativo.
- Schema do filho extraído via `filament-schema-class` ou `filament-form-component-reusable`; nunca inline gigante.
- Validar tamanho com `->minItems()`, `->maxItems()`, `->required()`; validações de campo no schema do filho.
- Reorder persistido exige coluna real no filho + `->orderColumn('sort')`. Sem coluna, use `->reorderable(false)`.
- Não adicionar `->dehydrated(false)` no Repeater com `relationship()`. Filament já configura.
- FK do pai não vai como campo visível do filho — `relationship()->save()` preenche.
- Action com modal contendo Repeater segue `filament-action-with-modal-heading` (heading traduzido).

## Workflow

- [ ] Confirmar que o fluxo é pai + filhos persistidos por `HasMany`. Para bulk sem pai persistido, parar e usar Action manual.

- [ ] Confirmar Model pai, relacionamento, Model filho, fillable/casts, policy e se a tabela filha tem coluna de ordenação caso reorder seja necessário.

- [ ] Em greenfield, criar Model filho, migration, factory, relacionamento no pai e policy antes do Repeater (`model-with-factory-and-seeder`, `migration-with-conventions`).

- [ ] Compor o Repeater usando schema sibling do filho:

```php
use App\Filament\App\Resources\Projects\Schemas\CollaboratorForm;
use Filament\Forms\Components\Repeater;

Repeater::make('collaborators')
    ->label(__('Collaborators'))
    ->relationship()
    ->schema(CollaboratorForm::components())
    ->minItems(1)
    ->maxItems(20)
    ->defaultItems(1)
    ->addActionLabel(__('Add collaborator'))
    ->collapsible()
    ->reorderable(false)
    ->columnSpanFull();
```

- [ ] Se a ordem precisa persistir, garantir migration/coluna no filho antes de ativar reorder:

```php
Repeater::make('documents')
    ->relationship()
    ->schema(ProjectDocumentForm::components())
    ->orderColumn('sort');
```

- [ ] Para dados derivados por contexto (tenant, company, user atual), mutar filhos novos e existentes:

```php
use App\Models\User;
use Filament\Facades\Filament;
use Illuminate\Auth\AuthenticationException;

$resolveUser = function (): User {
    $user = Filament::auth()->user();

    if (! $user instanceof User) {
        throw new AuthenticationException();
    }

    return $user;
};

Repeater::make('documents')
    ->relationship()
    ->schema(ProjectDocumentForm::components())
    ->mutateRelationshipDataBeforeCreateUsing(fn (array $data): array => [
        ...$data,
        'company_id' => $resolveUser()->company_id,
    ])
    ->mutateRelationshipDataBeforeSaveUsing(fn (array $data): array => [
        ...$data,
        'company_id' => $resolveUser()->company_id,
    ]);
```

- [ ] Se o fluxo estiver em Action/modal, aplicar `modalHeading()` traduzido (`filament-action-with-modal-heading`):

```php
use Filament\Actions\CreateAction;

CreateAction::make()
    ->modalHeading(__('Create project with collaborators'))
    ->modalWidth('5xl')
    ->schema([
        Repeater::make('collaborators')
            ->relationship()
            ->schema(CollaboratorForm::components())
            ->minItems(1),
    ]);
```

- [ ] Para `BelongsToMany`, criar model pivô explícito com `HasMany` no pai. Use o Repeater no relacionamento intermediário, não direto no `BelongsToMany`.

- [ ] Adicionar cada label nova em `lang/pt_BR.json` conforme `.agents/skills/translation/rules/translation-rules.md` §8.

- [ ] Cobrir com Pest: criação do pai com 1+ filhos via Livewire/Filament, `assertHasNoFormErrors`, `assertDatabaseHas` no pai e filhos, validação min/max, campos obrigatórios do filho, ordenação quando houver `orderColumn` e isolamento tenant/company.

## Anti-Patterns

- ❌ Usar `Repeater::make(...)->fields([...])`. **`->fields()` não existe em v5; quebra silenciosamente.** Use sempre `->schema([...])`:

```php
// BAD — não existe em v5
Repeater::make('items')->fields([
    TextInput::make('name'),
]);

// GOOD — v5
Repeater::make('items')->schema([
    TextInput::make('name'),
]);
```

- ❌ Usar `Repeater::make('products')->relationship()` direto em `BelongsToMany`. Use pivot model com `HasMany`.
- ❌ Salvar filhos com `foreach` manual quando `relationship()` cobre o `HasMany`.
- ❌ Ativar reorder sem coluna persistida no filho.
- ❌ Colocar FK do pai como campo visível/dehidratado no Repeater. `relationship()->save()` preenche a FK automaticamente.
- ❌ Adicionar `->dehydrated(false)` manualmente no Repeater com `relationship()`. Filament já configura.
- ❌ `FormRequest` para form exclusivamente Filament. Validações ficam nos componentes do schema do filho.
- ❌ Componente Livewire puro dentro do painel para repetir filhos. Use Repeater ou componente reutilizável (`filament-form-component-reusable`).
- ❌ Esquecer `modalHeading()` traduzido em Action com modal contendo Repeater.
- ❌ Schema do filho duplicado inline quando sibling `<Child>Form::components()` já existe.

## Verification

- [ ] `.agents/skills/_helpers/verify-skill.sh .agents/skills/filament-repeater-create-flow/SKILL.md`
- [ ] `vendor/bin/sail php -r 'json_decode(file_get_contents("lang/pt_BR.json"), true, 512, JSON_THROW_ON_ERROR); echo "OK\n";'`
- [ ] Grep contra `->fields(` em Repeater retorna vazio:

```bash
! grep -rE "Repeater::make\([^)]+\)[^;]*->fields\(" app
```

- [ ] `vendor/bin/sail bin pint --dirty --format agent`
- [ ] `vendor/bin/sail bin phpstan analyse`
- [ ] `vendor/bin/sail artisan test --compact --filter=Repeater`
- [ ] Confirmar que o relacionamento do Repeater é `HasMany` (ou pivot model com `HasMany`); `orderColumn` só com coluna real persistida; actions modais com `modalHeading()` traduzido

## Related

- `filament-schema-class` — fornece `<Child>Form::components()` reutilizado pelo Repeater.
- `filament-resource-scaffold` — Resource pai hospeda o fluxo de create com Repeater.
- `filament-action-with-modal-heading` — Actions com modal contendo Repeater seguem regra 0.1.
- `filament-form-component-reusable` — quando o schema do filho vira componente reutilizável.
- `translation` — labels e mensagens seguem `.agents/skills/translation/rules/translation-rules.md`.
- `model-with-factory-and-seeder` — Model filho precisa de fillable/casts/factory para os testes.
- `migration-with-conventions` — necessária ao adicionar coluna `sort` para ordenação persistida.
