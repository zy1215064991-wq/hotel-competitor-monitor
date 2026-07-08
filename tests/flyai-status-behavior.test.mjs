import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "hotel-monitor-flyai-status-"));
const configPath = path.join(tempDir, "hotel-monitor.json");
const outputRoot = path.join(tempDir, "api-combo");
const readText = (filePath) => fs.readFileSync(filePath, "utf8").replace(/^\uFEFF/, "");
const readJson = (filePath) => JSON.parse(readText(filePath));

const config = JSON.parse(fs.readFileSync(path.join(repoRoot, "config", "hotel-monitor.example.json"), "utf8"));
config.history = { enabled: false, directory: "data/history" };
config.baidu = { ...config.baidu, enabled: false };
config.flyai = {
  enabled: true,
  requestDelayMs: 0,
  maxRetries: 1
};

fs.writeFileSync(configPath, JSON.stringify(config, null, 2), "utf8");

try {
  execFileSync(
    "powershell",
    [
      "-NoProfile",
      "-ExecutionPolicy",
      "Bypass",
      "-File",
      path.join(repoRoot, "scripts", "run-api-mvp.ps1"),
      "-ConfigPath",
      configPath,
      "-OutputRoot",
      outputRoot,
      "-DryRun"
    ],
    { cwd: repoRoot, stdio: "pipe", encoding: "utf8" }
  );

  const runDir = fs
    .readdirSync(outputRoot, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => path.join(outputRoot, entry.name))
    .sort()
    .at(-1);
  assert.ok(runDir, "DryRun 应生成运行目录");

  const candidates = readJson(path.join(runDir, "candidates.json"));
  const reportInput = readText(path.join(runDir, "report-input.md"));

  assert.match(reportInput, /## FlyAI Usage/, "报告输入应输出 FlyAI 使用情况");
  assert.match(reportInput, /ExternalCallsUsed: 0/, "DryRun 不应消耗 FlyAI 真实调用");
  assert.match(reportInput, /DryRunNote: DryRun does not call FlyAI/, "报告应说明 DryRun 不调用 FlyAI");
  assert.match(reportInput, /PriceStatus/, "候选表应展示 FlyAI 价格状态");

  const firstCandidate = candidates[0];
  assert.equal(firstCandidate.fliggy_source, "dryrun", "DryRun 候选应标记价格来源");
  assert.equal(firstCandidate.fliggy_status, "ok", "DryRun 候选应标记价格状态");
  assert.equal(firstCandidate.fliggy_price_quality, "exact", "DryRun 价格应标记为精确价");
} finally {
  fs.rmSync(tempDir, { recursive: true, force: true });
}
