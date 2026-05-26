# Foreign Keys — Precedência e Comportamento de Delete

## Precedência da forma da FK

1. **Greenfield, model existente** — usar `foreignIdFor()`:

   ```php
   $table->foreignIdFor(Company::class)
       ->constrained()
       ->restrictOnDelete();
   ```

2. **Projeto existente** cujas migrations vizinhas usam FK explícita por nome:

   ```php
   $table->foreignId('company_id')
       ->constrained()
       ->restrictOnDelete();
   ```

3. **FK auto-referente ou com nome de coluna custom**:

   ```php
   $table->foreignIdFor(User::class, 'reviewed_by_id')
       ->nullable()
       ->constrained('users')
       ->nullOnDelete();
   ```

A regra é: leia o vizinho mais recente. Consistência local vence preferência global.

## Comportamento de delete

| Cenário | Cláusula | Justificativa |
| --- | --- | --- |
| Filho mantém valor histórico, auditoria ou registro regulado | `restrictOnDelete()` | Default seguro do kit. |
| Filho é realmente owned (sem valor fora do pai) e há teste cobrindo deleção | `cascadeOnDelete()` | Limpa dado órfão sem perder integridade. |
| Relação opcional, queda do pai só desfaz vínculo | `nullOnDelete()` | Coluna deve ser `nullable()`. |
| Filho tenant/company-scoped ou financeiro | `restrictOnDelete()` | Cascade aqui apaga rastro auditável. |

Cascade em registro auditável, multi-tenant ou regulado exige decisão explícita do domínio + teste de deleção verde.

## Composite e únicas com FK

```php
$table->foreignIdFor(Company::class)->constrained()->restrictOnDelete();
$table->string('slug');
$table->unique(['company_id', 'slug']);
$table->index(['company_id', 'created_at']);
```

A FK não substitui o índice composto: o índice cobre `where company_id = ? and ...` e `orderBy created_at desc`.

## Renomear/dropar FK em ambiente compartilhado

Nunca edite a migration original. Crie nova migration forward-only:

```bash
vendor/bin/sail artisan make:migration drop_company_fk_from_projects_table \
    --table=projects --no-interaction
```

```php
public function up(): void
{
    Schema::table('projects', function (Blueprint $table): void {
        $table->dropConstrainedForeignId('company_id');
    });
}
```

`dropConstrainedForeignId()` remove FK + índice + coluna no mesmo passo quando o objetivo é descartar tudo. Para preservar a coluna, use `dropForeign(['company_id'])` apenas.
