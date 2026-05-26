---
name: translation
description: "Aplicar quando init-project (A1) executar bootstrap de idioma ou quando o usuário pedir setup de tradução pt_BR no projeto Laravel + Filament."
license: MIT
metadata:
  author: coringawc
  version: 2.0.0
  requires:
    - laravel-best-practices
    - spatie-laravel-php-standards
  related:
    - init-project
    - composer-dep-install
    - enum-with-translations
    - faker-realistic-ptbr
---

# Translation Bootstrap

Bootstrap mecânico de tradução pt_BR. A **doutrina viva** (como traduzir, chave-frase, plural, gênero, capitalização, anti-patterns) vive em `rules/translation-rules.md` e é referência obrigatória de toda skill que produz strings.

## Consistency First

Antes de executar, leia `rules/translation-rules.md`. Se o projeto já está bootstrap-ado (`.env` com `APP_LOCALE=pt_BR` e `lang/pt_BR.json` presente), pular execução e apenas garantir seção `## Linguagem` no `AGENTS.md`. Esta skill é idempotente.

## Quick Reference

- Locale fixo: `APP_LOCALE=pt_BR`, `APP_FALLBACK_LOCALE=en`, `APP_FAKER_LOCALE=pt_BR`. Sem alternância em runtime.
- `config/app.php` **não é editado**. Laravel 13 lê do `.env`.
- Único pacote de tradução: `lucascudo/laravel-pt-br-localization` (instalado pela `composer-dep-install`). Publica `lang/pt_BR/validation.php`.
- Único arquivo de UI: `lang/pt_BR.json` com chave-frase em inglês.
- `AGENTS.md` recebe seção `## Linguagem` (idempotente): comunicação usuário ↔ IA em pt_BR.
- Doutrina de tradução: `rules/translation-rules.md` (obrigatório para toda skill que produz strings).

## Workflow

- [ ] Confirmar que `composer-dep-install` já instalou `lucascudo/laravel-pt-br-localization`:

```bash
vendor/bin/sail composer show lucascudo/laravel-pt-br-localization >/dev/null \
  || { echo "FAIL: instale via composer-dep-install antes"; exit 1; }
```

- [ ] Publicar `validation.php` do pacote (idempotente — pacote tem `--force` próprio, mas pulamos se já publicado):

```bash
if [[ ! -f lang/pt_BR/validation.php ]]; then
  vendor/bin/sail artisan vendor:publish --tag=laravel-pt-br-localization --no-interaction
fi
```

- [ ] Update-or-append idempotente no `.env` e `.env.example`:

```bash
for FILE in .env .env.example; do
  [[ -f "$FILE" ]] || continue
  for ENTRY in "APP_LOCALE=pt_BR" "APP_FALLBACK_LOCALE=en" "APP_FAKER_LOCALE=pt_BR"; do
    KEY="${ENTRY%%=*}"
    if grep -q "^${KEY}=" "$FILE"; then
      sed -i "s|^${KEY}=.*|${ENTRY}|" "$FILE"
    else
      echo "$ENTRY" >> "$FILE"
    fi
  done
done
```

- [ ] Criar `lang/pt_BR.json` vazio se ausente. Não sobrescrever se existe:

```bash
[[ -f lang/pt_BR.json ]] || echo '{}' > lang/pt_BR.json
vendor/bin/sail php -r 'json_decode(file_get_contents("lang/pt_BR.json"), true, 512, JSON_THROW_ON_ERROR); echo "JSON OK\n";'
```

- [ ] Garantir seção `## Linguagem` no `AGENTS.md` (idempotente — não duplica, não sobrescreve outras seções):

```bash
if [[ ! -f AGENTS.md ]]; then
  cat > AGENTS.md <<'EOF'
# AGENTS.md

Instruções de agente para este projeto.
EOF
fi

if ! grep -qE '^## Linguagem$' AGENTS.md; then
  cat >> AGENTS.md <<'EOF'

## Linguagem

- Toda comunicação usuário ↔ IA é em **pt_BR**.
- Strings de UI seguem `.agents/skills/translation/rules/translation-rules.md` (chave-frase em inglês no código, valor pt_BR em `lang/pt_BR.json`).
- Locale fixo: `APP_LOCALE=pt_BR`, sem alternância em runtime.
EOF
fi
```

- [ ] Limpar cache de config para o `.env` novo ter efeito:

```bash
vendor/bin/sail artisan config:clear
```

## Anti-Patterns

- ❌ **Editar `config/app.php`** para fixar locale. Laravel 13 lê do `.env`; edição quebra `php artisan config:cache`. Caso real: `config/app.php` em projetos Laravel 13 não declara `locale` literal.
- ❌ **Instalar `laravel-lang/lang`**. Pacote dispensado pela filosofia do projeto (locale fixo). Único pacote permitido: `lucascudo/laravel-pt-br-localization`.
- ❌ **Criar `lang/pt_BR/labels.php` ou `lang/pt_BR/enums.php`**. Tudo de UI vai no JSON. Ver `rules/translation-rules.md` §2.
- ❌ **Publicar `validation.php` cego** quando já existe customizado. Sobrescreve mensagens. Por isso o `Workflow` checa existência antes.
- ❌ **Sobrescrever `lang/pt_BR.json` sem `Read` prévio**. Apaga entradas de outras skills. Procedimento obrigatório: ver `rules/translation-rules.md` §8.
- ❌ **Append duplicado da seção `## Linguagem`**. Sempre testar com `grep -qE '^## Linguagem$'` antes. Caso real: rodar a skill 2× sem guard cria duas seções idênticas.
- ❌ **Criar marcadores HTML** (`<!-- BEGIN: translation -->`) no `AGENTS.md`. Edição é via heading markdown + `grep -qE`. Marcadores poluem o arquivo lido por humanos e agentes.

## Verification

- [ ] `vendor/bin/sail artisan tinker --execute 'echo config("app.locale");'` retorna `pt_BR`
- [ ] `vendor/bin/sail artisan tinker --execute 'echo config("app.fallback_locale");'` retorna `en`
- [ ] `vendor/bin/sail artisan tinker --execute 'echo config("app.faker_locale");'` retorna `pt_BR`
- [ ] `test -f lang/pt_BR/validation.php` e `test -f lang/pt_BR.json`
- [ ] `vendor/bin/sail php -r 'json_decode(file_get_contents("lang/pt_BR.json"), true, 512, JSON_THROW_ON_ERROR); echo "OK\n";'` imprime `OK`
- [ ] `grep -cE '^## Linguagem$' AGENTS.md` retorna `1` (exatamente uma seção)
- [ ] `.agents/skills/_helpers/verify-skill.sh .agents/skills/translation/SKILL.md` retorna `OK`

## Related

- Doutrina de tradução: `.agents/skills/translation/rules/translation-rules.md`
- Skill mestra: `init-project`
- Pacote de validação: `composer-dep-install` (instala `lucascudo/laravel-pt-br-localization`)
- Strings em enums: `enum-with-translations` (lê esta rule)
- Faker pt_BR: `faker-realistic-ptbr` (usa `APP_FAKER_LOCALE` fixado aqui)
