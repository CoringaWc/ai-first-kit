# Services Compartilhados entre docker-stack-fpm e docker-stack-octane-swoole

Ambas as skills usam **services idênticos** exceto `app`:

| Service | Imagem | Função | Compartilhado? |
|---|---|---|---|
| `app` | `<projeto>:latest` (build próprio) | runtime PHP | **NÃO** — fpm vs octane diferem aqui |
| `queue` | mesma imagem do `app` | `artisan queue:work` | Sim |
| `reverb` | mesma imagem do `app` | `artisan reverb:start` | Sim |
| `nginx` | `nginx:1.27-alpine` | reverse proxy SSL | Sim |
| `postgres` | `postgres:16-alpine` | DB | Sim |
| `redis` | `redis:7-alpine` | cache + queue driver | Sim |
| `minio` | `quay.io/minio/minio:latest` | S3-compatible storage | Sim |
| `ollama` | `ollama/ollama:latest` | LLM local opcional da stack migratória | Sim |
| `ollama-pull-models` | `ollama/ollama:latest` | bootstrap one-shot dos modelos locais | Sim |
| `qdrant` | `qdrant/qdrant:latest` | vector store local opcional da stack migratória | Sim |
| `mailpit` | `axllent/mailpit:latest` | email local em profile `mail` | Sim |

`queue` e `reverb` reutilizam a imagem `app` para garantir mesmo PHP/extensions/Node. Mudança em Dockerfile do `app` propaga automaticamente.

Cada processo long-running fica em um service próprio, sem Supervisor dentro do container `app`:

- `app`: apenas runtime HTTP (`php-fpm` no FPM, `octane:start` no Octane).
- `queue`: apenas `php artisan queue:work`.
- `reverb`: apenas `php artisan reverb:start` para WebSockets.

O kit canônico não adiciona helper one-shot para criação automática de bucket. O bucket local deve ser criado por seed/bootstrap explícito quando o domínio exigir.

## Healthchecks nos templates

- `postgres`: `pg_isready -U ${DB_USERNAME:-template} -d ${DB_DATABASE:-template}`.
- `app` FPM: socket PHP-FPM em `127.0.0.1:9000`.
- `app` Octane: socket HTTP em `127.0.0.1:8000`.
- `queue`: `/proc/1/cmdline` contendo `queue:work`.
- `reverb`: socket em `127.0.0.1:8080`.

## Variáveis de env consumidas por todos services

`APP_*`, `DB_*`, `REDIS_*`, `AWS_*` (MinIO), `REVERB_*`.
