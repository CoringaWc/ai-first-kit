---
name: model-with-factory-and-seeder
description: "Aplicar quando criar um Model Laravel com migration, factory e seeder."
license: MIT
metadata:
  author: coringawc
  version: 2.0.0
  requires:
    - laravel-best-practices
    - spatie-laravel-php-standards
  related:
    - migration-with-conventions
    - faker-realistic-ptbr
    - translation
---

# Model With Factory And Seeder

## Consistency First

Mass assignment é declarado **somente** via atributo PHP `#[Fillable]` (`Illuminate\Database\Eloquent\Attributes\Fillable`) — padrão Laravel 13. `protected $fillable` é anti-pattern neste projeto. Factory usa `fake()` sem argumento; o locale vem do `.env` via `translation`. Antes de editar um model existente, abra um vizinho para confirmar nomenclatura de colunas, casts e uso de `SoftDeletes`.

## Quick Reference

- Criar com `vendor/bin/sail artisan make:model <Model> -mfs --no-interaction`.
- Model declara `HasFactory` com generic tipado: `/** @use HasFactory<<Factory>> */`.
- Mass assignment: **somente** `#[Fillable([...])]` no model. Sem `protected $fillable`.
- `#[UseFactory(<Factory>::class)]` quando a factory não segue convenção de nome.
- `SoftDeletes` só com decisão explícita do domínio.
- Casts inferidos do tipo real da migration: `date()` → `'date'`, `timestamp()`/`*_at` → `'datetime'`, `is_*`/`has_*` → `'boolean'`, JSON → `'array'` ou `AsArrayObject::class`.
- Factory usa `fake()` sem argumento. Nunca `fake('pt_BR')` nem `fake('en_US')`.
- Seeder gera volume pequeno (10–50 registros), idempotente via `updateOrCreate` + chave natural.
- Strings de texto livre em seeders demo: `fake()->sentence()`, `fake()->name()`. Nunca strings hardcoded em PT ou EN.

## Workflow

- [ ] Gerar model + migration + factory + seeder:

```bash
vendor/bin/sail artisan make:model Project -mfs --no-interaction
```

- [ ] Declarar mass assignment via atributo `#[Fillable]`. Sem `protected $fillable`:

```php
<?php

namespace App\Models;

use App\Enums\ProjectStatusEnum;
use Database\Factories\ProjectFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\UseFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

#[Fillable([
    'name',
    'status',
    'metadata',
    'is_active',
])]
#[UseFactory(ProjectFactory::class)]
class Project extends Model
{
    /** @use HasFactory<ProjectFactory> */
    use HasFactory;

    protected function casts(): array
    {
        return [
            'status' => ProjectStatusEnum::class,
            'metadata' => 'array',
            'is_active' => 'boolean',
            'planned_starts_at' => 'date',
            'published_at' => 'datetime',
            // Dinheiro/valores fiscais: SEMPRE decimal:N — nunca 'float'.
            // 'budget_amount' => 'decimal:2',
            // PII/secret persistido: cast 'encrypted' (chave em APP_KEY). Sem hash manual.
            // 'tax_id' => 'encrypted',
            // 'preferences' => 'encrypted:array', // JSON criptografado
        ];
    }
}
```

- [ ] Adicionar `SoftDeletes` apenas com decisão explícita:

```php
use Illuminate\Database\Eloquent\SoftDeletes;

class Project extends Model
{
    use HasFactory;
    use SoftDeletes;
}
```

- [ ] Factory usa `fake()` sem argumento. Locale vem do `.env`:

```php
<?php

namespace Database\Factories;

use App\Enums\ProjectStatusEnum;
use App\Models\Project;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Project>
 */
class ProjectFactory extends Factory
{
    protected $model = Project::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'name' => fake()->sentence(3),
            'status' => fake()->randomElement(ProjectStatusEnum::cases()),
            'metadata' => ['source' => fake()->word()],
            'is_active' => true,
        ];
    }
}
```

- [ ] Seeder com volume pequeno e idempotente via chave natural. Strings vêm do Faker, nunca hardcoded:

```php
<?php

namespace Database\Seeders;

use App\Models\Project;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;

class ProjectSeeder extends Seeder
{
    public function run(): void
    {
        foreach (range(1, 25) as $index) {
            $name = fake()->sentence(3);

            Project::query()->updateOrCreate(
                ['slug' => Str::slug($name).'-'.$index],
                ['name' => $name, 'is_active' => true],
            );
        }
    }
}
```

- [ ] Registrar o seeder em `DatabaseSeeder` somente se fizer parte do bootstrap padrão. Cargas grandes ou específicas pertencem a seeders separados.

## Anti-Patterns

- ❌ `protected $fillable = [...]`. Este projeto usa **somente** `#[Fillable]` (atributo Laravel 13).
- ❌ `Model::unguard()` ou ausência de mass assignment explícito.
- ❌ `fake('pt_BR')->name()` em factory. Locale vem do `.env`; use `fake()` sem argumento. Veja `.agents/skills/translation/rules/translation-rules.md` §9.
- ❌ Strings hardcoded em seeder demo: `'Projeto demonstração 1'`. Use `fake()->sentence()`. Strings de UI traduzidas seguem `.agents/skills/translation/rules/translation-rules.md`.
- ❌ Gerar CPF/CNPJ com `numerify()` sem validar dígito verificador. Use `fake()->cpf()` / `fake()->cnpj()`.
- ❌ Seeder com milhares de registros por padrão. Carga grande pertence a seeder separado de performance/teste.
- ❌ Seeder com `delete()`/`truncate()` sem guard de ambiente. Risco de perda de dados em produção.
- ❌ Rodar `php artisan make:model` no host. Use `vendor/bin/sail artisan make:model`.

## Verification

- [ ] `.agents/skills/_helpers/verify-skill.sh .agents/skills/model-with-factory-and-seeder/SKILL.md`
- [ ] `vendor/bin/sail artisan test --compact --filter=Factory`
- [ ] `vendor/bin/sail bin pint --dirty --format agent`
- [ ] `vendor/bin/sail bin phpstan analyse`
- [ ] Confirmar zero ocorrências de `protected $fillable` nos arquivos tocados: `! git diff --staged -- 'app/Models/*.php' | grep -E '^\+.*protected \$fillable'`
- [ ] Confirmar zero ocorrências de `fake('pt_BR')` ou `fake('en_US')` no diff
- [ ] Model tem `HasFactory`, `#[Fillable([...])]` e `casts()` compatíveis com a migration

## Related

- `migration-with-conventions` — colunas, FKs, índices e SoftDeletes que o model espelha.
- `faker-realistic-ptbr` — provider custom para domínio fora do Faker nativo.
- `translation` — fixa `APP_FAKER_LOCALE=pt_BR` no `.env` (pré-requisito do `fake()` sem argumento).
- Downstream: `pest-feature-test-filament-resource`, `pest-unit-test-action`.
