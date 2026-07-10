import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "hotel-monitor-query-output-"));
const configPath = path.join(tempDir, "hotel-monitor.json");
const outputRoot = path.join(tempDir, "api-combo");
const readText = (filePath) => fs.readFileSync(filePath, "utf8").replace(/^\uFEFF/, "");

const config = JSON.parse(fs.readFileSync(path.join(repoRoot, "config", "hotel-monitor.example.json"), "utf8"));
config.query = {
  offsetDays: 3,
  nights: 2,
  rooms: 2,
  adults: 2,
  children: 1,
  roomType: "双床房"
};
config.discovery.competitorCount = 7;
config.discovery.maxCandidates = 9;
config.discovery.maxPrice = 450;
config.discovery.sort = "price_asc";
config.history = { enabled: false, directory: "data/history" };

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

  const reportInput = readText(path.join(outputRoot, "api-combo-latest-report-input.md"));
  assert.match(reportInput, /## Query/, "报告输入应包含查询口径章节");
  assert.match(reportInput, /- OffsetDays: 3/, "报告输入应写入入住偏移天数");
  assert.match(reportInput, /- Nights: 2/, "报告输入应写入入住晚数");
  assert.match(reportInput, /- Rooms: 2/, "报告输入应写入房间数");
  assert.match(reportInput, /- Adults: 2/, "报告输入应写入成人数");
  assert.match(reportInput, /- Children: 1/, "报告输入应写入儿童数");
  assert.match(reportInput, /- RoomType: 双床房/, "报告输入应写入房型");
  assert.match(reportInput, /## Applied Query Scope/, "报告输入应区分实际应用的查询口径");
  assert.match(reportInput, /- FlyAIBedType: twin/, "双床房应实际映射到 FlyAI twin");
  assert.match(reportInput, /- RoomTypeStatus: applied-by-flyai-cli/, "已识别床型应标记为已应用");
  assert.match(reportInput, /- Rooms: not-applied-by-flyai-cli/, "房间数不应伪装成 FlyAI 已应用条件");
  assert.match(reportInput, /- Adults: not-applied-by-flyai-cli/, "成人数不应伪装成 FlyAI 已应用条件");
  assert.match(reportInput, /- Children: not-applied-by-flyai-cli/, "儿童数不应伪装成 FlyAI 已应用条件");
  assert.match(reportInput, /- CompetitorCount: 7/, "报告输入应写入竞对数量");
  assert.match(reportInput, /- MaxCandidates: 9/, "报告输入应写入候选池上限");
  assert.match(reportInput, /- MaxPrice: 450/, "报告输入应写入价格筛选");
  assert.match(reportInput, /- Sort: price_asc/, "报告输入应写入排序方式");
  assert.match(reportInput, /- ReportedCandidateCount: 3/, "报告输入应写入实际输出竞对数量");
} finally {
  fs.rmSync(tempDir, { recursive: true, force: true });
}
