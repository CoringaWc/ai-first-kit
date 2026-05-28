import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { Database } from "bun:sqlite";

const START = "CLAUDE_MEM_MANUAL_SUMMARY";
const END = "END_CLAUDE_MEM_MANUAL_SUMMARY";
const DEFAULT_WORKER_URL = "http://127.0.0.1:37700";
const DEFAULT_OPENCODE_DB = path.join(os.homedir(), ".local/share/opencode/opencode.db");
const DEFAULT_CLAUDE_MEM_DB = path.join(os.homedir(), ".claude-mem/claude-mem.db");
const DEFAULT_CODEX_DIR = path.join(os.homedir(), ".codex/sessions");
const DEFAULT_COPILOT_DIR = path.join(os.homedir(), ".copilot/session-state");

export function parseLatestBlock(input) {
  if (!input || !input.includes(START)) return null;
  const blocks = [];
  let cursor = 0;
  while (cursor < input.length) {
    const start = input.indexOf(START, cursor);
    if (start === -1) break;
    const contentStart = start + START.length;
    const end = input.indexOf(END, contentStart);
    if (end === -1) break;
    blocks.push(parseBlockBody(input.slice(contentStart, end)));
    cursor = end + END.length;
  }
  return blocks.length ? blocks[blocks.length - 1] : null;
}

function parseBlockBody(body) {
  const lines = body.replace(/\r\n/g, "\n").split("\n");
  const result = { project: "", title: "", text: "" };
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const project = line.match(/^project:\s*(.*)$/);
    if (project) {
      result.project = project[1].trim();
      continue;
    }
    const title = line.match(/^title:\s*(.*)$/);
    if (title) {
      result.title = title[1].trim();
      continue;
    }
    if (/^text:\s*\|\s*$/.test(line)) {
      const textLines = [];
      for (let j = i + 1; j < lines.length; j++) textLines.push(lines[j].replace(/^  ?/, ""));
      result.text = textLines.join("\n").trim();
      break;
    }
    const inlineText = line.match(/^text:\s*(.*)$/);
    if (inlineText) result.text = inlineText[1].trim();
  }
  return result;
}

export function normalizeBlock(block) {
  if (!block) throw new Error("Missing summary block");
  const project = sanitizeSingleLine(block.project);
  const title = sanitizeSingleLine(block.title);
  const text = String(block.text || "").trim();
  if (!project) throw new Error("Missing project");
  if (!title) throw new Error("Missing title");
  if (!text) throw new Error("Missing text");
  if (text.length < 40) throw new Error("Text too short");
  if (text.length > 12000) throw new Error("Text too long");
  const redactedText = redactSecrets(text);
  if (hasPotentialSecret(redactedText)) throw new Error("Potential secret detected");
  return { project, title, text: redactedText };
}

function sanitizeSingleLine(value) {
  return String(value || "").replace(/[\r\n]/g, " ").replace(/\s+/g, " ").trim().slice(0, 160);
}

export function redactSecrets(value) {
  return String(value)
    .replace(/(Authorization:\s*Bearer\s+)[A-Za-z0-9._~+\/-]{20,}/gi, "$1[REDACTED_SECRET]")
    .replace(/\b(Bearer\s+)[A-Za-z0-9._~+\/-]{20,}/gi, "$1[REDACTED_SECRET]")
    .replace(/\b((?:[A-Z0-9_]*KEY|TOKEN|SECRET|PASSWORD)\s*=\s*)[^\s`'\"]{12,}/gi, "$1[REDACTED_SECRET]")
    .replace(/\b(gh[pousr]_[A-Za-z0-9_]{20,})\b/g, "[REDACTED_SECRET]")
    .replace(/\b(sk-[A-Za-z0-9_-]{20,})\b/g, "[REDACTED_SECRET]");
}

export function hasPotentialSecret(value) {
  const text = String(value);
  const patterns = [
    /\bgh[pousr]_[A-Za-z0-9_]{20,}\b/,
    /\bsk-[A-Za-z0-9_-]{20,}\b/,
    /\b(?:api[_-]?key|token|secret|password)\b\s*[=:]\s*(?!\[REDACTED_SECRET\])[^\s`'\"]{12,}/i,
    /Authorization:\s*Bearer\s+(?!\[REDACTED_SECRET\])[A-Za-z0-9._~+\/-]{20,}/i,
  ];
  return patterns.some((pattern) => pattern.test(text));
}

export function buildPayload(block, options = {}) {
  const normalized = normalizeBlock(block);
  const contentHash = hashBlock(normalized);
  return {
    project: normalized.project,
    title: normalized.title,
    text: normalized.text,
    metadata: {
      source: "manual_hook",
      platform: options.platform || "opencode",
      source_session_id: options.sessionId || "unknown",
      content_hash: contentHash,
    },
  };
}

function hashBlock(block) {
  const stable = JSON.stringify({ project: block.project, title: block.title, text: block.text });
  return crypto.createHash("sha256").update(stable).digest("hex");
}

export function alreadySaved(contentHash, dbPath = DEFAULT_CLAUDE_MEM_DB) {
  if (!fs.existsSync(dbPath)) return false;
  const db = new Database(dbPath, { readonly: true });
  try {
    const row = db
      .query("SELECT id FROM observations WHERE metadata LIKE ? LIMIT 1")
      .get(`%\"content_hash\":\"${contentHash}\"%`);
    return Boolean(row);
  } finally {
    db.close();
  }
}

export async function savePayload(payload, options = {}) {
  if (alreadySaved(payload.metadata.content_hash, options.claudeMemDbPath)) {
    return { saved: false, reason: "duplicate", contentHash: payload.metadata.content_hash };
  }
  const workerUrl = options.workerUrl || DEFAULT_WORKER_URL;
  const response = await fetch(`${workerUrl}/api/memory/save`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  if (!response.ok) throw new Error(`claude-mem save failed: HTTP ${response.status}`);
  const body = await response.json().catch(() => ({}));
  return { saved: true, id: body.id, contentHash: payload.metadata.content_hash };
}

export function extractSessionTextsFromOpenCode(dbPath = DEFAULT_OPENCODE_DB, recent = 200) {
  if (!fs.existsSync(dbPath)) return [];
  const db = new Database(dbPath, { readonly: true });
  try {
    const sessions = db
      .query("SELECT id, title, directory, time_updated FROM session ORDER BY time_updated DESC LIMIT ?")
      .all(recent);
    const parts = db.query("SELECT data FROM part WHERE session_id = ? ORDER BY time_created ASC");
    return sessions.map((session) => {
      const text = parts
        .all(session.id)
        .map((row) => safePartText(row.data))
        .filter(Boolean)
        .join("\n");
      return { ...session, text };
    });
  } finally {
    db.close();
  }
}

function safePartText(data) {
  try {
    const parsed = JSON.parse(data);
    if (parsed?.type === "text" && typeof parsed.text === "string") return parsed.text;
    return "";
  } catch {
    return "";
  }
}

async function saveText(input, options = {}) {
  const block = parseLatestBlock(input);
  if (!block) return { saved: false, reason: "no_block" };
  const payload = buildPayload(block, options);
  return savePayload(payload, options);
}

async function scanOpenCode(options = {}) {
  const sessions = extractSessionTextsFromOpenCode(options.openCodeDbPath, options.recent || 200);
  const results = [];
  for (const session of sessions) {
    const block = parseLatestBlock(session.text);
    if (!block) continue;
    try {
      const payload = buildPayload(block, { platform: "opencode", sessionId: session.id });
      results.push(await savePayload(payload, options));
    } catch (error) {
      const reason = error instanceof Error ? error.message : String(error);
      if (!["Missing project", "Missing title", "Missing text", "Text too short"].includes(reason)) {
        results.push({ saved: false, reason, sessionId: session.id });
      }
    }
  }
  return results;
}

export function extractRecentJsonlTexts(rootDir, recent = 200) {
  if (!fs.existsSync(rootDir)) return [];
  const files = listJsonlFiles(rootDir)
    .map((filePath) => ({ filePath, mtimeMs: fs.statSync(filePath).mtimeMs }))
    .sort((a, b) => b.mtimeMs - a.mtimeMs)
    .slice(0, recent);
  return files.map(({ filePath }) => ({ sessionId: filePath, text: extractTextFromJsonl(filePath) }));
}

function listJsonlFiles(rootDir) {
  const output = [];
  const stack = [rootDir];
  while (stack.length) {
    const current = stack.pop();
    let entries = [];
    try {
      entries = fs.readdirSync(current, { withFileTypes: true });
    } catch {
      continue;
    }
    for (const entry of entries) {
      const fullPath = path.join(current, entry.name);
      if (entry.isDirectory()) stack.push(fullPath);
      else if (entry.isFile() && entry.name.endsWith(".jsonl")) output.push(fullPath);
    }
  }
  return output;
}

function extractTextFromJsonl(filePath) {
  const lines = fs.readFileSync(filePath, "utf8").split("\n").filter(Boolean);
  const chunks = [];
  for (const line of lines) {
    try {
      const parsed = JSON.parse(line);
      collectRelevantStrings(parsed, chunks);
    } catch {
      chunks.push(line);
    }
  }
  return chunks.join("\n");
}

function collectRelevantStrings(value, chunks, key = "") {
  if (typeof value === "string") {
    if (["text", "message", "content", "detailedContent"].includes(key) || value.includes(START)) chunks.push(value);
    return;
  }
  if (Array.isArray(value)) {
    for (const item of value) collectRelevantStrings(item, chunks, key);
    return;
  }
  if (value && typeof value === "object") {
    for (const [childKey, childValue] of Object.entries(value)) collectRelevantStrings(childValue, chunks, childKey);
  }
}

async function scanTextSessions(sessions, platform, options = {}) {
  const results = [];
  for (const session of sessions) {
    const block = parseLatestBlock(session.text);
    if (!block) continue;
    try {
      const payload = buildPayload(block, { platform, sessionId: session.sessionId });
      results.push(await savePayload(payload, options));
    } catch (error) {
      const reason = error instanceof Error ? error.message : String(error);
      if (!["Missing project", "Missing title", "Missing text", "Text too short"].includes(reason)) {
        results.push({ saved: false, reason, sessionId: session.sessionId, platform });
      }
    }
  }
  return results;
}

async function scanAll(options = {}) {
  const recent = options.recent || 200;
  const opencode = await scanOpenCode({ ...options, recent });
  const codex = await scanTextSessions(extractRecentJsonlTexts(options.codexDir || DEFAULT_CODEX_DIR, recent), "codex", options);
  const copilot = await scanTextSessions(extractRecentJsonlTexts(options.copilotDir || DEFAULT_COPILOT_DIR, recent), "copilot", options);
  return { opencode, codex, copilot };
}

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) chunks.push(Buffer.from(chunk));
  return Buffer.concat(chunks).toString("utf8");
}

function argValue(name, fallback) {
  const index = process.argv.indexOf(name);
  return index >= 0 && process.argv[index + 1] ? process.argv[index + 1] : fallback;
}

async function main() {
  const command = process.argv[2];
  try {
    if (command === "save-text") {
      const input = await readStdin();
      const result = await saveText(input, {
        platform: argValue("--platform", "opencode"),
        sessionId: argValue("--session-id", "stdin"),
      });
      console.log(JSON.stringify(result));
      return;
    }
    if (command === "scan-opencode") {
      const recent = Number(argValue("--recent", "200"));
      const results = await scanOpenCode({ recent: Number.isFinite(recent) ? recent : 200 });
      console.log(JSON.stringify({ scanned: true, results }));
      return;
    }
    if (command === "scan-all") {
      const recent = Number(argValue("--recent", "200"));
      const results = await scanAll({ recent: Number.isFinite(recent) ? recent : 200 });
      console.log(JSON.stringify({ scanned: true, results }));
      return;
    }
    if (command === "self-test-fixture") {
      const fixture = `${START}\nproject: manual-hook-fixture\ntitle: manual hook fixture\ntext: |\n  manual hook fixture validates that claude-mem can save explicit summaries without an external provider.\n${END}`;
      const result = await saveText(fixture, { platform: "opencode", sessionId: `fixture-${Date.now()}` });
      console.log(JSON.stringify(result));
      return;
    }
    console.log("Usage: claude-mem-manual-summary.mjs save-text|scan-opencode|scan-all|self-test-fixture");
  } catch (error) {
    console.warn(`[claude-mem-manual-summary] ${error instanceof Error ? error.message : String(error)}`);
    process.exitCode = 0;
  }
}

if (import.meta.main) await main();
