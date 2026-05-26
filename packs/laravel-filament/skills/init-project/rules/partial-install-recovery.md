# Recovery de Install Parcial — Passo 0

Cenário: usuário rodou A1 antes, falhou no meio do `composer create-project` ou no boost, e agora o diretório tem artefatos parciais (composer.json sem vendor/, ou vendor/ incompleto).

## Detecção

```bash
if [ -f composer.json ] && [ ! -d vendor/laravel/framework ]; then
  echo "Detectado install parcial."
  ls -la
fi
```

## Limpeza (após confirmação do usuário)

**Nunca executar automaticamente.** Apresentar a lista ao usuário e aguardar OK explícito:

```bash
# Após confirmação manual do usuário:
rm -rf vendor/ composer.lock node_modules/ .env composer.json
```

Manter `.git/` intocado — se houver commits anteriores, o usuário pode preferir `git clean -fdx` ou fazer checkout para um estado limpo em vez de `rm`.

## Re-executar

Voltar ao Passo 0 da SKILL.md (verificação de diretório vazio passará após a limpeza).
