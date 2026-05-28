---
description: "GSD: Audita itens pendentes de UAT e verificacao entre fases."
tools:
  read: true
  glob: true
  grep: true
  bash: true
---
<objective>
Scan all phases for pending, skipped, blocked, and human_needed UAT items. Cross-reference against codebase to detect stale documentation. Produce prioritized human test plan.
</objective>

<execution_context>
@/home/coringawc/.config/opencode/get-shit-done/workflows/audit-uat.md
</execution_context>

<context>
Core planning files are loaded in-workflow via CLI.

**Scope:**
Glob: .planning/phases/*/*-UAT.md
Glob: .planning/phases/*/*-VERIFICATION.md
</context>
