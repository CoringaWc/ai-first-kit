---
name: ssl-local-dev
description: "Aplicar quando o projeto precisar de HTTPS local para o domínio `.test`, seja durante o bootstrap inicial ou ao adicionar HTTPS a um projeto Laravel existente."
license: MIT
metadata:
  author: coringawc
  version: 2.0.0
  requires:
    - laravel-best-practices
  related:
    - init-project
    - docker-stack-fpm
    - docker-stack-octane-swoole
    - enable-octane-swoole
---

# SSL Local Dev — HTTPS para Domínio `.test`

## Consistency First

Se `.cert/cert.pem` e `.cert/cert.key` já existem, **não regenerar** — apenas validar e adicionar entry no `/etc/hosts` se faltar.

A skill **assume**:

- Stack Docker já gerado por `docker-stack-fpm` ou `docker-stack-octane-swoole` (`docker/nginx/default.conf` existe com bloco SSL).
- Domínio padrão é derivado do nome do diretório do projeto: `$(basename "$PWD").test`. Pode ser sobrescrito via variável de ambiente `DOMAIN`.
- `mkcert` requer `sudo` no Linux para instalar a CA local em `/usr/local/share/ca-certificates/`. Em ambientes headless sem sudo, a skill usa fallback `openssl` self-signed apenas para permitir boot do nginx.

## Quick Reference

- `mkcert -install` adiciona CA local trusted; certs gerados são aceitos pelo browser sem warning.
- Domínio padrão: `<project-name>.test` (TLD reservado IETF, seguro contra HSTS).
- Certs persistem em `.cert/cert.pem` + `.cert/cert.key` (montados pelo nginx em `/etc/nginx/ssl/`).
- Append idempotente em `.env`: `APP_URL=https://...`, `FORCE_HTTPS=true`, `SESSION_SECURE_COOKIE=true`, `ASSET_URL=https://...`.
- Se runtime for Octane: também grava `OCTANE_HTTPS=true` (faz Octane gerar URLs HTTPS por trás do nginx terminador TLS).
- Idempotente: sempre safe rerodar.
- Fallback `openssl` self-signed quando `mkcert` ou `sudo` não estão disponíveis (boot only; browser exige aceite manual).

## Workflow

### Passo 1 — Detectar domínio e paths

- [ ] Inicializar variáveis:

```bash
PROJECT_NAME="${PROJECT_NAME:-$(basename "$PWD")}"
DOMAIN="${DOMAIN:-${PROJECT_NAME}.test}"
CERT_DIR=".cert"
CERT_FILE="${CERT_DIR}/cert.pem"
KEY_FILE="${CERT_DIR}/cert.key"
```

### Passo 2 — Gerar certificado TLS

- [ ] Preferir `mkcert` trusted; fallback `openssl` self-signed quando faltar `mkcert` ou `sudo`:

```bash
mkdir -p "$CERT_DIR"

if [[ ! -f "$CERT_FILE" || ! -f "$KEY_FILE" ]]; then
  if command -v mkcert >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
    mkcert -install
    mkcert -cert-file "$CERT_FILE" -key-file "$KEY_FILE" \
      "$DOMAIN" "*.${DOMAIN%.test}.test" localhost 127.0.0.1
  elif command -v openssl >/dev/null 2>&1; then
    echo "AVISO: mkcert ou sudo indisponíveis — gerando certificado self-signed de bootstrap."
    echo "       Para HTTPS trusted no browser: instale mkcert e re-rode esta skill."
    openssl req -x509 -nodes -newkey rsa:2048 -days 825 \
      -keyout "$KEY_FILE" \
      -out "$CERT_FILE" \
      -subj "/CN=${DOMAIN}" \
      -addext "subjectAltName=DNS:${DOMAIN},DNS:*.${DOMAIN%.test}.test,DNS:localhost,IP:127.0.0.1"
  else
    echo "ERRO: mkcert, sudo e openssl indisponíveis. Não é possível gerar certificados TLS para nginx."
    exit 1
  fi
fi
```

### Passo 3 — Adicionar entry em `/etc/hosts`

- [ ] Atualizar `/etc/hosts` quando sudo não-interativo estiver disponível:

```bash
if sudo -n true 2>/dev/null; then
  grep -q "$DOMAIN" /etc/hosts || \
    echo "127.0.0.1 $DOMAIN" | sudo tee -a /etc/hosts
else
  echo "AVISO: sudo não disponível não-interativamente — /etc/hosts não foi atualizado."
  echo "       Adicione manualmente se for acessar pelo browser:"
  echo "         127.0.0.1 ${DOMAIN}"
fi
```

### Passo 4 — Validar certs e config nginx

- [ ] Validar arquivos esperados pelo nginx:

```bash
test -f "$CERT_FILE"
test -f "$KEY_FILE"
```

- [ ] Garantir que `docker/nginx/default.conf` tem bloco SSL (skill de docker stack já criou; validar idempotente):

```bash
grep -q "listen 443 ssl" docker/nginx/default.conf || {
  echo "ERRO: nginx config sem SSL. Re-executar docker-stack-fpm ou docker-stack-octane-swoole."
  exit 1
}
```

### Passo 5 — Append idempotente em `.env` e `.env.example`

- [ ] Aplicar entries HTTPS em `.env` (sobrescreve se existe, append se falta) e em `.env.example` (chave sem valor):

```bash
ENTRIES=(
  "APP_URL=https://${DOMAIN}"
  "FORCE_HTTPS=true"
  "SESSION_SECURE_COOKIE=true"
  "ASSET_URL=https://${DOMAIN}"
)

# Se runtime for Octane (skill docker-stack-octane-swoole ativa), adicionar OCTANE_HTTPS
if grep -q "^OCTANE_SERVER=swoole" .env 2>/dev/null; then
  ENTRIES+=("OCTANE_HTTPS=true")
fi

for ENTRY in "${ENTRIES[@]}"; do
  KEY="${ENTRY%%=*}"
  if grep -q "^${KEY}=" .env; then
    sed -i "s|^${KEY}=.*|${ENTRY}|" .env
  else
    echo "$ENTRY" >> .env
  fi
  grep -q "^${KEY}=" .env.example || echo "${KEY}=" >> .env.example
done
```

### Passo 6 — Reload nginx se já rodando

- [ ] Reload sem derrubar o stack:

```bash
vendor/bin/sail exec nginx nginx -s reload 2>/dev/null || true
```

## Anti-Patterns

- ❌ **Não tratar o fallback self-signed como HTTPS trusted.** O bloco `openssl` existe só para permitir boot e CI headless quando `mkcert` ou `sudo` não estão disponíveis. Para browser local confiável, instale `mkcert` e rerode a skill.
- ❌ **Não esquecer `SESSION_SECURE_COOKIE=true` em HTTPS.** Login Filament falha silenciosamente quando o cookie é marcado `Secure` sob HTTPS sem essa flag — o navegador descarta o cookie e o usuário fica preso na tela de login sem mensagem clara.
- ❌ **Não usar `*.localhost` em vez de `*.test`.** Browsers tratam `localhost` de forma especial (HSTS embutido, restrições mixed-content); `.test` é TLD reservado pelo IETF para desenvolvimento e funciona consistentemente.
- ❌ **Não esquecer `OCTANE_HTTPS=true` em runtime Octane atrás de nginx.** Sem essa flag o Octane gera URLs `http://...` mesmo com nginx terminando TLS, e o Filament/Livewire emitem mixed-content errors no browser.
- ❌ **Não tentar `mkcert -install` em CI sem sudo persistente.** O passo de CA exige escrita em `/usr/local/share/ca-certificates/`. Em CI, prefira o fallback `openssl` ou já provisione certs como secrets do pipeline.

## Verification

- [ ] `.agents/skills/_helpers/verify-skill.sh .agents/skills/ssl-local-dev/SKILL.md` retorna `OK`
- [ ] `test -f .cert/cert.pem && test -f .cert/cert.key` retorna 0
- [ ] `getent hosts ${DOMAIN}` retorna `127.0.0.1`
- [ ] `grep -E "^(APP_URL|FORCE_HTTPS|SESSION_SECURE_COOKIE)=" .env | wc -l` retorna ≥ 3
- [ ] `curl -kv https://${DOMAIN} 2>&1 | grep -q "subject:"` (cert apresenta CN/subject)

## Related

- Orquestradora: `init-project`
- Docker stacks: `docker-stack-fpm`, `docker-stack-octane-swoole`
- Migração de runtime: `enable-octane-swoole` (ativa `OCTANE_HTTPS` se já houver certs)
- Doc mkcert: https://github.com/FiloSottile/mkcert
