# Verify Gate

`vendor/bin/sail composer verify` é o gate local obrigatório antes de commit, PR, release ou handoff.

O script deve rodar dentro do Sail e deve incluir estas etapas, nesta ordem:

1. Pint
2. Larastan/PHPStan
3. Pest Unit
4. Pest Feature
5. Pest Browser quando `tests/Browser/*Test.php` existir
6. Vite build

Se qualquer etapa falhar, corrija a causa e rode o gate inteiro novamente. Não reporte conclusão a partir de rodadas parciais.

Quando o projeto ainda não tiver suíte browser, `test:browser` pode retornar `N/A`, mas isso não deve ser reportado como `PASS`. Quando mudanças de UI exigirem uma suíte browser ausente, reporte `BLOCKED` conforme a skill operacional.
