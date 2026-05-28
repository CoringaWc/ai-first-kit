---
description: "GSD: Gera contrato de design UI-SPEC.md para fases frontend."
argument-hint: "[phase]"
requires: [phase]
tools:
  read: true
  write: true
  bash: true
  glob: true
  grep: true
  agent: true
  webfetch: true
  question: true
  mcp__context7__*: true
---
<objective>
Create a UI design contract (UI-SPEC.md) for a frontend phase.
Orchestrates gsd-ui-researcher and gsd-ui-checker.
Flow: Validate → Research UI → Verify UI-SPEC → Done
</objective>

<execution_context>
@/home/coringawc/.config/opencode/get-shit-done/workflows/ui-phase.md
@/home/coringawc/.config/opencode/get-shit-done/references/ui-brand.md
</execution_context>

<context>
Phase number: $ARGUMENTS — optional, auto-detects next unplanned phase if omitted.
</context>

<process>
Execute end-to-end.
Preserve all workflow gates.
</process>
