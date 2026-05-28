---
name: project-up
description: "Aplicar quando o usuario pedir para subir, inicializar, recuperar ou validar um clone existente deste kit Laravel/Filament via Docker/Sail. Use when bringing up an existing Laravel Filament Docker-first project, first run, recovery, smoke test, or handoff readiness."
license: MIT
metadata:
  author: coringawc
  version: 1.0.0
  requires:
    - laravel-best-practices
  related:
    - docker-stack-fpm
    - docker-stack-octane-swoole
    - composer-dep-install
    - npm-dep-install
    - verify-before-commit
---

# Project Up — Subir Clone Existente
## Consistency First

Esta skill opera um projeto Laravel/Filament ja criado a partir deste kit. Ela nao cria o projeto do zero; para greenfield use `init-project`.

O host e Docker-first: nao use PHP, Composer, Artisan, Node, npm ou npx do host, mesmo quando existirem. Antes do Sail existir, use Docker Compose direto. Depois que `vendor/bin/sail` existir, use Sail para PHP/Composer/Artisan/Node.

Bloqueie cedo quando segredos locais obrigatorios estiverem ausentes. Para este kit, antes de subir containers precisam existir `.env`, `auth.json`, `.cert/cert.pem` e `.cert/cert.key`. Se o usuario ainda nao destravou o repositorio, oriente `git-crypt unlock .git-crypt-keys/<nome-da-chave>.key`, sem pedir nem exibir segredos.

## Quick Reference

- Leia o `README.md` do projeto antes de agir; ele e a fonte operacional local.
- Pre-flight do host: `docker compose version`, `docker info`, `git --version`, `git-crypt --version`.
- Primeira subida sem Sail: `docker compose up -d --build`.
- Subida com Sail disponivel: `vendor/bin/sail up -d --build`.
- Se `vendor/` ou `node_modules/` ja existem em estado parcial, pergunte antes de qualquer `up` que possa disparar auto-install.
- Nunca rode `composer update`, `npm update`, `rm -rf vendor node_modules`, `docker compose down -v`, `migrate:fresh` ou troca de `APP_KEY` sem aprovacao explicita.
- O entrypoint canonico pode instalar dependencias ausentes quando `AUTO_INSTALL_DEPS=true`.
- Pos-up obrigatorio: migrations, smoke HTTPS de `/up` e `/`, e `vendor/bin/sail composer verify`.
- Logs sao recuperacao guiada, nao criterio de sucesso isolado.
- Antes de declarar pronto, todos os checks aplicaveis precisam passar no mesmo fluxo de verificacao.

## Workflow

### Passo 1 — Ler contexto e pre-flight

- [ ] Confirmar que esta e uma operacao em clone/projeto existente, nao bootstrap greenfield.
- [ ] Ler `README.md` e registrar comandos especificos do projeto.
- [ ] Validar ferramentas minimas do host:

```bash
docker compose version >/dev/null 2>&1 || { echo "ERRO: docker compose ausente"; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERRO: Docker daemon indisponivel"; exit 1; }
git --version >/dev/null 2>&1 || { echo "ERRO: git ausente"; exit 1; }
git-crypt --version >/dev/null 2>&1 || { echo "ERRO: git-crypt ausente"; exit 1; }
```

### Passo 2 — Validar segredos locais obrigatorios

- [ ] Bloquear antes de subir containers se qualquer arquivo local sensivel obrigatorio faltar:

```bash
for path in .env auth.json .cert/cert.pem .cert/cert.key; do
  [ -f "$path" ] || { echo "ERRO: arquivo obrigatorio ausente: $path"; exit 1; }
done
```

- [ ] Se faltar arquivo versionado protegido por `git-crypt`, orientar sem expor segredo:

```bash
git-crypt unlock .git-crypt-keys/<nome-da-chave>.key
```

- [ ] Se o arquivo for local, ignorado ou entregue fora do Git, bloquear e pedir que o usuario forneca por canal externo seguro. O `git-crypt unlock` nao cria arquivos sensiveis que nao estejam versionados.

### Passo 3 — Diagnosticar estado atual

- [ ] Registrar estado sem alterar arquivos:

```bash
git status --short
docker compose ps -a || true
test -x vendor/bin/sail && echo "Sail disponivel" || echo "Sail ainda ausente"
test -f vendor/autoload.php && echo "Composer instalado" || echo "Composer pendente"
test -f node_modules/.install-complete && echo "Node instalado" || echo "Node pendente"
```

- [ ] Se `vendor/` existir sem `vendor/autoload.php`, bloquear antes do `up` e pedir aprovacao para permitir `composer install` automatico no container:

```bash
if [ -d vendor ] && [ ! -f vendor/autoload.php ]; then
  echo "BLOQUEADO: vendor/ existe, mas vendor/autoload.php nao existe. O proximo up pode alterar vendor/. Peça aprovacao antes de continuar."
  exit 1
fi
```

- [ ] Se `node_modules/` existir sem `node_modules/.install-complete`, bloquear antes do `up` e pedir aprovacao para permitir `npm install` automatico no container:

```bash
if [ -d node_modules ] && [ ! -f node_modules/.install-complete ]; then
  echo "BLOQUEADO: node_modules/ existe, mas .install-complete nao existe. O proximo up pode alterar node_modules/. Peça aprovacao antes de continuar."
  exit 1
fi
```

- [ ] Se containers existentes indicarem tentativa anterior, diagnosticar primeiro. Pergunte antes de rebuild pesado (`--build`, `--no-cache`, `--pull`) quando a imagem ja existir e a intencao for apenas operacao diaria.

### Passo 4 — Subir pelo caminho correto

- [ ] Se `vendor/bin/sail` existir e for executavel, usar Sail. Para primeira subida, recuperacao, ou quando imagem/compose mudou, use build:

```bash
vendor/bin/sail up -d --build
```

- [ ] Para operacao diaria sem alteracao de imagem/compose, use:

```bash
vendor/bin/sail up -d
```

- [ ] Se `vendor/bin/sail` nao existir, usar Docker Compose direto com build:

```bash
docker compose up -d --build
```

- [ ] Acompanhar falhas com logs direcionados, sem trocar para ferramentas do host:

```bash
docker compose ps -a
docker compose logs --tail=200 app queue reverb vite nginx postgres redis
```

### Passo 5 — Verificar runtime e migrations

- [ ] Depois que Sail existir, migrar pelo container. A skill usa `--force --no-interaction` porque agentes executam de forma nao interativa:

```bash
vendor/bin/sail artisan migrate --force --no-interaction
```

- [ ] Confirmar services obrigatorios:

```bash
vendor/bin/sail ps
```

### Passo 6 — Smoke HTTPS obrigatorio

- [ ] Derivar a URL completa de `APP_URL` dentro do container e validar `/up` e `/`:

```bash
APP_URL="$(vendor/bin/sail php -r '$env = parse_ini_file(".env"); echo rtrim($env["APP_URL"] ?? "https://localhost", "/");')"
curl -fsSk "${APP_URL}/up" >/dev/null
curl -fsSkI "${APP_URL}/" >/dev/null
```

### Passo 7 — Gate final

- [ ] Rodar o gate local completo:

```bash
vendor/bin/sail composer verify
```

- [ ] Se qualquer etapa falhar, corrigir a causa raiz e rodar `vendor/bin/sail composer verify` inteiro de novo. Nao reporte sucesso com rodada parcial.

## Anti-Patterns

| Racionalizacao | Realidade |
| --- | --- |
| "Sail nao existe, vou instalar Composer/PHP no host." | Primeira subida usa `docker compose up -d --build`; host nao fornece runtime da app. |
| "Ja tem `vendor/`, entao posso atualizar tudo." | `composer update` e `npm update` mudam lockfiles e exigem aprovacao explicita. |
| "Faltou cert/auth, deixo o container mostrar o erro." | Segredos locais obrigatorios bloqueiam antes de subir para evitar diagnostico ruidoso. |
| "`vendor/` existe, posso deixar o entrypoint arrumar." | Se `vendor/autoload.php` falta, o proximo `up` pode alterar `vendor/`; pergunte antes. |
| "`node_modules/` existe, posso deixar npm completar." | Se `.install-complete` falta, o proximo `up` pode alterar `node_modules/`; pergunte antes. |
| "`/up` passou, entao esta pronto." | `/up` nao prova sessoes, migrations, assets, Filament ou build; rode raiz e `composer verify`. |
| "Logs sem erro bastam." | Logs ajudam recuperacao, mas sucesso exige migrations, smoke HTTPS e gate. |
| "Vou usar `docker compose down -v` para limpar." | Isso apaga volumes e dados. Exige aprovacao explicita. |
| "Trocar `APP_KEY` resolve criptografia." | Trocar chave invalida dados criptografados e sessoes. Exige decisao humana. |

Red flags: comando sem Docker/Sail, `npm` ou `composer` do host, upgrade sem confirmacao, apagar volumes, declarar pronto sem `composer verify`, trocar smoke HTTP por browser manual.

## Verification

- [ ] `.agents/skills/_helpers/verify-skill.sh .agents/skills/project-up/SKILL.md` retorna `OK`.
- [ ] `docker compose config --quiet` retorna 0.
- [ ] Dependencias parciais foram bloqueadas antes de qualquer `up` que pudesse alterar `vendor/` ou `node_modules/`.
- [ ] `vendor/bin/sail up -d`, `vendor/bin/sail up -d --build` ou `docker compose up -d --build` foi escolhido conforme disponibilidade do Sail e estado da imagem.
- [ ] `vendor/bin/sail artisan migrate --force --no-interaction` retorna 0.
- [ ] `curl -fsSk "${APP_URL}/up" >/dev/null` retorna 0.
- [ ] `curl -fsSkI "${APP_URL}/" >/dev/null` retorna 0.
- [ ] `vendor/bin/sail composer verify` retorna 0 no gate final.
- [ ] Nenhum segredo, certificado, chave git-crypt, `vendor/`, `node_modules/` ou artifact de teste foi stageado sem decisao explicita.

## Related

- `init-project` — cria projeto novo; nao usar para subir clone existente.
- `docker-stack-fpm` e `docker-stack-octane-swoole` — definem a stack gerada.
- `composer-dep-install` e `npm-dep-install` — adicionam dependencias canonicas quando o projeto esta em bootstrap.
- `verify-before-commit` — contrato do gate `vendor/bin/sail composer verify`.
- Laravel Sail docs: https://laravel.com/docs/sail
