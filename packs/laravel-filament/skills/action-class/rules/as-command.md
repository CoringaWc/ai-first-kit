# asCommand() — Action como Artisan Command

A trait `AsAction` permite expor a action como comando artisan sem criar classe Command separada.

## Uso básico

```php
<?php

declare(strict_types=1);

namespace App\Actions\Maintenance;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Lorisleiva\Actions\Concerns\AsAction;

final class PurgeStaleSessionsAction
{
    use AsAction;

    public string $commandSignature = 'sessions:purge {--days=30}';

    public string $commandDescription = 'Purge sessions older than N days.';

    public function handle(int $days): int
    {
        return DB::table('sessions')
            ->where('last_activity', '<', now()->subDays($days)->timestamp)
            ->delete();
    }

    public function asCommand(Command $command): int
    {
        $days = (int) $command->option('days');
        $deleted = $this->handle($days);

        $command->info(__('Purged :count stale sessions.', ['count' => $deleted]));

        return Command::SUCCESS;
    }
}
```

## Registrar comando

A trait `AsAction` registra automaticamente quando a classe tem `$commandSignature`. Confirme em `bootstrap/app.php` ou `app/Console/Kernel.php`:

```php
->withCommands([
    \App\Actions\Maintenance\PurgeStaleSessionsAction::class,
])
```

## Scheduling

Em `routes/console.php` (Laravel 11+) ou `Console\Kernel::schedule()`:

```php
use App\Actions\Maintenance\PurgeStaleSessionsAction;
use Illuminate\Support\Facades\Schedule;

Schedule::command(PurgeStaleSessionsAction::class, ['--days=60'])
    ->daily()
    ->onOneServer();
```

## Output estruturado

```php
public function asCommand(Command $command): int
{
    $command->components->info(__('Starting purge...'));

    $progress = $command->components->task(
        __('Purging sessions'),
        fn (): bool => $this->handle((int) $command->option('days')) >= 0,
    );

    return Command::SUCCESS;
}
```

## Anti-Patterns

- Não acessar `request()` ou `auth()` em comando — contexto HTTP não existe na CLI.
- Não retornar `void` de `asCommand()`; sempre retornar `Command::SUCCESS` ou `Command::FAILURE`.
- Não escrever em `STDOUT` direto (`echo`, `print`); use `$command->info()`, `$command->error()`.
- Não despachar job síncrono dentro de comando que já roda numa fila — risco de duplo enfileiramento.
- Não embutir lógica de I/O complexa em `asCommand()`; delegue para `handle()` e trate I/O apenas no command.

## Verification

- [ ] `$commandSignature` segue convenção `dominio:verbo {args} {--options}`.
- [ ] `$commandDescription` traduzível e clara.
- [ ] `asCommand()` retorna `Command::SUCCESS` ou `Command::FAILURE`.
- [ ] Comando registrado em `bootstrap/app.php` ou autodescoberto.
- [ ] Scheduling com `onOneServer()` quando aplicável.
