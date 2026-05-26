---
name: filament-page-with-inline-blade
description: "Aplicar quando criar página Filament v5 custom com markup Blade local."
license: MIT
metadata:
  author: coringawc
  version: 2.0.0
  requires:
    - laravel-best-practices
    - spatie-laravel-php-standards
  related:
    - filament-resource-scaffold
    - filament-schema-class
    - filament-form-component-reusable
    - translation
---

# Filament Page With Inline Blade

## Consistency First

Página Filament v5 (`Filament\Pages\Page` standalone ou `Filament\Resources\Pages\Page` resource-scoped) já é componente Livewire — não criar Livewire puro fora do painel. `BasePage::render()` retorna `Illuminate\Contracts\View\View`; não sobrescrever para devolver `Blade::render()` (que retorna `string`). O padrão é preservar `protected string $view = 'filament-panels::pages.page'` e injetar markup via `Html::make(Blade::render(...))` dentro de `content(Schema $schema)`. Toda string visível usa chave-frase em inglês via `__()` resolvida em `lang/pt_BR.json` conforme `.agents/skills/translation/rules/translation-rules.md`.

## Quick Reference

- Standalone page: estende `Filament\Pages\Page`.
- Resource-scoped page: estende `Filament\Resources\Pages\Page` com `protected static string $resource`.
- `$view` é **instance property** em v5: `protected string $view = 'filament-panels::pages.page';`. Nunca static.
- `$navigationIcon: string|BackedEnum|null` com `Heroicon::` enum.
- Padrão default: `Html::make(fn (): HtmlString => new HtmlString(Blade::render(<<<'BLADE' ... BLADE, $data)))` em `content()`.
- **Critério inline vs arquivo**: <30 linhas inline; ≥30 linhas extrair para `.blade.php` separado.
- Extração obrigatória também quando: usa `@push`/`@stack`; reutilização real por duas ou mais pages.
- Arquivo separado: `View::make('filament.<panel>.pages.<slug>')->viewData([...])` dentro de `content()`.
- Página é Livewire: propriedades públicas, `mount()`, actions, eventos diretos na classe.

## Workflow

- [ ] Decidir escopo da classe antes do markup:

```php
use Filament\Pages\Page;
// ou: use Filament\Resources\Pages\Page para resource-scoped.
```

- [ ] Gerar via Sail quando aplicável:

```bash
vendor/bin/sail artisan make:filament-page CompanyReadiness --panel=app --no-interaction
```

- [ ] Manter shell Filament e usar `content()` com `Html::make()` quando o markup tem <30 linhas:

```php
use BackedEnum;
use Filament\Pages\Page;
use Filament\Schemas\Components\Html;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Illuminate\Contracts\Support\Htmlable;
use Illuminate\Support\Facades\Blade;
use Illuminate\Support\HtmlString;

class CompanyReadiness extends Page
{
    protected static string|BackedEnum|null $navigationIcon = Heroicon::ShieldCheck;

    protected string $view = 'filament-panels::pages.page';

    public function getTitle(): string|Htmlable
    {
        return __('Company readiness');
    }

    public function content(Schema $schema): Schema
    {
        return $schema->components([
            Html::make(fn (): HtmlString => new HtmlString(
                Blade::render(<<<'BLADE'
<div class="space-y-4">
    <section class="rounded-xl border border-gray-200 bg-white p-5 shadow-sm dark:border-white/10 dark:bg-gray-900">
        <p class="text-sm font-medium text-gray-500 dark:text-gray-400">{{ __('Current company') }}</p>
        <h2 class="mt-1 text-xl font-semibold text-gray-950 dark:text-white">{{ $companyName }}</h2>
    </section>
</div>
BLADE,
                    ['companyName' => $this->companyName],
                ),
            ))->columnSpanFull(),
        ]);
    }
}
```

- [ ] Para markup ≥30 linhas, `@push`/`@stack` ou template reutilizável: extrair para `.blade.php` e referenciar com `View::make()`:

```php
use Filament\Schemas\Components\View;

public function content(Schema $schema): Schema
{
    return $schema->components([
        View::make('filament.app.pages.company-billing')
            ->viewData([
                'companyName' => $this->companyName,
                'invoices' => $this->invoices,
            ]),
    ]);
}
```

Arquivo em `resources/views/filament/<panel>/pages/<slug>.blade.php`.

- [ ] Passar para o template apenas dados de apresentação já resolvidos. Regra de negócio, autorização, queries e cálculos ficam na classe da page ou em Actions.

- [ ] Page resource-scoped preserva o vínculo com o Resource:

```php
use App\Filament\App\Resources\Projects\ProjectResource;
use Filament\Resources\Pages\Concerns\InteractsWithRecord;
use Filament\Resources\Pages\Page;

class ProjectChecklist extends Page
{
    use InteractsWithRecord;

    protected static string $resource = ProjectResource::class;

    protected static bool $shouldRegisterNavigation = false;

    protected string $view = 'filament-panels::pages.page';

    public function mount(int|string $record): void
    {
        $this->record = $this->resolveRecord($record);
    }
}
```

- [ ] Adicionar cada label nova em `lang/pt_BR.json` conforme `.agents/skills/translation/rules/translation-rules.md` §8.

- [ ] Cobrir com Pest/Livewire: acesso, título, dados renderizados, evento/método público se houver interação.

## Anti-Patterns

- ❌ Sobrescrever `render()` retornando `Blade::render()` ou `string`. `BasePage::render()` retorna `View`.
- ❌ `protected static string $view`. Em v5 é instance property: `protected string $view`.
- ❌ `protected static ?string $navigationIcon`. Property é `string|BackedEnum|null`.
- ❌ Criar Livewire puro (`extends \Livewire\Component`) para resolver página do painel. Page Filament já é Livewire.
- ❌ Heredoc inline com ≥30 linhas. Extraia para `.blade.php`.
- ❌ Criar `.blade.php` separado para template local, curto, sem `@push`/`@stack` e sem reuso. Inline resolve.
- ❌ Query, permissão, regra de domínio ou chamada a serviço externo dentro do heredoc.
- ❌ Renderizar HTML de usuário sem escaping Blade (`{{ }}`) ou sanitização explícita.
- ❌ Esquecer `__()` em textos visíveis. Toda string visível segue `translation-rules.md`.
- ❌ String de ícone (`'heroicon-o-shield-check'`). Use `Heroicon::ShieldCheck`.

## Verification

- [ ] `.agents/skills/_helpers/verify-skill.sh .agents/skills/filament-page-with-inline-blade/SKILL.md`
- [ ] `vendor/bin/sail php -r 'json_decode(file_get_contents("lang/pt_BR.json"), true, 512, JSON_THROW_ON_ERROR); echo "OK\n";'`
- [ ] `vendor/bin/sail bin pint --dirty --format agent`
- [ ] `vendor/bin/sail bin phpstan analyse`
- [ ] `vendor/bin/sail artisan test --compact --filter=CompanyReadiness`
- [ ] Em page resource-scoped com `InteractsWithRecord`, testar mount com `['record' => $model->getRouteKey()]`
- [ ] Confirmar: `$view` instance (não static); `render()` não sobrescrito; heredoc <30L ou extraído; textos via `__()`

## Related

- `filament-resource-scaffold` — Resources definem onde pages resource-scoped entram.
- `filament-schema-class` — preferir schemas/componentes Filament quando markup custom não for necessário.
- `filament-form-component-reusable` — extrair componente reutilizável quando a customização aparecer em duas ou mais pages.
- `translation` — toda string visível segue `.agents/skills/translation/rules/translation-rules.md`.
