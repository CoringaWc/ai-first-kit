# Visual Defaults

Ajustes visuais e de navegação que melhoram leitura sem mudar comportamento de dados.

## Striped rows

```php
return $table
    ->striped();
```

- Alterna cor de fundo das linhas. Útil em tabelas densas.

## Reorderable

```php
return $table
    ->reorderable('sort_order');
```

- Permite arrastar linhas para reordenar.
- Requer coluna inteira no model (`sort_order`, `position`, `order`).
- Combine com `->defaultSort('sort_order')` para manter ordem visível.
- Adicionar índice na coluna na migration.

## Groups

```php
use Filament\Tables\Grouping\Group;

return $table
    ->groups([
        Group::make('status')
            ->label(__('Status'))
            ->collapsible(),
        Group::make('category.name')
            ->label(__('Category'))
            ->collapsible(),
    ])
    ->defaultGroup('status');
```

- Agrupa linhas por coluna ou relationship.
- `->collapsible()` permite expandir/colapsar grupos no UI.

## Record URL

```php
return $table
    ->recordUrl(fn ($record): string => UserResource::getUrl('view', ['record' => $record]));
```

- Clique na linha navega para a URL.
- Conflita com `recordAction()` — use um ou outro.

## Record Action

```php
return $table
    ->recordAction('edit');
```

- Clique na linha dispara a action nomeada (precisa estar em `->recordActions([...])`).
- Para abrir modal de view: `recordAction('view')`.

## Empty State

```php
use Filament\Actions\Action;
use Filament\Support\Icons\Heroicon;

return $table
    ->emptyStateIcon(Heroicon::OutlinedDocumentText)
    ->emptyStateHeading(__('No records yet'))
    ->emptyStateDescription(__('Create your first record to get started.'))
    ->emptyStateActions([
        Action::make('create')
            ->label(__('Create record'))
            ->url(static::getUrl('create')),
    ]);
```

## Header Actions

```php
use Filament\Actions\Action;
use Filament\Actions\CreateAction;
use Filament\Actions\ExportAction;

return $table
    ->headerActions([
        CreateAction::make(),
        ExportAction::make(),
        Action::make('refresh')
            ->label(__('Refresh'))
            ->icon(Heroicon::OutlinedArrowPath)
            ->action(fn ($livewire) => $livewire->resetTable()),
    ]);
```

## Description e Heading

```php
return $table
    ->heading(__('Active Users'))
    ->description(__('Users who logged in within the last 30 days.'));
```

## Anti-Patterns

- Não combinar `recordUrl()` e `recordAction()` na mesma tabela.
- Não usar `reorderable` sem coluna persistente; reorder em memória é perdido no refresh.
- Não usar `groups()` em tabela com paginação pesada; agrupa apenas a página atual, confunde o usuário.
- Não chamar `Heroicon::Foo` em string `'heroicon-o-foo'` — use o enum sempre.
- Não duplicar `heading()` se a página já tem `getTitle()` definindo o mesmo texto.

## Verification

- [ ] `recordUrl` e `recordAction` não coexistem.
- [ ] `reorderable` usa coluna existente e indexada.
- [ ] Ícones via `Filament\Support\Icons\Heroicon` enum, nunca string.
- [ ] Empty state tem heading, description e action quando aplicável.
