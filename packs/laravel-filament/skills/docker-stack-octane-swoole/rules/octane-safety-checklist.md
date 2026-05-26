# Octane Safety Checklist

Octane mantém o processo PHP vivo entre requests. Estado global vaza. Verificar:

## Singletons no AppServiceProvider

❌ Singletons que cacheiam request-scope (user, locale, tenant) vazam para próxima request.
✅ Usar `bind` (instância nova por resolve) ou `singleton` com `app('octane')->flushSingleton()` no listener `RequestReceived`.

## Static properties

❌ `private static array $cache = []` em models acumula entre requests.
✅ Limpar via `\Laravel\Octane\Octane::tick()` ou refatorar para instance property.

## Auth::user() em providers

❌ `Auth::user()` no `boot()` de provider executa 1x e congela.
✅ Resolver dentro de listeners/middlewares por request.

## Eloquent boot()

✅ Eloquent já lida com isso via `static::booted()` — sem ação.

## Packages problemáticos

Lista revisar antes de migrar (A6):
- `spatie/laravel-permission` — usar versão ≥6.4 (suporte Octane oficial)
- `spatie/laravel-activitylog` — OK
- `filament/filament` — Filament v5 documenta compat Octane

## Verificação

```bash
vendor/bin/sail artisan octane:status
vendor/bin/sail logs app | grep -i "memory\|leak\|tick"
```
