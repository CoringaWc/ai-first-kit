# Checklist obrigatório de cada SKILL.md

Toda SKILL.md DEVE conter, na ordem:

1. `# <Skill Title>` — título humano descritivo (não é o slug)
2. `## Consistency First` — instrução para checar convenções existentes antes de impor as desta skill
3. `## Quick Reference` — 5-12 bullets curtos com o essencial
4. `## Workflow` — passos numerados com comandos exatos e checklist `- [ ]`
5. `## Anti-Patterns` — o que NÃO fazer, genérico (sem `file:line` real do projeto, para a skill permanecer reutilizável entre repos)
6. `## Verification` — comandos exatos para validar sucesso (incluindo testes/lints)
7. `## Related` — referências cruzadas (skills nossas + Boost + docs externas)

Se SKILL.md > 200 linhas, deportar detalhes para `rules/<topico>.md` e referenciar com path relativo.
