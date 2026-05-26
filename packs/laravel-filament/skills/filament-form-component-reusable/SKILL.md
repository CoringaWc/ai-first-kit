---
name: filament-form-component-reusable
description: "Aplicar quando criar componente reutilizável de form Filament v5 com lógica própria e uso em 2+ contextos do painel."
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
    - translation
    - action-class
---

# Filament Form Component Reusable

## Consistency First

Componente reutilizável de form Filament v5 existe em duas formas distintas: **custom field** (classe estendendo `Filament\Forms\Components\Field` com view própria em Blade, para comportamento JS/Alpine ou renderização custom) e **bloco estático reutilizável** (classe simples com método `make()` retornando `Fieldset`/`Group`/array de componentes Filament, sem view própria). Use apenas quando a interação aparece em **2+ contextos reais** do painel. Toda string visível usa chave-frase em inglês via `__()` resolvida em `lang/pt_BR.json` conforme `.agents/skills/translation/rules/translation-rules.md`.

Não criar Livewire puro dentro do painel para campo, bloco ou autocomplete que pertence ao painel — Filament já fornece o ciclo de vida. Componentes que apenas configuram `TextInput::make()` (ex.: `CpfInput::make()`) pertencem a métodos privados de `<Model>Form` (`filament-schema-class`), não a componente reutilizável.

## Quick Reference

- Path canônico: `app/Filament/Forms/Components/<Name>.php`.
- Custom field: estende `Filament\Forms\Components\Field`; view em `resources/views/filament/forms/components/<kebab-name>.blade.php`.
- Bloco estático: classe simples com `public static function make(): Fieldset|Group|array`.
- Gerar custom field: `vendor/bin/sail artisan make:filament-form-field <Name> --no-interaction`.
- Form components: `Filament\Forms\Components\*`.
- Layout components: `Filament\Schemas\Components\*` (Fieldset, Grid, Section, Tabs).
- Utilities reativas: `Filament\Schemas\Components\Utilities\Get` e `Set`.
- Critério de extração: 2+ contextos reais. Uso único → método privado do `<Model>Form`.
- View do custom field usa o wrapper Filament: `<x-dynamic-component :component="$getFieldWrapperView()" :field="$field">`.
- Regra de negócio pesada (consulta externa, integração, persistência) sai para `app/Actions` ou service. O componente orquestra UI, estado e validação.

## Workflow

- [ ] Confirmar que o comportamento aparece em 2+ contextos. Listar os Resources/schemas consumidores antes de criar.

- [ ] Buscar componente existente no projeto antes de criar:

```bash
vendor/bin/sail php -r "foreach (glob('app/Filament/Forms/Components/*.php') as \$f) echo \$f, PHP_EOL;"
```

- [ ] Se for apenas composição de campos existentes por Model, parar e usar `<Model>Form` privado (`filament-schema-class`).

- [ ] Para custom field com view própria, gerar via Sail e manter namespace v5:

```bash
vendor/bin/sail artisan make:filament-form-field PostalCodeLookupField --no-interaction
```

```php
namespace App\Filament\Forms\Components;

use Filament\Forms\Components\Field;

class PostalCodeLookupField extends Field
{
    protected string $view = 'filament.forms.components.postal-code-lookup-field';
}
```

- [ ] Garantir que a view do custom field usa o wrapper Filament:

```blade
<x-dynamic-component :component="$getFieldWrapperView()" :field="$field">
    <div x-data="postalCodeLookup()" x-init="init()">
        {{-- UI custom --}}
    </div>
</x-dynamic-component>
```

- [ ] Para bloco com vários campos persistidos, preferir classe estática que devolve `Fieldset`/`Group`/array:

```php
namespace App\Filament\Forms\Components;

use Filament\Forms\Components\TextInput;
use Filament\Schemas\Components\Fieldset;

class BrazilianAddressFields
{
    public static function make(): Fieldset
    {
        return Fieldset::make(__('Address'))
            ->schema([
                TextInput::make('postal_code')->label(__('Postal code')),
                TextInput::make('street')->label(__('Street')),
                TextInput::make('city')->label(__('City')),
                TextInput::make('state')->label(__('State'))->maxLength(2),
            ]);
    }
}
```

- [ ] Consumir o componente a partir de `<Model>Form::components()`:

```php
use App\Filament\Forms\Components\BrazilianAddressFields;
use App\Filament\Forms\Components\PostalCodeLookupField;

public static function components(): array
{
    return [
        PostalCodeLookupField::make('postal_code')->required(),
        BrazilianAddressFields::make(),
    ];
}
```

- [ ] Para reatividade entre campos, usar `Get`/`Set` de `Filament\Schemas\Components\Utilities` dentro do componente ou do schema consumidor, conforme a responsabilidade.

- [ ] Adicionar cada label nova em `lang/pt_BR.json` conforme `.agents/skills/translation/rules/translation-rules.md` §8.

- [ ] Criar teste Pest cobrindo pelo menos um schema consumidor e o comportamento principal (validação, lookup, estado reativo).

## Anti-Patterns

- ❌ Criar Livewire puro (`extends \Livewire\Component`) para campo ou bloco que pertence ao painel Filament.
- ❌ Criar componente reutilizável para uso único. Configure inline no `<Model>Form`.
- ❌ Confundir custom field com bloco estático: custom field tem view própria e estado; bloco estático compõe campos existentes em layout.
- ❌ Embrulhar simplesmente `TextInput::make()` numa classe (`CpfInput::make()`) sem view própria, lógica JS/Alpine ou estado custom. Use método privado de `<Model>Form`.
- ❌ Representar bloco multi-campo persistido como `Field` único sem contrato claro de estado. Use `Fieldset`/`Group`/array.
- ❌ Importar `Filament\Tables\Actions\*` ou `Filament\Forms\Actions\*`. Em v5 actions vivem em `Filament\Actions\*`.
- ❌ Confundir namespaces de form vs layout: form components em `Filament\Forms\Components`; layout (Fieldset, Grid, Section, Tabs) em `Filament\Schemas\Components`.
- ❌ Regra de negócio pesada (HTTP externo, persistência cruzada) dentro do componente. Delegue a `app/Actions`, policy, enum ou service.
- ❌ Consulta externa sem timeout, fallback e teste de erro. Autocomplete/lookup deve falhar de forma segura.
- ❌ Acoplar componente que promete reutilização a um Resource específico (constantes hardcoded, dependências de model específico).

## Verification

- [ ] `.agents/skills/_helpers/verify-skill.sh .agents/skills/filament-form-component-reusable/SKILL.md`
- [ ] `vendor/bin/sail php -r 'json_decode(file_get_contents("lang/pt_BR.json"), true, 512, JSON_THROW_ON_ERROR); echo "OK\n";'`
- [ ] `vendor/bin/sail bin pint --dirty --format agent`
- [ ] `vendor/bin/sail bin phpstan analyse`
- [ ] `vendor/bin/sail artisan test --compact --filter=PostalCodeLookupField`
- [ ] Confirmar 2+ schemas consumidores ou documentar a recusa de extração
- [ ] Verificar imports v5 corretos: `Filament\Forms\Components`, `Filament\Schemas\Components`, `Filament\Schemas\Components\Utilities`

## Related

- `filament-schema-class` — `<Model>Form` consome componentes reutilizáveis quando há 2+ contextos.
- `filament-resource-scaffold` — Resource delega ao `<Model>Form` que orquestra os componentes.
- `translation` — toda string visível segue `.agents/skills/translation/rules/translation-rules.md`.
- `action-class` — regra de negócio pesada acionada pelo componente vai para `app/Actions`.
