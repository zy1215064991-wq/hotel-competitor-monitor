import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "hotel-monitor-discovery-selection-"));
const readText = (filePath) => fs.readFileSync(filePath, "utf8").replace(/^\uFEFF/, "");
const readJson = (filePath) => JSON.parse(readText(filePath));

function runDryRun(config, name) {
  const configPath = path.join(tempDir, `${name}.json`);
  const outputRoot = path.join(tempDir, name);
  fs.writeFileSync(configPath, JSON.stringify(config, null, 2), "utf8");

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
  assert.ok(runDir, `${name} 应生成运行目录`);
  return {
    files: fs.readdirSync(runDir),
    candidates: readJson(path.join(runDir, "candidates.json")),
    reportInput: readText(path.join(outputRoot, "api-combo-latest-report-input.md"))
  };
}

try {
  const baseConfig = JSON.parse(fs.readFileSync(path.join(repoRoot, "config", "hotel-monitor.example.json"), "utf8"));
  baseConfig.history = { enabled: false, directory: "data/history" };

  const ratingConfig = JSON.parse(JSON.stringify(baseConfig));
  ratingConfig.discovery.competitorCount = 2;
  ratingConfig.discovery.maxCandidates = 20;
  ratingConfig.discovery.maxPrice = 600;
  ratingConfig.discovery.sort = "rate_desc";
  const ratingRun = runDryRun(ratingConfig, "rating");

  assert.equal(ratingRun.candidates.length, 2, "最终候选数量应受 competitorCount 控制");
  assert.deepEqual(
    ratingRun.candidates.map((candidate) => candidate.hotel_name),
    ["全季上海江桥万达广场酒店", "汉庭上海国家会展中心金运路酒店"],
    "rate_desc 应按评分优先选择最终竞对"
  );
  assert.match(ratingRun.reportInput, /- ReportedCandidateCount: 2/, "报告输入应记录实际输出竞对数量");

  const balancedConfig = JSON.parse(JSON.stringify(baseConfig));
  balancedConfig.discovery.competitorCount = 2;
  balancedConfig.discovery.maxCandidates = 20;
  balancedConfig.discovery.maxPrice = 600;
  balancedConfig.discovery.sort = "balanced";
  const balancedRun = runDryRun(balancedConfig, "balanced");

  assert.deepEqual(
    balancedRun.candidates.map((candidate) => candidate.hotel_name).sort(),
    ["全季上海江桥万达广场酒店", "汉庭上海国家会展中心金运路酒店"].sort(),
    "balanced 应优先选择标准酒店，不能让最近的替代住宿挤占核心竞品名额"
  );
  assert.ok(
    balancedRun.candidates.every((candidate) => candidate.hotel_type === "标准酒店"),
    "balanced 输出的核心名单应先保留标准酒店"
  );
  assert.ok(
    balancedRun.candidates.every((candidate) => Number(candidate.selection_score) > 0),
    "balanced 应给入围候选写入可解释的 selection_score"
  );
  assert.match(balancedRun.reportInput, /SelectionScore/, "报告输入应输出筛选分数列");
  assert.match(balancedRun.reportInput, /SelectionReason/, "报告输入应输出筛选理由列");
  assert.match(balancedRun.reportInput, /档位差\d+级/, "筛选理由应完整输出档位差级数");
  assert.match(balancedRun.reportInput, /- Sort: balanced/, "报告输入应记录 balanced 筛选策略");
  assert.ok(
    balancedRun.files.includes("flyai-001-DRY_AMAP_1.txt") &&
      balancedRun.files.includes("flyai-002-DRY_AMAP_2.txt") &&
      balancedRun.files.includes("flyai-003-DRY_AMAP_3.txt"),
    "FlyAI 原始输出文件名应包含序号和 AMAP id，避免中文名被统一写成 flyai-candidate.txt 后互相覆盖"
  );

  const maxPriceConfig = JSON.parse(JSON.stringify(baseConfig));
  maxPriceConfig.discovery.competitorCount = 5;
  maxPriceConfig.discovery.maxCandidates = 20;
  maxPriceConfig.discovery.maxPrice = 398;
  maxPriceConfig.discovery.sort = "distance_asc";
  const maxPriceRun = runDryRun(maxPriceConfig, "max-price");

  assert.equal(maxPriceRun.candidates.length, 0, "maxPrice 应过滤掉明确高于上限的候选");
  assert.match(maxPriceRun.reportInput, /- ReportedCandidateCount: 0/, "报告输入应记录过滤后的输出数量");
} finally {
  fs.rmSync(tempDir, { recursive: true, force: true });
}
