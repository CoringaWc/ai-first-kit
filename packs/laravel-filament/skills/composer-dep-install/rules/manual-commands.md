# Manual Commands

Em projetos com entrypoint canônico, a instalação inicial pode ser disparada automaticamente no primeiro `docker compose up -d --build`. Use comandos manuais de Composer quando estiver adicionando/removendo pacotes, recuperando falhas ou validando instalação parcial.

## Exemplos manuais

- Adicionar pacote: `vendor/bin/sail composer require vendor/package`
- Remover pacote: `vendor/bin/sail composer remove vendor/package`
- Recuperar falha: `vendor/bin/sail composer install`
- Validar instalação parcial: `vendor/bin/sail composer validate && vendor/bin/sail composer check-platform-reqs`
