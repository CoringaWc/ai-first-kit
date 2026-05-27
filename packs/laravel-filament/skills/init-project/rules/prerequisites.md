# Pré-requisitos — init-project (A1)

`init-project` é **Docker-first**. O host prepara e executa Docker; a aplicação prepara PHP, Composer, Artisan, Node, npm e npx dentro do container `app`.

## Host obrigatório antes de iniciar

- **Docker Engine/Daemon acessível** (`docker info` precisa funcionar).
- **Docker Compose v2** (`docker compose version`) ou fallback `docker-compose`.
- **git** configurado.
- **curl** para smoke test final.
- **mkcert** ou **openssl** opcionais para HTTPS local; sem `mkcert`, `ssl-local-dev` usa self-signed quando possível.

## Host explicitamente não exigido

- PHP no host.
- Composer no host.
- Node, npm ou npx no host.
- Laravel installer no host.

Mesmo se essas ferramentas existirem no host, **não use**. Elas criam `vendor/`, `node_modules/`, caches e binários fora da imagem canônica e quebram a reprodutibilidade Docker.

## Verificação rápida

```bash
docker compose version >/dev/null 2>&1 || docker-compose --version >/dev/null 2>&1 || { echo "ERRO: docker compose ausente"; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERRO: Docker daemon indisponível. Inicie Docker Desktop/Engine e habilite integração WSL se aplicável."; exit 1; }
git --version >/dev/null 2>&1 || { echo "ERRO: git ausente"; exit 1; }
curl --version >/dev/null 2>&1 || { echo "ERRO: curl ausente"; exit 1; }
```

## Ordem de ferramentas

- Antes do Laravel existir: use `docker compose build` e `docker compose run`.
- Depois de instalar `laravel/sail`: use `vendor/bin/sail` para tudo que envolva PHP, Composer, Artisan, Node ou npm.
- Nunca rode `composer create-project`, `composer require`, `php artisan`, `npm install` ou `npx` diretamente no host.
