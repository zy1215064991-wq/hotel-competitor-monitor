import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "hotel-monitor-failure-propagation-"));
const outputRoot = path.join(tempDir, "api-combo");
const setupReportPath = path.join(tempDir, "setup-check.md");
const runReportPath = path.join(tempDir, "run-once.md");
const missingConfigPath = path.join(tempDir, "missing-config.json");
const latestInputPath = path.join(outputRoot, "api-combo-latest-report-input.md");

fs.mkdirSync(outputRoot, { recursive: true });
fs.writeFileSync(
  setupReportPath,
  [
    "# Setup",
    "",
    "- ReadyForDryRun: True",
    "- ReadyForFormalRun: False",
    "- BlockingIssues: none",
    "- Warnings: none"
  ].join("\n"),
  "utf8"
);
fs.writeFileSync(latestInputPath, "# stale report input\n\n- RunId: stale-run\n- DryRun: True\n", "utf8");

try {
  const result = spawnSync(
    "powershell",
    [
      "-NoProfile",
      "-ExecutionPolicy",
      "Bypass",
      "-File",
      path.join(repoRoot, "scripts", "run-once.ps1"),
      "-ConfigPath",
      missingConfigPath,
      "-OutputRoot",
      outputRoot,
      "-SetupReportPath",
      setupReportPath,
      "-RunReportPath",
      runReportPath,
      "-SkipSetupCheck"
    ],
    { cwd: repoRoot, encoding: "utf8" }
  );

  const runReport = fs.readFileSync(runReportPath, "utf8").replace(/^\uFEFF/, "");

  assert.notEqual(result.status, 0, "底层采集失败时 run-once 必须返回非零退出码");
  assert.match(runReport, /- Status: failed/, "运行报告必须记录 failed");
  assert.match(runReport, /- LatestReportInput:\s*$/m, "失败报告不能引用旧的 latest 输入");
  assert.doesNotMatch(runReport, /- Status: ok/, "失败报告不能写成 ok");
} finally {
  fs.rmSync(tempDir, { recursive: true, force: true });
}
