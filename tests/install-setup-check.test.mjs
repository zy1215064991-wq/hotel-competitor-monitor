import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "hotel-monitor-install-check-"));
const configPath = path.join(tempDir, "hotel-monitor.json");
const reportPath = path.join(tempDir, "setup-check.md");
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
      path.join(repoRoot, "install.ps1"),
      "-ConfigPath",
      configPath,
      "-StatusReportPath",
      reportPath,
      "-SkipFlyAICommandCheck"
    ],
    { cwd: repoRoot, stdio: "pipe", encoding: "utf8" }
  );

  const report = readText(reportPath);

  assert.match(output, /No Amap, FlyAI or Baidu HTTP\/API call was made/, "安装体检应明确说明不调用远程 API");
  assert.match(report, /ZeroQuotaCheck: true/, "体检报告应标记零额度检查");
  assert.match(report, /NetworkCalls: 0/, "体检报告应标记网络调用为 0");
  assert.match(report, /does not call Amap, FlyAI or Baidu APIs/, "体检报告应说明不调用三方 API");
  assert.match(report, /\| config shape \| ok \|/, "示例配置应通过结构检查");
  assert.match(report, /\| flyai CLI \| skipped \|/, "测试可跳过 FlyAI CLI 检查");
  assert.match(report, /app\\flyai-guide\.html/, "体检报告应包含 FlyAI 引导页");
  assert.match(report, /app\\amap-guide\.html/, "体检报告应包含高德引导页");
  assert.match(report, /app\\baidu-guide\.html/, "体检报告应包含百度引导页");
  assert.doesNotMatch(report, /sk-[A-Za-z0-9]{10,}/, "体检报告不能包含 sk 形态的真实密钥");
} finally {
  fs.rmSync(tempDir, { recursive: true, force: true });
}
