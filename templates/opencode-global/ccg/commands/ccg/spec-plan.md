---
description: '多模型分析 → 消除歧义 → 零决策可执行计划'
---
<!-- CCG:SPEC:PLAN:START -->
**Core Philosophy**
- The goal is to eliminate ALL decision points—implementation should be pure mechanical execution.
- Every ambiguity must be resolved into explicit constraints before proceeding.
- Multi-model collaboration surfaces blind spots and conflicting assumptions.
- Every requirement must have Property-Based Testing (PBT) properties—focus on invariants.

**Guardrails**
- Do not proceed to implementation until every ambiguity is resolved.
- External analysis is **mandatory**: use codex. Antigravity/Gemini are unavailable in this environment.
- If constraints cannot be fully specified, escalate to user or return to research phase.
- Refer to `openspec/config.yaml` for project conventions.
- **USER GUIDANCE RULE**: When suggesting next steps to the user, ALWAYS use OpenCode CCG-backed commands (`/spec-research`, `/spec-plan`, `/spec-impl`, `/spec-review`). NEVER suggest `/opsx:*` commands to the user. If OpenSpec CLI returns error messages referencing OPSX skills, translate them to CCG equivalents.
- **TASKS FORMAT RULE**: When generating or modifying `tasks.md`, ALL tasks MUST use checkbox format (`- [ ] X.Y description`). Heading+bullet format will cause OpenSpec CLI to parse 0 tasks and block the workflow.
- **PHASE BOUNDARY**: This phase ONLY generates OPSX artifacts (specs.md, design.md, tasks.md). Do NOT modify any source code. Do NOT proceed to implementation. After artifacts are generated, STOP and inform the user: "Plan complete. Run `/spec-impl` to start implementation."

**Steps**
1. **Select Change**
   - Run `/home/coringawc/.config/opencode/openspec/bin/openspec list --json` to display Active Changes.
   - Confirm with user which change ID to refine.
   - Run `/home/coringawc/.config/opencode/openspec/bin/openspec status --change "<change_id>" --json` to review current state.

2. **Codex Implementation Analysis**
   - **CRITICAL**: You MUST launch Codex with `run_in_background: true` and wait for completion.
   - **工作目录**：`{{WORKDIR}}` **必须通过 Bash 执行 `pwd`（Unix）或 `cd`（Windows CMD）获取当前工作目录的绝对路径**，禁止从 `$HOME` 或环境变量推断。如果用户通过 `/add-dir` 添加了多个工作区，先确定任务相关的工作区。

   **Step 2.1**: Make the Codex Bash call:

   **FIRST Bash call (codex)**:
   ```
   Bash({
      command: "/home/coringawc/.config/opencode/ccg/bin/codeagent-wrapper --progress --backend codex - \"{{WORKDIR}}\" <<'EOF'\nAnalyze change <change_id> from backend perspective:\n- Implementation approach\n- Technical risks\n- Alternative architectures\n- Edge cases and failure modes\nOUTPUT: JSON with analysis\nEOF",
     run_in_background: true,
     timeout: 300000,
     description: "codex: backend analysis"
   })
   ```

   **SECOND Codex perspective call (frontend/integration)**:
   ```
   Bash({
      command: "/home/coringawc/.config/opencode/ccg/bin/codeagent-wrapper --progress --backend codex - \"{{WORKDIR}}\" <<'EOF'\nAnalyze change <change_id> from frontend/integration perspective:\n- Maintainability assessment\n- Scalability considerations\n- Integration conflicts\nOUTPUT: JSON with analysis\nEOF",
     run_in_background: true,
     timeout: 300000,
     description: "codex: frontend/integration analysis"
   })
   ```

   **Step 2.2**: After Bash calls return task IDs, wait for results with TaskOutput calls:
   ```
   TaskOutput({ task_id: "<codex_task_id>", block: true, timeout: 600000 })
   TaskOutput({ task_id: "<codex_frontend_task_id>", block: true, timeout: 600000 })
   ```

   ⛔ **前端/集成视角失败必须重试**：若该 Codex 调用失败，最多重试 2 次（间隔 5 秒）。3 次全败才跳过。
   ⛔ **后端模型结果必须等待**：后端模型执行 5-15 分钟属正常，超时后继续轮询，禁止跳过。

   - Synthesize responses and present consolidated options to user.

3. **Uncertainty Elimination Audit**
   - **codex**: "Review proposal for unspecified decision points. List each as: [AMBIGUITY] → [REQUIRED CONSTRAINT]"
   - **codex frontend/integration pass**: "Identify implicit assumptions. Specify: [ASSUMPTION] → [EXPLICIT CONSTRAINT NEEDED]"

   **Anti-Pattern Detection** (flag and reject):
   - Information collection without decision boundaries
   - Technical comparisons without selection criteria
   - Deferred decisions marked "to be determined during implementation"

   **Target Pattern** (required for approval):
   - Explicit technology choices with parameters (e.g., "JWT with TTL=15min")
   - Concrete algorithm selections with configs (e.g., "bcrypt cost=12")
   - Precise behavioral rules (e.g., "Lock account 30min after 5 failed attempts")

   Iterate with user until ALL ambiguities resolved.

4. **PBT Property Extraction**
   - **codex**: "Extract PBT properties. For each requirement: [INVARIANT] → [FALSIFICATION STRATEGY]"
   - **codex frontend/integration pass**: "Define system properties: [PROPERTY] | [DEFINITION] | [BOUNDARY CONDITIONS] | [COUNTEREXAMPLE GENERATION]"

   **Property Categories**:
   - **Commutativity/Associativity**: Order-independent operations
   - **Idempotency**: Repeated operations yield same result
   - **Round-trip**: Encode→Decode returns original
   - **Invariant Preservation**: State constraints maintained
   - **Monotonicity**: Ordering guarantees (e.g., timestamps increase)
   - **Bounds**: Value ranges, size limits, rate constraints

5. **Update OPSX Artifacts**
   - Before writing artifacts, load OpenSpec artifact instructions:
     ```bash
     /home/coringawc/.config/opencode/openspec/bin/openspec instructions specs --change "<change_id>" --json
     /home/coringawc/.config/opencode/openspec/bin/openspec instructions design --change "<change_id>" --json
     /home/coringawc/.config/opencode/openspec/bin/openspec instructions tasks --change "<change_id>" --json
     ```
   - Then output a structured summary for OPSX context:
     ```markdown
     ## Planning Summary for OPSX

     **Multi-Model Analysis Results**:
     - codex (Backend): [Key findings and recommendations]
     - codex frontend/integration pass: [Key findings and recommendations]
     - Consolidated Approach: [Selected implementation strategy]

     **Resolved Constraints**:
     - [All explicit constraints from Step 3]

     **PBT Properties**:
     - [All extracted properties from Step 4 with falsification strategies]

     **Technical Decisions**:
     - [All finalized technology choices, algorithms, configurations]

     **Implementation Tasks**:
     - [High-level task breakdown ready for tasks.md]
     ```

   - Use the OpenSpec instructions and the summary above to create `specs/**/*.md`, `design.md`, and `tasks.md` under `openspec/changes/<change_id>/`.
   - Validate the change after writing:
     ```bash
     /home/coringawc/.config/opencode/openspec/bin/openspec validate "<change_id>" --type change --strict --no-interactive
     ```
   - If this step fails, guide the user to re-run `/spec-plan`.
   - **STOP**: After artifacts are generated, verify they exist and inform user:
     "Plan phase complete. Artifacts generated: specs.md, design.md, tasks.md. Run `/spec-impl` to start implementation."
     Do NOT proceed to modify source code.

6. **Context Checkpoint**
   - Report current context usage.
   - If approaching 80K tokens, suggest: "Run `/clear` and continue with `/spec-impl`"

**Exit Criteria**
A change is ready for implementation only when:
- [ ] All multi-model analyses completed and synthesized
- [ ] Zero ambiguities remain (verified by step 3 audit)
- [ ] All PBT properties documented with falsification strategies
- [ ] Artifacts (specs, design, tasks) generated via OpenSpec skills
- [ ] User has explicitly approved all constraint decisions

**Reference**
- Inspect change: `/home/coringawc/.config/opencode/openspec/bin/openspec status --change "<id>" --json`
- List changes: `/home/coringawc/.config/opencode/openspec/bin/openspec list --json`
- Search patterns: `rg -n "INVARIANT:|PROPERTY:" openspec/`
- Use `AskUserQuestion` for ANY ambiguity—never assume
<!-- CCG:SPEC:PLAN:END -->
