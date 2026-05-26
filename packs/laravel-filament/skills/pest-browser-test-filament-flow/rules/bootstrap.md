# Bootstrap Pest Browser + helper loginAsAdmin

Setup único por projeto. Aplique antes do primeiro `tests/Browser/*Test.php`.

## 1. `tests/Pest.php`

Suite `Browser` + config Playwright. Helpers ficam fora deste arquivo.

```php
use Illuminate\Foundation\Testing\LazilyRefreshDatabase;
use Tests\TestCase;

pest()->extend(TestCase::class)
    ->use(LazilyRefreshDatabase::class)
    ->in('Browser');

pest()->browser()
    ->inChrome()
    ->timeout(10000);
```

Nunca commitar `->headed()` no config.

## 2. `tests/Support/browser.php`

Criar uma vez. Registrar em `composer.json` → `autoload-dev.files: ["tests/Support/browser.php"]` e rodar `vendor/bin/sail composer dump-autoload`.

```php
<?php

use App\Models\User;

function loginAsAdmin($page = null): mixed
{
    $admin = User::factory()->admin()->create([
        'email' => 'admin@test.local',
        'password' => 'password',
    ]);

    $page = $page ?? visit('/admin/login');

    return $page
        ->assertSee(__('Sign in'))
        ->fill('email', $admin->email)
        ->fill('password', 'password')
        ->click(__('Sign in'))
        ->assertNoJavaScriptErrors()
        ->assertNoConsoleLogs();
}
```

## 3. Por que helper fora do Pest.php

- `Pest.php` é só configuração de suíte; misturar helpers vira god-file.
- Helper autoloadado por composer roda **antes** de qualquer teste, sem `require` manual.
- Refatoração (`loginAsCompanyUser`, `loginAsCollaborator`) adiciona função no mesmo `tests/Support/browser.php`.

## 4. Pitfalls

- ❌ `require __DIR__.'/Support/browser.php'` no `Pest.php`. Use `autoload-dev.files`.
- ❌ Helper sem `User::factory()->admin()` — login via DB direto pula middleware Filament e mascara bug de panel auth.
- ❌ Hardcodar `'password'` em produção. OK em teste: o factory cria o user na hora.
