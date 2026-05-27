# `.env.example` Bootstrap (A1)

A1 é dona do `.env.example` inicial (Princípio 16 do spec). No fluxo Docker-first, `.env`, `.env.example` e `.env.testing` podem nascer **antes** do skeleton Laravel para alimentar `docker-compose.yml`. Depois que o Laravel é criado dentro do container, A1 reaplica as mesmas chaves idempotentemente. Outras skills fazem **append idempotente** das suas chaves.

## Ambiente mínimo pré-Laravel

```bash
PROJECT_NAME="$(basename "$PWD")"
DOMAIN="${PROJECT_NAME}.test"

touch .env .env.example

set_env_entry() {
  local ENV_FILE="$1" ENTRY="$2" KEY_NAME="${ENTRY%%=*}"
  if grep -q "^${KEY_NAME}=" "$ENV_FILE"; then
    sed -i "s|^${KEY_NAME}=.*|${ENTRY}|" "$ENV_FILE"
  else
    echo "$ENTRY" >> "$ENV_FILE"
  fi
}

for ENV_FILE in .env .env.example; do
  for ENTRY in \
    "APP_NAME=Laravel" \
    "APP_ENV=local" \
    "APP_DEBUG=true" \
    "APP_URL=https://${DOMAIN}" \
    "APP_SERVICE=app" \
    "WWWUSER=1000" \
    "WWWGROUP=1000" \
    "DB_CONNECTION=pgsql" \
    "DB_HOST=postgres" \
    "DB_PORT=5432" \
    "DB_DATABASE=laravel" \
    "DB_USERNAME=sail" \
    "DB_PASSWORD=password" \
    "FORWARD_DB_PORT=5432" \
    "FORWARD_REDIS_PORT=6379"; do
    set_env_entry "$ENV_FILE" "$ENTRY"
  done
done
```

## Header de ownership (idempotente)

```bash
if ! grep -q "gerenciado por init-project (A1)" .env.example 2>/dev/null; then
  {
    printf '# ============================================\n'
    printf '# .env.example — gerenciado por init-project (A1)\n'
    printf '# Outras skills fazem APPEND IDEMPOTENTE das suas chaves.\n'
    printf '# Verifique com: grep -c "^[A-Z]" .env.example\n'
    printf '# ============================================\n\n'
    cat .env.example
  } > .env.example.new && mv .env.example.new .env.example
fi
```

Reaplique este bloco depois de copiar o skeleton Laravel do container, porque `composer create-project` pode sobrescrever `.env.example`.

## `.env.testing` derivado

```bash
[ -f .env.testing ] || cp .env.example .env.testing
sed -i 's/^APP_ENV=.*/APP_ENV=testing/' .env.testing
sed -i 's/^DB_DATABASE=.*/DB_DATABASE=testing/' .env.testing
if grep -q '^APP_KEY=' .env.testing; then
  sed -i 's#^APP_KEY=.*#APP_KEY=base64:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=#' .env.testing
else
  printf 'APP_KEY=base64:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\n' >> .env.testing
fi
```

## Convenções para skills downstream

Cada skill que adiciona chaves ao `.env.example` deve:

1. Guardar a seção com sentinela (`grep -q "^# --- <skill> ---" || { append }`)
2. Nunca remover chaves de outras skills
3. Comentar com nome da skill responsável (`# --- Reverb (gerenciado por composer-dep-install / A4) ---`)
