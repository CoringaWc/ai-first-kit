# Boost Install — Fallback Manual

Se `php artisan boost:install` travar ou o usuário marcar harness errado:

## Recuperação

1. **Limpar artefatos errados** (se Copilot/Codex/Gemini foram marcados) — **com segurança**:

```bash
# Listar antes de remover para o usuário ver o que existe:
ls -la .github/instructions/ .cursorrules .roo/ .codex/ GEMINI.md 2>/dev/null

# Para cada caminho, verificar se já está rastreado por git antes de remover:
for path in .github/instructions/ .cursorrules .roo/ .codex/ GEMINI.md; do
  if [ -e "$path" ]; then
    if git ls-files --error-unmatch "$path" >/dev/null 2>&1; then
      echo "AVISO: '$path' está rastreado por git — PEDIR CONFIRMAÇÃO DO USUÁRIO antes de rm"
      echo "       (provavelmente foi commit anterior intencional — não remover automaticamente)"
    else
      echo "Candidato a remover (criado pelo boost:install errado, untracked): $path"
      echo "  Após confirmação do usuário: rm -rf \"$path\""
    fi
  fi
done
```

**Nunca** executar `rm -rf` em modo automatizado nessa lista. Sempre apresentar os caminhos ao usuário e aguardar confirmação explícita por item.

2. **Verificar AGENTS.md**: deve existir com bloco `<laravel-boost-guidelines>` apenas para opencode. Se contiver tags de outros harnesses, abrir editor e remover seções marcadas.

3. **Re-rodar boost interactive APENAS para opencode**:

```bash
php artisan boost:install --only=opencode
```

Se a flag `--only` não existir nesta versão do Boost (verificar com `--help`), rodar interativo e desmarcar todos os outros explicitamente.

4. **Validar resultado**:

```bash
ls -la .github/skills/ AGENTS.md opencode.jsonc 2>&1 | head -20
```

Expected:
- `.github/skills/` populado com skills Boost
- `AGENTS.md` contém `<laravel-boost-guidelines>`
- `opencode.jsonc` existe (Boost cria/atualiza para OpenCode)

## Retomada da skill init-project

```bash
# Pular o passo 1 (boost) na re-execução:
# Invocar init-project com flag mental --skip-boost e continuar do Passo 2
```
