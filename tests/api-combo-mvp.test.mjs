import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const read = (relativePath) => fs.readFileSync(path.join(repoRoot, relativePath), "utf8");
const exists = (relativePath) => fs.existsSync(path.join(repoRoot, relativePath));

const envExample = read(".env.example");
const gitignore = read(".gitignore");
const configExample = read("config/hotel-monitor.example.json");
const runScript = read("scripts/run-api-mvp.ps1");
const automationTemplate = read("templates/automation-prompt.template.md");
const dailyPrompt = read("templates/daily-prompt.md");
const readme = read("README.md");
const dataSources = read("docs/data-sources.md");
const flyaiSetup = read("docs/flyai-setup.md");
const appHtml = read("app/index.html");
const appJs = read("app/app.js");

assert.match(gitignore, /^data\/$/m, "API 原始数据目录必须被忽略");
assert.match(gitignore, /^config\/hotel-monitor\.json$/m, "本地私有配置必须被忽略");

assert.match(envExample, /^FLYAI_API_KEY=replace_with_your_flyai_key$/m, "env 示例应包含 FlyAI Key 占位符");
assert.match(envExample, /^AMAP_API_KEY=replace_with_your_amap_key$/m, "env 示例应包含高德 Key 占位符");
assert.match(envExample, /^BAIDU_MAP_AK=replace_with_your_baidu_ak$/m, "env 示例应包含百度 AK 占位符");
assert.doesNotMatch(envExample, /\b(sk-[A-Za-z0-9]{10,}|[A-Za-z0-9_-]{32,})\b/, "env 示例不能包含真实 Key");

const config = JSON.parse(configExample);
assert.equal(config.dataSources.primaryMap, "amap", "高德应是主地图源");
assert.equal(config.dataSources.price, "flyai", "FlyAI 应是价格源");
assert.equal(config.dataSources.reputation, "baidu", "百度应是口碑补充源");
assert.ok(config.discovery.radiusMeters >= 1000, "配置应包含半径");
assert.ok(config.discovery.maxCandidates >= 10, "配置应包含候选池上限");
assert.ok(config.baidu.enrichTopN >= 1, "配置应包含百度补充数量");
assert.ok(Array.isArray(config.discovery.excludeNameKeywords), "配置应包含剔除关键词");

assert.ok(exists("scripts/run-api-mvp.ps1"), "应该提供三源组合运行脚本");
assert.match(runScript, /AMAP_API_KEY/, "组合脚本必须从环境变量读取高德 Key");
assert.match(runScript, /BAIDU_MAP_AK/, "组合脚本必须从环境变量读取百度 AK");
assert.match(runScript, /FLYAI_API_KEY/, "组合脚本必须从环境变量读取 FlyAI Key");
assert.match(runScript, /v5\/place\/text/, "组合脚本应调用高德文本检索");
assert.match(runScript, /v5\/place\/around/, "组合脚本应调用高德周边检索");
assert.match(runScript, /place\/v2\/search/, "组合脚本应调用百度地点检索");
assert.match(runScript, /place\/v2\/detail/, "组合脚本应调用百度地点详情");
assert.match(runScript, /search-hotel/, "组合脚本应调用 FlyAI 酒店搜索");
assert.match(runScript, /comp_tier/, "组合脚本应输出竞品分层字段");
assert.match(runScript, /api-combo-latest-report-input\.md/, "组合脚本应生成最新组合数据输入");
assert.doesNotMatch(runScript, /\b(sk-[A-Za-z0-9]{10,}|[A-Za-z0-9_-]{40,})\b/, "组合脚本不能包含真实 Key");

assert.match(automationTemplate, /run-api-mvp\.ps1/, "自动化模板应运行组合脚本");
assert.match(automationTemplate, /高德/, "自动化模板应说明高德角色");
assert.match(automationTemplate, /百度/, "自动化模板应说明百度角色");
assert.match(automationTemplate, /FlyAI\/飞猪/, "自动化模板应说明 FlyAI 角色");

assert.match(dailyPrompt, /高德/, "日报提示词应分析高德数据");
assert.match(dailyPrompt, /百度/, "日报提示词应分析百度口碑");
assert.match(dailyPrompt, /品质压力/, "日报提示词应输出品质压力");
assert.match(dailyPrompt, /评论数/, "日报提示词应关注评论数");

assert.match(readme, /高德/, "README 应说明高德主地图源");
assert.match(readme, /百度/, "README 应说明百度口碑补充");
assert.match(dataSources, /高德作为主地图源/, "数据源文档应说明高德主地图源");
assert.match(dataSources, /百度作为口碑补充源/, "数据源文档应说明百度口碑补充");
assert.match(flyaiSetup, /AMAP_API_KEY/, "设置文档应说明高德环境变量");
assert.match(flyaiSetup, /BAIDU_MAP_AK/, "设置文档应说明百度环境变量");

assert.match(appHtml, /id="radiusMeters"/, "向导应收集半径");
assert.match(appHtml, /id="baiduEnrichTopN"/, "向导应收集百度补充数量");
assert.match(appJs, /AMAP_API_KEY/, "向导运行提示应提示高德 Key");
assert.match(appJs, /BAIDU_MAP_AK/, "向导运行提示应提示百度 AK");
