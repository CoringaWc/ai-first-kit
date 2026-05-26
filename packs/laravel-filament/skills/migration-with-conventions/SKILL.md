---
name: migration-with-conventions
description: "Aplicar quando criar ou alterar migration Laravel para tabela de domínio neste kit, definir colunas, FKs, índices, soft deletes ou colunas que carregam enums de domínio."
license: MIT
metadata:
  author: coringawc
  version: 2.0.0
  requires:
    - laravel-best-practices
    - spatie-laravel-php-standards
  related:
    - model-with-factory-and-seeder
    - enum-with-translations
    - filament-resource-scaffold
    - form-request-validation
    - filament-table-defaults
---

# Migration With Conventions — Schema de Domínio

## Consistency First

Antes de escrever migration, inspecione migrations vizinhas e o schema atual. Em projeto com Laravel Boost, use a tool `database-schema` para tabela existente; para tabela nova, leia migrations relacionadas e replique convenções (nomes de FK, ordem de colunas, presença de `softDeletes`, comentários).

Nunca edite migration que já rodou em ambiente compartilhado. Mudanças vão sempre em migration nova, forward-only. DDL e DML/backfill **não** dividem o mesmo arquivo.

Colunas que persistem enum de domínio armazenam o **valor escalar** do enum (geralmente `string`) e o cast vive no model via `protected $casts` (decisão D40). Não use `$table->enum(...)` do MySQL: ele cria constraint nativa que conflita com evolução do enum PHP e dificulta migration de valor.

## Quick Reference

- Criar via `vendor/bin/sail artisan make:migration <name> --no-interaction`.
- Tabelas novas começam com `$table->id()` e `$table->timestamps()`.
- `softDeletes()` só quando o model exige arquivamento ou recuperação lógica.
- FK: `foreignIdFor(Model::class)->constrained()` em greenfield; siga vizinhança em projeto existente.
- `restrictOnDelete()` é o default seguro; `cascadeOnDelete()` só para filho realmente owned, com teste cobrindo deleção; `nullOnDelete()` quando a relação é opcional.
- Índices são obrigatórios em colunas de `where`, `orderBy`, filtros Filament e constraints de unicidade.
- Enums de domínio persistem como `$table->string('status', N)` com `default()` opcional; cast `\App\Enums\<Enum>::class` mora no model. `enum-with-translations` define o enum.
- Use `comment()` apenas em coluna de negócio não óbvia; campos autoexplicativos não recebem comentário.
- Money: armazene em centavos com `unsignedInteger`/`unsignedBigInteger`, nunca `float`/`double`.
- Datas: `date` para data pura, `timestamp`/`timestampTz` para instante; alinhe com cast do model.
- JSON: prefira `jsonb` no PostgreSQL deste kit; cast `array` ou DTO custom no model.

## Workflow

### Passo 1 — Consultar docs versionadas e schema

- [ ] Via Laravel Boost MCP: `search-docs` com queries `migration column types`, `foreign keys`, `schema indexes`, `migration enum string`, `packages: ['laravel/framework']`. Use `database-schema` para inspecionar tabela existente antes de planejar coluna ou índice.
- [ ] Sem MCP, leia migrations vizinhas em `database/migrations/` e o model alvo em `app/Models/`.

### Passo 2 — Criar migration via Sail

```bash
vendor/bin/sail artisan make:migration create_projects_table --create=projects --no-interaction
```

Para alteração:

```bash
vendor/bin/sail artisan make:migration add_status_to_projects_table --table=projects --no-interaction
```

### Passo 3 — Estrutura mínima de tabela nova

```php
Schema::create('projects', function (Blueprint $table): void {
    $table->id();
    $table->timestamps();
});
```

### Passo 4 — Chaves estrangeiras com precedência clara

Forma da FK (greenfield vs. projeto existente), comportamento de delete (`restrict`/`cascade`/`null`), composite indexes com FK e drop em ambiente compartilhado: ver `rules/foreign-keys.md`. Default seguro continua sendo `restrictOnDelete()`.

### Passo 5 — Colunas com tipos alinhados aos casts do model

```php
$table->string('name');
$table->string('slug')->unique();
$table->date('planned_starts_at')->nullable();
$table->timestamp('published_at')->nullable();
$table->jsonb('metadata')->nullable();
$table->boolean('is_active')->default(true);
$table->unsignedInteger('tpa_cents')->default(0);
```

### Passo 6 — Persistir enums de domínio como `string` + cast (D40)

Migration:

```php
$table->string('status', 32)->default('draft');
```

Model (espelhando a migration):

```php
use App\Enums\ProjectStatus;

protected $casts = [
    'status' => ProjectStatus::class,
];
```

O enum em `app/Enums/ProjectStatus.php` é definido pela skill `enum-with-translations` (BackedEnum string, `HasLabel`/`HasColor`/`HasIcon` no painel Filament). Nunca use `$table->enum('status', [...])` neste kit.

Quando o conjunto de valores ainda for instável ou multi-tenant, prefira `string` sem `default` e exija o valor explícito via FormRequest/Filament.

### Passo 7 — Índices obrigatórios

```php
$table->index(['company_id', 'status']);
$table->index(['company_id', 'created_at']);
$table->unique(['company_id', 'name']);
```

Toda coluna usada em `where`, `orderBy`, filtro Filament (`filament-table-defaults`) ou regra de unicidade ganha índice. Composite index segue a ordem real de uso (coluna mais seletiva primeiro quando aplicável).

### Passo 8 — Soft delete só com decisão de domínio

```php
$table->softDeletes();
```

Adicione somente quando o model precisar de arquivamento/restauração. Não aplique por reflexo: `MigratoryProcessDraft` neste repo já existe sem soft delete.

### Passo 9 — Comentário só em regra de negócio não óbvia

```php
$table->unsignedInteger('tpa_cents')
    ->default(0)
    ->comment('Valor da TPA em centavos para evitar erro de arredondamento.');
```

Campos autoexplicativos (`name`, `email`, `is_active`) não recebem `comment()`.

### Passo 10 — DDL separado de DML/backfill

Backfills vão em migration própria, pequena, idempotente quando possível, e tratados como forward-fix. Nunca misture `Schema::table(...)` com `DB::table(...)->update(...)` no mesmo arquivo.

### Passo 11 — Rodar e validar

```bash
vendor/bin/sail artisan migrate:fresh --env=testing --no-interaction
vendor/bin/sail artisan test --compact
vendor/bin/sail bin pint --dirty --format agent
```

## Anti-Patterns

| Racionalização | Realidade |
| --- | --- |
| "Uso `$table->enum('status', [...])` que é mais explícito." | D40 fixa `string` + cast: enum nativo do MySQL/PostgreSQL conflita com evolução do enum PHP. |
| "Adiciono `softDeletes()` em todo model por garantia." | Soft delete exige decisão de domínio; modelos do repo (ex.: `MigratoryProcessDraft`) provam que não é default. |
| "Cascade em tudo simplifica." | Cascade em registro auditável, tenant/company-scoped ou regulado é perigoso. Default seguro é `restrictOnDelete()`. |
| "Esse índice eu coloco depois." | Coluna de filtro Filament sem índice já vira problema em PR; planeje no momento da migration. |
| "Junto o backfill na mesma migration pra economizar arquivo." | DDL+DML no mesmo arquivo dificulta rollback e revisão; separe sempre. |
| "Coloco `comment()` em todas as colunas." | Comentário é exceção para regra ambígua. Em colunas claras, é ruído. |
| "Valor monetário em `decimal(10,2)`." | Este kit usa centavos em `unsignedInteger` para evitar arredondamento. |
| "Mexo na migration original, ninguém rodou ainda." | Em ambiente compartilhado, considere imutável. Crie migration nova forward-only. |

Red flags:

- `$table->enum(...)` em migration nova.
- FK sem `onDelete` explícito.
- Coluna usada em filtro Filament sem índice correspondente.
- `softDeletes()` em model sem caso de uso de arquivamento.
- DDL e DML/backfill no mesmo arquivo.
- Tipo da coluna desalinhado do cast no model.
- `float`/`double` para valor monetário.

## Verification

- [ ] `.agents/skills/_helpers/verify-skill.sh .agents/skills/migration-with-conventions/SKILL.md` retorna `OK`
- [ ] `git diff --check -- .agents/skills/migration-with-conventions/SKILL.md` limpo
- [ ] `vendor/bin/sail artisan migrate:fresh --env=testing --no-interaction` passa
- [ ] Se há seeders no diff: `vendor/bin/sail artisan migrate:fresh --seed --env=testing --no-interaction` passa
- [ ] `vendor/bin/sail artisan test --compact` passa
- [ ] `vendor/bin/sail bin pint --dirty --format agent` passa
- [ ] Cast no model espelha o tipo da coluna (especialmente enums via D40)
- [ ] Toda coluna usada em filtro/ordenação Filament tem índice correspondente
- [ ] Soft delete e cascade têm justificativa documentada (commit message ou ADR do domínio)

## Related

- `enum-with-translations` — define o enum PHP que o cast do model referencia (coluna `string` na migration).
- `model-with-factory-and-seeder` — model, factory e seeder espelham tipos, casts e soft delete definidos aqui.
- `filament-resource-scaffold` — Resource usa as colunas e índices planejados aqui.
- `form-request-validation` — rules externas espelham constraints de migration (unicidade, length, nullable).
- `filament-table-defaults` — filtros e ordenação exigem índices planejados nesta skill.
