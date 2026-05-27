# Snippets Canônicos

Use estes trechos como referência. Não cole por cima de arquivo customizado sem seguir `overwrite-safety.md`.

## Nginx

```nginx
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}

location ^~ /vite/ {
    allow 127.0.0.1;
    allow ::1;
    allow 10.0.0.0/8;
    allow 172.16.0.0/12;
    allow 192.168.0.0/16;
    deny all;

    proxy_ssl_verify off;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
    rewrite ^/vite/__laravel_vite_plugin__/(.*)$ /__laravel_vite_plugin__/$1 break;
    proxy_pass https://vite:5173;
}

location ^~ /ws/apps/ {
    return 404;
}

location ^~ /ws/ {
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
    rewrite ^/ws/(.*)$ /$1 break;
    proxy_pass http://reverb:8080;
}

location = /mailpit {
    return 301 /mailpit/;
}

location ^~ /mailpit/ {
    allow 127.0.0.1;
    allow ::1;
    allow 10.0.0.0/8;
    allow 172.16.0.0/12;
    allow 192.168.0.0/16;
    deny all;

    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_pass http://mailpit:8025;
}
```

Use `proxy_pass https://vite:5173` com `server.https` no Vite. Se o projeto optar por Vite interno sem TLS, troque o upstream para `http://vite:5173` e remova `proxy_ssl_verify off`.

## Compose

```yaml
reverb:
  command: ["php", "artisan", "reverb:start"]
  # sem ports: acesso público passa por nginx /ws

vite:
  command: ["npm", "run", "dev", "--", "--host=0.0.0.0"]
  # sem ports: acesso público passa por nginx /vite

postgres:
  ports:
    - "127.0.0.1:${FORWARD_DB_PORT:-5432}:5432"

redis:
  ports:
    - "127.0.0.1:${FORWARD_REDIS_PORT:-6379}:6379"

mailpit:
  environment:
    MP_WEBROOT: mailpit
  ports:
    - "127.0.0.1:${MAILPIT_SMTP_PORT:-1026}:1025"
    - "127.0.0.1:${MAILPIT_DASHBOARD_PORT:-8026}:8025"

minio:
  ports:
    - "127.0.0.1:${FORWARD_MINIO_PORT:-9000}:9000"
    - "127.0.0.1:${FORWARD_MINIO_CONSOLE_PORT:-9001}:9001"

ollama:
  ports:
    - "127.0.0.1:${OLLAMA_PORT:-11434}:11434"

qdrant:
  ports:
    - "127.0.0.1:${QDRANT_HTTP_PORT:-6333}:6333"
    - "127.0.0.1:${QDRANT_GRPC_PORT:-6334}:6334"
```

## Vite

```js
export default defineConfig(({ mode }) => {
    const env = loadEnv(mode, process.cwd(), '');
    const appUrl = env.APP_URL ?? 'https://localhost';

    return {
        base: '/vite/',
        server: {
            host: '0.0.0.0',
            port: 5173,
            strictPort: true,
            origin: appUrl,
            https: {
                cert: fs.readFileSync(env.VITE_SSL_CERT_PATH ?? '.cert/cert.pem'),
                key: fs.readFileSync(env.VITE_SSL_KEY_PATH ?? '.cert/cert.key'),
            },
            hmr: {
                host: new URL(appUrl).hostname,
                protocol: 'wss',
                clientPort: 443,
                path: 'vite-hmr',
            },
        },
    };
});
```

## Echo

```js
window.Echo = new Echo({
    broadcaster: 'reverb',
    key: import.meta.env.VITE_REVERB_APP_KEY,
    wsHost: import.meta.env.VITE_REVERB_HOST,
    wsPort: import.meta.env.VITE_REVERB_PORT ?? 80,
    wssPort: import.meta.env.VITE_REVERB_PORT ?? 443,
    wsPath: '/ws',
    forceTLS: (import.meta.env.VITE_REVERB_SCHEME ?? 'https') === 'https',
    enabledTransports: (import.meta.env.VITE_REVERB_SCHEME ?? 'https') === 'https' ? ['wss'] : ['ws'],
});
```

## Broadcasting

```php
'options' => [
    'host' => env('REVERB_BROADCAST_HOST', env('REVERB_HOST')),
    'port' => env('REVERB_BROADCAST_PORT', env('REVERB_PORT', 443)),
    'scheme' => env('REVERB_BROADCAST_SCHEME', env('REVERB_SCHEME', 'https')),
    'useTLS' => env('REVERB_BROADCAST_SCHEME', env('REVERB_SCHEME', 'https')) === 'https',
],
```

`REVERB_ALLOWED_ORIGINS` deve usar host permitido pelo Reverb, como `siasgfacil.ddns.net`; para múltiplos hosts, use lista separada por vírgula e normalize com `explode(',')` + `trim` em `config/reverb.php`.
