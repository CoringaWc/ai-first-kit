# Pré-requisitos — init-project (A1)

Os Passos 0 e 1 rodam **no host** (antes do Sail existir). A partir do Passo 5 (A2+), comandos rodam dentro de containers Sail.

## Host (obrigatório antes de iniciar)

- **PHP ≥ 8.4** instalado no host (`composer create-project` e `php artisan boost:install` rodam aqui)
- **Composer 2.x**
- **Docker** + **docker-compose** (usados a partir de A2)
- **git** configurado

## Verificação rápida

```bash
php -v | grep -qE "PHP 8\.(4|5|6)" || { echo "ERRO: host PHP precisa ser 8.4+"; exit 1; }
composer --version | grep -q "Composer version 2" || { echo "ERRO: Composer 2.x necessário"; exit 1; }
docker --version >/dev/null 2>&1 || { echo "ERRO: docker ausente"; exit 1; }
docker compose version >/dev/null 2>&1 || docker-compose --version >/dev/null 2>&1 || { echo "ERRO: docker compose ausente"; exit 1; }
git --version >/dev/null 2>&1 || { echo "ERRO: git ausente"; exit 1; }
```

## Após A2

A partir de `docker-stack-fpm` / `docker-stack-octane-swoole`, todos os comandos PHP/Composer/Node passam por `vendor/bin/sail`. O host só precisa de Docker e git daí em diante.
