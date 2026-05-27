import { defineConfig, loadEnv } from 'vite';
import laravel from 'laravel-vite-plugin';
import tailwindcss from '@tailwindcss/vite';
import fs from 'node:fs';

// Gerenciado por npm-dep-install (A5). Edite com cuidado — A5 sobrescreve.
export default defineConfig(({ mode }) => {
    const env = loadEnv(mode, process.cwd(), '');
    const appUrl = env.APP_URL ?? 'https://localhost';

    return {
        base: '/vite/',
        plugins: [
            laravel({
                input: [
                    'resources/css/app.css',
                    'resources/js/app.js',
                    'resources/css/filament/admin/theme.css',
                ],
                refresh: true,
            }),
            tailwindcss(),
        ],
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
            watch: {
                ignored: ['**/storage/framework/views/**'],
            },
        },
    };
});
