# Instruções Globais do OpenCode

## Idioma de Conversa

- Todas as conversas de chat com o usuário devem ser em `pt_BR`.
- Use português do Brasil para respostas finais, atualizações de progresso, perguntas de esclarecimento, planos e resumos.
- Mantenha nomes de arquivos, comandos, código, identificadores, mensagens de erro e termos técnicos no idioma original quando isso preservar precisão.

## Ferramentas Locais

- `agent-browser` está instalado localmente em `/home/coringawc/.config/opencode/tools/agent-browser`.
- Quando precisar usar o `agent-browser`, prefira `/home/coringawc/.config/opencode/bin/agent-browser` em vez de instalação global.
- Para automação web autenticada, use `/home/coringawc/.config/opencode/bin/agent-browser-windows <comando>`; ele inicia/conecta automaticamente no Chrome dedicado do Windows e depois executa o comando do `agent-browser`.
- O perfil dedicado do Chrome para automação fica em `C:\Users\nt_17\AppData\Local\opencode-agent-browser-profile`; não copie o perfil pessoal do Chrome, cookies, senhas ou arquivos de credenciais.
- O launcher do Windows fica em `C:\Users\nt_17\AppData\Local\opencode-agent-browser\start-agent-browser.ps1` e também é chamado no login por `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\opencode-agent-browser.cmd`.

<claude-mem-context>
# Memory Context from Past Sessions

*No context yet. Complete your first session and context will appear here.*

Use claude-mem search tools for manual memory queries.
</claude-mem-context>

## Consulta de Memória do claude-mem

- Em tarefas não triviais, retomadas de contexto, depuração, configuração de ambiente, trabalho em projetos conhecidos ou ao ser despachado como subagente, consulte `claude_mem_search` antes de assumir que não há contexto prévio.
- Use consultas curtas com o nome do projeto, host, serviço, erro, arquivo ou decisão relevante.
- Se a busca não retornar resultados úteis, continue normalmente e não invente memória.

## Quiz Colaborativo de Arquitetura

- Durante brainstorming, arquitetura, planejamento ou descoberta de requisitos, faça um quiz com pelo menos cinco perguntas de esclarecimento antes de consolidar o design.
- Use a ferramenta nativa `question` do OpenCode para o quiz sempre que houver opções; não substitua por perguntas em texto puro, exceto quando a pergunta for inerentemente aberta.
- Faça perguntas em lotes de cinco dentro da ferramenta `question` do OpenCode, salvo quando restarem menos de cinco perguntas para encerrar a etapa.
- Antes de enviar cada lote, estime com esforço explícito a quantidade total de perguntas finais necessárias para concluir o brainstorming e exponha esse total no texto das perguntas.
- Cada pergunta deve indicar sua posição e quantas perguntas restarão depois dela, por exemplo: `Pergunta 7 de 12 estimadas — restam 5`.
- Se o escopo mudar e o total estimado aumentar ou diminuir, atualize explicitamente o total e o restante no próximo lote para que o usuário consiga prever o tempo necessário.

## Memória Manual do claude-mem

- Quando uma sessão tiver aprendizados duráveis, decisões, correções, caminhos importantes, comandos úteis ou próximos passos que devem sobreviver a reinícios, emita um bloco `CLAUDE_MEM_MANUAL_SUMMARY` perto do encerramento da resposta.
- Não emita o bloco para conversas triviais, perguntas sem consequência ou conteúdo temporário.
- Nunca inclua segredos, tokens, senhas, chaves de API ou outputs grandes de ferramentas.
- Use exatamente este formato:

```text
CLAUDE_MEM_MANUAL_SUMMARY
project: <nome-do-projeto-ou-global>
title: <titulo curto>
text: |
  <resumo durável em pt_BR com decisões, caminhos, comandos e próximos passos úteis>
END_CLAUDE_MEM_MANUAL_SUMMARY
```
