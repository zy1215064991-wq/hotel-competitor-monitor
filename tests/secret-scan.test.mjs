import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const scriptPath = path.join(repoRoot, "scripts", "scan-secrets.ps1");
const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "hotel-monitor-secret-scan-"));

function runScan(env = {}) {
  return spawnSync(
    "powershell",
    ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", scriptPath, "-RootPath", tempDir],
    { cwd: repoRoot, encoding: "utf8", env: { ...process.env, ...env } }
  );
}

try {
  fs.writeFileSync(
    path.join(tempDir, "safe.env.example"),
    'setx FLYAI_API_KEY "replace-with-your-key"\nhttps://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=xxxxxxxx\n',
    "utf8"
  );
  const safe = runScan();
  assert.equal(safe.status, 0, `占位符不应触发扫描：${safe.stdout}${safe.stderr}`);

  const skSecret = ["sk", "testSecretValue123456"].join("-");
  fs.writeFileSync(path.join(tempDir, "leaked-token.txt"), `token=${skSecret}\n`, "utf8");
  const tokenResult = runScan();
  assert.notEqual(tokenResult.status, 0, "sk 形态令牌应触发扫描失败");
  assert.match(tokenResult.stdout, /leaked-token\.txt:1.*sk-token/, "扫描应报告文件、行号和类型");
  assert.doesNotMatch(tokenResult.stdout + tokenResult.stderr, new RegExp(skSecret), "扫描输出不能回显令牌");
  fs.rmSync(path.join(tempDir, "leaked-token.txt"));

  const webhookKey = "12345678-1234-1234-1234-123456789abc";
  fs.writeFileSync(
    path.join(tempDir, "leaked-webhook.md"),
    `https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=${webhookKey}\n`,
    "utf8"
  );
  const webhookResult = runScan();
  assert.notEqual(webhookResult.status, 0, "真实企业微信 webhook 应触发扫描失败");
  assert.match(webhookResult.stdout, /leaked-webhook\.md:1.*wecom-webhook/, "扫描应标记 webhook 类型");
  assert.doesNotMatch(webhookResult.stdout + webhookResult.stderr, new RegExp(webhookKey), "扫描输出不能回显 webhook key");
  fs.rmSync(path.join(tempDir, "leaked-webhook.md"));

  const envSecret = "flyai-test-secret-value-12345";
  fs.writeFileSync(path.join(tempDir, "leaked-env.txt"), `value=${envSecret}\n`, "utf8");
  const envResult = runScan({ FLYAI_API_KEY: envSecret });
  assert.notEqual(envResult.status, 0, "当前环境变量的真实值出现在文件中时应触发扫描失败");
  assert.match(envResult.stdout, /leaked-env\.txt:1.*FLYAI_API_KEY/, "扫描应标记命中的环境变量名");
  assert.doesNotMatch(envResult.stdout + envResult.stderr, new RegExp(envSecret), "扫描输出不能回显环境变量值");
} finally {
  fs.rmSync(tempDir, { recursive: true, force: true });
}
