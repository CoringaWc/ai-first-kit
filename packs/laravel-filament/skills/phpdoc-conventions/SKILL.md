---
name: phpdoc-conventions
description: "Aplicar quando criar ou alterar classes, Actions, Services, Traits ou métodos PHP/Laravel não convencionais que precisam de PHPDoc em pt_BR com exemplos de uso. Use when documenting non-obvious PHP classes, business rules, Laravel Actions, services, traits, model methods, array shapes, side effects, exceptions, and usage examples."
license: MIT
metadata:
  author: coringawc
  version: 1.0.0
  requires:
    - laravel-best-practices
  related:
    - action-class
    - laravel-actions
    - static-analysis-larastan-pint
---

# PHPDoc Conventions
## Consistency First

Use PHPDoc para tornar explícito o que não é óbvio pelo nome, pelos tipos nativos ou pela convenção do Laravel. O objetivo é explicar a regra de negócio, o contrato de uso e os efeitos relevantes sem poluir métodos convencionais do framework.

Todo texto explicativo deve estar em **pt_BR com acentuação correta**. Mantenha nomes de classes, métodos, parâmetros, tipos, comandos e APIs em inglês quando forem identificadores reais.

Antes de escrever PHPDoc, confira arquivos irmãos e docs oficiais. A documentação deve seguir o estilo Laravel: `@param  Tipo  $nome`, `@return`, `@throws`, array shapes e generics apenas quando agregam informação que o tipo nativo não expressa.

## Quick Reference

- Documente classes e métodos **não convencionais**: Actions, Services, Traits, regras de negócio em Models, normalizadores, orquestradores e integrações.
- Dispense PHPDoc em boilerplate óbvio: `up()`, `down()`, `casts()`, relationships Eloquent claras, getters simples e métodos herdados sem regra própria.
- Classes de regra de negócio recebem resumo do caso de uso e motivo da existência.
- Métodos documentados recebem finalidade, parâmetros relevantes, retorno, efeitos colaterais, exceções e exemplo de uso.
- Em `Action` com `handle()` único: resumo curto na classe e documentação detalhada no `handle()`.
- Todo PHPDoc criado por esta skill deve conter ao menos um `Exemplo de uso` quando documentar uma API ou regra não óbvia.
- Não repita no PHPDoc o que o nome e o tipo nativo já dizem; explique contexto, decisão e contrato.
- Use `@param`/`@return` para array shapes, generics, collections tipadas e contratos que o PHP não consegue representar.
- Prefira PHPDoc a comentários inline; comentários inline só para lógica excepcionalmente complexa.
- Se uma implementação foge da convenção do kit ou da comunidade Laravel, documente o motivo no ponto de extensão.

## Workflow

- [ ] Identificar se o código é convencional ou não convencional.

```text
Convencional e óbvio: relationship simples, cast simples, migration up/down direta, getter trivial.
Não convencional: regra de negócio, cálculo com política, integração SIASG, normalizador, trait com contrato, action, service, mutação com side effects.
```

- [ ] Para classe de regra de negócio, escrever PHPDoc de classe com resumo do problema resolvido:

```php
/**
 * Processa a importação de uma planilha de itens de IRP.
 *
 * Esta action concentra a regra que transforma linhas já lidas da planilha em
 * itens persistidos, registrando quantas linhas foram criadas ou ignoradas.
 * Use quando a origem dos dados já foi validada pela camada de upload/leitura.
 */
final class ProcessImportSpreadsheetAction
{
    use AsAction;
}
```

- [ ] Para `Action` com `handle()`, documentar o método com detalhes, array shape, exceções, side effects e exemplo:

```php
/**
 * Cria itens de IRP a partir de linhas normalizadas de uma planilha.
 *
 * Persiste cada linha válida dentro de uma transação e ignora linhas sem
 * descrição, preservando o total processado para auditoria da importação.
 *
 * Exemplo de uso:
 *
 * ```php
 * $resultado = ProcessImportSpreadsheetAction::run($irp, $linhas);
 * ```
 *
 * @param  array<int, array{description?: string|null, quantity?: int|float|string|null, unit_price?: int|float|string|null}>  $rows
 *
 * @throws ValidationException Quando a planilha não possui linhas processáveis.
 */
public function handle(Irp $irp, array $rows): ImportSpreadsheetResult
{
    // ...
}
```

- [ ] Para Service, documentar a classe e cada método público não óbvio com exemplo:

```php
/**
 * Normaliza códigos CatMat e CatServ recebidos do SIASG ou de planilhas.
 *
 * Use este serviço antes de comparar, persistir ou buscar códigos de catálogo,
 * pois entradas humanas podem conter prefixos, espaços e separadores.
 */
final class SiasgCatalogNormalizer
{
    /**
     * Remove caracteres não numéricos e retorna o código canônico do catálogo.
     *
     * Exemplo de uso:
     *
     * ```php
     * $codigo = $normalizer->normalize('CATMAT 12.345-6');
     * ```
     *
     * @throws InvalidArgumentException Quando o valor não contém dígitos.
     */
    public function normalize(string|int|null $code): ?string
    {
        // ...
    }
}
```

- [ ] Para Trait, explicar contrato esperado do model consumidor:

```php
/**
 * Adiciona normalização automática para models que armazenam código SIASG.
 *
 * O model consumidor precisa possuir o atributo `siasg_catalog_code` e deve
 * usar este trait apenas quando o valor representar CatMat ou CatServ.
 */
trait HasSiasgCatalogCode
{
    /**
     * Normaliza e atribui o código SIASG ao atributo persistido.
     *
     * Exemplo de uso:
     *
     * ```php
     * $item->siasg_catalog_code = 'CATSERV 9988';
     * ```
     */
    public function setSiasgCatalogCodeAttribute(string|int|null $value): void
    {
        // ...
    }
}
```

- [ ] Para método não convencional em Model, documentar a regra de negócio completa:

```php
/**
 * Indica se o item precisa de recotação conforme a política de divergência SIASG.
 *
 * A recotação é exigida quando o item veio do SIASG e a cotação expirou, não há
 * preço atual confiável ou a divergência percentual ultrapassa o limite aceito.
 *
 * Exemplo de uso:
 *
 * ```php
 * if ($item->precisaRecotacao(15.0)) {
 *     SolicitarRecotacaoAction::run($item);
 * }
 * ```
 */
public function precisaRecotacao(float $limiteDivergenciaPercentual = 10.0): bool
{
    // ...
}
```

- [ ] Rodar formatação/análise aplicáveis após alterar PHP:

```bash
vendor/bin/sail bin pint --dirty --format agent
vendor/bin/sail composer stan
```

## Anti-Patterns

| Racionalização | Realidade |
| --- | --- |
| "O método é importante, mas o nome já explica." | Regra de negócio precisa explicar contexto, motivo e exemplo de uso. |
| "Vou comentar tudo para garantir." | Boilerplate óbvio vira ruído. Documente o que foge da convenção. |
| "Action de `handle()` único só precisa do tipo." | A classe resume o caso de uso; o `handle()` detalha contrato, efeitos e exemplo. |
| "PHPDoc em inglês é mais técnico." | Neste projeto, explicação de intenção e regra é pt_BR com acentuação correta. |
| "Exemplo é opcional." | Se a API não é óbvia e foi documentada, inclua exemplo de uso. |
| "Comentário inline resolve." | Prefira PHPDoc para contrato público e comentários inline apenas para lógica excepcional. |

Red flags: PHPDoc sem exemplo, descrição genérica, duplicar o nome do método em palavras, explicar apenas tipos nativos, omitir side effects, omitir exceções, misturar português sem acentuação.

## Verification

- [ ] `.agents/skills/_helpers/verify-skill.sh .agents/skills/phpdoc-conventions/SKILL.md` retorna `OK`.
- [ ] Classes de regra de negócio novas têm PHPDoc de classe com resumo da regra abordada.
- [ ] Métodos não convencionais documentados têm descrição, exemplo de uso e contrato relevante.
- [ ] Actions com `handle()` único têm resumo na classe e documentação detalhada no `handle()`.
- [ ] Services, Traits e métodos não convencionais de Model têm PHPDoc em pt_BR com acentuação correta.
- [ ] Boilerplate óbvio não recebeu comentário desnecessário.
- [ ] `vendor/bin/sail bin pint --dirty --format agent` e análise estática aplicável passam quando arquivos PHP são alterados.

## Related
- `action-class` — convenção de Actions em `app/Actions/<Domain>/`.
- `laravel-best-practices` — padrões Laravel, arquitetura, segurança e Eloquent.
- `static-analysis-larastan-pint` — formatação e análise estática após tocar PHP.
