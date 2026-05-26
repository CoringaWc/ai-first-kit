# Extraction Patterns — Helpers e Concerns de Teste

Este documento detalha os snippets de helpers `tests/Support/*.php` e traits `tests/Concerns/*.php` referenciados em `SKILL.md`.

## Helper funcional de auth — `tests/Support/auth.php`

```php
<?php

declare(strict_types=1);

namespace Tests\Support;

use App\Models\Admin;
use App\Models\Company;
use App\Models\User;

use function Pest\Laravel\actingAs;

function loginAsAdmin(): Admin
{
    $admin = Admin::factory()->create();

    actingAs($admin, 'admin');

    return $admin;
}

function actingAsCompanyAdmin(?Company $company = null): User
{
    $company ??= Company::factory()->create();
    $user = User::factory()->for($company)->create();

    actingAs($user, 'web');

    return $user;
}
```

## Helper de browser — `tests/Support/browser.php`

Pest 4 browser, seletores via `__()` conforme D33.

```php
<?php

declare(strict_types=1);

namespace Tests\Support;

use App\Models\Admin;
use Pest\Browser\Page;

function loginAsAdmin(Page $page): Admin
{
    $admin = Admin::factory()->create();

    $page->visit(route('filament.admin.auth.login'))
        ->fill(__('Email address'), $admin->email)
        ->fill(__('Password'), 'password')
        ->click(__('Sign in'));

    return $admin;
}
```

## Registro em `tests/Pest.php`

```php
<?php

use Illuminate\Foundation\Testing\LazilyRefreshDatabase;
use Tests\TestCase;

pest()->extend(TestCase::class)
    ->use(LazilyRefreshDatabase::class)
    ->in('Feature');

pest()->extend(TestCase::class)
    ->use(LazilyRefreshDatabase::class)
    ->in('Unit');

require_once __DIR__ . '/Support/auth.php';
require_once __DIR__ . '/Support/browser.php';
require_once __DIR__ . '/Support/faker.php';
```

## Uso por arquivo de teste

```php
<?php

use function Tests\Support\loginAsAdmin;

it('lista usuários ativos', function (): void {
    loginAsAdmin();

    // ...
});
```

## Trait em `tests/Concerns/` (apenas quando exige `setUp()` ou estado)

```php
<?php

declare(strict_types=1);

namespace Tests\Concerns;

use Filament\Facades\Filament;

trait RegistersTestPanels
{
    protected function setFilamentPanel(string $panel = 'app'): void
    {
        Filament::setCurrentPanel(Filament::getPanel($panel));
    }
}
```

Registro por arquivo:

```php
use Tests\Concerns\RegistersTestPanels;

uses(RegistersTestPanels::class);

beforeEach(function (): void {
    $this->setFilamentPanel('app');
});
```

Registro global apenas quando todos os testes da suite precisam:

```php
uses(RegistersTestPanels::class)->in('Feature');
```

## Tabela de migração de duplicação

| Antes | Depois |
| --- | --- |
| 6 chamadas repetidas de `actingAs` + factory de admin | `loginAsAdmin()` em `tests/Support/auth.php` |
| Seed de permissões em muitos arquivos | `seedDefaultPermissions()` em `tests/Support/permissions.php` |
| Fake BR repetido com provider custom | helper em `tests/Support/faker.php` |
| Setup de browser login em 5+ browser tests | `loginAsAdmin($page)` em `tests/Support/browser.php` |
| Setup de upload/storage repetido | `tests/Support/storage.php` ou inline se único |
