import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const html = fs.readFileSync(path.join(repoRoot, "app", "index.html"), "utf8");
const app = fs.readFileSync(path.join(repoRoot, "app", "app.js"), "utf8");

assert.match(html, /id="competitorCount"/, "酒店识别页应该有竞对数量输入框");
assert.match(html, /id="applyCompetitorCount"/, "酒店识别页应该有应用竞对数量按钮");
assert.match(app, /competitorCount/, "前端状态应该保存用户指定的竞对数量");
assert.match(app, /buildRoles\(/, "角色列表应该由竞对数量动态生成");
assert.doesNotMatch(app, /const roles = \["本店", "竞对1", "竞对2", "竞对3"\]/, "不能写死本店 + 3 家竞对");
assert.match(app, /已确认酒店：\$\{confirmedCount\}\/\$\{roles\.length\}/, "汇总里的确认数量应该跟随动态角色总数");
assert.match(app, /竞对数量/, "搜索提示词应该告诉 WorkBuddy 当前竞对数量");
