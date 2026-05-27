---
name: vite-reverb-nginx-routing
description: "Aplicar quando configurar ou revisar Vite, HMR, Reverb, WebSocket, Echo, Nginx ou docker-compose neste kit Laravel/Filament, especialmente paths /vite, /ws, /app, porta 5173, /ws/apps, REVERB_ALLOWED_ORIGINS, REVERB_BROADCAST_* ou risco de sobrescrever arquivos gerados."
license: MIT
metadata:
  author: coringawc
  version: 1.0.0
  related:
    - docker-stack-fpm
    - docker-stack-octane-swoole
    - npm-dep-install
    - composer-dep-install
    - echo-development
---

# Vite + Reverb via Nginx

## Consistency First

Este kit usa Nginx como única borda HTTP(S) do browser. Vite e Reverb rodam em containers internos e nunca devem ser acessados por porta pública própria.

Antes de alterar `docker/nginx/default.conf`, `docker-compose.yml`, `vite.config.js`, `resources/js/echo.js`, `config/broadcasting.php` ou `config/reverb.php`, leia `rules/overwrite-safety.md` e aplique patch mínimo. Não copie template por cima de arquivo customizado sem backup, diff e confirmação.

## Quick Reference

- Browser → `https://<dominio>/vite/...` → Nginx → `https://vite:5173`.
- Browser → `wss://<dominio>/ws/app/<key>` → Nginx → `http://reverb:8080/app/<key>`.
- `/app` fica livre para painel Filament; Reverb não usa `/app` publicamente.
- `/ws/apps/` é bloqueado; é superfície administrativa/API, não endpoint de cliente.
- `vite` e `reverb` não publicam `ports:` no Compose.
- Serviços auxiliares (`postgres`, `redis`, `mailpit`, `minio`, `ollama`, `qdrant`) bindam em `127.0.0.1` por padrão.
- `REVERB_ALLOWED_ORIGINS` nunca é `*` em projeto real.

## Workflow

1. Leia `rules/topology.md` para entender o roteamento esperado.
2. Use `rules/canonical-snippets.md` como referência de implementação.
3. Leia `rules/overwrite-safety.md` antes de editar qualquer arquivo gerado.
4. Leia `rules/security-checklist.md` antes de finalizar.
5. Aplique a menor alteração possível.
6. Rode a verificação da seção abaixo.

## Anti-Patterns

- Não publicar `5173`, `8080`, `9000`, `1025`, `8025`, `6379` ou `5432` em todas as interfaces por padrão.
- Não trocar `/ws` por `/app`; isso conflita com Filament.
- Não expor `/ws/apps/` ao browser.
- Não colocar `REVERB_APP_SECRET` em variável `VITE_*`.
- Não usar `allowed_origins => ['*']` fora de protótipo descartável.
- Não substituir arquivos customizados por templates sem revisar diff.

## Verification

```bash
vendor/bin/sail exec nginx nginx -t
vendor/bin/sail config >/tmp/opencode/compose.yml 2>/dev/null || docker compose config >/tmp/opencode/compose.yml
grep -q '^  vite:' /tmp/opencode/compose.yml
! grep -q '5173:5173' /tmp/opencode/compose.yml
! (grep -A30 '^  vite:' /tmp/opencode/compose.yml | grep -q '^    ports:')
! (grep -A30 '^  reverb:' /tmp/opencode/compose.yml | grep -q '^    ports:')
grep -q 'location ^~ /vite/' docker/nginx/default.conf
grep -q 'location ^~ /ws/' docker/nginx/default.conf
grep -q 'location ^~ /ws/apps/' docker/nginx/default.conf
grep -q "base: '/vite/'" vite.config.js
grep -q "wsPath: '/ws'" resources/js/echo.js
grep -q 'REVERB_ALLOWED_ORIGINS' config/reverb.php
! grep -q "'allowed_origins' => \['\*'\]" config/reverb.php
```

## Related

- `rules/topology.md`
- `rules/canonical-snippets.md`
- `rules/overwrite-safety.md`
- `rules/security-checklist.md`
