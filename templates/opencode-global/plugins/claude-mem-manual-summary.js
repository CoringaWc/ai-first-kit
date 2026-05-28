import { spawn } from "node:child_process";

const BUN = "/home/coringawc/.bun/bin/bun";
const SCRIPT = "/home/coringawc/.config/opencode/scripts/claude-mem-manual-summary.mjs";

function runScan() {
  const child = spawn(BUN, [SCRIPT, "scan-opencode", "--recent", "30"], {
    detached: true,
    stdio: "ignore",
  });
  child.unref();
}

export const ClaudeMemManualSummaryPlugin = async () => ({
  "session.idle": async () => {
    runScan();
  },
  "session.deleted": async () => {
    runScan();
  },
});

export default ClaudeMemManualSummaryPlugin;
