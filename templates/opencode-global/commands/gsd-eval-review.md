---
description: "GSD: Audita cobertura de avaliacao de fase de IA executada e gera plano de remediacao."
argument-hint: "[phase number]"
requires: [phase]
tools:
  read: true
  write: true
  bash: true
  glob: true
  grep: true
  agent: true
  question: true
---
<objective>
Conduct a retroactive evaluation coverage audit of a completed AI phase.
Checks whether the evaluation strategy from AI-SPEC.md was implemented.
Produces EVAL-REVIEW.md with score, verdict, gaps, and remediation plan.
</objective>

<execution_context>
@/home/coringawc/.config/opencode/get-shit-done/workflows/eval-review.md
@/home/coringawc/.config/opencode/get-shit-done/references/ai-evals.md
</execution_context>

<context>
Phase: $ARGUMENTS — optional, defaults to last completed phase.
</context>

<process>
Execute end-to-end.
Preserve all workflow gates.
</process>
