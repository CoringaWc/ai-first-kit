---
name: policy-native-laravel
description: "Aplicar quando adicionar autorização para Model ou Resource Laravel com Gate e Policy nativos do framework."
license: MIT
metadata:
  author: coringawc
  version: 2.0.0
  requires:
    - laravel-best-practices
    - spatie-laravel-php-standards
  related:
    - filament-resource-scaffold
    - filament-nested-resource
    - model-with-factory-and-seeder
---

# Policy Native Laravel

## Consistency First

Autorização do projeto usa **policies nativas do Laravel 13** com autodiscovery. Não há `AuthServiceProvider` neste app — não criar. Não usar `spatie/laravel-permission` por padrão (caminho opt-in vive em `policy-with-spatie-permission`). Policies recebem o usuário autenticado tipado via **union** dos models reais de usuário do projeto e decidem pelo `instanceof` + relação de domínio (ex.: `belongsToCompany()`), não por nome de permissão em string.

## Quick Reference

- Criar com `vendor/bin/sail artisan make:policy <Model>Policy --model=<Model> --no-interaction`.
- Sem `AuthServiceProvider`. Autodiscovery resolve `App\Models\X` → `App\Policies\XPolicy`.
- Assinatura tipa o usuário por **union** dos models reais (ex.: `Admin|User`). Nunca `Authenticatable` solto.
- Decisão por `instanceof` + relação/atributo de domínio (`belongsToCompany($record)`, `is_active`).
- Métodos cobrem `viewAny`, `view`, `create`, `update`, `delete`, `restore`, `forceDelete`.
- Retorno `bool`. `Response::deny('mensagem')` apenas quando UI precisa do motivo.
- Filament v5 respeita policy do model do Resource automaticamente. Sem hooks manuais.
- Testes Pest cobrem happy path por papel + negação cross-tenant.

## Workflow

- [ ] Gerar a policy:

```bash
vendor/bin/sail artisan make:policy ProjectPolicy --model=Project --no-interaction
```

- [ ] Tipar o ator pela union real do projeto e decidir por `instanceof` + relação de domínio:

```php
<?php

namespace App\Policies;

use App\Models\Admin;
use App\Models\Project;
use App\Models\User;

class ProjectPolicy
{
    public function viewAny(Admin|User $user): bool
    {
        return $user->is_active;
    }

    public function view(Admin|User $user, Project $project): bool
    {
        if ($user instanceof Admin) {
            return true;
        }

        return $user->is_active && $user->belongsToCompany($project);
    }

    public function create(Admin|User $user): bool
    {
        if ($user instanceof Admin) {
            return true;
        }

        return $user->is_active && filled($user->company_id);
    }

    public function update(Admin|User $user, Project $project): bool
    {
        return $this->view($user, $project);
    }

    public function delete(Admin|User $user, Project $project): bool
    {
        return $user instanceof Admin;
    }
}
```

- [ ] Confirmar autodiscovery (sem registrar manualmente):

```bash
vendor/bin/sail artisan tinker --execute 'echo Gate::getPolicyFor(App\Models\Project::class)::class;'
# Esperado: App\Policies\ProjectPolicy
```

- [ ] Usar a policy no Filament Resource. O painel respeita automaticamente:

```php
public static function canViewAny(): bool
{
    return auth()->user()?->can('viewAny', Project::class) ?? false;
}
```

- [ ] Cobrir com Pest (happy path + negação cross-tenant):

```php
it('allows admin to view any project', function () {
    $admin = Admin::factory()->create();
    expect($admin->can('viewAny', Project::class))->toBeTrue();
});

it('denies user from another company', function () {
    $project = Project::factory()->create();
    $outsider = User::factory()->create(['company_id' => Company::factory()->create()->id]);
    expect($outsider->can('view', $project))->toBeFalse();
});
```

## Anti-Patterns

- ❌ Criar `App\Providers\AuthServiceProvider` ou registrar `protected $policies` manualmente. Laravel 13 usa autodiscovery; este projeto não tem esse provider.
- ❌ `function view(Authenticatable $user, ...)`. Tipar pela union real (`Admin|User`) preserva inferência e bloqueia atores indevidos.
- ❌ Decidir por string de permissão (`$user->can('view-project')`) sem coluna/relação correspondente. Use `instanceof` + relação de domínio.
- ❌ Instalar `spatie/laravel-permission` neste fluxo. Caminho opt-in está em `policy-with-spatie-permission`.
- ❌ Retornar `true` em `viewAny` sem checar `is_active`. Usuário desativado não acessa o painel.
- ❌ Omitir negação cross-tenant nos testes. O bug típico é `view()` retornar `true` para qualquer registro porque esqueceram `belongsToCompany()`.
- ❌ Esquecer `viewAny` na policy. Filament chama o método para listar registros; ausência derruba o panel ou libera acesso indevido.

## Verification

- [ ] `.agents/skills/_helpers/verify-skill.sh .agents/skills/policy-native-laravel/SKILL.md`
- [ ] `vendor/bin/sail artisan tinker --execute 'echo Gate::getPolicyFor(App\Models\Project::class)::class;'` retorna a policy correta
- [ ] `vendor/bin/sail artisan test --compact --filter=ProjectPolicy`
- [ ] `vendor/bin/sail bin pint --dirty --format agent`
- [ ] `vendor/bin/sail bin phpstan analyse`
- [ ] Confirmar ausência de Spatie no diff: `! git diff --staged | grep -E 'spatie/laravel-permission|HasRoles|hasPermissionTo'`
- [ ] Confirmar ausência de `AuthServiceProvider`: `! test -f app/Providers/AuthServiceProvider.php`

## Related

- `filament-resource-scaffold` — Resource consome a policy automaticamente.
- `filament-nested-resource` — policies cobrem acesso ao pai e ao filho.
- `model-with-factory-and-seeder` — factories alimentam testes de policy.
- `policy-with-spatie-permission` — alternativa **opt-in** quando o domínio realmente exige RBAC dinâmico.
