import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const modulePath = path.join(repoRoot, "scripts", "HotelMonitor.Core.psm1").replaceAll("'", "''");
const command = `
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
Import-Module '${modulePath}' -Force -DisableNameChecking
$masked = Compare-HotelMonitorPrice -TodayPrice '¥3xx' -TodayQuality 'masked' -PreviousPrice '¥399' -PreviousQuality 'exact'
$exact = Compare-HotelMonitorPrice -TodayPrice '¥359' -TodayQuality 'exact' -PreviousPrice '¥399' -PreviousQuality 'exact'
[ordered]@{ masked = $masked; exact = $exact } | ConvertTo-Json -Compress -Depth 5
`;
const result = spawnSync(
  "powershell",
  ["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", command],
  { cwd: repoRoot, encoding: "utf8" }
);

assert.equal(result.status, 0, `历史价格比较函数应可运行：${result.stderr || result.stdout}`);
const behavior = JSON.parse(result.stdout.trim().replace(/^\uFEFF/, ""));
assert.equal(behavior.masked.Trend, "价格带不可精确比较");
assert.equal(behavior.masked.Delta, "");
assert.equal(behavior.masked.DeltaPct, "");
assert.equal(behavior.exact.Trend, "降价");
assert.equal(behavior.exact.Delta, -40);
assert.equal(behavior.exact.DeltaPct, "-10%");
