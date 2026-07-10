import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const appJs = fs.readFileSync(path.join(repoRoot, "app", "app.js"), "utf8");
const appHtml = fs.readFileSync(path.join(repoRoot, "app", "index.html"), "utf8");

assert.match(appHtml, /app\.js\?v=0\.2/, "向导脚本应带版本号，避免升级后继续使用旧缓存");

assert.match(appJs, /function validateForm\(/, "向导必须在生成和下载前校验当前表单");
assert.match(appJs, /download\("hotel-monitor\.json",\s*buildConfigJson\(\)/, "配置下载必须现场读取当前表单");
assert.doesNotMatch(appJs, /state\.generated\.config\s*\|\|\s*buildConfigJson/, "下载不能优先使用初始化缓存");
assert.match(appJs, /\.form-grid[\s\S]*addEventListener\("input"/, "表单变化后应自动刷新预览");
assert.match(appJs, /pushMode\s*===\s*"clawbot"/, "自动化提示词必须单独处理 ClawBot");
assert.match(appJs, /pushMode\s*===\s*"wecom"/, "自动化提示词必须单独处理企业微信");
assert.match(appJs, /pushMode\s*===\s*"none"/, "自动化提示词必须单独处理只保存本地");
assert.match(appJs, /usageDirectory:\s*"data\/usage"/, "向导配置应包含百度每日额度账本目录");
assert.doesNotMatch(appHtml, /品牌补漏关键词/, "未实现补充搜索前不能把品牌加权称为补漏");
assert.match(appHtml, /品牌加权关键词/, "品牌字段应准确说明只是筛选加权");
