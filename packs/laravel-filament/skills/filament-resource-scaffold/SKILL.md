---
name: filament-resource-scaffold
description: "Aplicar quando criar Resource Filament v5 para um Model Laravel."
license: MIT
metadata:
  author: coringawc
  version: 2.0.0
  requires:
    - laravel-best-practices
    - spatie-laravel-php-standards
  related:
    - filament-schema-class
    - translation
    - enum-with-translations
    - model-with-factory-and-seeder
    - policy-native-laravel
---

# Filament Resource Scaffold

## Consistency First

Resource Filament v5 vive em `app/Filament/<Panel>/Resources/<ModelPlural>/` com `Pages/` e `Schemas/` siblings. O form schema não fica inline no Resource: é extraído para `Resources/<ModelPlural>/Schemas/<Model>Form` no padrão sibling Filament v5 com `configure(Schema $schema): Schema`. Labels, navegação e slug vêm de chave-frase em inglês resolvida via `__()`, conforme `.agents/skills/translation/rules/translation-rules.md`.

## Quick Reference

- Criar com `vendor/bin/sail artisan make:filament-resource <Model> --panel=<panel> --no-interaction`.
- Path canônico: `app/Filament/<Panel>/Resources/<ModelPlural>/<Model>Resource.php`.
- Pages siblings: `Pages/List<Model>.php`, `Pages/Create<Model>.php`, `Pages/Edit<Model>.php`, `Pages/View<Model>.php`.
- Schema sibling: `Schemas/<Model>Form.php` com `public static function configure(Schema $schema): Schema`.
- Labels via `getModelLabel()`, `getPluralModelLabel()`, `getNavigationLabel()` retornando `__('English phrase')`.
- Slug em pt_BR (URL final que o usuário vê): `protected static ?string $slug = 'projetos';`.
- `$navigationIcon: string|BackedEnum|null` com `Heroicon::` enum, nunca string solta.
- Pesquisa global: `getGloballySearchableAttributes()` retorna `['name']`/`['title']` quando existir atributo natural; `$isGloballySearchable = false` para pivot/log/relação operacional.
- Validações ficam nos componentes do `<Model>Form`: `->required()`, `->maxLength()`, `->unique()`, `->rules()`.
- Namespaces Filament v5: `Filament\Forms\Components`, `Filament\Schemas\Components`, `Filament\Actions`, `Filament\Support\Icons\Heroicon`.

## Workflow

- [ ] Gerar Resource via Sail:

```bash
vendor/bin/sail artisan make:filament-resource Project --panel=app --no-interaction
```

- [ ] Confirmar estrutura gerada e ajustar para o padrão canônico se necessário:

```text
app/Filament/App/Resources/Projects/ProjectResource.php
app/Filament/App/Resources/Projects/Pages/ListProjects.php
app/Filament/App/Resources/Projects/Pages/CreateProject.php
app/Filament/App/Resources/Projects/Pages/EditProject.php
app/Filament/App/Resources/Projects/Pages/ViewProject.php
app/Filament/App/Resources/Projects/Schemas/ProjectForm.php
```

- [ ] Compor form no Resource via schema sibling:

```php
use App\Filament\App\Resources\Projects\Schemas\ProjectForm;
use Filament\Schemas\Schema;

public static function form(Schema $schema): Schema
{
    return ProjectForm::configure($schema);
}
```

- [ ] Definir ícone, slug e labels traduzidos. Slug em pt_BR (URL pública), labels via chave-frase em inglês:

```php
use BackedEnum;
use Filament\Support\Icons\Heroicon;

protected static string|BackedEnum|null $navigationIcon = Heroicon::DocumentText;

protected static ?string $slug = 'projetos';

public static function getNavigationLabel(): string
{
    return __('Projects');
}

public static function getModelLabel(): string
{
    return __('Project');
}

public static function getPluralModelLabel(): string
{
    return __('Projects');
}
```

- [ ] Adicionar cada label nova em `lang/pt_BR.json` conforme `.agents/skills/translation/rules/translation-rules.md` §8 (ler antes, mesclar preservando ordem, validar parse).

- [ ] Configurar pesquisa global se houver atributo natural:

```php
public static function getGloballySearchableAttributes(): array
{
    return ['name'];
}
```

Para pivot/log/relação operacional, desativar explicitamente:

```php
protected static bool $isGloballySearchable = false;
```

- [ ] Em pages, usar actions do namespace correto. Quando action abrir modal, `modalHeading()` traduzido via chave-frase em inglês:

```php
use Filament\Actions\EditAction;

EditAction::make()
    ->modalHeading(__('Edit project'));
```

- [ ] Criar testes Pest cobrindo list, create, edit, view e validações principais.

## Anti-Patterns

- ❌ Form schema inline no Resource. Sempre extrair para `Schemas/<Model>Form::configure($schema)`.
- ❌ `Filament\Tables\Actions\` ou `Filament\Forms\Actions\`. Actions vivem em `Filament\Actions\`.
- ❌ String solta para ícone (`'heroicon-o-document'`). Use `Heroicon::DocumentText`.
- ❌ `protected static ?string $navigationIcon`. Property é `string|BackedEnum|null` em v5.
- ❌ Labels com texto em pt direto no `__()`: `__('Criar projeto')`. Chave-frase é sempre em inglês: `__('Create project')`.
- ❌ Slug em inglês quando a URL pública é pt_BR. Slug reflete o que o usuário vê no browser.
- ❌ Habilitar pesquisa global por reflexo em log/pivot/auditoria.
- ❌ `RelationManager` registrado aqui. Pertence a `filament-nested-resource` ou `filament-relation-page`.
- ❌ `FormRequest` para fluxo exclusivamente Filament. Use validação nativa do componente.
- ❌ Duplicar middleware/auth guard/asset global do panel provider em cada Resource.

## Verification

- [ ] `.agents/skills/_helpers/verify-skill.sh .agents/skills/filament-resource-scaffold/SKILL.md`
- [ ] `vendor/bin/sail php -r 'json_decode(file_get_contents("lang/pt_BR.json"), true, 512, JSON_THROW_ON_ERROR); echo "OK\n";'`
- [ ] `test -f app/Filament/App/Resources/Projects/ProjectResource.php`
- [ ] `test -f app/Filament/App/Resources/Projects/Schemas/ProjectForm.php`
- [ ] `vendor/bin/sail artisan test --compact --filter=Project`
- [ ] `vendor/bin/sail bin pint --dirty --format agent`
- [ ] `vendor/bin/sail bin phpstan analyse`
- [ ] Confirmar zero ocorrências de `Filament\\Tables\\Actions` ou `Filament\\Forms\\Actions` no diff

## Related

- `filament-schema-class` — `Schemas/<Model>Form` sibling com `configure(Schema $schema): Schema`.
- `translation` — labels e slug seguem `.agents/skills/translation/rules/translation-rules.md`.
- `enum-with-translations` — colunas castadas para enums alimentam selects e badges do Resource.
- `model-with-factory-and-seeder` — Resource depende de model, factory e casts coerentes.
- `policy-native-laravel` — autorização do Resource segue Gate/Policy nativos (opt-in alternativo: `policy-with-spatie-permission`).
