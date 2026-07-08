import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "hotel-monitor-tier-rules-"));
const configPath = path.join(tempDir, "hotel-monitor.json");
const outputRoot = path.join(tempDir, "api-combo");
const readJson = (filePath) => JSON.parse(fs.readFileSync(filePath, "utf8").replace(/^\uFEFF/, ""));

const config = JSON.parse(fs.readFileSync(path.join(repoRoot, "config", "hotel-monitor.example.json"), "utf8"));
config.history = { enabled: false, directory: "data/history" };
config.tierRules = {
  coreRadiusMeters: 500,
  extendedRadiusMeters: 900,
  pricePressureRatio: 0.5,
  qualityRatingThreshold: 5.0,
  qualityRadiusMeters: 500,
  includeAlternativeLodging: false
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
  const byName = new Map(candidates.map((candidate) => [candidate.hotel_name, candidate]));

  assert.equal(byName.get("全季上海江桥万达广场酒店")?.comp_tier, "延展竞品", "可配置规则应让 1200m 高评分酒店不再被默认品质规则吸入");
  assert.equal(byName.get("汉庭上海国家会展中心金运路酒店")?.comp_tier, "延展竞品", "可配置规则应让 650m 酒店落入延展竞品");
  assert.equal(byName.get("上海福家甄选主题公寓（江桥万达店）")?.comp_tier, "剔除", "关闭替代住宿后应剔除公寓/民宿候选");
} finally {
  fs.rmSync(tempDir, { recursive: true, force: true });
}
