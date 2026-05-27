# Segurança contra Sobrescrita

Antes de editar arquivos gerados, classifique o estado:

1. Arquivo ausente: pode criar pelo template.
2. Arquivo canônico sem alterações do usuário: header do kit presente e diff contra template esperado vazio ou limitado a variáveis renderizadas; pode atualizar pelo template, depois revisar diff.
3. Arquivo canônico editado manualmente: header do kit presente, mas diff contém rotas, ports, plugins, env ou headers extras; não copie template por cima, aplique patch mínimo.
4. Arquivo customizado sem header do kit: faça backup e peça confirmação antes de alterar.

## Arquivos sensíveis a preservar

- `docker/nginx/default.conf`: preservar server names, certificados, redirects, headers e locations custom.
- `docker-compose.yml`: preservar profiles, volumes, env, redes e portas customizadas.
- `vite.config.js`: preservar plugins, aliases, inputs, SSR/build options e certificados custom.
- `resources/js/echo.js`: preservar listeners, `authEndpoint`, headers, interceptors e configuração custom de canais.
- `config/broadcasting.php` e `config/reverb.php`: preservar conexões, client options, guards e allowed origins custom.

## Regra prática

Use `cp arquivo arquivo.bak.<timestamp>` antes de alteração arriscada. Depois, mostre diff e valide que só mudou o necessário para `/vite`, `/ws`, origins, bind local ou broadcast interno.

Se não conseguir classificar com segurança, pare e pergunte. Não trate arquivo com header do kit como descartável.
