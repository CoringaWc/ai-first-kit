# `.env.example` Bootstrap (A1)

A1 é dona do `.env.example` inicial (Princípio 16 do spec). Outras skills fazem **append idempotente** das suas chaves. Detalhe de implementação do Passo 4:

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

## `.env.testing` derivado

```bash
[ -f .env.testing ] || cp .env.example .env.testing
sed -i 's/^APP_ENV=.*/APP_ENV=testing/' .env.testing
sed -i 's/^DB_DATABASE=.*/DB_DATABASE=testing/' .env.testing
```

## Convenções para skills downstream

Cada skill que adiciona chaves ao `.env.example` deve:

1. Guardar a seção com sentinela (`grep -q "^# --- <skill> ---" || { append }`)
2. Nunca remover chaves de outras skills
3. Comentar com nome da skill responsável (`# --- Reverb (gerenciado por composer-dep-install / A4) ---`)
