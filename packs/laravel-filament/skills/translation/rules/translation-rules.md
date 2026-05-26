# Translation Rules

Doutrina viva de tradução do projeto. Toda string visível ao usuário segue estas regras. Skills que produzem UI/strings (filament-*, enum-with-translations, model-with-factory-and-seeder, action-class, form-request-validation) referenciam este arquivo.

A rule é **imutável durante a vida do projeto**. A skill `translation` cobre apenas o bootstrap mecânico; o **como traduzir** vive aqui.

## 1. Princípio

- **Locale fixo**: `APP_LOCALE=pt_BR`, `APP_FALLBACK_LOCALE=en`. Nunca alternar idioma em runtime, nunca expor seletor de idioma.
- **Chave-frase em inglês no código**: `__('Create Document')`, não `__('document.create')`.
- **Valor traduzido em pt_BR no JSON**: `lang/pt_BR.json` resolve a chave inglesa para a string pt_BR.
- **Comunicação usuário ↔ IA é em pt_BR** (declarado no `AGENTS.md` seção `## Linguagem`).

Justificativa: chave-frase preserva legibilidade do código sem dicionário paralelo, e o fallback `en` é o próprio código — se faltar uma entrada no JSON, a tela mostra a frase inglesa em vez de quebrar.

## 2. Arquivo destino

- **Único canal de tradução de UI**: `lang/pt_BR.json`.
- **Proibido**: `lang/pt_BR/labels.php`, `lang/pt_BR/enums.php`, `lang/pt_BR/messages.php`, qualquer arquivo PHP de domínio com strings.
- **Exceção única**: `lang/pt_BR/validation.php` — vem do pacote `lucascudo/laravel-pt-br-localization`. Edição manual permitida apenas para **sobrescrever uma mensagem específica** de validação. Não criar outros arquivos PHP de tradução.
- `config/app.php` permanece intocado. Laravel 13 lê `locale`/`fallback_locale`/`faker_locale` direto do `.env`.

## 3. Pluralização

Formato canônico com ranges inline:

```php
trans_choice('{0} No documents|{1} :count document|[2,*] :count documents', $count)
```

JSON correspondente:

```json
{
  "{0} No documents|{1} :count document|[2,*] :count documents": "{0} Nenhum documento|{1} :count documento|[2,*] :count documentos"
}
```

Regras:

- Sempre incluir o caso `{0}` mesmo quando improvável — torna a chave explícita e robusta.
- Não usar a forma curta `:count document|:count documents` (sem ranges). Ambígua em pt_BR para zero.
- Nunca concatenar contagem: `$count . ' documentos'` é proibido. Use `trans_choice`.

## 4. Gênero

### 4.1 Enums (status, tipo, categoria) — sempre neutro, **sem `(a)`**

Enums representam **estado/categoria do objeto**, não pessoa. Por isso o valor traduzido nunca recebe sufixo de gênero, mesmo neutro `(a)`. Use forma curta sem variação:

```json
{
  "status.active": "Ativo",
  "status.pending": "Pendente",
  "status.archived": "Arquivado",
  "role.collaborator": "Colaborador",
  "role.legal_representative": "Representante legal"
}
```

❌ Proibido em enum: `"Ativo(a)"`, `"Colaborador(a)"`, `"Selecionado(a)"`.

A regra vale em **qualquer contexto** de enum: badge de tabela, filtro Select, label de form, breadcrumb, e-mail transacional, notificação. Não há exceção por superfície.

### 4.2 Texto geral dirigido ao usuário — neutro com `(a)` ou variação `|m`/`|f`

Quando a string fala **com** a pessoa (saudação, confirmação, mensagem de fluxo), o default é neutro com `(a)`:

- `Bem-vindo(a)`, `Cadastrado(a)`, `Convidado(a)`, `Selecionado(a)`.

**Sufixos `|m` / `|f` na chave**: somente quando o model tem **coluna persistida de gênero** (ex.: `users.gender` enum). Caso contrário, default neutro.

```php
// User tem coluna gender — autoriza variação
__("Welcome|{$user->gender}")
```

```json
{
  "Welcome|m": "Bem-vindo",
  "Welcome|f": "Bem-vinda"
}
```

Sem coluna de gênero no model = `Bem-vindo(a)`, fim. Não inferir gênero de nome próprio, não pedir input só para escolher pronome.

## 5. Capitalização

- **Title Case**: labels de UI estáveis — botões, headings, items de menu, títulos de coluna de tabela, labels de campo de form.
  - `Create Document` → `Criar Documento`
  - `Project Settings` → `Configurações do Projeto`
- **Sentence case**: mensagens, notificações, erros, helper text, placeholders, modal body.
  - `The document was created successfully.` → `O documento foi criado com sucesso.`
  - `Choose a file to upload` → `Escolha um arquivo para enviar`

Não misturar. Se a string aparece em botão **e** em notificação, criar duas chaves.

## 6. Pontuação

- **Mensagens completas terminam com ponto final**: notificações, erros, helpers em frase, body de modal.
- **Labels não terminam com ponto**: botões, headings, items de menu, labels de campo.
- **Dois pontos em label de campo**: opcional, decidido por skill de UI (Filament default não usa).
- **Não usar reticências `...`** salvo placeholder de loading (`Carregando...`).

## 7. Tecnicismos preservados

Não traduzir, não flexionar, não pluralizar com `s` português:

- Siglas técnicas: `URL`, `API`, `ID`, `JSON`, `HTTP`, `HTTPS`, `SQL`, `CSV`, `PDF`.
- Documentos brasileiros: `CPF`, `CNPJ`, `RG`, `CEP`, `PIS`.
- Termos técnicos consagrados: `email`, `login`, `logout`, `token`, `cache`, `cookie`.
- Plural: `URLs`, `IDs`, `CPFs` (com `s` minúsculo, sem apóstrofo).

Domínio TPA / processo migratório: termos jurídicos brasileiros (`processo`, `decreto`, `morador`, `pré-cadastro`) traduzem normalmente. Siglas do domínio (`TPA`, `DLE`) preservadas como tecnicismos.

## 8. Procedimento para adicionar entrada nova

Toda inclusão de string traduzida segue este protocolo. Não há exceção.

**Passo 1 — Ler o JSON inteiro antes de tocar.** Use o tool `Read` sobre `lang/pt_BR.json`. Nunca `Write` cego.

**Passo 2 — Verificar duplicata.** Busca exata, case-sensitive, pela chave inglesa. Se a chave já existe e o valor é o desejado, não fazer nada. Se existe com valor diferente, parar e levantar conflito com o usuário — não sobrescrever.

**Passo 3 — Mesclar preservando ordenação alfabética** pela chave inglesa. JSON ordenado facilita diff e revisão.

**Passo 4 — Validar parse**:

```bash
vendor/bin/sail php -r 'json_decode(file_get_contents("lang/pt_BR.json"), true, 512, JSON_THROW_ON_ERROR); echo "OK\n";'
```

Se falhar, `Write` foi destrutivo — restaurar do git e refazer.

**Passo 5 — Verificar resolução em tinker**:

```bash
vendor/bin/sail artisan tinker --execute 'echo __("Create Document");'
```

Deve imprimir a string pt_BR. Se imprimir a chave inglesa, JSON não foi recarregado (`vendor/bin/sail artisan optimize:clear`) ou chave está errada.

## 9. Anti-patterns

- ❌ **Chave abstrata**: `__('document.create')`, `__('messages.welcome')`. Quebra o princípio chave-frase.
- ❌ **Concatenação**: `__('Created') . ' ' . $name`. Use placeholder: `__('Created :name', ['name' => $name])`.
- ❌ **Arquivo PHP de domínio**: criar `lang/pt_BR/labels.php` ou `lang/pt_BR/enums.php`. Tudo vai no JSON.
- ❌ **Chave duplicada no JSON**: parser PHP aceita mas comportamento é indefinido entre runtimes. Sempre verificar antes de inserir.
- ❌ **Sobrescrita destrutiva**: `Write` sobre `lang/pt_BR.json` sem `Read` prévio. Apaga entradas de outras skills.
- ❌ **Sobrescrita destrutiva de `validation.php`**: copiar do pacote `lucascudo` cego, perdendo mensagens já customizadas. Editar chave por chave.
- ❌ **`fake('pt_BR')` em factory**: Faker locale já vem do `.env` (`APP_FAKER_LOCALE=pt_BR`). Use `fake()` sem argumento. Forçar locale por chamada é redundante e mascara configuração quebrada.
- ❌ **Editar `config/app.php`** para fixar locale. Laravel 13 lê do `.env`. Edição em `config/app.php` quebra `php artisan config:cache`.
- ❌ **Tradução em código**: `if ($locale === 'pt_BR') { $label = 'Criar'; } else { $label = 'Create'; }`. Use `__()`.
- ❌ **Pluralização manual**: `$count === 1 ? 'documento' : 'documentos'`. Use `trans_choice`.
- ❌ **Concatenar gênero**: `'Bem-vindo' . ($user->isFemale() ? 'a' : '')`. Use `__("Welcome|{$user->gender}")` se autorizado por coluna persistida, ou `Bem-vindo(a)` neutro.
- ❌ **Inferir gênero de nome próprio**: `Str::endsWith($name, 'a')`. Não fazer.
- ❌ **Pluralizar sigla com apóstrofo**: `ID's`, `URL's`. Correto: `IDs`, `URLs`.

## 10. Como skills referenciam esta rule

Skills que produzem strings declaram no frontmatter:

```yaml
metadata:
  related:
    - translation
```

E citam no corpo da skill, na seção `## Workflow` ou `## Anti-Patterns`, conforme onde a regra se aplica:

```md
Toda string visível ao usuário segue `.agents/skills/translation/rules/translation-rules.md`.
```

Skills que **adicionam entradas no JSON** (ex.: `enum-with-translations`) referenciam explicitamente o **Passo 8** (procedimento para adicionar entrada) e replicam o `php -r` de validação de parse na sua própria seção `## Verification`.
