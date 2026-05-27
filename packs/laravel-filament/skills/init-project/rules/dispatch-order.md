# Dispatch Order (A1 → A2..A8)

Ordem estrita justificada no fluxo Docker-first:

- **Env mínimo primeiro**: `docker-compose.yml` lê `${WWWGROUP}`, `${DB_*}` e portas antes do Laravel existir.
- **A2 containers antes do Laravel**: a imagem `app` fornece PHP 8.4, Composer 2, Node 22, libs Chromium e extensões PHP; o host não fornece runtime de aplicação.
- **Laravel skeleton dentro do container**: `composer create-project` roda via `docker compose run app`, copiando o resultado para o workspace e preservando `.agents/`.
- **Sail helper depois do skeleton**: instalar `laravel/sail` cria `vendor/bin/sail`; não rodar `sail:install` porque o compose canônico já existe.
- **Boost depois do Sail helper**: `vendor/bin/sail artisan boost:install` garante que Artisan rode no mesmo PHP da imagem.
- **A3 SSL/hosts antes de A4**: `composer require` pode validar URLs HTTPS internas (mirrors, packagist proxy, etc.).
- **A4 composer antes de A5**: Filament gera `resources/css/filament/admin/theme.css` que A5 referencia em `vite.config.js`.
- **A5 npm antes de A6/A7**: `npm run build` precisa rodar dentro do container para validar wiring.
- **A6 Octane opt-in**: **skip em greenfield** — A2-octane já é octane. A6 só roda em migração de projeto existente FPM.
- **A7 i18n depois de A4**: `lang:add` (ou `lang:publish`) depende de pacotes instalados por A4.
- **A8 CI por último**: referencia stack estável (Dockerfile, package.json, composer.lock fixos).

Cada skill pode falhar e abortar a cadeia (`exit 1`). A1 não recupera automaticamente — exibe instrução de re-invocação.
