import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "hotel-monitor-verify-local-"));
const reportPath = path.join(tempDir, "verify-local.md");
const readText = (filePath) => fs.readFileSync(filePath, "utf8").replace(/^\uFEFF/, "");

try {
  const output = execFileSync(
    "powershell",
    [
      "-NoProfile",
      "-ExecutionPolicy",
      "Bypass",
      "-File",
      path.join(repoRoot, "scripts", "verify-local.ps1"),
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
  assert.match(report, /\| zero-quota setup check \| ok \|/, "本地验收应跑安装体检");
  assert.match(report, /\| api combo dryrun \| ok \|/, "本地验收应跑 DryRun");
  assert.match(report, /\| node tests \| ok \|/, "跳过 Node 测试时步骤仍应通过");
  assert.match(report, /\| secret scan \| ok \|/, "本地验收应跑敏感信息扫描");
  assert.doesNotMatch(report, /sk-[A-Za-z0-9]{10,}/, "本地验收报告不能包含 sk 形态密钥");
} finally {
  fs.rmSync(tempDir, { recursive: true, force: true });
}
