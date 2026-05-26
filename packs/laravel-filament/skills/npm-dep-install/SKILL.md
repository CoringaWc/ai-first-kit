---
name: npm-dep-install
description: "Aplicar quando a stack Node canônica precisar ser instalada num projeto Laravel recém-criado, junto com Playwright e Chromium dentro do container `app` para testes Pest browser."
license: MIT
metadata:
  author: coringawc
  version: 2.0.0
  requires:
    - laravel-best-practices
  related:
    - init-project
    - composer-dep-install
    - docker-stack-fpm
    - docker-stack-octane-swoole
    - translation
    - pest-browser-test-filament-flow
---

# NPM Dep Install — Stack Node Canônica + Playwright

## Consistency First

Esta skill **assume**:

- Docker stack já está rodando — Dockerfile do `app` já contém libs de sistema do Chromium (`libnss3`, `libatk1.0`, `libxss1` e similares), instalados via `.agents/skills/_shared/docker-base-deps.md`. Instalar Chromium aqui no container não vai falhar por dependência de SO.
- A skill `composer-dep-install` já rodou — `composer.json` lista `filament/filament`, `livewire/livewire` e `laravel/reverb`. Sem isso, o input do theme Filament no Vite e o wiring de Echo apontam para arquivos inexistentes.
- Container `app` está up: `vendor/bin/sail ps --status=running | grep -q '\bapp\b'` retorna 0.

Esta skill **não**:

- não roda `npm` ou `npx` no host. Toda chamada é `vendor/bin/sail npm …` ou `vendor/bin/sail npx …`. Caso contrário, `node_modules/` ganha binários linkados ao kernel do host e Playwright baixa browsers em `~/.cache/ms-playwright` fora do container.
- não duplica wiring de locale ou Faker — responsabilidade da skill `translation`.
- não inicia daemon Reverb (`reverb:start`). Só configura HMR no `vite.config.js`. Subir o daemon é responsabilidade do `composer run dev` ou serviço Docker dedicado.

## Quick Reference

- 3 grupos de `npm install`: build (vite + tailwindcss v4 + plugin), realtime client (laravel-echo + pusher-js + axios), testing (playwright dev-only).
- 1 `npx playwright install --with-deps chromium` **obrigatório** após instalar Playwright (~150MB em `node_modules/playwright/.local-browsers/` dentro do container). `--with-deps` garante libs APT necessárias caso o Dockerfile evolua sem alguma.
- Tailwind v4 não usa `tailwind.config.js`; configuração vive em `@theme` dentro do CSS. Theme do Filament em `resources/css/filament/admin/theme.css`.
- `vite.config.js` recebe input do theme Filament + plugin `@tailwindcss/vite` + bloco `server.hmr` ajustado para Sail (porta 5173, host `0.0.0.0`).
- Append idempotente em `.env.example` das chaves Vite (`VITE_REVERB_*`, `VITE_APP_NAME`).
- Build final (`npm run build`) precisa sair com exit 0 antes do commit.

## Workflow

### Passo 1 — Validar pré-condições

- [ ] `vendor/bin/sail ps --status=running | grep -q '\bapp\b'` retorna 0 (senão abortar; peça reinvocação por `init-project`).
- [ ] `grep -q "filament/filament" composer.json` retorna 0 (senão `composer-dep-install` não rodou — abortar).

### Passo 2 — Instalar Grupo 1: Build (Vite + Tailwind v4)

- [ ] Rodar dentro do container:

```bash
vendor/bin/sail npm install --save-dev --no-fund --no-audit \
  vite \
  laravel-vite-plugin \
  tailwindcss@^4.0 \
  @tailwindcss/vite@^4.0
```

### Passo 3 — Instalar Grupo 2: Realtime client + axios

- [ ] Rodar:

```bash
vendor/bin/sail npm install --no-fund --no-audit \
  laravel-echo \
  pusher-js \
  axios
```

### Passo 4 — Configurar theme Filament + Tailwind v4 + HMR

- [ ] Confirmar que Filament gerou o theme em `composer-dep-install`: `ls resources/css/filament/admin/theme.css` (não sobrescrever; se faltar, `composer-dep-install` não rodou completo).

- [ ] Aplicar `vite.config.js` template (idempotente — guarda por sentinela `@tailwindcss/vite`):

```bash
if ! grep -q "@tailwindcss/vite" vite.config.js 2>/dev/null; then
  [[ -f vite.config.js ]] && cp vite.config.js vite.config.js.bak
  cp .agents/skills/npm-dep-install/templates/vite.config.js vite.config.js
fi
```

> O template inclui: input do theme Filament, plugin `@tailwindcss/vite` (Tailwind v4 não usa PostCSS) e bloco `server` com HMR para Sail (`0.0.0.0` + polling).

### Passo 5 — Append idempotente em `.env.example`

- [ ] Rodar:

```bash
if ! grep -q "^VITE_REVERB_APP_KEY=" .env.example; then
  {
    printf '\n# --- Vite + Reverb client (gerenciado por npm-dep-install) ---\n'
    printf 'VITE_APP_NAME="${APP_NAME}"\n'
    printf 'VITE_REVERB_APP_KEY="${REVERB_APP_KEY}"\n'
    printf 'VITE_REVERB_HOST="${REVERB_HOST}"\n'
    printf 'VITE_REVERB_PORT="${REVERB_PORT}"\n'
    printf 'VITE_REVERB_SCHEME="${REVERB_SCHEME}"\n'
  } >> .env.example
fi
```

### Passo 6 — Instalar Playwright + Chromium dentro do container

- [ ] Instalar pacote Node (dev-only):

```bash
vendor/bin/sail npm install --save-dev --no-fund --no-audit playwright
```

- [ ] Baixar Chromium + libs SO dentro do container (libs base já vieram do Dockerfile; `--with-deps` cobre evoluções futuras):

```bash
vendor/bin/sail npx playwright install --with-deps chromium
```

> ~150MB. Binário cai em `/var/www/html/node_modules/playwright/.local-browsers/chromium-*` (ou `~/.cache/ms-playwright/` do usuário `sail` — ambos dentro do container).

### Passo 7 — Build de verificação

- [ ] Rodar:

```bash
vendor/bin/sail npm run build
```

- [ ] Exit 0 obrigatório. Se falhar por `theme.css` inexistente, voltar ao Passo 4.

### Passo 8 — Commit do estado

- [ ] Rodar:

```bash
git add package.json package-lock.json vite.config.js .env.example resources/css/
git commit -m "feat(deps): instala stack node canônica (vite + tailwind v4 + echo + playwright/chromium)"
```

## Anti-Patterns

- ❌ **Não esquecer `resources/css/filament/admin/theme.css` no `input` do Vite.** Sem isso, Filament carrega o tema base do CDN e qualquer customização local some — sintoma é painel "quase certo" mas com cores erradas, e o debug demora porque `npm run build` passa sem erro.
- ❌ **Não rodar `npx playwright install --with-deps chromium` fora do container.** Os browsers caem em `~/.cache/ms-playwright/` do host, que não está montado no container `app` — `pest` browser test acusa `Executable doesn't exist` mesmo com Playwright instalado. Sempre via `vendor/bin/sail npx playwright install`.
- ❌ **Não tentar usar `tailwind.config.js` em Tailwind v4.** v4 abandonou o config JS em favor de `@theme` dentro do CSS. Manter `tailwind.config.js` legado causa regras não aplicadas e warnings silenciosos.
- ❌ **Não rodar `npm install` no host.** Reproduz o mesmo problema de `composer` no host: `node_modules/` ganha binários para a arquitetura e kernel do host e `npm run dev` no container quebra com erros de `node-gyp` ou módulos nativos.
- ❌ **Não commitar `node_modules/`.** Garantir que `.gitignore` (gerado pelo skeleton Laravel) já cobre. Conferir `git status` antes do commit do Passo 8.

## Verification

- [ ] `.agents/skills/_helpers/verify-skill.sh .agents/skills/npm-dep-install/SKILL.md` retorna `OK`
- [ ] `vendor/bin/sail npm list --depth=0 | grep -E "vite|tailwindcss|laravel-echo|pusher-js|playwright"` lista ≥ 5 linhas
- [ ] `vendor/bin/sail npm run build` exit 0 e gera `public/build/manifest.json`
- [ ] `vendor/bin/sail ls node_modules/playwright/.local-browsers/ 2>/dev/null | grep -q chromium` retorna 0
- [ ] `grep -c "^VITE_REVERB_" .env.example` ≥ 4
- [ ] `grep -q "@tailwindcss/vite" vite.config.js` retorna 0
- [ ] `git log --oneline -1` mostra commit `feat(deps): instala stack node canônica…`

## Related

- Skills Boost: `laravel-best-practices`
- Skills upstream: `docker-stack-fpm` ou `docker-stack-octane-swoole`, `composer-dep-install`
- Skills downstream: `translation`, `pest-browser-test-filament-flow`
- Orquestradora: `init-project`
- Template: `.agents/skills/npm-dep-install/templates/vite.config.js`
- Helper SO/Node/Chromium: `.agents/skills/_shared/docker-base-deps.md`
