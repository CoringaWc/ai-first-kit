# Advanced Filters

Filtros que ultrapassam `SelectFilter`/`TernaryFilter`/`TrashedFilter`.

## Filter com schema custom

```php
use Filament\Forms\Components\DatePicker;
use Filament\Forms\Components\Select;
use Filament\Tables\Filters\Filter;
use Illuminate\Database\Eloquent\Builder;

Filter::make('date_range_with_status')
    ->schema([
        DatePicker::make('from')->label(__('From')),
        DatePicker::make('until')->label(__('Until')),
        Select::make('status')
            ->label(__('Status'))
            ->options(StatusEnum::class),
    ])
    ->query(fn (Builder $query, array $data): Builder => $query
        ->when($data['from'] ?? null, fn (Builder $q, string $d): Builder => $q->whereDate('created_at', '>=', $d))
        ->when($data['until'] ?? null, fn (Builder $q, string $d): Builder => $q->whereDate('created_at', '<=', $d))
        ->when($data['status'] ?? null, fn (Builder $q, string $s): Builder => $q->where('status', $s)));
```

## Filter toggle

```php
Filter::make('verified_only')
    ->label(__('Verified only'))
    ->toggle()
    ->query(fn (Builder $query): Builder => $query->whereNotNull('verified_at'));
```

- `->toggle()` renderiza como switch único, sem schema.

## Filter com indicator custom

```php
use Filament\Tables\Filters\Indicator;

Filter::make('high_priority')
    ->schema([
        Select::make('priority')
            ->options(['high' => __('High'), 'urgent' => __('Urgent')]),
    ])
    ->query(fn (Builder $query, array $data): Builder => $query
        ->when($data['priority'] ?? null, fn (Builder $q, string $p): Builder => $q->where('priority', $p)))
    ->indicateUsing(function (array $data): array {
        if (! ($data['priority'] ?? null)) {
            return [];
        }

        return [
            Indicator::make(__('Priority: :priority', ['priority' => $data['priority']]))
                ->removeField('priority'),
        ];
    });
```

## QueryBuilder (Filament Pro)

```php
use Filament\Tables\Filters\QueryBuilder;
use Filament\Tables\Filters\QueryBuilder\Constraints\BooleanConstraint;
use Filament\Tables\Filters\QueryBuilder\Constraints\DateConstraint;
use Filament\Tables\Filters\QueryBuilder\Constraints\SelectConstraint;
use Filament\Tables\Filters\QueryBuilder\Constraints\TextConstraint;

QueryBuilder::make()
    ->constraints([
        TextConstraint::make('name')->label(__('Name')),
        SelectConstraint::make('status')
            ->label(__('Status'))
            ->options(StatusEnum::class),
        BooleanConstraint::make('is_active')->label(__('Active')),
        DateConstraint::make('created_at')->label(__('Created at')),
    ]);
```

- Requer licença Filament Pro.
- Permite filtros combinados AND/OR pelo usuário em runtime.
- Substitui múltiplos `Filter::make()` por uma UI unificada.

## Filter condicional por permissão

```php
Filter::make('archived')
    ->visible(fn (): bool => auth()->user()?->can('viewArchived', Project::class) ?? false)
    ->query(fn (Builder $query): Builder => $query->whereNotNull('archived_at'));
```

## Anti-Patterns

- Não duplicar lógica de filtro em escopo do Model + Filter; mantenha em um lugar (`Builder` macro ou método na Resource).
- Não filtrar por coluna não indexada em tabelas grandes sem confirmar plano de query (`EXPLAIN`).
- Não usar `Filter` com schema sem `->query()` — filtro aplica nada e confunde.
- Não combinar `QueryBuilder` com `Filter::make()` que sobreponham os mesmos campos.

## Verification

- [ ] Filtros com `->schema()` sempre têm `->query()` correspondente.
- [ ] `QueryBuilder` é usado apenas com licença Pro confirmada.
- [ ] Filtros sensíveis usam `->visible(fn () => $user->can(...))`.
- [ ] Indicators custom usam `__('English')` nas mensagens.
