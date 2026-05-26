---
name: filament-relation-page
description: "Aplicar quando criar página Filament v5 para gerenciar coleção relacionada de um Resource pai com URL própria."
license: MIT
metadata:
  author: coringawc
  version: 2.0.0
  requires:
    - laravel-best-practices
    - spatie-laravel-php-standards
  related:
    - filament-resource-scaffold
    - filament-nested-resource
    - filament-action-with-modal-heading
    - translation
    - policy-native-laravel
---

# Filament Relation Page

## Consistency First

Três padrões distintos para relação no Filament v5; escolha consciente:

- **Relation page (esta skill)**: `ManageRelatedRecords` com URL própria, breadcrumb e título. Lista + CRUD via actions modais. Use quando o filho não merece Resource separado mas precisa de URL.
- **Nested resource** (`filament-nested-resource`): filho com Resource próprio e pages completas (create/view/edit como páginas, não modais). Use quando CRUD do filho exige experiência de página.
- **RelationManager** (não esta skill): tab dentro da página Edit do pai, sem URL própria. Use só quando inline na Edit faz sentido visual.

Relation page **registra em `getPages()`** do parent Resource, nunca em `getRelations()`. Toda string visível usa chave-frase em inglês via `__()` resolvida em `lang/pt_BR.json` conforme `.agents/skills/translation/rules/translation-rules.md`.

## Quick Reference

- Gerar com `vendor/bin/sail artisan make:filament-page --resource=<ParentResource> --type=ManageRelatedRecords --panel=<panel> --no-interaction`.
- Classe estende `Filament\Resources\Pages\ManageRelatedRecords`.
- `protected static string $resource = <ParentResource>::class;`.
- `protected static string $relationship = '<eloquentRelationship>';`.
- `protected static bool $shouldRegisterNavigation = false;` por padrão. Habilite navegação só por decisão explícita.
- Path canônico: `app/Filament/<Panel>/Resources/<ParentPlural>/Pages/Manage<Parent><ChildPlural>.php`.
- Slug da rota em pt_BR (URL pública): `/{record}/documentos`, `/{record}/colaboradores`.
- Actions de modal sempre via `Filament\Actions\*` com `modalHeading(__('English phrase'))`.
- Toda string nova vai em `lang/pt_BR.json`. Nunca `lang/<locale>/labels.php`.
- Registro no parent Resource: `'documents' => Pages\ManageProjectDocuments::route('/{record}/documentos')` dentro de `getPages()`.

## Workflow

- [ ] Decidir entre relation page, nested resource e RelationManager antes de gerar. Critérios na Consistency First.

- [ ] Gerar via Artisan oficial:

```bash
vendor/bin/sail artisan make:filament-page \
  --resource=ProjectResource \
  --type=ManageRelatedRecords \
  --panel=app \
  --no-interaction
```

- [ ] Configurar a classe gerada com `$relationship`, navegação oculta e título traduzido:

```php
namespace App\Filament\App\Resources\Projects\Pages;

use App\Filament\App\Resources\Projects\ProjectResource;
use Filament\Resources\Pages\ManageRelatedRecords;
use Filament\Schemas\Schema;
use Filament\Tables\Table;

class ManageProjectDocuments extends ManageRelatedRecords
{
    protected static string $resource = ProjectResource::class;

    protected static string $relationship = 'documents';

    protected static bool $shouldRegisterNavigation = false;

    public function getTitle(): string
    {
        return __('Project documents');
    }

    public function form(Schema $schema): Schema
    {
        return $schema->components([
            // componentes Filament\Forms\Components\*
        ]);
    }

    public function table(Table $table): Table
    {
        return $table
            ->recordTitleAttribute('name')
            ->modelLabel(__('Document'))
            ->pluralModelLabel(__('Documents'));
    }
}
```

- [ ] Registrar a rota no parent Resource via `getPages()`. Slug em pt_BR:

```php
public static function getPages(): array
{
    return [
        // ...
        'documents' => Pages\ManageProjectDocuments::route('/{record}/documentos'),
    ];
}
```

- [ ] Actions de modal sempre traduzidas com chave-frase em inglês:

```php
use Filament\Actions\CreateAction;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;

CreateAction::make()->modalHeading(__('Add document'));
EditAction::make()->modalHeading(__('Edit document'));
DeleteAction::make()->modalHeading(__('Delete document'));
```

- [ ] Adicionar cada label nova em `lang/pt_BR.json` conforme `.agents/skills/translation/rules/translation-rules.md` §8.

- [ ] Cobrir com Pest: render da page, principais columns/labels, action de create/edit/delete e autorização aplicável.

## Anti-Patterns

- ❌ Registrar relation page em `getRelations()`. Esse array é exclusivo de `RelationManager`. Relation page vive em `getPages()`.
- ❌ Criar `RelationManager` quando o requisito inclui URL própria, breadcrumb ou navegação direta. Use `ManageRelatedRecords`.
- ❌ Criar nested resource quando o filho não precisa de pages completas. Relation page resolve com menos código.
- ❌ Actions de modal sem `modalHeading()` traduzido (regra global `AGENTS.md` UI Rules 0.1).
- ❌ Imports antigos: `Filament\Tables\Actions\*`, `Filament\Forms\Actions\*`. Tudo vem de `Filament\Actions\*`.
- ❌ `__('labels.documents')` ou criar `lang/<locale>/labels.php`. Chave-frase em inglês resolvida no JSON único (`translation-rules.md` §2).
- ❌ Slug da rota em inglês quando a URL pública do projeto é pt_BR.
- ❌ Habilitar navegação global (`$shouldRegisterNavigation = true`) sem decisão explícita. Relation page é contextual ao parent.
- ❌ Forçar path global `app/Filament/Resources/...` em projeto com painéis. Preserve `app/Filament/<Panel>/Resources/...`.

## Verification

- [ ] `.agents/skills/_helpers/verify-skill.sh .agents/skills/filament-relation-page/SKILL.md`
- [ ] `vendor/bin/sail php -r 'json_decode(file_get_contents("lang/pt_BR.json"), true, 512, JSON_THROW_ON_ERROR); echo "OK\n";'`
- [ ] `vendor/bin/sail artisan route:list --except-vendor` mostra a rota da relation page
- [ ] `vendor/bin/sail artisan test --compact --filter=ManageProjectDocuments`
- [ ] `vendor/bin/sail bin pint --dirty --format agent`
- [ ] `vendor/bin/sail bin phpstan analyse`
- [ ] Confirmar: imports `Filament\Resources\Pages\ManageRelatedRecords`, `Filament\Actions\*`, `Filament\Schemas\Schema`, `Filament\Tables\Table`; registro em `getPages()` do parent

## Related

- `filament-resource-scaffold` — parent Resource registra a rota da relation page e define labels base.
- `filament-nested-resource` — alternativa quando o filho precisa de pages completas com URL própria.
- `filament-action-with-modal-heading` — actions de modal seguem regra de `modalHeading()` traduzido.
- `translation` — toda string visível segue `.agents/skills/translation/rules/translation-rules.md`.
- `policy-native-laravel` — autorização do parent E da relation cobre o acesso (opt-in: `policy-with-spatie-permission`).
