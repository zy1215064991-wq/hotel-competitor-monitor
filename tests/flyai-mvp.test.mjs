import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const read = (relativePath) => fs.readFileSync(path.join(repoRoot, relativePath), "utf8");
const exists = (relativePath) => fs.existsSync(path.join(repoRoot, relativePath));

const gitignore = read(".gitignore");
const envExample = read(".env.example");
const configExample = read("config/hotel-monitor.example.json");
const runScript = read("scripts/run-flyai-mvp.ps1");
const automationTemplate = read("templates/automation-prompt.template.md");
const dailyPrompt = read("templates/daily-prompt.md");
const installScript = read("install.ps1");
const appHtml = read("app/index.html");
const appJs = read("app/app.js");
const readme = read("README.md");
const startHere = read("workbuddy-start-here.md");

assert.match(gitignore, /^\.env$/m, ".env 必须被忽略");
assert.match(gitignore, /^data\/$/m, "FlyAI 原始数据目录必须被忽略");
assert.match(gitignore, /^reports\/$/m, "日报输出目录必须被忽略");
assert.match(gitignore, /^config\/hotel-monitor\.json$/m, "本地私有配置必须被忽略");

assert.match(envExample, /^FLYAI_API_KEY=replace_with_your_flyai_key$/m, ".env.example 应该只提供占位符");
assert.doesNotMatch(envExample, /sk-[A-Za-z0-9]/, ".env.example 不能包含真实 key");
assert.doesNotMatch(configExample, /sk-[A-Za-z0-9]/, "配置示例不能包含真实 key");

const exampleConfig = JSON.parse(configExample);
assert.equal(exampleConfig.city, "上海");
assert.ok(exampleConfig.homeHotelName, "配置示例必须包含本店名称");
assert.ok(exampleConfig.poiName, "配置示例必须包含商圈/POI");
assert.ok(exampleConfig.query.offsetDays >= 0, "配置示例必须包含入住偏移");
assert.ok(exampleConfig.discovery.competitorCount >= 1, "配置示例必须包含竞对数量");
assert.ok(Array.isArray(exampleConfig.discovery.brandKeywords), "配置示例必须包含品牌补漏数组");

assert.ok(exists("scripts/run-flyai-mvp.ps1"), "应该提供 FlyAI MVP 运行脚本");
assert.match(runScript, /FLYAI_API_KEY/, "FlyAI 脚本必须从环境变量读取 key");
assert.match(runScript, /Get-Command\s+"flyai"/, "FlyAI 脚本应该检测 flyai CLI");
assert.match(runScript, /search-hotel/, "FlyAI 脚本应该调用酒店搜索");
assert.match(runScript, /report-input\.md/, "FlyAI 脚本应该生成日报输入文件");
assert.match(runScript, /\[switch\]\$DryRun/, "FlyAI 脚本应该支持 DryRun 验证");
assert.doesNotMatch(runScript, /sk-[A-Za-z0-9]/, "FlyAI 脚本不能包含真实 key");

assert.match(installScript, /FlyAI MVP installer/, "安装脚本应该面向 FlyAI MVP");
assert.match(installScript, /FLYAI_API_KEY/, "安装脚本应该检查 FlyAI Key");
assert.doesNotMatch(installScript, /playwright|browser|ctrip/i, "安装脚本不应该再配置浏览器自动化");

assert.match(automationTemplate, /run-flyai-mvp\.ps1/, "自动化模板应该运行 FlyAI MVP 脚本");
assert.match(automationTemplate, /微信助理 ClawBot/, "自动化模板应该默认 ClawBot 推送");
assert.doesNotMatch(automationTemplate, /playwright-browser|携程|登录态|验证码/, "FlyAI MVP 自动化模板不应该依赖浏览器或携程登录");

assert.match(dailyPrompt, /FlyAI\/飞猪/, "日报提示词应该只分析 FlyAI/飞猪数据");
assert.match(dailyPrompt, /核心竞品/, "日报提示词应该输出竞品分层");
assert.match(dailyPrompt, /价格压力/, "日报提示词应该输出价格压力");
assert.doesNotMatch(dailyPrompt, /携程点评|早餐|取消政策/, "MVP 日报提示词不应该要求网页补充字段");

assert.match(appHtml, /id="homeHotelName"/, "向导应该收集本店名称");
assert.match(appHtml, /id="poiName"/, "向导应该收集 POI/商圈");
assert.match(appHtml, /id="brandKeywords"/, "向导应该收集品牌补漏关键词");
assert.match(appJs, /buildConfigJson/, "向导应该生成 hotel-monitor.json");
assert.doesNotMatch(appJs, /playwright-browser|CTRIP_LOGIN_URL|携程登录页/, "向导主流程不应该再生成浏览器登录提示词");

assert.match(readme, /FlyAI\/飞猪/, "README 应该介绍 FlyAI MVP 主流程");
assert.match(readme, /FLYAI_API_KEY/, "README 应该说明环境变量");
assert.match(startHere, /run-flyai-mvp\.ps1/, "WorkBuddy 入口应该运行 FlyAI MVP 脚本");
assert.doesNotMatch(startHere, /Playwright|携程登录|扫码登录/, "WorkBuddy 入口不应该要求浏览器登录");
