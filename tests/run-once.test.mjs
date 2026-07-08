import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "hotel-monitor-run-once-"));
const configPath = path.join(tempDir, "hotel-monitor.json");
const oldConfigPath = path.join(tempDir, "old-hotel-monitor.json");
const outputRoot = path.join(tempDir, "api-combo");
const setupReportPath = path.join(tempDir, "setup-check.md");
const runReportPath = path.join(tempDir, "run-once.md");
const blockedReportPath = path.join(tempDir, "run-once-blocked.md");
const readText = (filePath) => fs.readFileSync(filePath, "utf8").replace(/^\uFEFF/, "");

fs.copyFileSync(path.join(repoRoot, "config", "hotel-monitor.example.json"), configPath);
fs.writeFileSync(
  oldConfigPath,
  JSON.stringify(
    {
      city: "上海",
      homeHotelName: "测试酒店",
      poiName: "测试商圈",
      query: { offsetDays: 7, nights: 1, rooms: 1, adults: 1, children: 0, roomType: "大床房" },
      discovery: { competitorCount: 3, radiusMeters: 1500, maxCandidates: 10, brandKeywords: [], maxPrice: 500, sort: "distance_asc", excludeNameKeywords: [] }
    },
    null,
    2
  ),
  "utf8"
);

try {
  const output = execFileSync(
    "powershell",
    [
      "-NoProfile",
      "-ExecutionPolicy",
      "Bypass",
      "-File",
      path.join(repoRoot, "scripts", "run-once.ps1"),
      "-ConfigPath",
      configPath,
      "-OutputRoot",
      outputRoot,
      "-SetupReportPath",
      setupReportPath,
      "-RunReportPath",
      runReportPath
    ],
    { cwd: repoRoot, stdio: "pipe", encoding: "utf8" }
  );

  const setupReport = readText(setupReportPath);
  const runReport = readText(runReportPath);
  const latestInput = path.join(outputRoot, "api-combo-latest-report-input.md");

  assert.match(output, /DryRun completed/, "run-once 默认应只跑 DryRun");
  assert.match(setupReport, /ReadyForDryRun: True/, "run-once 应先跑 readiness 体检");
  assert.match(runReport, /Mode: DryRun/, "run-once 报告应标记 DryRun 模式");
  assert.match(runReport, /FormalCollection: false/, "run-once 默认不能正式采集");
  assert.match(runReport, /NetworkCallsToAmapFlyAIBaidu: 0/, "run-once DryRun 应标记三源正式调用为 0");
  assert.match(runReport, /ReadyForDryRun: True/, "run-once 报告应带 readiness");
  assert.match(runReport, /Status: ok/, "run-once DryRun 应成功");
  assert.ok(fs.existsSync(latestInput), "run-once DryRun 应生成最新报告输入");
  assert.match(readText(latestInput), /DryRun: True/, "run-once 生成的报告输入应来自 DryRun");
  assert.doesNotMatch(runReport, /sk-[A-Za-z0-9]{10,}/, "run-once 报告不能包含 sk 形态密钥");

  assert.throws(
    () =>
      execFileSync(
        "powershell",
        [
          "-NoProfile",
          "-ExecutionPolicy",
          "Bypass",
          "-File",
          path.join(repoRoot, "scripts", "run-once.ps1"),
          "-ConfigPath",
          oldConfigPath,
          "-OutputRoot",
          path.join(tempDir, "blocked-output"),
          "-SetupReportPath",
          path.join(tempDir, "blocked-setup.md"),
          "-RunReportPath",
          blockedReportPath
        ],
        { cwd: repoRoot, stdio: "pipe", encoding: "utf8" }
      ),
    /ReadyForDryRun is False/,
    "旧配置缺字段时 run-once 应停止"
  );

  const blockedReport = readText(blockedReportPath);
  assert.match(blockedReport, /Status: blocked/, "旧配置被拦截时应写 blocked 报告");
  assert.match(blockedReport, /ReadyForDryRun: False/, "blocked 报告应说明 DryRun readiness false");
} finally {
  fs.rmSync(tempDir, { recursive: true, force: true });
}
