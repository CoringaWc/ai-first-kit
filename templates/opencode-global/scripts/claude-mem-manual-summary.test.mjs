import { describe, expect, test } from "bun:test";
import {
  buildPayload,
  extractRecentJsonlTexts,
  hasPotentialSecret,
  normalizeBlock,
  parseLatestBlock,
  redactSecrets,
} from "./claude-mem-manual-summary.mjs";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const sample = `noise
CLAUDE_MEM_MANUAL_SUMMARY
project: siasgfacil-app
title: Decisao de memoria manual
text: |
  Aprendemos que o claude-mem pode salvar memoria manual sem provider.
  O hook deve salvar apenas blocos marcados explicitamente.
END_CLAUDE_MEM_MANUAL_SUMMARY`;

describe("manual summary parser", () => {
  test("extracts the latest marked block", () => {
    const block = parseLatestBlock(`${sample}\n${sample.replace("siasgfacil-app", "global")}`);
    expect(block).not.toBeNull();
    expect(block.project).toBe("global");
    expect(block.title).toBe("Decisao de memoria manual");
    expect(block.text).toContain("hook deve salvar");
  });

  test("returns null when no marker exists", () => {
    expect(parseLatestBlock("sem memoria duravel")).toBeNull();
  });

  test("rejects blocks with missing fields", () => {
    const bad = `CLAUDE_MEM_MANUAL_SUMMARY\nproject: demo\ntext: |\n  texto suficiente\nEND_CLAUDE_MEM_MANUAL_SUMMARY`;
    expect(() => normalizeBlock(parseLatestBlock(bad))).toThrow("Missing title");
  });

  test("redacts common secrets", () => {
    const redacted = redactSecrets("Authorization: Bearer abcdefghijklmnopqrstuvwxyz012345");
    expect(redacted).toContain("Bearer [REDACTED_SECRET]");
    expect(redacted).not.toContain("abcdefghijklmnopqrstuvwxyz012345");
  });

  test("detects suspicious unredacted secrets", () => {
    expect(hasPotentialSecret("OPENAI_API_KEY=sk-abcdefghijklmnopqrstuvwxyz0123456789")).toBe(true);
    expect(hasPotentialSecret("Sem segredo aqui, apenas uma decisao tecnica.")).toBe(false);
  });

  test("builds claude-mem payload with dedupe metadata", () => {
    const block = normalizeBlock(parseLatestBlock(sample));
    const payload = buildPayload(block, { platform: "opencode", sessionId: "abc123" });
    expect(payload.project).toBe("siasgfacil-app");
    expect(payload.title).toBe("Decisao de memoria manual");
    expect(payload.metadata.source).toBe("manual_hook");
    expect(payload.metadata.platform).toBe("opencode");
    expect(payload.metadata.source_session_id).toBe("abc123");
    expect(payload.metadata.content_hash).toMatch(/^[a-f0-9]{64}$/);
  });

  test("extracts marker blocks from jsonl transcripts", () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "manual-summary-jsonl-"));
    const file = path.join(dir, "session.jsonl");
    fs.writeFileSync(
      file,
      `${JSON.stringify({ type: "assistant.message", data: { content: sample } })}\n`,
      "utf8",
    );
    const sessions = extractRecentJsonlTexts(dir, 10);
    expect(sessions).toHaveLength(1);
    expect(parseLatestBlock(sessions[0].text).project).toBe("siasgfacil-app");
    fs.rmSync(dir, { recursive: true, force: true });
  });
});
