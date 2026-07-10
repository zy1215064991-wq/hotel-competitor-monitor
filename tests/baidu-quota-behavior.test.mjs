import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "hotel-monitor-baidu-quota-"));
const configPath = path.join(tempDir, "hotel-monitor.json");
const outputRoot = path.join(tempDir, "api-combo");
const readText = (filePath) => fs.readFileSync(filePath, "utf8").replace(/^\uFEFF/, "");
const readJson = (filePath) => JSON.parse(readText(filePath));

const config = JSON.parse(fs.readFileSync(path.join(repoRoot, "config", "hotel-monitor.example.json"), "utf8"));
config.history = { enabled: false, directory: "data/history" };
config.baidu = {
  enabled: true,
  enrichTopN: 10,
  cacheEnabled: false,
  cacheDirectory: "data/cache/baidu",
  cacheTtlDays: 30,
  usageDirectory: path.join(tempDir, "usage"),
  dailyCallLimit: 0
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

  assert.match(reportInput, /## Baidu Usage/, "报告输入应输出百度配额使用情况");
  assert.match(reportInput, /DailyCallLimit: 0/, "报告输入应记录百度每日调用上限");
  assert.match(reportInput, /ApiCallsUsed: 0/, "限额为 0 时不应消耗百度调用");
  assert.match(reportInput, /ApiCallsUsedThisRun: 0/, "报告输入应区分本次调用数");
  assert.match(reportInput, /DailyCallsUsedBefore: 0/, "报告输入应记录运行前当日累计");
  assert.match(reportInput, /DailyCallsUsedTotal: 0/, "报告输入应记录运行后当日累计");
  assert.match(reportInput, /SkippedByLimit: [1-9]/, "限额为 0 时应记录被限额跳过的候选");
  assert.equal(fs.existsSync(config.baidu.usageDirectory), false, "DryRun 不应创建正式百度额度账本");

  const firstCandidate = candidates[0];
  assert.equal(firstCandidate.baidu_source, "skipped-limit", "限额为 0 时候选应标记为被限额跳过");
  assert.equal(firstCandidate.baidu_rating, "", "限额为 0 时不应填充百度评分");
  assert.equal(firstCandidate.baidu_comment_num, "", "限额为 0 时不应填充百度评论数");
} finally {
  fs.rmSync(tempDir, { recursive: true, force: true });
}
