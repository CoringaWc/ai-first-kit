---
name: ci-github-actions
description: "Aplicar quando o usuário pedir pipeline GitHub Actions para Laravel com Pint, Larastan, Pest unit/feature, Pest Browser e build Vite na branch main."
license: MIT
metadata:
  author: coringawc
  version: 2.0.0
  requires:
    - laravel-best-practices
  related:
    - init-project
    - composer-dep-install
    - npm-dep-install
    - verify-before-commit
---

# CI GitHub Actions

## Consistency First

Pipeline canônica roda **apenas na branch `main`** (push e PR contra `main`). Não criar matriz multi-branch — staging/feature branches usam o hook local `verify-before-commit`. Se `.github/workflows/ci.yml` já existe e diverge do template, peça confirmação antes de sobrescrever.

Node, PHP e extensões devem casar com o que está nos Dockerfiles (`_shared/docker-base-deps.md`): PHP 8.4, Node 22, `mbstring`, `intl`, `pdo_pgsql`, `redis`, `gd`, `opcache`.

## Quick Reference

- 5 jobs: `lint`, `static` (paralelos, gate); depois `test`, `browser`, `build` (paralelos, dependem do gate).
- Triggers: `push` em `main`, `pull_request` contra `main`.
- `concurrency: group: ci-${{ github.ref }}, cancel-in-progress: true` para matar runs obsoletos no mesmo branch.
- Service containers: Postgres 16, Redis 7.
- Cache: Composer, npm, e browsers do Playwright em path explícito (`~/.cache/ms-playwright`).
- `test` roda `vendor/bin/pest --exclude-group=browser`; `browser` roda `vendor/bin/pest --group=browser` em job próprio com Chromium.
- Cobertura mínima Pest: 70% (`--coverage --min=70`).
- Screenshots de `tests/Browser/Screenshots/` enviados em failure via `actions/upload-artifact@v4`.

## Workflow

- [ ] Detectar Pest:

```bash
[[ -f vendor/bin/pest ]] || { echo "Pest não instalado. Rode composer-dep-install primeiro."; exit 1; }
```

- [ ] Comparar e copiar template:

```bash
mkdir -p .github/workflows
TEMPLATE=".agents/skills/ci-github-actions/templates/ci.yml"
TARGET=".github/workflows/ci.yml"

[[ -f "$TEMPLATE" ]] || { echo "Template ausente: $TEMPLATE"; exit 1; }

if [[ -f "$TARGET" ]] && ! cmp -s "$TEMPLATE" "$TARGET"; then
  printf 'CI existente diverge do template. Sobrescrever? [y/N] '
  read -r ANSWER
  [[ "$ANSWER" =~ ^[Yy]$ ]] || { echo "Abortando: CI customizado preservado."; exit 1; }
fi

cp "$TEMPLATE" "$TARGET"
```

- [ ] Verificar YAML válido:

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))" && echo OK
```

- [ ] Confirmar versões batem com o Docker:

```bash
grep -q "node-version: '22'" .github/workflows/ci.yml || echo "AVISO: Node deveria ser 22 (igual ao Dockerfile)."
grep -q "php-version: '8.4'" .github/workflows/ci.yml || echo "AVISO: PHP deveria ser 8.4 (igual ao Dockerfile)."
grep -q "extensions: mbstring, intl" .github/workflows/ci.yml || echo "AVISO: faltam extensões mbstring/intl no setup-php."
```

- [ ] Commit:

```bash
git add .github/workflows/ci.yml
git commit -m "ci: pipeline GitHub Actions (lint, static, test, browser, build) em main"
```

## Anti-Patterns

| Racionalização | Realidade |
| --- | --- |
| "Rodo `pest` inteiro no job `test`." | Browser tests precisam Chromium + Node + display; tempo do job dobra e flakiness contamina cobertura. Separe via `--exclude-group=browser` no `test` e `--group=browser` no `browser`. |
| "Uso `node-version: lts/*`." | LTS muda sem aviso e quebra reprodutibilidade. Pin **Node 22** igual ao Dockerfile. |
| "Pulo `mbstring`/`intl` no `setup-php`." | Larastan e Filament dependem; falha silenciosa em validações com locale `pt_BR`. |
| "Não preciso de `concurrency`." | Push em sequência rápida deixa runs obsoletos consumindo minutos. `cancel-in-progress: true` no `group` por ref resolve. |
| "Defino `MIN_COVERAGE=90` desde o bootstrap." | Projeto novo sem testes não atinge; pipeline vermelha vira ruído. Começar em 70%, subir quando código maduro. |
| "Cache do Playwright sem path explícito." | `actions/cache` precisa do `~/.cache/ms-playwright`; sem path certo, baixa Chromium toda execução (~3min). |
| "Rodo a pipeline em todas as branches." | Feature branches usam `verify-before-commit` local; CI em branch fechada queima minutos por nada. Manter só `main`. |

Sinais ruins: ausência de `concurrency`, services sem healthcheck, `playwright install` sem `--with-deps`, paths de template apontando para diretórios inexistentes.

## Verification

- [ ] `./.agents/skills/_helpers/verify-skill.sh .agents/skills/ci-github-actions/SKILL.md`
- [ ] `.github/workflows/ci.yml` existe e é YAML válido (`python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"`).
- [ ] `grep -E "branches:\s*\[main\]" .github/workflows/ci.yml` confirma trigger apenas em `main`.
- [ ] `grep -q "concurrency:" .github/workflows/ci.yml` confirma cancel-in-progress.
- [ ] `gh workflow list` mostra `CI` ativo após push.
- [ ] `gh run list --workflow=ci.yml --limit=1` mostra execução `success` para o último commit em `main`.

## Related

- `templates/ci.yml` - Pipeline canônica.
- `_shared/docker-base-deps.md` - Versões de Node, PHP e extensões alinhadas com o Docker.
- `init-project` - Skill mestra que invoca esta CI.
- `composer-dep-install`, `npm-dep-install` - Pré-requisitos (Pest e Playwright instalados).
- `verify-before-commit` - Equivalente local rodado em feature branches.
