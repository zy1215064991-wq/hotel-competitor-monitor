import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "hotel-monitor-install-check-"));
const configPath = path.join(tempDir, "hotel-monitor.json");
const noBaiduConfigPath = path.join(tempDir, "hotel-monitor-no-baidu.json");
const oldConfigPath = path.join(tempDir, "old-hotel-monitor.json");
const reportPath = path.join(tempDir, "setup-check.md");
const noBaiduReportPath = path.join(tempDir, "setup-check-no-baidu.md");
const repairReportPath = path.join(tempDir, "setup-check-repair.md");
const readText = (filePath) => fs.readFileSync(filePath, "utf8").replace(/^\uFEFF/, "");
const readJson = (filePath) => JSON.parse(readText(filePath));
const configuredKeyEnv = {
  ...process.env,
  AMAP_API_KEY: ["test", "amap", "key"].join("-"),
  FLYAI_API_KEY: ["test", "flyai", "key"].join("-"),
  BAIDU_MAP_AK: ["test", "baidu", "ak"].join("-")
};
const noBaiduKeyEnv = { ...configuredKeyEnv, BAIDU_MAP_AK: "" };

fs.copyFileSync(path.join(repoRoot, "config", "hotel-monitor.example.json"), configPath);
const noBaiduConfig = JSON.parse(fs.readFileSync(configPath, "utf8"));
noBaiduConfig.baidu.dailyCallLimit = 0;
fs.writeFileSync(noBaiduConfigPath, JSON.stringify(noBaiduConfig, null, 2), "utf8");
fs.writeFileSync(
  oldConfigPath,
  JSON.stringify(
    {
      city: "苏州",
      homeHotelName: "测试本店",
      poiName: "测试商圈",
      query: {
        offsetDays: 3,
        nights: 2,
        rooms: 1,
        adults: 2,
        children: 0,
        roomType: "双床房"
      },
      discovery: {
        competitorCount: 3,
        radiusMeters: 1500,
        maxCandidates: 12,
        brandKeywords: ["全季"],
        maxPrice: 500,
        sort: "distance_asc",
        excludeNameKeywords: []
      },
      pushMode: "none"
    },
    null,
    2
  ),
  "utf8"
);

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
    { cwd: repoRoot, stdio: "pipe", encoding: "utf8", env: configuredKeyEnv }
  );

  const report = readText(reportPath);

  assert.match(output, /No Amap, FlyAI or Baidu HTTP\/API call was made/, "安装体检应明确说明不调用远程 API");
  assert.match(report, /ZeroQuotaCheck: true/, "体检报告应标记零额度检查");
  assert.match(report, /NetworkCalls: 0/, "体检报告应标记网络调用为 0");
  assert.match(report, /ReadyForDryRun: True/, "完整示例配置应可 DryRun");
  assert.match(report, /ReadyForFormalRun: False/, "跳过 FlyAI CLI 检查时不应标记可正式运行");
  assert.match(report, /BlockingIssues: flyai CLI=skipped/, "体检报告应指出正式运行阻塞项");
  assert.match(report, /does not call Amap, FlyAI or Baidu APIs/, "体检报告应说明不调用三方 API");
  assert.match(report, /\| config shape \| ok \|/, "示例配置应通过结构检查");
  assert.match(report, /\| flyai CLI \| skipped \|/, "测试可跳过 FlyAI CLI 检查");
  assert.match(report, /\| BAIDU_MAP_AK requirement \| required \|/, "默认配置应要求百度 AK");
  assert.match(report, /app\\flyai-guide\.html/, "体检报告应包含 FlyAI 引导页");
  assert.match(report, /app\\amap-guide\.html/, "体检报告应包含高德引导页");
  assert.match(report, /app\\baidu-guide\.html/, "体检报告应包含百度引导页");
  assert.doesNotMatch(report, /sk-[A-Za-z0-9]{10,}/, "体检报告不能包含 sk 形态的真实密钥");

  execFileSync(
    "powershell",
    [
      "-NoProfile",
      "-ExecutionPolicy",
      "Bypass",
      "-File",
      path.join(repoRoot, "install.ps1"),
      "-ConfigPath",
      noBaiduConfigPath,
      "-StatusReportPath",
      noBaiduReportPath,
      "-SkipFlyAICommandCheck"
    ],
    { cwd: repoRoot, stdio: "pipe", encoding: "utf8", env: noBaiduKeyEnv }
  );

  const noBaiduReport = readText(noBaiduReportPath);
  assert.match(noBaiduReport, /\| BAIDU_MAP_AK requirement \| optional \|/, "百度每日上限为 0 时百度 AK 应是可选项");
  assert.match(noBaiduReport, /dailyCallLimit=0/, "体检报告应说明百度 AK 可选原因");
  assert.doesNotMatch(noBaiduReport, /BlockingIssues: .*BAIDU_MAP_AK=missing/, "百度每日上限为 0 时不应把 BAIDU_MAP_AK 缺失写入阻塞项");

  execFileSync(
    "powershell",
    [
      "-NoProfile",
      "-ExecutionPolicy",
      "Bypass",
      "-File",
      path.join(repoRoot, "install.ps1"),
      "-ConfigPath",
      oldConfigPath,
      "-StatusReportPath",
      repairReportPath,
      "-SkipFlyAICommandCheck",
      "-RepairConfigFromExample"
    ],
    { cwd: repoRoot, stdio: "pipe", encoding: "utf8", env: configuredKeyEnv }
  );

  const repairedConfig = readJson(oldConfigPath);
  const repairReport = readText(repairReportPath);
  const backups = fs.readdirSync(tempDir).filter((name) => name.startsWith("old-hotel-monitor.json.bak-"));

  assert.equal(repairedConfig.city, "苏州", "修复配置不能覆盖用户城市");
  assert.equal(repairedConfig.homeHotelName, "测试本店", "修复配置不能覆盖本店名称");
  assert.equal(repairedConfig.query.roomType, "双床房", "修复配置不能覆盖查询口径");
  assert.equal(repairedConfig.baidu.cacheDirectory, "data/cache/baidu", "修复配置应补齐百度配置");
  assert.equal(repairedConfig.baidu.usageDirectory, "data/usage", "修复配置应补齐百度每日额度账本目录");
  assert.equal(repairedConfig.flyai.requestDelayMs, 800, "修复配置应补齐 FlyAI 配置");
  assert.equal(repairedConfig.tierRules.pricePressureRatio, 0.75, "修复配置应补齐分层规则");
  assert.equal(repairedConfig.history.directory, "data/history", "修复配置应补齐历史配置");
  assert.equal(backups.length, 1, "修复配置前应备份旧文件");
  assert.match(repairReport, /\| config repair \| repaired \|/, "修复报告应记录 repaired 状态");
  assert.match(repairReport, /\| config shape \| ok \|/, "修复后配置结构应通过检查");
  assert.match(repairReport, /ReadyForDryRun: True/, "修复后配置应可 DryRun");
  assert.match(repairReport, /NetworkCalls: 0/, "修复配置不应调用远程 API");
} finally {
  fs.rmSync(tempDir, { recursive: true, force: true });
}
