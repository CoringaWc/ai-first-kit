# asListener() — Action como Event Listener

A trait `AsAction` permite que a mesma action reaja a eventos sem criar Listener separado.

## Uso básico

```php
<?php

declare(strict_types=1);

namespace App\Actions\Notification;

use App\Events\UserRegistered;
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

    public function asListener(UserRegistered $event): void
    {
        $this->handle($event->user);
    }
}
```

## Registrar listener

Em `app/Providers/EventServiceProvider.php`:

```php
use App\Actions\Notification\SendWelcomeEmailAction;
use App\Events\UserRegistered;

protected $listen = [
    UserRegistered::class => [
        SendWelcomeEmailAction::class,
    ],
];
```

Ou listener autodiscovery (Laravel 11+):

```php
use App\Events\UserRegistered;
use Illuminate\Support\Facades\Event;

Event::listen(UserRegistered::class, SendWelcomeEmailAction::class);
```

## Listener assíncrono

Para o listener rodar em fila, combine `asListener()` com `asJob()` e use `ShouldQueue`:

```php
use Illuminate\Contracts\Queue\ShouldQueue;

final class SendWelcomeEmailAction implements ShouldQueue
{
    use AsAction;

    public string $jobQueue = 'emails';

    public function handle(User $user): void { /* ... */ }

    public function asListener(UserRegistered $event): void
    {
        $this->handle($event->user);
    }
}
```

## Múltiplos eventos

Uma action pode reagir a vários eventos via overloads de assinatura:

```php
public function asListener(UserRegistered|UserActivated $event): void
{
    $this->handle($event->user);
}
```

## Anti-Patterns

- Não despachar evento dentro de `asListener()` da mesma action — risco de loop.
- Não fazer queries pesadas em listener síncrono; mova para listener assíncrono via `ShouldQueue`.
- Não acessar `request()` dentro de listener — pode ser disparado fora de contexto HTTP (CLI, queue).
- Não reagir a eventos do framework (`Illuminate\Auth\Events\*`) sem confirmar payload exato; eventos third-party podem mudar entre versões.

## Verification

- [ ] Listener registrado em `EventServiceProvider::$listen` ou via `Event::listen()`.
- [ ] `asListener()` extrai payload do evento e delega para `handle()`.
- [ ] Implementa `ShouldQueue` quando trabalho não precisa ser síncrono.
- [ ] Não acessa contexto HTTP global.
