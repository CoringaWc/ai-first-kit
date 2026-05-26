# Smoke Test Checklist — Quando `curl https://${DOMAIN}` ≠ 200

`DOMAIN` é derivado de `$(basename "$PWD").test` em A1. Exemplo: projeto em `~/work/meuapp` → `meuapp.test`.

Diagnóstico em ordem:

## 1. Container subiu?

```bash
vendor/bin/sail ps
```

Expected: services `app`, `nginx`, `postgres`, `redis` em `running`. Se algum `exited` ou `restarting`:

```bash
vendor/bin/sail logs <service> --tail=50
```

## 2. DNS local resolve?

```bash
getent hosts ${DOMAIN}
```

Expected: `127.0.0.1 <seu-dominio>.test`. Se vazio: A3 (`ssl-local-dev`) não adicionou ao `/etc/hosts`.

## 3. Certificado mkcert válido?

```bash
curl -v https://${DOMAIN} 2>&1 | grep -i "ssl\|certificate"
```

Se erro de cert: re-rodar `mkcert -install && mkcert ${DOMAIN} "*.test"` e mover para `docker/nginx/certs/`.

## 4. Nginx encontra upstream?

```bash
vendor/bin/sail exec nginx nginx -t
```

Se erro: revisar `docker/nginx/default.conf` — `fastcgi_pass app:9000` (fpm) ou `proxy_pass http://app:8000` (octane).

## 5. Migrations rodaram?

```bash
vendor/bin/sail artisan migrate:status
```

Se nenhuma rodou: `vendor/bin/sail artisan migrate --force`.

## 6. APP_KEY gerado?

```bash
grep APP_KEY .env
```

Se vazio: `vendor/bin/sail artisan key:generate`.

## 7. Logs Laravel

```bash
vendor/bin/sail artisan pail --timeout=10
```

Procurar exception nos primeiros 10s de requisição.
