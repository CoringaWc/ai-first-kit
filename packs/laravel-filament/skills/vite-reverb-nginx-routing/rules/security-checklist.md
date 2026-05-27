# Checklist de Segurança

## Deve passar

- `vite` sem `ports:` no Compose.
- `reverb` sem `ports:` no Compose.
- `postgres`, `redis`, `mailpit`, `minio`, `ollama` e `qdrant` com bind `127.0.0.1:` quando publicados.
- Nginx tem `/vite/`, `/ws/` e bloqueio de `/ws/apps/`.
- `/vite/` e `/mailpit/` são restritos a loopback/LAN privada ou protegidos por controle equivalente.
- `config/reverb.php` usa `REVERB_ALLOWED_ORIGINS` e não `['*']`.
- `.env` não contém `REVERB_ALLOWED_ORIGINS=*`.
- `resources/js/echo.js` tem `wsPath: '/ws'`.
- `config/broadcasting.php` usa `REVERB_BROADCAST_*` para publish interno.

## Probes úteis

```bash
vendor/bin/sail exec nginx nginx -t
curl -kfsSI https://${DOMAIN}/vite/@vite/client
curl -kso /dev/null -w '%{http_code}' https://${DOMAIN}/ws/apps/test
MAILPIT_STATUS=$(curl -kso /dev/null -w '%{http_code}' https://${DOMAIN}/mailpit/ || true)
test "$MAILPIT_STATUS" = "200" || test "$MAILPIT_STATUS" = "502"
curl -kfsSI https://${DOMAIN}/up
! grep -q '^REVERB_ALLOWED_ORIGINS=\*$' .env
docker compose config >/tmp/opencode/compose.yml
grep -q '127.0.0.1:.*:5432' /tmp/opencode/compose.yml
grep -q '127.0.0.1:.*:6379' /tmp/opencode/compose.yml
! (grep -A30 '^  vite:' /tmp/opencode/compose.yml | grep -q '^    ports:')
! (grep -A30 '^  reverb:' /tmp/opencode/compose.yml | grep -q '^    ports:')

VITE_STATUS=$(curl --max-time 5 -ksS --http1.1 -o /dev/null -w '%{http_code}' \
  -H 'Connection: Upgrade' \
  -H 'Upgrade: websocket' \
  -H 'Sec-WebSocket-Version: 13' \
  -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' \
  -H 'Sec-WebSocket-Protocol: vite-hmr' \
  "https://${DOMAIN}/vite/vite-hmr" || true)

REVERB_KEY=$(grep '^REVERB_APP_KEY=' .env | cut -d= -f2- | tr -d '"' | tr -d "'")
REVERB_STATUS=$(curl --max-time 5 -ksS --http1.1 -o /dev/null -w '%{http_code}' \
  -H "Origin: https://${DOMAIN}" \
  -H 'Connection: Upgrade' \
  -H 'Upgrade: websocket' \
  -H 'Sec-WebSocket-Version: 13' \
  -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' \
  "https://${DOMAIN}/ws/app/${REVERB_KEY}?protocol=7&client=js&version=8.4.0&flash=false" || true)

test "$VITE_STATUS" = "101"
test "$REVERB_STATUS" = "101"
```

`/ws/apps/*` deve retornar `404` ou `403`. Se retornar `200`, endpoints administrativos vazaram.
