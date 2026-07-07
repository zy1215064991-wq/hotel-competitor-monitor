import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const html = fs.readFileSync(path.join(repoRoot, "app", "index.html"), "utf8");
const app = fs.readFileSync(path.join(repoRoot, "app", "app.js"), "utf8");
const readme = fs.readFileSync(path.join(repoRoot, "README.md"), "utf8");

assert.match(html, /id="competitorDiscoveryMode"/, "酒店识别页应该允许选择手动输入或自动发现竞对");
assert.match(html, /id="discoveryLocation"/, "自动发现应该有位置、商圈或地标输入框");
assert.match(html, /id="discoveryBrandKeywords"/, "自动发现应该有品牌筛选输入框");
assert.match(html, /id="discoveryPriceMin"/, "自动发现应该有最低价格输入框");
assert.match(html, /id="discoveryPriceMax"/, "自动发现应该有最高价格输入框");
assert.match(html, /id="discoveryMaxDistanceKm"/, "自动发现应该有距离范围输入框");

assert.match(app, /competitorDiscoveryMode/, "前端状态应该保存竞对发现模式");
assert.match(app, /buildAutoDiscoveryInstructions/, "应该有单独的自动发现提示词构建逻辑");
assert.match(app, /侧边栏/, "自动发现提示词应该要求使用携程侧边栏");
assert.match(app, /品牌筛选/, "自动发现提示词应该要求使用品牌筛选");
assert.match(app, /价格筛选/, "自动发现提示词应该要求使用价格筛选");
assert.match(app, /排除本店/, "自动发现提示词应该要求排除本店");
assert.match(app, /竞对角色必须使用/, "自动发现提示词应该约束输出角色为竞对1..竞对N");

assert.match(readme, /自动发现竞对/, "README 应该说明自动发现竞对能力");
