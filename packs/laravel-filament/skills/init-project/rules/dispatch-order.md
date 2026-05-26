# Dispatch Order (A1 → A2..A8)

Ordem estrita justificada:

- **A2** (containers) primeiro: tudo downstream roda dentro do container Sail.
- **A3** (SSL/hosts) antes de A4: `composer install` pode validar URLs HTTPS internas (mirrors, packagist proxy, etc.).
- **A4** (composer) antes de A5: Filament gera `resources/css/filament/admin/theme.css` que A5 referencia em `vite.config.js`.
- **A5** (npm) antes de A6/A7: `npm run build` precisa rodar para validar wiring.
- **A6** (Octane opt-in): **skip em greenfield** — A2-octane já é octane. A6 só roda em migração de projeto existente FPM.
- **A7** (i18n) depois de A4: `lang:add` (ou `lang:publish`) depende de pacotes instalados por A4.
- **A8** (CI) por último: referencia stack estável (Dockerfile, package.json, composer.lock fixos).

Cada skill pode falhar e abortar a cadeia (`exit 1`). A1 não recupera automaticamente — exibe instrução de re-invocação.
