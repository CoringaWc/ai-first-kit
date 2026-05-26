# Editable Columns

Colunas que permitem edição inline na tabela, sem abrir modal ou navegar.

## TextInputColumn

```php
use Filament\Tables\Columns\TextInputColumn;

TextInputColumn::make('display_name')
    ->label(__('Display Name'))
    ->rules(['required', 'max:255'])
    ->sortable();
```

- `->rules([...])` é obrigatório para validar a entrada antes de persistir.
- Combine com `->disabled(fn ($record) => ! auth()->user()->can('update', $record))` para autorização inline.

## SelectColumn

```php
use Filament\Tables\Columns\SelectColumn;

SelectColumn::make('status')
    ->label(__('Status'))
    ->options(StatusEnum::class)
    ->rules(['required']);
```

- Aceita `Enum::class` quando o enum implementa `HasLabel`.
- Para options dinâmicas, use closure: `->options(fn () => Type::pluck('name', 'id'))`.

## ToggleColumn

```php
use Filament\Tables\Columns\ToggleColumn;

ToggleColumn::make('is_active')
    ->label(__('Active'));
```

- Salva direto no banco no clique. Sem confirmação.
- Para boolean com confirmação, use `Action` com `requiresConfirmation()`.

## CheckboxColumn

```php
use Filament\Tables\Columns\CheckboxColumn;

CheckboxColumn::make('verified')
    ->label(__('Verified'));
```

- Comportamento idêntico a `ToggleColumn`, visual de checkbox.

## Anti-Patterns

- Não usar editable column sem `->rules()` em campo validável (string, numérico).
- Não usar `TextInputColumn` para campos sensíveis (preço, quantidade financeira); prefira ação com modal e confirmação.
- Não combinar editable column com `->action()` na mesma linha — confunde o usuário sobre o que persiste o quê.
- Editable column ignora `mutateFormDataBeforeSave()` da Resource; lógica de transformação precisa estar no observer/setter do model.

## Verification

- [ ] Cada editable column tem `->rules([...])` quando o campo é validável.
- [ ] Autorização inline via `->disabled(fn ($record) => ...)` quando policy se aplica.
- [ ] Em campo sensível, substituído por action com modal.
