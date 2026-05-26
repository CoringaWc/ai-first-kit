---
name: filament-nested-resource
description: "Aplicar quando criar Resource Filament v5 filho acessado por URL aninhada ao Resource pai."
license: MIT
metadata:
  author: coringawc
  version: 2.0.0
  requires:
    - laravel-best-practices
    - spatie-laravel-php-standards
  related:
    - filament-resource-scaffold
    - filament-relation-page
    - translation
    - policy-native-laravel
---

# Filament Nested Resource

## Consistency First

Nested resource é Resource filho com páginas próprias dentro do contexto de um Resource pai (`/projetos/{project}/colaboradores/{record}`). Use quando create/view/edit do filho precisam ser **páginas completas com URL própria**, não modais nem tabs. Para gerenciar coleção relacionada sem CRUD completo separado, use `filament-relation-page`. Para tab dentro de Edit sem URL, use RelationManager (não esta skill). O filho registra o pai via `ParentResourceRegistration` e acessa o pai pelas pages via `$this->getParentRecord()`.

## Quick Reference

- Criar com `vendor/bin/sail artisan make:filament-resource <Child> --panel=<panel> --no-interaction` e ajustar manualmente para nested (gerador nem sempre cobre).
- Resource filho: `protected static bool $shouldRegisterNavigation = false;` (acesso só via pai).
- Slug do filho em pt_BR: `protected static ?string $slug = 'colaboradores';`.
- Parent registration via `getParentResourceRegistration()` com `relationship()` + `inverseRelationship()` explícitos.
- URL gerada: `/<parent-slug>/{<parent-param>}/<child-slug>/...`.
- Nome do parâmetro do pai = inverse relationship em snake singular: `inverseRelationship('project')` → `{project}`.
- Em pages do filho, sempre `$this->getParentRecord()`. Nunca `request()->route()`.
- `$recordRouteKeyName` (slug/uuid): declarar no Resource pai E no filho consistentemente.
- Path canônico: `app/Filament/<Panel>/Resources/<Child>s/<Child>Resource.php`.

## Workflow

- [ ] Confirmar pai, filho, relationship, inverse relationship, painel e route keys antes de scaffolding.

- [ ] Gerar Resource base via Sail:

```bash
vendor/bin/sail artisan make:filament-resource ProjectCollaborator --panel=app --no-interaction
```

- [ ] No Resource filho, registrar pai e ocultar navegação global:

```php
use App\Filament\App\Resources\Projects\ProjectResource;
use Filament\Resources\ParentResourceRegistration;
use Filament\Resources\Resource;

class ProjectCollaboratorResource extends Resource
{
    protected static ?string $slug = 'colaboradores';

    protected static bool $shouldRegisterNavigation = false;

    public static function getParentResourceRegistration(): ?ParentResourceRegistration
    {
        return ProjectResource::asParent()
            ->relationship('collaborators')
            ->inverseRelationship('project');
    }
}
```

- [ ] Quando o nome inferido bate exatamente, `protected static ?string $parentResource = ProjectResource::class;` resolve. Use `getParentResourceRegistration()` se precisar fixar `relationship()`/`inverseRelationship()` sem ambiguidade.

- [ ] Definir pages com rotas relativas ao child slug. O prefix do pai é aplicado pelo Filament:

```php
public static function getPages(): array
{
    return [
        'create' => Pages\CreateProjectCollaborator::route('/incluir'),
        'view' => Pages\ViewProjectCollaborator::route('/{record}'),
        'edit' => Pages\EditProjectCollaborator::route('/{record}/editar'),
    ];
}
```

- [ ] Nas pages, acessar o pai via API Filament e proteger com tipagem:

```php
use App\Models\Project;
use Filament\Resources\Pages\CreateRecord;

class CreateProjectCollaborator extends CreateRecord
{
    protected static string $resource = ProjectCollaboratorResource::class;

    public function getTitle(): string
    {
        return __('Add collaborator to :project', [
            'project' => $this->getParentProject()->name,
        ]);
    }

    private function getParentProject(): Project
    {
        $project = $this->getParentRecord();

        if (! $project instanceof Project) {
            abort(404);
        }

        return $project;
    }
}
```

- [ ] Gerar URL manual passando o parâmetro do pai pelo nome derivado da inverse relationship:

```php
ProjectCollaboratorResource::getUrl('view', [
    'project' => $project,
    'record' => $collaborator,
], panel: 'app');
```

- [ ] Customizar route key apenas quando necessário (uuid/slug público). Aplicar no pai E no filho:

```php
protected static ?string $recordRouteKeyName = 'uuid';
```

Atualizar model (`getRouteKeyName()`), policies e asserts de URL em testes.

- [ ] Adicionar cada label nova em `lang/pt_BR.json` conforme `.agents/skills/translation/rules/translation-rules.md` §8.

- [ ] Cobrir com Pest: listagem pelo pai, create/view/edit do nested, URL com parâmetro do pai, isolamento multi-tenant.

```php
livewire(ViewProjectCollaborator::class, [
    'project' => $project->getRouteKey(),
    'record' => $collaborator->getRouteKey(),
])->assertOk();
```

## Anti-Patterns

- ❌ Confundir nested resource com relation page: relation page lista filhos numa única página agregadora; nested resource dá ao filho páginas próprias com URL.
- ❌ Confundir nested resource com RelationManager: RelationManager é tab dentro de Edit, sem URL própria.
- ❌ Criar rotas web/controllers manuais para resolver aninhamento. Filament já fornece.
- ❌ Usar `{record}` como parâmetro do pai em URL manual. Use o nome derivado da inverse relationship (`{project}`).
- ❌ `request()->route('project')` espalhado nas pages. `$this->getParentRecord()` é o padrão.
- ❌ Esquecer `$shouldRegisterNavigation = false` no filho. Nested resource é contextual; não vai no menu global.
- ❌ Customizar `getRecordRouteKeyName()` apenas no filho quando a URL aninhada também expõe chave pública do pai. Pai resolve `{project}`; configure ambos.
- ❌ Remover escopos de tenant/company em `getEloquentQuery()`. Parent registration não substitui isolamento de acesso.
- ❌ Slug do filho em inglês quando a URL pública é pt_BR. Slug reflete o que o usuário vê.
- ❌ `CreateAction::make()` na ListPage do filho sem `->modalHeading(__('Create :model', ['model' => __('label.collaborator')]))` (Project UI Rule 0.1). Toda Action que abre modal em nested resource precisa de título traduzido baseado no label do filho — não no label do pai. Sintoma: modal abre com "Create" genérico ou o label do pai vazado.

## Verification

- [ ] `.agents/skills/_helpers/verify-skill.sh .agents/skills/filament-nested-resource/SKILL.md`
- [ ] `vendor/bin/sail artisan route:list --except-vendor` mostra a rota aninhada esperada
- [ ] `vendor/bin/sail php -r 'json_decode(file_get_contents("lang/pt_BR.json"), true, 512, JSON_THROW_ON_ERROR); echo "OK\n";'`
- [ ] `vendor/bin/sail artisan test --compact --filter=ProjectCollaborator`
- [ ] `vendor/bin/sail bin pint --dirty --format agent`
- [ ] `vendor/bin/sail bin phpstan analyse`
- [ ] Conferir manualmente: URL do filho contém parâmetro do pai (`/{project}/colaboradores`), pages usam `$this->getParentRecord()`, route key consistente entre pai e filho

## Related

- `filament-resource-scaffold` — convenções base aplicam ao Resource filho (labels, slug, pages).
- `filament-relation-page` — agregadora no pai apontando para o nested resource; ou alternativa sem nested.
- `translation` — labels, títulos e mensagens seguem `.agents/skills/translation/rules/translation-rules.md`.
- `policy-native-laravel` — policies do pai E do filho cobrem acesso aninhado (opt-in: `policy-with-spatie-permission`).
