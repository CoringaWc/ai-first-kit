# Topologia Vite/Reverb/Nginx

## Rotas públicas

| Browser | Nginx | Upstream interno | Observação |
| --- | --- | --- | --- |
| `/vite/*` | `location ^~ /vite/` | `https://vite:5173` | Dev/HMR, restrito a loopback/LAN privada |
| `/vite/vite-hmr` | WebSocket HMR | `https://vite:5173/vite-hmr` | `Sec-WebSocket-Protocol: vite-hmr` |
| `/ws/app/<key>` | `location ^~ /ws/` + rewrite | `http://reverb:8080/app/<key>` | WebSocket público controlado por origin/canais |
| `/ws/apps/*` | `location ^~ /ws/apps/` | bloqueado | API/admin do protocolo Pusher/Reverb, não cliente |
| `/app/*` | Laravel/Filament | `app` | reservado para painel ou rotas da aplicação |

## Variáveis Reverb

- `REVERB_SERVER_HOST=0.0.0.0` e `REVERB_SERVER_PORT=8080`: bind interno do servidor Reverb.
- `REVERB_HOST=<dominio>`, `REVERB_PORT=443`, `REVERB_SCHEME=https`: endereço público usado pelo cliente.
- `REVERB_BROADCAST_HOST=reverb`, `REVERB_BROADCAST_PORT=8080`, `REVERB_BROADCAST_SCHEME=http`: endereço interno usado pelo Laravel para publicar mensagens.
- `REVERB_ALLOWED_ORIGINS=<dominio>`: origins permitidas pelo servidor Reverb.
- `VITE_REVERB_*`: somente valores públicos para o browser. Nunca exporte `REVERB_APP_SECRET`.

## Vite

`vite.config.js` precisa ter `base: '/vite/'`, `server.origin` baseado em `APP_URL`, HMR `protocol: 'wss'`, `clientPort: 443` e `path: 'vite-hmr'`. O browser nunca deve acessar `:5173` diretamente.
