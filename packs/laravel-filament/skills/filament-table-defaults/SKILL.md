---
name: filament-table-defaults
description: "Aplicar quando criar ou revisar Table Filament v5 para Resource ou Relation page."
license: MIT
metadata:
  author: coringawc
  version: 2.0.0
  requires:
    - laravel-best-practices
    - spatie-laravel-php-standards
  related:
    - translation
    - filament-app-panel-provider-defaults
    - filament-resource-scaffold
    - filament-action-with-modal-heading
    - enum-with-translations
---

# Filament Table Defaults

## Consistency First

Esta skill padroniza defaults locais da `Table` sem invadir defaults globais do Panel Provider. A tabela deve ser previsível: 25 itens por página, sort default coerente, search apenas em colunas display pesquisáveis e filtros úteis ao modelo.

Preserve decisões explícitas existentes. `created_at desc` é default para tabelas novas, não motivo para substituir ordenações semânticas como `name`, `title` ou `id desc` quando a tela já depende delas.

Densidade extra mora em `rules/`:

- `rules/editable-columns.md` — `TextInputColumn`, `SelectColumn`, `ToggleColumn`, `CheckboxColumn`.
- `rules/advanced-filters.md` — `Filter` com schema custom, `QueryBuilder`, filtros condicionais.
- `rules/performance.md` — `deferLoading()`, `persistFiltersInSession()`, `persistSortInSession()`, eager loading.
- `rules/visual-defaults.md` — `striped()`, `reorderable()`, `groups()`, `recordUrl()`, `recordAction()`.

## Quick Reference

- Consultar Laravel Boost `search-docs` antes de editar com `packages: ['filament/filament']` e queries `table pagination`, `default sort`, `table filters`, `searchable columns`.
- Paginação local: `->defaultPaginationPageOption(25)`. Se customizar `->paginated([...])`, inclua `25`.
- Sort novo: `->defaultSort('created_at', 'desc')` quando existir `created_at` e não houver sort explícito.
- Search: marcar `TextColumn` display com `->searchable()` ou `->searchable(['real_column'])` para valor computado.
- Filtros base: `TrashedFilter` para SoftDeletes, `SelectFilter` para enum/relationship, `TernaryFilter` para boolean, `Filter` com `->schema()` + `->query()` para intervalo.
- Actions de linha: namespace `Filament\Actions\*` (v5). Bulk actions: `->toolbarActions([...])` ou `->groupedBulkActions([...])` (v5).
- Toda action de tabela que abre modal exige `modalHeading(__('English'))` (ver `filament-action-with-modal-heading`).

## Workflow

- [ ] Consultar docs versionadas via Laravel Boost `search-docs` com `packages: ['filament/filament']`.

- [ ] Mapear defaults existentes na tabela:

```bash
vendor/bin/sail bin grep -rE "defaultSort|defaultPaginationPageOption|paginated\(|paginationPageOptions\(|filters\(|recordActions\(|toolbarActions\(" app/Filament
```

- [ ] Em tabela nova ou sem paginação explícita, definir 25:

```php
use Filament\Tables\Table;

public static function configure(Table $table): Table
{
    return $table
        ->defaultPaginationPageOption(25);
}
```

- [ ] Se a tabela usar `paginated([...])` ou `paginationPageOptions([...])`, garantir que `25` está presente:

```php
return $table
    ->paginated([10, 25, 50, 100])
    ->defaultPaginationPageOption(25);
```

- [ ] Definir sort default sem sobrescrever ordem semântica existente:

```php
return $table
    ->defaultSort('created_at', 'desc');
```

Preserve `->defaultSort('name')`, `->defaultSort('title')`, `->defaultSort('id', 'desc')` ou sort de coluna de negócio quando a tela exige leitura alfabética, hierarquia ou ordem de domínio.

- [ ] Marcar search em colunas display reais:

```php
use Filament\Tables\Columns\TextColumn;

TextColumn::make('name')
    ->label(__('Name'))
    ->searchable()
    ->sortable();

TextColumn::make('display_name')
    ->label(__('Display Name'))
    ->searchable(['first_name', 'last_name']);
```

- [ ] Adicionar filtros base só quando o model/tela justificar:

```php
use Filament\Forms\Components\DatePicker;
use Filament\Tables\Filters\Filter;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Filters\TrashedFilter;
use Illuminate\Database\Eloquent\Builder;

return $table
    ->filters([
        TrashedFilter::make(),
        SelectFilter::make('status')
            ->label(__('Status'))
            ->options(StatusEnum::class),
        TernaryFilter::make('is_active')
            ->label(__('Active')),
        Filter::make('created_at')
            ->schema([
                DatePicker::make('created_from')->label(__('Created from')),
                DatePicker::make('created_until')->label(__('Created until')),
            ])
            ->query(fn (Builder $query, array $data): Builder => $query
                ->when($data['created_from'] ?? null, fn (Builder $query, string $date): Builder => $query->whereDate('created_at', '>=', $date))
                ->when($data['created_until'] ?? null, fn (Builder $query, string $date): Builder => $query->whereDate('created_at', '<=', $date))),
    ]);
```

- [ ] Para SoftDeletes, confirmar trait no model antes de usar `TrashedFilter::make()`.

- [ ] Para filtros complexos, ver `rules/advanced-filters.md`.

- [ ] Para colunas editáveis inline, ver `rules/editable-columns.md`.

- [ ] Para `deferLoading`, `persistFiltersInSession`, eager loading, ver `rules/performance.md`.

- [ ] Para `striped`, `reorderable`, `groups`, `recordUrl`, ver `rules/visual-defaults.md`.

- [ ] Testar com Pest/Livewire cobrindo records visíveis, search, filtros principais e sort quando alterado.

## Anti-Patterns

- Não importar `Filament\Tables\Actions\DeleteAction` (namespace v4). Use `Filament\Actions\DeleteAction` (v5).
- Não usar `->actions([...])` na Table (v4). Use `->recordActions([...])` (v5).
- Não usar `->bulkActions([...])` na Table (v4). Use `->toolbarActions([...])` ou `->groupedBulkActions([...])` (v5).
- Não trocar sort explícito de leitura (`name`, `title`) por `created_at desc` sem requisito.
- Não adicionar filtro de data em toda tabela automaticamente; filtro inútil polui UI.
- Não aplicar `TrashedFilter` em model sem `SoftDeletes`.
- Não pesquisar coluna computada sem indicar coluna real pesquisável via `->searchable(['real_column'])`.
- Não duplicar defaults globais do Panel Provider (`Action::iconButton()`, `Section::compact()`) em todas as tabelas.
- Não quebrar tabelas parametrizadas (`includeFilters`, `includeBulkActions`); preserve flags/visibilidade existentes.
- Não usar enum em `SelectFilter` se o enum não implementa `HasLabel` adequadamente.

## Verification

- [ ] `./.agents/skills/_helpers/verify-skill.sh .agents/skills/filament-table-defaults/SKILL.md`
- [ ] `git diff --check -- .agents/skills/filament-table-defaults/SKILL.md`
- [ ] Em PHP editado: `vendor/bin/sail bin pint --dirty --format agent`
- [ ] Em fluxo Filament: `vendor/bin/sail artisan test --compact --filter=Filament`
- [ ] Conferir ausência de namespaces v4: `vendor/bin/sail bin grep -rE "Filament\\\\Tables\\\\Actions|Filament\\\\Forms\\\\Actions" app/Filament` (esperado: 0 resultados).
- [ ] Conferir `defaultPaginationPageOption(25)` e, se houver `paginated([...])`, presença de `25`.
- [ ] Conferir sort default novo ou justificativa para sort semântico preservado.
- [ ] Conferir search/filtros contra colunas reais e relações existentes.

## Related

- `translation` — labels de coluna e filtro seguem a regra de chave-frase em inglês via `__()`.
- `filament-app-panel-provider-defaults` — Panel Provider centraliza defaults globais de actions, sections e brand.
- `filament-resource-scaffold` — Resources novos devem usar tabelas consistentes via esta skill.
- `filament-action-with-modal-heading` — actions de tabela que abrem modal exigem `modalHeading()` traduzido.
- `enum-with-translations` — enums usados em `SelectFilter` precisam de labels traduzidos via `HasLabel`.
