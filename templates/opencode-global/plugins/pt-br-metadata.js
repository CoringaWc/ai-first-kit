/**
 * Experimental pt_BR metadata overlay for OpenCode.
 *
 * Goal: test whether command descriptions changed in the config hook are
 * reflected in the web slash-command picker. This intentionally touches only
 * runtime metadata and does not edit command files or skills.
 */

const COMMAND_METADATA_PT_BR = {
  plan: ["ECC", "Cria um plano de implementacao detalhado para features complexas."],
  tdd: ["ECC", "Guia implementacao com TDD: teste falhando, codigo minimo e verificacao."],
  "code-review": ["ECC", "Revisa codigo procurando bugs, riscos, seguranca e manutencao."],
  security: ["ECC", "Executa revisao de seguranca em auth, inputs, endpoints e dados sensiveis."],
  "build-fix": ["ECC", "Corrige erros de build, TypeScript ou compilacao com mudancas minimas."],
  e2e: ["ECC", "Cria ou executa testes E2E para fluxos importantes do usuario."],
  "refactor-clean": ["ECC", "Remove codigo morto, duplicacao e simplifica implementacoes."],
  orchestrate: ["ECC", "Coordena varios agents para planejar ou revisar tarefas complexas."],
  "update-docs": ["ECC", "Atualiza documentacao afetada por mudancas no projeto."],
  "update-codemaps": ["ECC", "Atualiza mapas de codigo e documentacao estrutural do projeto."],
  "test-coverage": ["ECC", "Analisa cobertura de testes e aponta lacunas importantes."],
  "spec-init": ["OpenSpec/CCG", "Inicializa ou valida o ambiente OpenSpec do projeto."],
  "spec-research": ["OpenSpec/CCG", "Pesquisa requisitos e cria uma proposta OpenSpec."],
  "spec-plan": ["OpenSpec/CCG", "Transforma proposta OpenSpec em specs, design e tarefas."],
  "spec-impl": ["OpenSpec/CCG", "Implementa uma mudanca OpenSpec com revisao e arquivamento."],
  "spec-review": ["OpenSpec/CCG", "Revisa implementacao contra a mudanca OpenSpec."],
};

const COMMAND_PREFIX_RULES = [
  [/^gsd-/, "GSD"],
  [/^spec-/, "OpenSpec/CCG"],
  [/^multi-/, "CCG Multi-Agent"],
  [/^hookify/, "Hookify"],
  [/^prp-/, "PRP"],
  [/^instinct-|^evolve$|^promote$|^learn$/, "Continuous Learning"],
  [/^ccg-/, "CCG"],
  [/^(plan|tdd|code-review|security|build-fix|e2e|refactor-clean|orchestrate|update-docs|update-codemaps|test-coverage)$/, "ECC"],
];

function inferCommandPrefix(name) {
  for (const [pattern, prefix] of COMMAND_PREFIX_RULES) {
    if (pattern.test(name)) return prefix;
  }
  return null;
}

function withPrefix(prefix, description) {
  if (!prefix || !description) return description;
  if (description.startsWith(`${prefix}: `)) return description;
  return `${prefix}: ${description}`;
}

function applyCommandDescriptions(config) {
  if (!config.command || typeof config.command !== "object") return;

  for (const [name, metadata] of Object.entries(COMMAND_METADATA_PT_BR)) {
    const command = config.command[name];
    if (!command || typeof command !== "object") continue;
    const [prefix, description] = metadata;
    command.description = withPrefix(prefix, description);
  }

  for (const [name, command] of Object.entries(config.command)) {
    if (!command || typeof command !== "object" || !command.description) continue;
    const prefix = inferCommandPrefix(name);
    if (!prefix) continue;
    if (/^[A-Za-z][A-Za-z0-9 /-]{1,32}: /.test(command.description)) continue;
    command.description = withPrefix(prefix, command.description);
  }
}

export const PtBrMetadataPlugin = async ({ client }) => ({
  config: (config) => {
    applyCommandDescriptions(config);
    client.app.log({
      body: {
        service: "pt-br-metadata",
        level: "info",
        message: "Applied experimental pt_BR command metadata overlay",
      },
    });
  },
});

export default PtBrMetadataPlugin;
