---
name: enum-with-translations
description: "Aplicar quando criar enum PHP de domínio para status, tipo ou categoria usado por Laravel ou Filament."
license: MIT
metadata:
  author: coringawc
  version: 2.0.0
  requires:
    - laravel-best-practices
    - spatie-laravel-php-standards
  related:
    - translation
    - filament-schema-class
    - filament-table-defaults
---

# Enum With Translations

## Consistency First

Enums de domínio devem ser `BackedEnum` com cases TitleCase. Quando aparecerem em badges, selects ou filters do Filament v5, implementam os contratos `HasLabel`, `HasColor` e `HasIcon` e expõem `getLabel()`, `getColor()`, `getIcon()`. Strings retornadas por `getLabel()` seguem **chave-frase em inglês** resolvida via `__()`, conforme `.agents/skills/translation/rules/translation-rules.md`. Não criar `lang/<locale>/enums.php`: tudo de UI vive no JSON único.

## Quick Reference

- Criar com `vendor/bin/sail artisan make:enum <Name>Enum --no-interaction`.
- Case PHP em TitleCase: `Draft`, `InReview`, `Approved`.
- Backing value em snake estável: `'draft'`, `'in_review'`, `'approved'`.
- Sufixo `Enum` no nome da classe: `ProjectStatusEnum`.
- Filament v5: contratos `HasLabel`, `HasColor`, `HasIcon` e métodos `getLabel()`, `getColor()`, `getIcon()`.
- Tradução: `getLabel()` retorna `__('Frase inglês')`; entrada vai em `lang/pt_BR.json`.
- Ícone via `Filament\Support\Icons\Heroicon`, nunca string solta.
- Cor via tokens Filament (`gray`, `warning`, `success`, `danger`, `info`).
- **Sem sufixo `(a)` por padrão**. Aplicar variação `|m`/`|f` apenas com coluna persistida de gênero (raríssimo em enums).

## Workflow

- [ ] Criar enum:

```bash
vendor/bin/sail artisan make:enum ProjectStatusEnum --no-interaction
```

- [ ] Implementar `BackedEnum` + contratos Filament. Toda label sai por `__()` com chave-frase em inglês:

```php
<?php

namespace App\Enums;

use Filament\Support\Contracts\HasColor;
use Filament\Support\Contracts\HasIcon;
use Filament\Support\Contracts\HasLabel;
use Filament\Support\Icons\Heroicon;

enum ProjectStatusEnum: string implements HasColor, HasIcon, HasLabel
{
    case Draft = 'draft';
    case InReview = 'in_review';
    case Approved = 'approved';

    public function getLabel(): string
    {
        return match ($this) {
            self::Draft => __('Draft'),
            self::InReview => __('In review'),
            self::Approved => __('Approved'),
        };
    }

    public function getColor(): string
    {
        return match ($this) {
            self::Draft => 'gray',
            self::InReview => 'warning',
            self::Approved => 'success',
        };
    }

    public function getIcon(): Heroicon
    {
        return match ($this) {
            self::Draft => Heroicon::DocumentText,
            self::InReview => Heroicon::Clock,
            self::Approved => Heroicon::CheckCircle,
        };
    }
}
```

- [ ] Adicionar cada label nova em `lang/pt_BR.json` seguindo §8 de `.agents/skills/translation/rules/translation-rules.md` (ler antes, mesclar preservando ordenação, validar parse):

```json
{
    "Approved": "Aprovado",
    "Draft": "Rascunho",
    "In review": "Em análise"
}
```

- [ ] Castar a coluna no model usando o enum:

```php
protected function casts(): array
{
    return [
        'status' => ProjectStatusEnum::class,
    ];
}
```

- [ ] Validar resolução das chaves:

```bash
vendor/bin/sail artisan tinker --execute 'echo __("In review");'
vendor/bin/sail artisan tinker --execute 'echo App\\Enums\\ProjectStatusEnum::InReview->getLabel();'
```

## Anti-Patterns

- ❌ Criar enum sem backing value quando será persistido em banco.
- ❌ Criar `lang/<locale>/enums.php`. Tudo de UI vai no JSON único (`lang/pt_BR.json`), conforme `.agents/skills/translation/rules/translation-rules.md` §2.
- ❌ Usar chaves abstratas em `__()`: `__('enums.project_status.draft')`. Use chave-frase: `__('Draft')`.
- ❌ Case lowercase em PHP (`draft`). Case é `Draft`, value é `'draft'`.
- ❌ String de ícone (`'heroicon-o-check'`). Use `Heroicon::CheckCircle`.
- ❌ Métodos `label()`, `color()`, `icon()` em Filament v5. Os contratos exigem `getLabel()`, `getColor()`, `getIcon()`.
- ❌ Hardcodar label pt_BR no `match`. Saída é sempre `__('Frase inglês')`.
- ❌ Aplicar sufixo `(a)` em enums genéricos. Reservado para textos que se referem a usuário com coluna persistida de gênero.

## Verification

- [ ] `.agents/skills/_helpers/verify-skill.sh .agents/skills/enum-with-translations/SKILL.md`
- [ ] `vendor/bin/sail php -r 'json_decode(file_get_contents("lang/pt_BR.json"), true, 512, JSON_THROW_ON_ERROR); echo "OK\n";'`
- [ ] `vendor/bin/sail artisan tinker --execute 'echo App\\Enums\\ProjectStatusEnum::Draft->getLabel();'` imprime a tradução pt_BR
- [ ] `vendor/bin/sail bin pint --dirty --format agent`
- [ ] `vendor/bin/sail bin phpstan analyse`
- [ ] `test ! -f lang/pt_BR/enums.php && test ! -f lang/en/enums.php` (arquivos PHP de enum proibidos)

## Related

- `translation` — toda string visível segue `.agents/skills/translation/rules/translation-rules.md` (§8 para inserção no JSON).
- `filament-schema-class` — `Select::make()->options(ProjectStatusEnum::class)` consome o enum.
- `filament-table-defaults` — usa o enum em badges, filters e columns.
- `model-with-factory-and-seeder` — model casta a coluna para o enum.
