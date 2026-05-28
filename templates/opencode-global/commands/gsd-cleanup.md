---
description: "GSD: Arquiva diretorios acumulados de fases em milestones concluidos."
requires: [phase]
tools:
  read: true
  write: true
  bash: true
  question: true
---
<objective>
Archive phase directories from completed milestones into `.planning/milestones/v{X.Y}-phases/`.

Use when `.planning/phases/` has accumulated directories from past milestones.
</objective>

<execution_context>
@/home/coringawc/.config/opencode/get-shit-done/workflows/cleanup.md
</execution_context>

<process>
Execute end-to-end.
Identify completed milestones, show a dry-run summary, and archive on confirmation.
</process>
