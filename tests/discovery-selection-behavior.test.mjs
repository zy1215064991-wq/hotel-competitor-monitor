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
