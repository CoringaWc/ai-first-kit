---
name: faker-realistic-ptbr
description: "Aplicar quando factory Laravel precisar de dados brasileiros realísticos além do Faker pt_BR nativo."
license: MIT
metadata:
  author: coringawc
  version: 2.0.0
  requires:
    - laravel-best-practices
    - spatie-laravel-php-standards
  related:
    - model-with-factory-and-seeder
    - translation
    - composer-dep-install
---

# Faker Realistic pt_BR

## Consistency First

Esta skill é opt-in. O locale do Faker já vem fixado por `translation` (`APP_FAKER_LOCALE=pt_BR` no `.env`). Use `fake()` sem argumento em todas as factories: o locale resolve automaticamente. Antes de criar provider custom, valide que o Faker `pt_BR` nativo não cobre o caso (CPF, CNPJ, celular, CEP, rua, cidade, nome, email seguro são nativos).

## Quick Reference

- `fake()` sem argumento. Locale vem do `.env` (`APP_FAKER_LOCALE=pt_BR`).
- Não instalar pacote externo de Faker BR. `fakerphp/faker` cobre tudo nativo.
- Nativos pt_BR cobertos: `cpf()`, `cnpj()`, `cellphoneNumber()`, `postcode()`, `streetName()`, `city()`, `name()`, `safeEmail()`, `companyEmail()`, `jobTitle()`.
- Provider custom só para domínio específico: códigos internos, fixtures JSON, valores de catálogo.
- Provider estende `\Faker\Provider\Base`, registrado em `AppServiceProvider::boot()`.
- Factories chamam métodos do provider; nunca leem JSON diretamente.
- Fixtures JSON ficam em `resources/json/`, versionadas, sem dados pessoais reais.

## Workflow

- [ ] Confirmar que o locale do Faker está fixado:

```bash
vendor/bin/sail artisan tinker --execute 'echo config("app.faker_locale");'
# Esperado: pt_BR
```

- [ ] Validar que o Faker nativo não resolve o caso antes de criar provider:

```bash
vendor/bin/sail artisan tinker --execute 'echo fake()->cpf();'
vendor/bin/sail artisan tinker --execute 'echo fake()->cnpj();'
vendor/bin/sail artisan tinker --execute 'echo fake()->cellphoneNumber();'
vendor/bin/sail artisan tinker --execute 'echo fake()->safeEmail();'
```

- [ ] Se precisar de provider custom, criar diretório e classe:

```bash
mkdir -p app/Providers/Faker
```

```php
<?php

namespace App\Providers\Faker;

use Faker\Provider\Base;
use Illuminate\Support\Arr;
use RuntimeException;

final class FakerProvider extends Base
{
    /**
     * @var list<array{code: string, name: string}>
     */
    private array $cachedItems = [];

    public function internalCode(): string
    {
        return (string) static::numberBetween(100000, 999999);
    }

    public function catalogName(): string
    {
        $item = Arr::random($this->items());

        return $item['name'];
    }

    /**
     * @return list<array{code: string, name: string}>
     */
    private function items(): array
    {
        if ($this->cachedItems !== []) {
            return $this->cachedItems;
        }

        $path = resource_path('json/catalog.json');

        if (! file_exists($path)) {
            throw new RuntimeException('Fixture resources/json/catalog.json não encontrada.');
        }

        $items = json_decode((string) file_get_contents($path), true, flags: JSON_THROW_ON_ERROR);

        if (! is_array($items) || $items === []) {
            throw new RuntimeException('Fixture catalog.json deve ser lista não vazia.');
        }

        /** @var list<array{code: string, name: string}> $items */
        return $this->cachedItems = $items;
    }
}
```

- [ ] Registrar o provider em `App\Providers\AppServiceProvider::boot()`. Locale único — sem laço por idioma:

```php
use App\Providers\Faker\FakerProvider;

public function boot(): void
{
    $faker = fake();
    $faker->addProvider(new FakerProvider($faker));
}
```

- [ ] Usar nas factories sem repassar locale:

```php
public function definition(): array
{
    return [
        'document_number' => fake()->cpf(),
        'phone' => fake()->cellphoneNumber(),
        'internal_code' => fake()->internalCode(),
        'catalog_name' => fake()->catalogName(),
    ];
}
```

- [ ] Fixtures JSON em `resources/json/`. Apenas dados sintéticos ou referência pública. Proibido: nomes de pessoa natural reais, CPF/CNPJ vinculado a entidade privada, emails, telefones, endereços, tokens ou export de produção.

## Anti-Patterns

- ❌ `fake('pt_BR')->name()` em factory. Locale vem do `.env`; uso explícito é redundante e mascara configuração quebrada. Veja `.agents/skills/translation/rules/translation-rules.md` §9.
- ❌ Instalar pacote externo de Faker BR. `fakerphp/faker` é nativo do Laravel e cobre pt_BR.
- ❌ Criar provider custom para CPF, CNPJ ou celular. O Faker nativo pt_BR já gera.
- ❌ Gerar CPF/CNPJ com `fake()->numerify('###########')` sem validar dígito verificador. Use `fake()->cpf()` / `fake()->cnpj()`.
- ❌ Ler `resources/json/*` direto em cada factory. Encapsule no provider para cache e validação centralizada.
- ❌ Registrar provider em múltiplos locales (`pt_BR` e `en_US`). O projeto tem locale único.
- ❌ Versionar dados pessoais reais em fixtures JSON.

## Verification

- [ ] `.agents/skills/_helpers/verify-skill.sh .agents/skills/faker-realistic-ptbr/SKILL.md`
- [ ] `vendor/bin/sail artisan tinker --execute 'echo config("app.faker_locale");'` retorna `pt_BR`
- [ ] `vendor/bin/sail artisan tinker --execute 'echo fake()->cpf();'` retorna CPF formatado
- [ ] Se provider custom foi registrado: `vendor/bin/sail artisan tinker --execute 'echo fake()->internalCode();'`
- [ ] `vendor/bin/sail artisan test --compact --filter=Factory`
- [ ] `vendor/bin/sail bin pint --dirty --format agent`
- [ ] `vendor/bin/sail bin phpstan analyse`
- [ ] Confirmar zero ocorrências de `fake('pt_BR')` ou `fake('en_US')` no diff: `! git diff --staged | grep -E "fake\(['\"](pt_BR|en_US)['\"]\)"`

## Related

- `translation` — fixa `APP_FAKER_LOCALE=pt_BR` no `.env` (pré-requisito).
- `model-with-factory-and-seeder` — factories consomem `fake()` sem argumento.
- `composer-dep-install` — mantém stack sem pacote Faker adicional.
- Downstream: `pest-feature-test-filament-resource`, `pest-unit-test-action`.
