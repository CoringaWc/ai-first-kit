# Rollback da migração Octane → FPM

Use quando a migração subiu mas algum package vaza estado, performance regrediu, ou WebSockets quebraram em produção. Os `.bak` files gerados em `enable-octane-swoole` são a fonte de verdade.

## Rollback rápido (descartar branch)

Use quando ainda não fez merge da branch de migração e quer voltar ao FPM em segundos:

```bash
git checkout main
git branch -D octane-migration-<timestamp>
vendor/bin/sail down
vendor/bin/sail build --no-cache
vendor/bin/sail up -d
```

## Rollback dentro da branch (preservar histórico)

Use quando precisa investigar o motivo da reversão depois e quer manter os arquivos da migração no git:

```bash
TS=<timestamp gerado pela migração>  # ex.: 20250526-143012

cp docker/php/Dockerfile.bak.${TS}     docker/php/Dockerfile
cp docker/nginx/default.conf.bak.${TS} docker/nginx/default.conf
cp docker-compose.yml.bak.${TS}        docker-compose.yml
cp .github/workflows/ci.yml.bak.${TS}  .github/workflows/ci.yml

vendor/bin/sail composer remove laravel/octane
sed -i '/^OCTANE_/d' .env .env.example

# Remover middleware InvokeCachedRoutes manualmente em bootstrap/app.php

vendor/bin/sail down
vendor/bin/sail build --no-cache
vendor/bin/sail up -d
```

## Verificação pós-rollback

- [ ] `grep -q 'fastcgi_pass' docker/nginx/default.conf` retorna 0.
- [ ] `! grep -q '^OCTANE_' .env` (env vars Octane removidas).
- [ ] `! vendor/bin/sail exec app php -m | grep -x swoole` (extensão fora do worker).
- [ ] `vendor/bin/sail exec app php -v` mostra PHP 8.4 sem mention a Swoole.
- [ ] `curl -fsSk https://localhost/` retorna HTTP 200.
- [ ] Logs do `app` mostram PHP-FPM workers, não Octane.

## Causas comuns que justificam rollback

- Singleton de auth (`Auth::user()` em service provider boot) vazando entre requests.
- Package terceiro mantendo estado em static prop (ex.: cliente HTTP cacheando token em variável global).
- WebSocket falhando porque `OCTANE_HTTPS=true` não foi setado e `route()` gera URLs `http://`.
- Performance pior em endpoints com muita injeção via container (overhead de re-bootstrap pesa mais que ganho do worker).
- Memory leak progressivo (worker passa de 256 MB em poucas horas; OCTANE_MAX_REQUESTS mascara mas não corrige).

Antes de declarar rollback definitivo, capture `octane-packages-report.txt` da branch de migração e abra issue contra o checklist em `docker-stack-octane-swoole/rules/octane-safety-checklist.md`.
