---
name: filament-action-with-modal-heading
description: "Aplicar quando criar, revisar ou corrigir Action Filament v5 que abre modal."
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
    - filament-repeater-create-flow
    - translation
---

# Filament Action With Modal Heading

## Consistency First

Regra 0.1 do `AGENTS.md`: **TODA action Filament v5 que abre modal DEVE definir `modalHeading(__('English phrase'))` traduzido** — inclui forms, wizards, confirmation modals e built-ins (`CreateAction`, `EditAction`, `DeleteAction`) quando renderizam modal. Chave-frase em inglês resolvida em `lang/pt_BR.json` conforme `.agents/skills/translation/rules/translation-rules.md`. Em v5 **todas as actions vêm de `Filament\Actions\*`**; namespaces `Filament\Tables\Actions\*` e `Filament\Forms\Actions\*` são proibidos.

Não adicionar `modalHeading()` em action que apenas navega via `->url()`, dispara JS via `->alpineClickHandler()` ou link de menu — só action que abre modal real exige heading.

## Quick Reference

- Actions de qualquer contexto (page, table, infolist, repeater header): `Filament\Actions\*` apenas.
- Modal real é gatilhado por: `->requiresConfirmation()`, `->schema()`, `->steps()`, `->modalContent()`, `->modalContentFooter()`, `->modalFooter()`, `->modalDescription()`, `->modal(true)`.
- Indícios não bastam isoladamente: `->modalWidth()`, `->modalIcon()`, `->modalSubmitActionLabel()`, `->slideOver()` exigem heading só com gatilho real junto.
- Built-ins (`CreateAction`, `EditAction`, `DeleteAction`, `ViewAction`, `ReplicateAction`) abrem modal por padrão e já têm heading interno; sobrescreva quando o default ficar genérico/incorreto.
- `->form()` é legado em v5 — preferir `->schema()` em código novo; tratar como modal quando encontrado em código existente.
- Heading sempre traduzido: `->modalHeading(__('Delete project'))`, nunca string crua nem chave técnica (`__('deleteProject')`).
- Wizard com `->steps()` segue mesma regra; cada `Step::make(__('English'))` recebe label traduzido.
- Modal options completas: `modalDescription`, `modalSubmitActionLabel`, `modalCancelActionLabel`, `modalWidth`, `modalIcon`, `modalAlignment`.
- Action com `->url(...)` sem outros gatilhos de modal é link/redirect — sem heading.

## Workflow

- [ ] Localizar actions Filament reais no diff/PR, ignorando testes e `TestAction`:

```bash
vendor/bin/sail php -r "echo shell_exec('grep -rE \"Action::make|CreateAction::make|EditAction::make|DeleteAction::make|ViewAction::make\" app');"
```

- [ ] Para cada cadeia fluent, decidir se abre modal. Se houver `requiresConfirmation`/`schema`/`steps`/`modalContent`/`modalDescription`/`modal(true)`, é modal e exige heading.

- [ ] Ignorar actions URL-only e JS-only:

```php
use Filament\Actions\Action;

Action::make('openCollaborators')
    ->url(ProjectCollaboratorResource::getUrl('index', ['project' => $record]));

Action::make('openCopilot')
    ->alpineClickHandler('window.dispatchEvent(new CustomEvent("open-copilot"))');
```

- [ ] Inserir `modalHeading()` traduzido perto dos demais metadados do modal, preservando a fluent chain:

```php
use Filament\Actions\Action;

Action::make('archive')
    ->label(__('Archive collaborator'))
    ->requiresConfirmation()
    ->modalHeading(__('Archive collaborator'))
    ->modalDescription(__('This collaborator will no longer appear in active lists.'))
    ->modalSubmitActionLabel(__('Archive'))
    ->action(function (): void {
        // ...
    });
```

- [ ] Para built-ins com heading dinâmico, ajustar `modelLabel()`/`recordTitle()` em vez de sobrescrever heading com string menos precisa:

```php
use Filament\Actions\CreateAction;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;

CreateAction::make()->modelLabel(__('Project'));

EditAction::make()
    ->recordTitle(fn ($record): string => $record->title);

DeleteAction::make()
    ->recordTitle(fn ($record): string => $record->title);
```

- [ ] Para fluxo com Repeater criando lote, usar plural no heading:

```php
use Filament\Actions\CreateAction;
use Filament\Forms\Components\Repeater;

CreateAction::make()
    ->modalHeading(__('Create documents'))
    ->schema([
        Repeater::make('documents')
            ->relationship()
            ->schema(/* ... */),
    ]);
```

- [ ] Para wizard, traduzir heading da action E label de cada `Step`:

```php
use Filament\Actions\Action;
use Filament\Schemas\Components\Wizard\Step;

Action::make('onboardCollaborator')
    ->modalHeading(__('Onboard collaborator'))
    ->modalWidth('5xl')
    ->steps([
        Step::make(__('Identity'))
            ->schema([
                // componentes Filament\Forms\Components\*
            ]),
        Step::make(__('Permissions'))
            ->schema([
                // ...
            ]),
    ]);
```

- [ ] Adicionar cada label nova em `lang/pt_BR.json` conforme `.agents/skills/translation/rules/translation-rules.md` §8.

- [ ] Cobrir com Pest no contexto real da action (Livewire + Filament Testing):

```php
use App\Filament\App\Resources\Projects\Pages\ListProjects;
use Filament\Actions\Testing\TestAction;
use function Pest\Livewire\livewire;

livewire(ListProjects::class)
    ->mountAction(TestAction::make('archive')->table($project))
    ->assertMountedActionModalSee(__('Archive project'));
```

## Anti-Patterns

- ❌ Importar action de `Filament\Tables\Actions\*` ou `Filament\Forms\Actions\*`. V5 usa **somente** `Filament\Actions\*`:

```php
// BAD — v4 legado
use Filament\Tables\Actions\DeleteAction;
use Filament\Forms\Actions\Action;

// GOOD — v5
use Filament\Actions\DeleteAction;
use Filament\Actions\Action;
```

- ❌ `modalHeading('Delete Project')` sem `__()`. Sempre traduzido.
- ❌ Usar nome técnico como heading: `__('deleteProject')`, `__('createDocument')`. Use frase humana em inglês.
- ❌ Tratar action URL-only como modal. Se `->url()` está setado sem outros gatilhos, é link/redirect.
- ❌ Confundir `schema()` de `Section`, `Grid` ou `Repeater` com `schema()` de action. Analise a cadeia fluent da action específica.
- ❌ Duplicar `modalHeading()` quando já existe.
- ❌ Sobrescrever heading dinâmico de built-in com string menos precisa quando ajustar `modelLabel()`/`recordTitle()` resolve.
- ❌ Esquecer heading em wizard. Action com `->steps()` é modal e exige heading.
- ❌ Chave de tradução em pt direto no `__()`: `__('Arquivar projeto')`. Chave-frase é em inglês: `__('Archive project')`.

## Verification

- [ ] `.agents/skills/_helpers/verify-skill.sh .agents/skills/filament-action-with-modal-heading/SKILL.md`
- [ ] `vendor/bin/sail php -r 'json_decode(file_get_contents("lang/pt_BR.json"), true, 512, JSON_THROW_ON_ERROR); echo "OK\n";'`
- [ ] Grep contra namespaces proibidos retorna vazio:

```bash
! grep -rE "use Filament\\\\(Tables|Forms)\\\\Actions" app
```

- [ ] `vendor/bin/sail bin pint --dirty --format agent`
- [ ] `vendor/bin/sail bin phpstan analyse`
- [ ] `vendor/bin/sail artisan test --compact --filter=Action`
- [ ] Toda action modal no diff tem `modalHeading(__('English'))`; actions URL-only/JS-only permanecem sem heading

## Related

- `filament-resource-scaffold` — actions de Resource seguem labels e slug do Resource.
- `filament-relation-page` — actions modais em relation pages seguem esta skill.
- `filament-repeater-create-flow` — actions com Repeater no schema usam heading plural quando criam lote.
- `translation` — heading e labels seguem `.agents/skills/translation/rules/translation-rules.md`.
