---
name: policy-with-spatie-permission
description: "Aplicar quando o domínio exigir RBAC dinâmico com papéis e permissões persistidos via spatie/laravel-permission."
license: MIT
metadata:
  author: coringawc
  version: 1.0.0
  requires:
    - laravel-best-practices
    - spatie-laravel-php-standards
  related:
    - policy-native-laravel
    - filament-resource-scaffold
---

# Policy With Spatie Permission

## Consistency First

Skill **opt-in**. Só aplicar quando o domínio realmente precisar de RBAC dinâmico — papéis e permissões editáveis em runtime por administrador, persistidos em banco. Para autorização estática baseada em tipo de usuário + relação de domínio, use `policy-native-laravel`. Antes de instalar `spatie/laravel-permission`, confirme com o usuário que o caminho nativo foi descartado e que existe UI de gestão de papéis no escopo.

## Quick Reference

- Pré-requisito: decisão explícita do usuário para adotar Spatie. Não instalar por inferência.
- Pacote: `spatie/laravel-permission` (compatível com Laravel 13).
- User aplica `Spatie\Permission\Traits\HasRoles`.
- Permissões em snake_case e descritivas: `view_project`, `update_project`, `delete_project`.
- Roles seedadas via seeder dedicado e idempotente (`firstOrCreate`).
- Policies usam `$user->can('view_project')`/`hasPermissionTo()` ao invés de `instanceof`.
- Cache de permissões: limpar com `vendor/bin/sail artisan permission:cache-reset` após mudanças em seeders.
- Filament v5 respeita policies normalmente — sem hook adicional.

## Workflow

- [ ] Confirmar adoção com o usuário (decisão arquitetural). Sem isso, voltar para `policy-native-laravel`.

- [ ] Instalar pacote:

```bash
vendor/bin/sail composer require spatie/laravel-permission
vendor/bin/sail artisan vendor:publish --provider="Spatie\Permission\PermissionServiceProvider" --no-interaction
vendor/bin/sail artisan migrate
```

- [ ] Aplicar trait no model User real do projeto:

```php
<?php

namespace App\Models;

use Illuminate\Foundation\Auth\User as Authenticatable;
use Spatie\Permission\Traits\HasRoles;

class User extends Authenticatable
{
    use HasRoles;
}
```

- [ ] Criar seeder idempotente para papéis e permissões. Strings de UI/label permanecem no JSON via `translation`:

```php
<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;

class RolesAndPermissionsSeeder extends Seeder
{
    public function run(): void
    {
        $permissions = [
            'view_project',
            'create_project',
            'update_project',
            'delete_project',
        ];

        foreach ($permissions as $name) {
            Permission::query()->firstOrCreate(['name' => $name, 'guard_name' => 'web']);
        }

        $admin = Role::query()->firstOrCreate(['name' => 'admin', 'guard_name' => 'web']);
        $admin->syncPermissions($permissions);

        $manager = Role::query()->firstOrCreate(['name' => 'manager', 'guard_name' => 'web']);
        $manager->syncPermissions(['view_project', 'create_project', 'update_project']);
    }
}
```

- [ ] Policy decide por permissão nomeada:

```php
<?php

namespace App\Policies;

use App\Models\Project;
use App\Models\User;

class ProjectPolicy
{
    public function viewAny(User $user): bool
    {
        return $user->can('view_project');
    }

    public function view(User $user, Project $project): bool
    {
        return $user->can('view_project') && $user->belongsToCompany($project);
    }

    public function create(User $user): bool
    {
        return $user->can('create_project');
    }

    public function update(User $user, Project $project): bool
    {
        return $user->can('update_project') && $user->belongsToCompany($project);
    }

    public function delete(User $user, Project $project): bool
    {
        return $user->can('delete_project');
    }
}
```

- [ ] Reset de cache após mudanças no seeder:

```bash
vendor/bin/sail artisan permission:cache-reset
```

- [ ] Cobrir com Pest:

```php
it('allows user with permission to view', function () {
    $user = User::factory()->create()->assignRole('manager');
    expect($user->can('viewAny', Project::class))->toBeTrue();
});

it('denies user without permission', function () {
    $user = User::factory()->create();
    expect($user->can('viewAny', Project::class))->toBeFalse();
});
```

## Anti-Patterns

- ❌ Instalar Spatie sem decisão explícita. Se a autorização é estática por tipo de usuário, use `policy-native-laravel`.
- ❌ Misturar `instanceof Admin` com `hasPermissionTo()` na mesma policy. Escolha um modelo e seja consistente.
- ❌ Hardcodar atribuição de role no seeder de demo sem `firstOrCreate`. Seeder de RBAC precisa ser idempotente.
- ❌ Esquecer `permission:cache-reset` após editar seeder em ambiente já populado. Mudanças não aparecem.
- ❌ Nomes de permissão em camelCase ou com espaço (`viewProject`, `view project`). Convenção é snake_case.
- ❌ Esquecer `belongsToCompany()` na policy. Permissão concedida ≠ acesso cross-tenant liberado.
- ❌ Editar migrations publicadas do Spatie sem necessidade. Mantenha o schema padrão; estenda via pivots se preciso.

## Verification

- [ ] `.agents/skills/_helpers/verify-skill.sh .agents/skills/policy-with-spatie-permission/SKILL.md`
- [ ] `vendor/bin/sail composer show spatie/laravel-permission` retorna versão instalada
- [ ] `vendor/bin/sail artisan migrate:status` mostra migrations `*_create_permission_tables` aplicadas
- [ ] `vendor/bin/sail artisan db:seed --class=RolesAndPermissionsSeeder` é idempotente (rodar 2× sem duplicar)
- [ ] `vendor/bin/sail artisan test --compact --filter=Policy`
- [ ] `vendor/bin/sail bin pint --dirty --format agent`
- [ ] `vendor/bin/sail bin phpstan analyse`

## Related

- `policy-native-laravel` — caminho padrão do projeto; Spatie é exceção opt-in.
- `filament-resource-scaffold` — Resource consome a policy automaticamente.
- `translation` — labels de UI de gestão de papéis seguem chave-frase em inglês.
