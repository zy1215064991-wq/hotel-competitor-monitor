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
$flyResult = [pscustomobject]@{
  data = [pscustomobject]@{
    itemList = @(
      [pscustomobject]@{ name = '上海别家酒店'; price = '¥199' },
      [pscustomobject]@{ name = '桔子水晶上海江桥万达酒店'; price = '¥399' }
    )
  }
}
$mismatchResult = [pscustomobject]@{
  data = [pscustomobject]@{
    itemList = @([pscustomobject]@{ name = '上海别家酒店'; price = '¥199' })
  }
}
$matched = Select-HotelMonitorFlyAIItem -Result $flyResult -ExpectedName '桔子水晶上海江桥万达酒店'
$mismatch = Select-HotelMonitorFlyAIItem -Result $mismatchResult -ExpectedName '桔子水晶上海江桥万达酒店'
[ordered]@{
  king = Get-HotelMonitorBedType -RoomType '豪华大床房'
  twin = Get-HotelMonitorBedType -RoomType '高级双床房'
  unsupported = Get-HotelMonitorBedType -RoomType '家庭房'
  exactPrice = Get-HotelMonitorPriceNumber -Price '¥399'
  maskedPrice = Get-HotelMonitorPriceNumber -Price '¥3xx'
  matchedName = [string]$matched.name
  mismatchIsNull = ($null -eq $mismatch)
  looseBrandMatch = Test-HotelMonitorNameCompatible -ExpectedName '汉庭上海江桥万达酒店' -ActualName '汉庭上海虹桥站酒店'
} | ConvertTo-Json -Compress
`;

const result = spawnSync(
  "powershell",
  ["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", command],
  { cwd: repoRoot, encoding: "utf8" }
);

assert.equal(result.status, 0, `核心查询模块应可加载：${result.stderr || result.stdout}`);
const behavior = JSON.parse(result.stdout.trim().replace(/^\uFEFF/, ""));
assert.equal(behavior.king, "king", "大床房应映射为 FlyAI king");
assert.equal(behavior.twin, "twin", "双床房应映射为 FlyAI twin");
assert.equal(behavior.unsupported, "", "无法识别的房型不应猜床型");
assert.equal(behavior.exactPrice, 399, "精确价格应解析为数值");
assert.equal(behavior.maskedPrice, 0, "脱敏价格不能解析成精确数值");
assert.equal(behavior.matchedName, "桔子水晶上海江桥万达酒店", "应按名称选择正确酒店，而不是第一条");
assert.equal(behavior.mismatchIsNull, true, "没有兼容酒店名时必须返回空");
assert.equal(behavior.looseBrandMatch, false, "只有品牌相同但门店不同不能视为同一家酒店");
