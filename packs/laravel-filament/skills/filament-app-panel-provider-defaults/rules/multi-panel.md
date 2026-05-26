# Multi-Panel Setup

Quando criar `BasePanelProvider` abstrato e quando manter providers independentes.

## Quando promover a base

Crie `BasePanelProvider` apenas quando **2+ painéis reais** compartilham defaults significativos (brand, colors, dark mode, SPA, middleware, defaults de plugin comum).

Anti-padrão: criar `BasePanelProvider` com 1 painel "para o futuro". YAGNI. Promova quando o segundo painel chegar.

## Estrutura

```
app/Providers/Filament/
    BasePanelProvider.php       # abstrato, defaults comuns
    AppPanelProvider.php        # estende, painel de usuário final
    AdminPanelProvider.php      # estende, painel administrativo
```

## BasePanelProvider abstrato

```php
<?php

declare(strict_types=1);

namespace App\Providers\Filament;

use Filament\Panel;
use Filament\PanelProvider;
use Filament\Support\Colors\Color;

abstract class BasePanelProvider extends PanelProvider
{
    protected function configureBasePanel(Panel $panel): Panel
    {
        return $panel
            ->brandName((string) config('app.name'))
            ->colors([
                'primary' => Color::Teal,
            ])
            ->darkMode(false)
            ->spa()
            ->sidebarCollapsibleOnDesktop();
    }
}
```

## Painel concreto

```php
<?php

declare(strict_types=1);

namespace App\Providers\Filament;

use Filament\Navigation\NavigationGroup;
use Filament\Pages\Dashboard;
use Filament\Panel;

final class AppPanelProvider extends BasePanelProvider
{
    public function panel(Panel $panel): Panel
    {
        return $this->configureBasePanel(
            $panel
                ->default()
                ->id('app')
                ->path('app')
                ->login()
        )
            ->viteTheme('resources/css/filament/app/theme.css')
            ->authGuard('web')
            ->discoverResources(in: app_path('Filament/App/Resources'), for: 'App\\Filament\\App\\Resources')
            ->discoverPages(in: app_path('Filament/App/Pages'), for: 'App\\Filament\\App\\Pages')
            ->pages([Dashboard::class])
            ->navigationGroups([
                NavigationGroup::make(__('Operations')),
                NavigationGroup::make(__('Settings')),
            ]);
    }
}
```

```php
<?php

declare(strict_types=1);

namespace App\Providers\Filament;

use Filament\Panel;

final class AdminPanelProvider extends BasePanelProvider
{
    public function panel(Panel $panel): Panel
    {
        return $this->configureBasePanel(
            $panel
                ->id('admin')
                ->path('admin')
                ->login()
        )
            ->viteTheme('resources/css/filament/admin/theme.css')
            ->authGuard('web')
            ->discoverResources(in: app_path('Filament/Admin/Resources'), for: 'App\\Filament\\Admin\\Resources')
            ->discoverPages(in: app_path('Filament/Admin/Pages'), for: 'App\\Filament\\Admin\\Pages')
            ->plugins([
                \BezhanSalleh\FilamentShield\FilamentShieldPlugin::make(),
            ]);
    }
}
```

## Distribuição de responsabilidades

| Configuração | Onde mora |
|---|---|
| `brandName`, `colors`, `darkMode`, `spa`, `sidebarCollapsibleOnDesktop` | `BasePanelProvider` |
| `id`, `path`, `default`, `login`, `authGuard` | Painel concreto |
| `viteTheme` (cada painel tem tema próprio) | Painel concreto |
| `discoverResources`, `discoverPages`, `discoverWidgets` | Painel concreto |
| `navigationGroups` | Painel concreto |
| `pages([Dashboard::class])` | Painel concreto |
| Plugin específico (Shield no admin) | Painel concreto |
| Plugin comum (ex: tradução global, copilot global) | `BasePanelProvider` |
| `Action::configureUsing()`, `Section::configureUsing()` | `AppServiceProvider::boot()` (global) |

## Discovery por painel

Resources, pages e widgets devem ser fisicamente segregados:

```
app/Filament/App/Resources/
app/Filament/App/Pages/
app/Filament/App/Widgets/
app/Filament/Admin/Resources/
app/Filament/Admin/Pages/
app/Filament/Admin/Widgets/
```

Não compartilhe Resource entre painéis duplicando classe. Se a mesma entidade aparece em ambos os painéis com permissões diferentes, prefira uma policy por painel ou um Resource único + autorização granular.

## Tenant panel

Quando houver tenant (cada empresa/organização tem painel próprio):

```php
final class TenantPanelProvider extends BasePanelProvider
{
    public function panel(Panel $panel): Panel
    {
        return $this->configureBasePanel(
            $panel
                ->id('tenant')
                ->path('tenant')
        )
            ->tenant(Company::class, slugAttribute: 'slug')
            ->tenantMiddleware([
                \App\Http\Middleware\EnsureUserBelongsToTenant::class,
            ], isPersistent: true);
    }
}
```

## Anti-Patterns

- Não criar `BasePanelProvider` com 1 painel único.
- Não mover `id()`, `path()`, `default()`, `viteTheme()` para a base — são identidade do painel concreto.
- Não duplicar Resource entre painéis; use discovery por path + policy por painel.
- Não compartilhar plugin app-specific (copilot, billing) via base; vai no painel concreto.
- Não definir `Action::configureUsing()` em cada provider; vai em `AppServiceProvider::boot()` e aplica globalmente.

## Verification

- [ ] `BasePanelProvider` é `abstract` e tem método `configureBasePanel(Panel $panel): Panel`.
- [ ] Cada provider concreto tem `id()`, `path()`, `viteTheme()` próprios.
- [ ] Discovery aponta para namespaces distintos (`App\\Filament\\App\\Resources` vs `App\\Filament\\Admin\\Resources`).
- [ ] Plugins app-specific ficam no painel concreto, não na base.
- [ ] `Action::configureUsing()` aparece uma única vez (em `AppServiceProvider::boot()`).
