---
name: filament-cache-performance
description: "Aplicar quando criar, revisar ou otimizar contagens, badges de navegação, badges de RelationManager, aggregates, withCount, cache ou performance de Table Filament v5."
license: MIT
metadata:
  author: coringawc
  version: 1.0.0
  requires:
    - laravel-best-practices
    - filament-table-defaults
  related:
    - filament-resource-scaffold
    - filament-relation-page
    - pest-feature-test-filament-resource
    - static-analysis-larastan-pint
---

# Filament Cache Performance

## Consistency First

Esta skill define o padrão local para contagens e cache em Filament v5. A ordem é: evitar N+1 com aggregates nativos, usar cache somente para badges/contagens globais caras, e invalidar explicitamente quando o domínio muda.

Não transforme toda contagem em cache. Para colunas por linha, filtros, search e paginação, deixe o banco trabalhar com `withCount()`, `withExists()`, índices e query plan. Cache de tabela filtrada costuma gerar chaves frágeis e dados stale.

## Quick Reference

- Consulte Laravel Boost `search-docs` antes de editar: `table relationship count`, `navigation badge`, `relation manager badge`, `cache flexible`, `withCount`.
- Coluna por linha: `TextColumn::make('items_count')->counts('items')`; Filament aplica `withCount()` na query.
- Não use `TextColumn::count()` singular; em Filament v5 local o método é `counts()`.
- Se várias colunas/actions usam a mesma contagem, centralize em `->modifyQueryUsing(fn ($query) => $query->withCount('items'))`.
- Badge de navegação simples: query direta aceita pela docs; cache só se a query for cara ou aparecer em muitas telas.
- Badge caro: use `Cache::flexible($key, [fresh, stale], fn (): int => ...)` com TTL curto.
- Chave de cache deve incluir contexto que muda o resultado: panel, resource, badge, usuário, tenant/carteira, estado/filtro.
- Chave contextual não substitui autorização; a query cacheada deve aplicar os mesmos escopos de visibilidade da tela.
- RelationManager com badge caro: preferir `protected static bool $isBadgeDeferred = true` e `getBadge()`.
- `Cache::tags()` só quando o store suportar tags; `file`, `database` e `dynamodb` não suportam tags.
- `Cache::flexible()` serve dado stale por design; não use para badge sensível que precisa sumir imediatamente após revogação de acesso.
- Sempre deixe TTL como rede de segurança mesmo quando há invalidação por observer/action.

## Workflow

- [ ] Confirmar se o problema é tabela por linha, badge de navegação, badge de relation tab, summary ou widget.

- [ ] Para tabela por linha, preferir aggregate nativo:

```php
use Filament\Tables\Columns\TextColumn;

TextColumn::make('items_count')
    ->label(__('Items'))
    ->counts('items')
    ->sortable();
```

- [ ] Para múltiplas contagens na mesma relation, usar aliases Eloquent:

```php
use Illuminate\Database\Eloquent\Builder;

return $table
    ->modifyQueryUsing(fn (Builder $query): Builder => $query->withCount([
        'items',
        'items as pending_items_count' => fn (Builder $query): Builder => $query->where('status', 'pending'),
    ]))
    ->columns([
        TextColumn::make('items_count')->label(__('Items')),
        TextColumn::make('pending_items_count')->label(__('Pending items')),
    ]);
```

- [ ] Para relationship exibida por dot syntax, garantir eager loading ou confiar no applyEagerLoading do Filament quando suficiente; se a relação é usada fora da coluna, explicitar `with()`:

```php
return $table
    ->modifyQueryUsing(fn (Builder $query): Builder => $query->with(['tenant.wallet.user']));
```

- [ ] Para badge de navegação caro, criar chave contextual e cachear inteiro simples, não Model/Collection:

```php
use Filament\Facades\Filament;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\Cache;

public static function getNavigationBadge(): ?string
{
    $panel = Filament::getCurrentPanel()?->getId() ?? 'unknown-panel';
    $user = Filament::auth()->user();
    $tenant = Filament::getTenant();

    if ($user === null) {
        return null;
    }

    $tenantId = $tenant?->getKey() ?? 'no-tenant';
    $version = Cache::get("filament:{$panel}:tenant:{$tenantId}:issuing-badge-version", 1);
    $key = "filament:{$panel}:tenant:{$tenantId}:".static::class.":badge:issuing:v{$version}:user:{$user->getKey()}";

    $count = Cache::flexible($key, [30, 300], fn (): int => static::getEloquentQuery()
        ->when($tenant, fn (Builder $query): Builder => $query->whereBelongsTo($tenant))
        ->where('status', 'issuing')
        ->toBase()
        ->count());

    return $count > 0 ? (string) $count : null;
}
```

- [ ] Invalide por serviço central de chave ou versão de domínio/tenant quando create/update/delete/restore/forceDelete afetar a contagem. Bulk updates via query builder não disparam observers, então devem incrementar a versão ou chamar `Cache::forget()` explicitamente.

```php
Cache::increment("filament:{$panel}:tenant:{$tenantId}:issuing-badge-version");
```

- [ ] Para RelationManager badge caro, usar API nativa de badge deferido:

```php
use Filament\Resources\RelationManagers\RelationManager;
use Illuminate\Database\Eloquent\Model;

class NotesRelationManager extends RelationManager
{
    protected static string $relationship = 'notes';

    protected static bool $isBadgeDeferred = true;

    public static function getBadge(Model $ownerRecord, string $pageClass): ?string
    {
        $query = $ownerRecord->{static::getRelationshipName()}();

        // Aplique aqui os mesmos escopos/autorização usados pela tabela do RelationManager.
        $count = $query->toBase()->count();

        return $count > 0 ? (string) $count : null;
    }
}
```

- [ ] Para grupos de RelationManager, usar `->deferBadge()` quando a query do badge for cara.

- [ ] Se cachear várias contagens do mesmo domínio, prefira uma query agregada ou serviço pequeno que retorne array de escalares, evitando uma query por badge.

- [ ] Se a chave incluir filtros/search, use allowlist e hash canônico para evitar chaves longas, cardinalidade explosiva e cache pollution.

- [ ] Cobrir com teste: o primeiro render mostra valor correto, a mutation invalida cache, e o render seguinte mostra o novo valor.

## Anti-Patterns

- Não usar `->badge(fn () => $ownerRecord->items()->count())` repetido em várias tabs sem `$isBadgeDeferred = true` ou `->deferBadge()` quando a query é cara.
- Não cachear `Model`, `Builder`, `Collection` grande ou objeto de estado; cacheie `int`, `string`, `bool` ou array escalar.
- Não usar `rememberForever()` para contagem que muda no fluxo normal do sistema.
- Não usar chave global como `invoices_badge` quando o resultado depende de usuário, tenant, panel, carteira, permissão ou filtro.
- Não cachear resultado de tabela com filtros/search/sort por padrão. Se houver exceção documentada, a chave deve incluir usuário, tenant, permissões, versão de invalidação e hash canônico dos parâmetros permitidos.
- Não usar `Cache::tags()` sem confirmar store compatível.
- Não usar tags globais como `badges` ou `filament`; tags também precisam de panel/tenant/resource e valores normalizados.
- Não confiar em observer para bulk `update()`/`delete()` via query builder.
- Não resolver N+1 com cache por linha; corrija a query com `with()`, `withCount()` ou aggregate.
- Não criar trait genérica que descobre relações por reflection antes de provar que chaves, invalidação e tenancy estão corretas.
- Não usar cache para mascarar falta de índice em coluna usada por filtro, search, `where`, `orderBy` ou count condicionado.
- Não liberar `cache.serializable_classes` de forma ampla para cachear objetos; use payload escalar ou DTO allowlisted.

## Verification

- [ ] `./.agents/skills/_helpers/verify-skill.sh .agents/skills/filament-cache-performance/SKILL.md`
- [ ] `git diff --check -- .agents/skills/filament-cache-performance/SKILL.md`
- [ ] Confirmar com Boost docs: `Cache::flexible`, `Cache::memo`, `withCount`, `getNavigationBadge`, `isBadgeDeferred`.
- [ ] Conferir no vendor que `TextColumn::counts()` aplica `withCount()` quando houver dúvida.
- [ ] Em PHP editado: `vendor/bin/sail bin pint --dirty --format agent`.
- [ ] Em Resource/RelationManager editado: `vendor/bin/sail artisan test --compact --filter=Filament`.
- [ ] Teste específico prova invalidação de badge/cache após create/update/delete/restore relevante.
- [ ] Revisar chaves de cache contra vazamento cross-user/cross-tenant/cross-panel.

## Related

- `filament-table-defaults` - defaults, eager loading, search, filtros e sort da Table.
- `laravel-best-practices` - `withCount()`, aggregates, cache, locks, índices e observers.
- `filament-relation-page` - páginas que gerenciam coleções relacionadas com badges/contagens.
- `pest-feature-test-filament-resource` - cobertura de list/search/create/edit e assertions de tabela.
- `static-analysis-larastan-pint` - gate obrigatório após tocar PHP/Blade.
