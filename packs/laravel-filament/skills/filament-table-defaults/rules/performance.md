# Table Performance

Otimizações para tabelas com volume alto ou queries pesadas.

## Defer loading

```php
return $table
    ->deferLoading();
```

- Tabela não executa query inicial; espera o usuário interagir (filtro, search, paginação).
- Útil quando a página tem múltiplas tabelas ou widgets e a primeira renderização precisa ser rápida.

## Persistir filtros, sort e search

```php
return $table
    ->persistFiltersInSession()
    ->persistSortInSession()
    ->persistSearchInSession();
```

- Estado sobrevive a navegação dentro do painel.
- Limpa ao logout ou expiração de sessão.

## Eager loading de relationships exibidas

```php
public static function getEloquentQuery(): Builder
{
    return parent::getEloquentQuery()
        ->with(['author', 'category', 'tags']);
}
```

- Evita N+1 quando `TextColumn::make('author.name')` ou similares são renderizadas.
- Para Resource, sobrescreva em `XResource::getEloquentQuery()`.
- Para Relation Manager, sobrescreva em `XRelationManager::getTableQuery()`.

## Selecionar apenas colunas necessárias

```php
public static function getEloquentQuery(): Builder
{
    return parent::getEloquentQuery()
        ->select(['id', 'name', 'status', 'created_at']);
}
```

- Reduz payload do banco quando o model tem JSON columns grandes ou TEXT/BLOB.
- Cuidado: campos não selecionados não estarão disponíveis em `recordAction`/`recordUrl` e modal forms.

## Paginação cursor

```php
return $table
    ->paginateUsing(fn ($query, $perPage) => $query->cursorPaginate($perPage));
```

- Mais rápido em tabelas com milhões de linhas e ordenação por chave única.
- Não suporta navegação por número de página.

## Search com índice de banco

Para search em colunas grandes:

```php
TextColumn::make('description')
    ->searchable(isIndividual: true, isGlobal: false);
```

- `isIndividual: true` adiciona campo de search por coluna (filtro).
- `isGlobal: false` remove da search global (que faz `LIKE` em todas).
- Combine com índice full-text no banco (`migration->fullText(['description'])`).

## Polling

```php
return $table
    ->poll('30s');
```

- Re-renderiza tabela a cada 30s.
- Use apenas quando dados realmente mudam frequentemente; consome recursos.

## Anti-Patterns

- Não usar `deferLoading()` em tabela única da página — usuário espera ver dados imediatos.
- Não fazer eager loading sem confirmar que a coluna realmente exibe a relationship.
- Não usar `select(['id'])` excluindo colunas que actions/modals precisam ler.
- Não combinar `poll()` com tabela grande e sem filtros — re-query pesada constante.
- Não persistir filtros em painel público anônimo — sessão pode vazar entre dispositivos compartilhados.

## Verification

- [ ] Tabelas com N+1 confirmado têm `getEloquentQuery()` com `->with([...])`.
- [ ] `deferLoading()` é usado apenas em páginas com múltiplas tabelas/widgets.
- [ ] `poll()` tem intervalo coerente com cadência real dos dados.
- [ ] `select([...])` não exclui colunas que modals/actions consomem.
