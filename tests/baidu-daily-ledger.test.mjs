import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "hotel-monitor-baidu-ledger-"));
const usagePath = path.join(tempDir, "baidu-2026-07-10.json");
const modulePath = path.join(repoRoot, "scripts", "HotelMonitor.Core.psm1");

function runPowerShell(expression) {
  const escapedModule = modulePath.replaceAll("'", "''");
  const command = `
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
Import-Module '${escapedModule}' -Force -DisableNameChecking
${expression} | ConvertTo-Json -Compress -Depth 5
`;
  const result = spawnSync(
    "powershell",
    ["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", command],
    { cwd: repoRoot, encoding: "utf8" }
  );
  assert.equal(result.status, 0, result.stderr || result.stdout);
  return JSON.parse(result.stdout.trim().replace(/^\uFEFF/, ""));
}

const escapedUsagePath = usagePath.replaceAll("'", "''");

try {
  const first = runPowerShell(`Reserve-HotelMonitorDailyUsage -UsagePath '${escapedUsagePath}' -Limit 2`);
  const second = runPowerShell(`Reserve-HotelMonitorDailyUsage -UsagePath '${escapedUsagePath}' -Limit 2`);
  const third = runPowerShell(`Reserve-HotelMonitorDailyUsage -UsagePath '${escapedUsagePath}' -Limit 2`);

  assert.equal(first.Allowed, true);
  assert.equal(first.CountBefore, 0);
  assert.equal(first.CountAfter, 1);
  assert.equal(second.Allowed, true);
  assert.equal(second.CountBefore, 1);
  assert.equal(second.CountAfter, 2);
  assert.equal(third.Allowed, false, "新的进程也必须看到当日额度已用完");
  assert.equal(third.CountBefore, 2);
  assert.equal(third.CountAfter, 2);

  const beforeRead = fs.statSync(usagePath).mtimeMs;
  const usage = runPowerShell(`Get-HotelMonitorDailyUsage -UsagePath '${escapedUsagePath}'`);
  const afterRead = fs.statSync(usagePath).mtimeMs;
  assert.equal(usage.Count, 2);
  assert.equal(afterRead, beforeRead, "只读额度状态不能修改账本文件");
  assert.equal(JSON.parse(fs.readFileSync(usagePath, "utf8")).count, 2);
} finally {
  fs.rmSync(tempDir, { recursive: true, force: true });
}
