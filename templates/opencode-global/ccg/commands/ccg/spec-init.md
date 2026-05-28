---
description: '初始化 OpenSpec (OPSX) 环境 + 验证多模型 MCP 工具'
---
<!-- CCG:SPEC:INIT:START -->
**Core Philosophy**
- OPSX provides the specification framework; CCG adds multi-model collaboration.
- This phase ensures all tools are ready before any development work begins.
- Fail fast: detect missing dependencies early rather than mid-workflow.

**Guardrails**
- Detect OS (Linux/macOS/Windows) and adapt commands accordingly.
- Do not proceed to next step until current step completes successfully.
- Provide clear, actionable error messages when a step fails.
- Respect user's existing configurations; avoid overwriting without confirmation.

**Steps**
1. **Detect Operating System**
   - Identify OS using `uname -s` (Unix) or environment variables (Windows).
   - Inform user which OS was detected.

2. **Check and Install OpenSpec (OPSX)**
   - **IMPORTANT**: OpenSpec CLI command is `/home/coringawc/.config/opencode/openspec/bin/openspec`, NOT `opsx`
   - Verify if OpenSpec is available:
     ```bash
     /home/coringawc/.config/opencode/openspec/bin/openspec --version
     ```
   - If not found, install in the OpenCode-managed OpenSpec root:
     ```bash
     npm install --prefix /home/coringawc/.config/opencode/openspec @fission-ai/openspec@latest
     ```
   - After installation, verify again:
     ```bash
     /home/coringawc/.config/opencode/openspec/bin/openspec --version
     ```
   - If the OpenCode-managed wrapper is unavailable, stop and reinstall into the OpenCode root:
     ```bash
     npm install --prefix /home/coringawc/.config/opencode/openspec @fission-ai/openspec@1.3.1
     ```
   - **Note**: Prefer `/home/coringawc/.config/opencode/openspec/bin/openspec` (not `opsx`) for CLI commands.

3. **Initialize OPSX for Current Project**
   - **重要**：所有命令必须在当前工作目录下执行，禁止 `cd` 到其他路径。如不确定当前目录，先执行 `pwd` 确认。
   - Check if already initialized:
     ```bash
     ls -la openspec/ 2>/dev/null || echo "Not initialized"
     ```
   - If not initialized, run interactive setup (v1.2+ auto-detects AI tools):
     ```bash
     /home/coringawc/.config/opencode/openspec/bin/openspec init
     ```
   - **Profile Selection** (v1.2+):
     - `core` profile (default): 4 essential workflows (`propose`, `explore`, `apply`, `archive`)
     - `custom` profile: Pick any subset of workflows
     - To change profile later: `/home/coringawc/.config/opencode/openspec/bin/openspec config profile`
   - Verify initialization:
     - Check `openspec/` directory exists
     - Check `openspec/config.yaml` exists
     - Check `/home/coringawc/.config/opencode/openspec/bin/openspec status --json` runs in initialized projects
   - Report any errors with remediation steps.

4. **Validate Multi-Model MCP Tools**
   - Check `codeagent-wrapper` availability: `/home/coringawc/.config/opencode/ccg/bin/codeagent-wrapper --version`
   - **工作目录**：`{{WORKDIR}}` **必须通过 Bash 执行 `pwd`（Unix）或 `cd`（Windows CMD）获取当前工作目录的绝对路径**，禁止从 `$HOME` 或环境变量推断。如果用户通过 `/add-dir` 添加了多个工作区，先确定任务相关的工作区。
   - Test codex backend:
     ```bash
     echo "echo test" | /home/coringawc/.config/opencode/ccg/bin/codeagent-wrapper --backend codex - "{{WORKDIR}}"
     ```
   - Test secondary Codex perspective backend:
     ```bash
     echo "echo test" | /home/coringawc/.config/opencode/ccg/bin/codeagent-wrapper --backend codex - "{{WORKDIR}}"
     ```
   - For each unavailable tool, display warning with installation instructions.

5. **Summary Report**
   Display status table:
   ```
   Component                 Status
   ─────────────────────────────────
   OpenSpec (OPSX) CLI       ✓/✗
   Project initialized       ✓/✗
   OPSX Skills               ✓/✗
   codeagent-wrapper         ✓/✗
   codex backend             ✓/✗
   secondary codex perspective    ✓/✗
   ```

   **Next Steps (Use CCG Encapsulated Commands)**
   1. Start Research: `/spec-research "description"`
   2. Plan & Design: `/spec-plan`
   3. Implement: `/spec-impl` (Includes auto-review & archive)

   **Standalone Tools (Available Anytime)**
   - Code Review: `/spec-review` (Independent dual-model review)

**Reference**
- OpenSpec (OPSX) CLI: `/home/coringawc/.config/opencode/openspec/bin/openspec --help`
- Profile Management: `/home/coringawc/.config/opencode/openspec/bin/openspec config profile`
- CCG Workflow: `npx ccg-workflow`
- 后端/前端模型 MCP: Bundled with codeagent-wrapper
- Node.js >= 18.x required for OpenSpec
<!-- CCG:SPEC:INIT:END -->
