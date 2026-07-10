import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "hotel-monitor-verify-local-"));
const configPath = path.join(tempDir, "hotel-monitor.json");
const reportPath = path.join(tempDir, "verify-local.md");
const failedReportPath = path.join(tempDir, "verify-local-failed.md");
const readText = (filePath) => fs.readFileSync(filePath, "utf8").replace(/^\uFEFF/, "");

fs.copyFileSync(path.join(repoRoot, "config", "hotel-monitor.example.json"), configPath);

try {
  const output = execFileSync(
    "powershell",
    [
      "-NoProfile",
      "-ExecutionPolicy",
      "Bypass",
      "-File",
      path.join(repoRoot, "scripts", "verify-local.ps1"),
      "-ConfigPath",
      configPath,
      "-SkipNodeTests",
      "-ReportPath",
      reportPath
    ],
    { cwd: repoRoot, stdio: "pipe", encoding: "utf8" }
  );

  const report = readText(reportPath);

  assert.match(output, /No formal Amap, FlyAI or Baidu collection was run/, "本地验收脚本应说明不跑正式采集");
  assert.match(report, /ZeroQuotaCheck: true/, "本地验收报告应标记零额度");
  assert.match(report, /NetworkCallsToAmapFlyAIBaidu: 0/, "本地验收报告应标记三源正式调用为 0");
  assert.match(report, /ReadyForDryRun: True/, "本地验收通过时应标记可 DryRun");
  assert.match(report, /ReadyForFormalRun: False/, "跳过 FlyAI CLI 检查时不应标记可正式运行");
  assert.match(report, /BlockingIssues: flyai CLI=skipped/, "本地验收报告应带出正式运行阻塞项");
  assert.match(report, /\| zero-quota setup check \| ok \|/, "本地验收应跑安装体检");
  assert.match(report, /\| api combo dryrun \| ok \|/, "本地验收应跑 DryRun");
  assert.match(report, /\| node tests \| skipped \|/, "跳过 Node 测试时必须明确记录 skipped");
  assert.match(report, /\| secret scan \| ok \|/, "本地验收应跑敏感信息扫描");
  assert.doesNotMatch(report, /sk-[A-Za-z0-9]{10,}/, "本地验收报告不能包含 sk 形态密钥");

  const failed = spawnSync(
    "powershell",
    [
      "-NoProfile",
      "-ExecutionPolicy",
      "Bypass",
      "-File",
      path.join(repoRoot, "scripts", "verify-local.ps1"),
      "-ConfigPath",
      path.join(tempDir, "missing-config.json"),
      "-SkipNodeTests",
      "-SkipSecretScan",
      "-ReportPath",
      failedReportPath
    ],
    { cwd: repoRoot, encoding: "utf8" }
  );
  const failedReport = readText(failedReportPath);
  assert.notEqual(failed.status, 0, "DryRun 子进程失败时本地验收必须返回非零退出码");
  assert.match(failedReport, /\| api combo dryrun \| failed \|/, "验收报告必须记录 DryRun 失败");
} finally {
  fs.rmSync(tempDir, { recursive: true, force: true });
}
