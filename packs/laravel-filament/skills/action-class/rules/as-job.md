# asJob() — Action como Job assíncrono

A trait `AsAction` permite despachar a action como job sem criar classe Job separada.

## Uso básico

```php
<?php

declare(strict_types=1);

namespace App\Actions\Notification;

use App\Models\User;
use Illuminate\Support\Facades\Mail;
use Lorisleiva\Actions\Concerns\AsAction;

final class SendWelcomeEmailAction
{
    use AsAction;

    public function handle(User $user): void
    {
        Mail::to($user->email)->send(new WelcomeMail($user));
    }
}
```

## Despachar

```php
// Síncrono (fila sync ou queue padrão):
SendWelcomeEmailAction::run($user);

// Assíncrono (vai pra fila configurada):
SendWelcomeEmailAction::dispatch($user);

// Com delay:
SendWelcomeEmailAction::dispatch($user)->delay(now()->addMinutes(5));

// Em fila específica:
SendWelcomeEmailAction::dispatch($user)->onQueue('emails');
```

## Configurações do job

```php
final class SendWelcomeEmailAction
{
    use AsAction;

    public string $jobConnection = 'redis';
    public string $jobQueue = 'emails';
    public int $jobTries = 3;
    public int $jobTimeout = 60;
    public int $jobMaxExceptions = 2;
    public int $jobBackoff = 30;

    public function handle(User $user): void
    {
        // ...
    }

    /**
     * @return list<object>
     */
    public function getJobMiddleware(): array
    {
        return [
            new \Illuminate\Queue\Middleware\WithoutOverlapping("user-{$this->user->id}"),
        ];
    }

    public function getJobUniqueId(User $user): string
    {
        return "welcome-{$user->id}";
    }
}
```

## Retry e falha

```php
public function handle(User $user): void
{
    if (! $user->email_verified_at) {
        $this->release(60); // re-queue em 60s
        return;
    }

    try {
        Mail::to($user->email)->send(new WelcomeMail($user));
    } catch (\Throwable $e) {
        $this->fail($e); // marca job como falho
    }
}
```

`release()` e `fail()` vêm do trait `AsAction` quando executando como job.

## Anti-Patterns

- Não usar `::dispatch()` dentro de outra action sem garantir idempotência.
- Não acessar Request, Session ou Auth dentro de action despachada como job — contexto HTTP não existe.
- Não passar Eloquent model como argumento sem `SerializesModels` automático (a trait já cuida disso, mas confirme model leve).
- Não despachar job síncrono via `::run()` quando o caso de uso real é assíncrono — fila local engana em testes.

## Verification

- [ ] `handle()` não depende de `request()`, `session()` ou `auth()` global.
- [ ] `jobConnection`/`jobQueue` configurados quando diferem do default.
- [ ] `jobTries` definido para jobs idempotentes; 1 para jobs não-idempotentes.
- [ ] `getJobMiddleware()` aplica `WithoutOverlapping` quando há concorrência.
