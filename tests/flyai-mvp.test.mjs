import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const read = (relativePath) => fs.readFileSync(path.join(repoRoot, relativePath), "utf8");
const exists = (relativePath) => fs.existsSync(path.join(repoRoot, relativePath));

const gitignore = read(".gitignore");
const envExample = read(".env.example");
const runScript = read("scripts/run-flyai-mvp.ps1");
const readme = read("README.md");
const startHere = read("workbuddy-start-here.md");

assert.match(gitignore, /^\.env$/m, ".env 必须被忽略");
assert.match(gitignore, /^data\/$/m, "原始数据目录必须被忽略");
assert.match(gitignore, /^reports\/$/m, "日报输出目录必须被忽略");
assert.match(gitignore, /^config\/hotel-monitor\.json$/m, "本地私有配置必须被忽略");

assert.match(envExample, /^FLYAI_API_KEY=replace_with_your_flyai_key$/m, ".env.example 应该提供 FlyAI Key 占位符");
assert.match(envExample, /^AMAP_API_KEY=replace_with_your_amap_key$/m, ".env.example 应该提供高德 Key 占位符");
assert.match(envExample, /^BAIDU_MAP_AK=replace_with_your_baidu_ak$/m, ".env.example 应该提供百度 AK 占位符");
assert.doesNotMatch(envExample, /\b(sk-[A-Za-z0-9]{10,}|[A-Za-z0-9_-]{32,})\b/, ".env.example 不能包含真实 key");

assert.ok(exists("scripts/run-flyai-mvp.ps1"), "应该保留 FlyAI-only 备用脚本");
assert.match(runScript, /FLYAI_API_KEY/, "FlyAI 备用脚本必须从环境变量读取 key");
assert.match(runScript, /Get-Command\s+"flyai"/, "FlyAI 备用脚本应该检测 flyai CLI");
assert.match(runScript, /search-hotel/, "FlyAI 备用脚本应该调用酒店搜索");
assert.match(runScript, /\[switch\]\$DryRun/, "FlyAI 备用脚本应该支持 DryRun 验证");
assert.doesNotMatch(runScript, /\b(sk-[A-Za-z0-9]{10,}|[A-Za-z0-9_-]{40,})\b/, "FlyAI 备用脚本不能包含真实 key");

assert.match(readme, /API 组合版/, "README 应以 API 组合版为主流程");
assert.match(startHere, /run-api-mvp\.ps1/, "WorkBuddy 入口应该运行 API 组合脚本");
assert.doesNotMatch(startHere, /Playwright|携程登录|扫码登录/, "WorkBuddy 入口不应该要求浏览器登录");
