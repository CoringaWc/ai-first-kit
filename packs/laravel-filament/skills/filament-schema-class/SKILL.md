---
name: filament-schema-class
description: "Aplicar quando compor schema de form Filament v5 para Model Laravel em Resource existente."
license: MIT
metadata:
  author: coringawc
  version: 2.0.0
  requires:
    - laravel-best-practices
    - spatie-laravel-php-standards
  related:
    - filament-resource-scaffold
    - translation
    - enum-with-translations
    - action-class
    - form-request-validation
---

# Filament Schema Class

## Consistency First

Schema de form Filament v5 vive em classe sibling ao `Pages/` do Resource: `app/Filament/<Panel>/Resources/<ModelPlural>/Schemas/<Model>Form.php`. A classe expõe `public static function configure(Schema $schema): Schema` e o Resource delega via `return <Model>Form::configure($schema);`. Toda string visível usa chave-frase em inglês via `__()` resolvida em `lang/pt_BR.json` conforme `.agents/skills/translation/rules/translation-rules.md`.

Não existe "schema global" fora do Resource — schemas são sibling do Resource. Reuso entre painéis ou entre Resources distintos se resolve com método estático compartilhado dentro de um único sibling, traits dedicadas ou componentes reutilizáveis (`filament-form-component-reusable`).

## Quick Reference

- Path canônico: `app/Filament/<Panel>/Resources/<ModelPlural>/Schemas/<Model>Form.php`.
- Assinatura padrão: `public static function configure(Schema $schema): Schema`.
- Resource delega: `return <Model>Form::configure($schema);`.
- Componentes de form: `Filament\Forms\Components\*`.
- Layouts (Section, Grid, Fieldset, Tabs): `Filament\Schemas\Components\*`.
- Schema container: `Filament\Schemas\Schema`.
- Utilities reativas: `Filament\Schemas\Components\Utilities\Get` e `Set`.
- Validação inline no componente: `->required()`, `->maxLength()`, `->unique()`, `->rules()`.
- Labels via `__('English phrase')`; sem `__('labels.xxx')` e sem `lang/<locale>/labels.php`.
- Reuso entre schemas do mesmo painel: método privado/protegido estático no próprio `<Model>Form`. Promover a componente reutilizável apenas quando aparecer em 2+ schemas independentes.

## Workflow

- [ ] Identificar Model, painel alvo e padrão de Resources do projeto antes de criar a classe.

- [ ] Gerar o Resource via Sail se ainda não existir (a classe sibling é criada manualmente em seguida):

```bash
vendor/bin/sail artisan make:filament-resource Project --panel=app --no-interaction
```

- [ ] Criar `app/Filament/App/Resources/Projects/Schemas/ProjectForm.php` com `configure()` e composição em método dedicado:

```php
namespace App\Filament\App\Resources\Projects\Schemas;

use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Schemas\Components\Fieldset;
use Filament\Schemas\Schema;

class ProjectForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->columns(1)
            ->components(self::components());
    }

    /**
     * @return array<int, Fieldset>
     */
    public static function components(): array
    {
        return [
            Fieldset::make(__('Project details'))
                ->schema([
                    self::titleField(),
                    self::statusField(),
                ]),
        ];
    }

    private static function titleField(): TextInput
    {
        return TextInput::make('title')
            ->label(__('Title'))
            ->required()
            ->maxLength(255)
            ->validationAttribute(__('Title'));
    }

    private static function statusField(): Select
    {
        return Select::make('status')
            ->label(__('Status'))
            ->required()
            ->native(false);
    }
}
```

- [ ] No Resource, delegar o form ao sibling:

```php
use App\Filament\App\Resources\Projects\Schemas\ProjectForm;
use Filament\Schemas\Schema;

public static function form(Schema $schema): Schema
{
    return ProjectForm::configure($schema);
}
```

- [ ] Usar `Get`/`Set` para reatividade entre campos dentro do schema:

```php
use Filament\Schemas\Components\Utilities\Get;
use Filament\Schemas\Components\Utilities\Set;
use Illuminate\Support\Str;

TextInput::make('title')
    ->live(onBlur: true)
    ->afterStateUpdated(fn (Set $set, ?string $state): mixed => $set(
        'slug',
        Str::slug($state ?? ''),
    ));

TextInput::make('company_name')
    ->visible(fn (Get $get): bool => $get('type') === 'business');
```

- [ ] Adicionar cada label nova em `lang/pt_BR.json` conforme `.agents/skills/translation/rules/translation-rules.md` §8 (ler, mesclar preservando ordem, validar parse).

- [ ] Cobrir com Pest: create, edit, validações principais e comportamento reativo (`afterStateUpdated`, `visible`).

## Anti-Patterns

- ❌ Criar `app/Filament/Schemas/<Model>/<Model>Schema.php` global fora do Resource. Schemas são sibling ao Resource.
- ❌ Nomear a classe `<Model>Schema`. Nome canônico é `<Model>Form`.
- ❌ Assinatura alternativa `formSchema(): array` exposta como caminho principal. A entrada padrão é `configure(Schema $schema): Schema`.
- ❌ Form inline dentro do Resource (`form()` retornando array gigante). Extrair sempre para sibling `<Model>Form`.
- ❌ Namespaces invertidos: layouts em `Filament\Forms\Components` ou form components em `Filament\Schemas\Components`. Form vai em `Filament\Forms\Components`; layout vai em `Filament\Schemas\Components`.
- ❌ `FormRequest` para fluxo exclusivamente Filament. Use validação inline do componente.
- ❌ Regra de negócio dentro de closures longas no schema. Extraia para Action, Policy ou método privado dedicado.
- ❌ Labels com texto em pt direto no `__()`: `__('Criar projeto')`. Chave-frase é em inglês: `__('Create project')`.

## Verification

- [ ] `.agents/skills/_helpers/verify-skill.sh .agents/skills/filament-schema-class/SKILL.md`
- [ ] `test -f app/Filament/App/Resources/Projects/Schemas/ProjectForm.php`
- [ ] `vendor/bin/sail php -r 'json_decode(file_get_contents("lang/pt_BR.json"), true, 512, JSON_THROW_ON_ERROR); echo "OK\n";'`
- [ ] `vendor/bin/sail bin pint --dirty --format agent`
- [ ] `vendor/bin/sail bin phpstan analyse`
- [ ] `vendor/bin/sail artisan test --compact --filter=Project`
- [ ] Confirmar que o Resource usa `<Model>Form::configure($schema)` e não há schema inline gigante

## Related

- `filament-resource-scaffold` — Resource delega o form para o sibling `<Model>Form::configure()`.
- `translation` — labels e validações seguem `.agents/skills/translation/rules/translation-rules.md`.
- `enum-with-translations` — `Select` para status/tipo/categoria deve usar enum traduzido.
- `action-class` — regra de negócio acionada por form sai do schema para `app/Actions`.
- `form-request-validation` — alternativa apenas para endpoints HTTP fora de forms Filament.
