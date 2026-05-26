# Composer Package List — Canônico (A4)

Lista exata de pacotes instalados por A4, agrupada por domínio. **Ordem importa**: dentro do grupo, instalar tudo em uma chamada `composer require` (atômico no grupo, mas isolando falhas entre grupos).

> Versões mínimas refletem o stack alvo (PHP 8.4, Laravel 13). Use `^` para permitir patch/minor compatíveis. Não fixe `=` salvo justificativa explícita.

## Grupo 1 — UI Stack (production)

```bash
vendor/bin/sail composer require \
  filament/filament:^5.0 \
  livewire/livewire:^4.0
```

| Pacote | Razão |
|---|---|
| `filament/filament` | Painel admin (princípio mestre do projeto) |
| `livewire/livewire` | Dependência declarada de Filament; já vem transitiva mas fixar versão evita drift |

**Pós-instalação obrigatória**:

```bash
vendor/bin/sail artisan filament:install --panels --no-interaction
```

(cria `app/Providers/Filament/AdminPanelProvider.php`. **Não pular** — sem isso Filament não registra rotas.)

## Grupo 2 — Realtime (production)

```bash
vendor/bin/sail composer require laravel/reverb:^1.0
```

| Pacote | Razão |
|---|---|
| `laravel/reverb` | WebSocket server first-party (broadcasting Filament notifications, Echo) |

**Pós-instalação**:

```bash
vendor/bin/sail artisan install:broadcasting --reverb --without-node --without-reverb --no-interaction
vendor/bin/sail artisan reverb:install --no-interaction
```

Laravel 13 exige `--reverb`: `install:broadcasting` tem um `select()` obrigatório sem default, e `reverb:install` chama esse comando sem driver quando `routes/channels.php` ainda não existe. As chaves `REVERB_*` devem existir em `.env` antes porque o comando troca `BROADCAST_CONNECTION` e carrega `routes/channels.php`. A4 espelha as chaves em `.env.example` via append idempotente.

> `spatie/laravel-permission` **não** é parte da stack canônica. Projeto atual (`composer.json` em `require`) usa autorização nativa Laravel + policies. Adicionar apenas sob demanda explícita do usuário.

## Grupo 2b — Octane opcional (production, profile=octane)

```bash
if grep -q "^OCTANE_SERVER=swoole" .env 2>/dev/null; then
  vendor/bin/sail composer require laravel/octane
  vendor/bin/sail artisan octane:install --server=swoole --no-interaction
  vendor/bin/sail restart app
fi
```

| Pacote | Razão |
|---|---|
| `laravel/octane` | Runtime HTTP persistente para profile Octane/Swoole; instalado após A2 porque A4 precisa do container bootstrap rodando para executar Composer via Sail |

## Grupo 3 — Static Analysis + Style (dev)

```bash
vendor/bin/sail composer require --dev \
  larastan/larastan:^3.0 \
  laravel/pint:^1.0 \
  laravel/pail:^1.0
```

| Pacote | Razão |
|---|---|
| `larastan/larastan` | PHPStan + regras Laravel (qualidade) |
| `laravel/pint` | Formatador oficial (style guideline do repo) |
| `laravel/pail` | `sail artisan pail` para tail de logs estruturados em dev |

## Grupo 4 — Testing (dev)

```bash
vendor/bin/sail composer require --dev -W \
  pestphp/pest:^4.6 \
  pestphp/pest-plugin-laravel:^4.1 \
  pestphp/pest-plugin-livewire:4.x-dev \
  pestphp/pest-plugin-browser:4.x-dev \
  fakerphp/faker:^1.23
```

| Pacote | Razão |
|---|---|
| `pestphp/pest` | Test runner padrão do projeto (substitui PHPUnit direto) |
| `pestphp/pest-plugin-laravel` | Helpers Laravel (`actingAs`, `assertDatabaseHas`) em pest |
| `pestphp/pest-plugin-livewire` | `Pest\Livewire\livewire()` — obrigatório para testar Filament |
| `pestphp/pest-plugin-browser` | Browser tests Pest v4 para fluxos reais Filament/Livewire |
| `fakerphp/faker` | Locale-aware fake data; locale lido de `APP_FAKER_LOCALE` (fixado por A7) |

Usar `-W`: o skeleton Laravel 13 traz `laravel/pao` e `phpunit/phpunit` travados; Pest 4.6+ exige ajuste transitivo de PHPUnit. Plugins `4.x-dev` são necessários até os tags estáveis declararem compatibilidade com Laravel 13.

> `laravel-lang/lang` **não** é parte da stack. Filosofia i18n do projeto proíbe (locale fixo `pt_BR`, sem alternância em runtime). Ver `.agents/skills/translation/rules/translation-rules.md` §1.

**Pós-instalação**:

```bash
vendor/bin/sail bin pest --init
```

## Grupo 5 — i18n (dev)

```bash
vendor/bin/sail composer require --dev lucascudo/laravel-pt-br-localization:^3.0
```

| Pacote | Razão |
|---|---|
| `lucascudo/laravel-pt-br-localization` | Único pacote de tradução permitido. Fornece `lang/pt_BR/validation.php` com mensagens nativas de validação em pt_BR. Publicação é feita por A7 (`translation`), não aqui. |

Por que `--dev`: o pacote só publica arquivos de tradução estáticos durante o bootstrap do projeto e nas instalações de novo ambiente; não é usado em runtime de produção (Laravel apenas lê `lang/pt_BR/validation.php` já publicado).

## Grupo 6 — Action Pattern (production)

```bash
vendor/bin/sail composer require lorisleiva/laravel-actions:^2.0
```

| Pacote | Razão |
|---|---|
| `lorisleiva/laravel-actions` | Padrão canônico de `app/Actions/<Domain>/`. Trait `AsAction` permite que a mesma classe sirva como controller, job, listener e command via opt-in (`asController()`, `asJob()`, `asListener()`, `asCommand()`). Ver skill `action-class`. |

Sem publicação obrigatória pós-instalação. Configuração opcional em `config/actions.php` só se o projeto quiser customizar discovery de comandos.

## Notas de Versionamento

- **Não fixe versão exata (`=X.Y.Z`)** salvo lockfile-driven CI — usar `^` permite patches de segurança.
- Se um grupo falhar (ex. conflito de versão), **não fallback para instalar tudo em uma linha** — diagnostique com `composer why-not <pkg> <version>` antes.
- Após cada grupo, rodar `composer show -i | wc -l` para sanity check (esperado: crescimento monotônico).

## Configs publicadas

Após Grupos 1–5 instalados, publicar configs essenciais (idempotente — `--force` só se necessário):

```bash
vendor/bin/sail artisan vendor:publish --tag=filament-config --no-interaction
vendor/bin/sail artisan vendor:publish --provider="Laravel\Reverb\ReverbServiceProvider" --no-interaction
```

A7 (`translation`) publica `lang/pt_BR/validation.php` do `lucascudo` separadamente.
