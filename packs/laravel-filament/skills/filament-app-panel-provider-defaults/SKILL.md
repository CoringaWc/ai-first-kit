---
name: filament-app-panel-provider-defaults
description: "Aplicar quando configurar defaults globais de painel Filament v5."
license: MIT
metadata:
  author: coringawc
  version: 2.0.0
  requires:
    - laravel-best-practices
    - spatie-laravel-php-standards
  related:
    - translation
    - filament-table-defaults
    - filament-action-with-modal-heading
    - filament-resource-scaffold
---

# Filament App Panel Provider Defaults

## Consistency First

Esta skill define source-of-truth global para painel Filament v5. Em greenfield com painel único, tudo vive em `AppPanelProvider`. Defaults estáticos de componentes (`Action::configureUsing()`, `Section::configureUsing()`) ficam em `AppServiceProvider::boot()` para serem aplicados antes do boot do painel.

Não duplique defaults globais em Resources/Tables. Se `Action::configureUsing()` centraliza `iconButton()`, não espalhe `->iconButton()` em cada action local.

Multi-painel (admin + app + tenant) com `BasePanelProvider` abstrato é caso avançado e vive em `rules/multi-panel.md`. Não promova um painel a base sem 2+ painéis reais.

## Quick Reference

- Consultar Laravel Boost `search-docs` antes de editar com `packages: ['filament/filament']` e queries `panel configuration`, `configureUsing`, `dark mode`, `spa mode`, `vite theme`.
- Painel único: `AppPanelProvider` concentra `id()`, `path()`, `default()`, `authGuard()`, `viteTheme()`, brand, colors, dark mode, SPA, plugins, discovery.
- Defaults estáticos de componentes (Action, Section): `AppServiceProvider::boot()`.
- Decisão explícita de dark mode obrigatória: `->darkMode()` ou `->darkMode(false)`.
- SPA mode: `->spa()` reduz full-page reloads.
- Vite theme: `->viteTheme('resources/css/filament/app/theme.css')` para tema custom.
- Navigation groups via `__('English')` (ver `translation`).
- Plugins (Shield, Spatie Permission, Copilot) só com requisito explícito.

## Workflow

- [ ] Consultar docs via Laravel Boost `search-docs` com `packages: ['filament/filament']`.

- [ ] Mapear estado atual:

```bash
grep -rE "class .*PanelProvider|configureUsing|->colors\(|->darkMode|->spa\(|navigationGroups|->plugin\(" app/Providers app/Filament
```

- [ ] Em painel único (greenfield padrão), `app/Providers/Filament/AppPanelProvider.php` segue o esqueleto gerado por `php artisan filament:install --panels`. Adicione/ajuste apenas o bloco de defaults globais:

```php
use Filament\Navigation\NavigationGroup;
use Filament\Panel;
use Filament\Support\Colors\Color;

public function panel(Panel $panel): Panel
{
    return $panel
        ->default()
        ->id('app')
        ->path('app')
        ->login()
        ->brandName((string) config('app.name'))
        ->colors(['primary' => Color::Teal])
        ->darkMode(false)
        ->spa()
        ->sidebarCollapsibleOnDesktop()
        ->viteTheme('resources/css/filament/app/theme.css')
        ->navigationGroups([
            NavigationGroup::make(__('Operations')),
            NavigationGroup::make(__('Settings')),
        ]);
    // ->discoverResources(...), ->pages([...]), ->middleware([...]), ->authMiddleware([...]) preservados do scaffold.
}
```

Troque `->darkMode(false)` por `->darkMode()` somente quando UI, tema custom e assets estiverem prontos para dark mode.

- [ ] Defaults estáticos de componentes em `app/Providers/AppServiceProvider.php`:

```php
use Filament\Actions\Action;
use Filament\Actions\AssociateAction;
use Filament\Actions\AttachAction;
use Filament\Actions\CreateAction;
use Filament\Actions\DeleteAction;
use Filament\Actions\DetachAction;
use Filament\Actions\DissociateAction;
use Filament\Actions\EditAction;
use Filament\Actions\ForceDeleteAction;
use Filament\Actions\ReplicateAction;
use Filament\Actions\RestoreAction;
use Filament\Actions\ViewAction;
use Filament\Schemas\Components\Section;

public function boot(): void
{
    Action::configureUsing(fn (Action $action): Action => $action->slideOver());
    Section::configureUsing(fn (Section $section): Section => $section->compact());

    foreach ($this->conventionalActionClasses() as $actionClass) {
        $actionClass::configureUsing(fn (Action $action): Action => $action->iconButton());
    }
}

/**
 * @return list<class-string<Action>>
 */
private function conventionalActionClasses(): array
{
    return [
        AssociateAction::class,
        AttachAction::class,
        CreateAction::class,
        DeleteAction::class,
        DetachAction::class,
        DissociateAction::class,
        EditAction::class,
        ForceDeleteAction::class,
        ReplicateAction::class,
        RestoreAction::class,
        ViewAction::class,
    ];
}
```

- [ ] Adicionar plugins opcionais apenas com requisito explícito e pacote instalado:

```php
->plugins([
    \BezhanSalleh\FilamentShield\FilamentShieldPlugin::make(),
])
```

- [ ] Para projeto com 2+ painéis, ver `rules/multi-panel.md` para `BasePanelProvider` abstrato.

- [ ] Não mover `id()`, `path()`, `default()`, `authGuard()`, `viteTheme()`, discovery ou plugins app-specific entre painéis sem verificar escopo.

- [ ] Testar boot, login, navegação e uma action/table que dependa dos defaults.

## Anti-Patterns

- Não criar `BasePanelProvider` abstrato com 1 único painel; YAGNI até existir segundo painel.
- Não duplicar `Action::configureUsing()` em múltiplos providers.
- Não deixar dark mode implícito; decida `darkMode()` ou `darkMode(false)`.
- Não espalhar `->iconButton()`, `->slideOver()`, `->compact()` em cada action/section local.
- Não mover plugin app-specific para um painel admin ou vice-versa.
- Não usar `setlocale()` ou alternar locale em runtime no provider; locale é fixo via `.env` (ver `translation`).
- Não usar strings pt nos `__()` de navigation groups; sempre chave-frase em inglês.
- Não introduzir ACL/audit/billing plugin sem dependência declarada em `composer.json`.

## Verification

- [ ] `./.agents/skills/_helpers/verify-skill.sh .agents/skills/filament-app-panel-provider-defaults/SKILL.md`
- [ ] `git diff --check -- .agents/skills/filament-app-panel-provider-defaults/SKILL.md`
- [ ] Em PHP editado: `vendor/bin/sail composer pint`
- [ ] `vendor/bin/sail artisan route:list --except-vendor --path=app` (filtra rotas do painel `/app`)
- [ ] `vendor/bin/sail artisan test --compact --filter=Filament`
- [ ] Conferir decisão explícita de dark mode no provider.
- [ ] Conferir `Action::configureUsing()` em `AppServiceProvider::boot()`, não em `panel()`.
- [ ] Conferir navigation groups com `__('English')` (não pt nativo).
- [ ] Conferir plugins com pacote em `composer.json`.

## Related

- `translation` — labels de navigation groups e brand seguem chave-frase em inglês via `__()`.
- `filament-table-defaults` — tabelas consomem defaults globais de actions sem duplicar localmente.
- `filament-action-with-modal-heading` — actions herdam `iconButton`/`slideOver` daqui, mas `modalHeading()` permanece por action.
- `filament-resource-scaffold` — Resources descobertos pelo `discoverResources()` configurado nesta skill.
