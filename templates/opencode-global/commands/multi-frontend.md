---
description: "CCG Multi-Agent: Executa workflow multi-modelo focado em componentes, layout, animacao e UI."
---

# Frontend - Frontend-Focused Development

Frontend-focused workflow (Research -> Ideation -> Plan -> Execute -> Optimize -> Review), Codex-led for this environment.

## Environment Override

- Gemini is not installed here. Never call the Gemini backend.
- Use `--backend codex` for all external model calls.
- Copilot CLI is installed, but `codeagent-wrapper` does not support a `copilot` backend and this shell is not authenticated for `copilot -p`.

## Usage

```bash
/frontend <UI task description>
```

## Context

- Frontend task: $ARGUMENTS
- Codex-led; no Gemini calls in this environment
- Applicable: Component design, responsive layout, UI animations, style optimization

## Your Role

You are the **Frontend Orchestrator**, coordinating multi-model collaboration for UI/UX tasks (Research → Ideation → Plan → Execute → Optimize → Review).

**Collaborative Models**:
- **Codex** – Frontend/UI analysis, implementation planning, and review
- **Claude (self)** – Orchestration, planning, execution, delivery

---

## Multi-Model Call Specification

**Call Syntax**:

```
# New session call
Bash({
  command: "/home/coringawc/.config/opencode/ccg/bin/codeagent-wrapper {{LITE_MODE_FLAG}}--backend codex - \"$PWD\" <<'EOF'
ROLE_FILE: <role prompt path>
<TASK>
Requirement: <enhanced requirement (or $ARGUMENTS if not enhanced)>
Context: <project context and analysis from previous phases>
</TASK>
OUTPUT: Expected output format
EOF",
  run_in_background: false,
  timeout: 3600000,
  description: "Brief description"
})

# Resume session call
Bash({
  command: "/home/coringawc/.config/opencode/ccg/bin/codeagent-wrapper {{LITE_MODE_FLAG}}--backend codex resume <SESSION_ID> - \"$PWD\" <<'EOF'
ROLE_FILE: <role prompt path>
<TASK>
Requirement: <enhanced requirement (or $ARGUMENTS if not enhanced)>
Context: <project context and analysis from previous phases>
</TASK>
OUTPUT: Expected output format
EOF",
  run_in_background: false,
  timeout: 3600000,
  description: "Brief description"
})
```

**Role Prompts**:

| Phase | Codex |
|-------|--------|
| Analysis | `/home/coringawc/.config/opencode/ccg/.ccg/prompts/codex/analyzer.md` |
| Planning | `/home/coringawc/.config/opencode/ccg/.ccg/prompts/codex/architect.md` |
| Review | `/home/coringawc/.config/opencode/ccg/.ccg/prompts/codex/reviewer.md` |

**Session Reuse**: Each call returns `SESSION_ID: xxx`, use `resume xxx` for subsequent phases. Save `CODEX_SESSION` in Phase 2, use `resume` in Phases 3 and 5.

---

## Communication Guidelines

1. Start responses with mode label `[Mode: X]`, initial is `[Mode: Research]`
2. Follow strict sequence: `Research → Ideation → Plan → Execute → Optimize → Review`
3. Use `AskUserQuestion` tool for user interaction when needed (e.g., confirmation/selection/approval)

---

## Core Workflow

### Phase 0: Prompt Enhancement (Optional)

`[Mode: Prepare]` - If ace-tool MCP available, call `mcp__ace-tool__enhance_prompt`, **replace original $ARGUMENTS with enhanced result for subsequent Codex calls**. If unavailable, use `$ARGUMENTS` as-is.

### Phase 1: Research

`[Mode: Research]` - Understand requirements and gather context

1. **Code Retrieval** (if ace-tool MCP available): Call `mcp__ace-tool__search_context` to retrieve existing components, styles, design system. If unavailable, use built-in tools: `Glob` for file discovery, `Grep` for component/style search, `Read` for context gathering, `Task` (Explore agent) for deeper exploration.
2. Requirement completeness score (0-10): >=7 continue, <7 stop and supplement

### Phase 2: Ideation

`[Mode: Ideation]` - Codex-led analysis

**MUST call Codex** (follow call specification above):
- ROLE_FILE: `/home/coringawc/.config/opencode/ccg/.ccg/prompts/codex/analyzer.md`
- Requirement: Enhanced requirement (or $ARGUMENTS if not enhanced)
- Context: Project context from Phase 1
- OUTPUT: UI feasibility analysis, recommended solutions (at least 2), UX evaluation

**Save SESSION_ID** (`CODEX_SESSION`) for subsequent phase reuse.

Output solutions (at least 2), wait for user selection.

### Phase 3: Planning

`[Mode: Plan]` - Codex-led planning

**MUST call Codex** (use `resume <CODEX_SESSION>` to reuse session):
- ROLE_FILE: `/home/coringawc/.config/opencode/ccg/.ccg/prompts/codex/architect.md`
- Requirement: User's selected solution
- Context: Analysis results from Phase 2
- OUTPUT: Component structure, UI flow, styling approach

Claude synthesizes plan, save to `.opencode/plan/task-name.md` after user approval.

### Phase 4: Implementation

`[Mode: Execute]` - Code development

- Strictly follow approved plan
- Follow existing project design system and code standards
- Ensure responsiveness, accessibility

### Phase 5: Optimization

`[Mode: Optimize]` - Codex-led review

**MUST call Codex** (follow call specification above):
- ROLE_FILE: `/home/coringawc/.config/opencode/ccg/.ccg/prompts/codex/reviewer.md`
- Requirement: Review the following frontend code changes
- Context: git diff or code content
- OUTPUT: Accessibility, responsiveness, performance, design consistency issues list

Integrate review feedback, execute optimization after user confirmation.

### Phase 6: Quality Review

`[Mode: Review]` - Final evaluation

- Check completion against plan
- Verify responsiveness and accessibility
- Report issues and recommendations

---

## Key Rules

1. **Codex is the only configured external model for this workflow**
2. **Do not call Gemini in this environment**
3. External models have **zero filesystem write access**
4. Claude handles all code writes and file operations
