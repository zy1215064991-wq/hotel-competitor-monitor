import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const html = fs.readFileSync(path.join(repoRoot, "app", "index.html"), "utf8");
const app = fs.readFileSync(path.join(repoRoot, "app", "app.js"), "utf8");
const automationTemplate = fs.readFileSync(path.join(repoRoot, "templates", "automation-prompt.template.md"), "utf8");
const pushDoc = fs.readFileSync(path.join(repoRoot, "docs", "push-setup.md"), "utf8");

assert.match(html, /<option value="clawbot" selected>微信助理 ClawBot<\/option>/, "向导应该默认选中微信助理 ClawBot");
assert.match(app, /pushMode:\s*"clawbot"/, "前端状态应该默认使用 ClawBot 推送");
assert.match(app, /微信助理 ClawBot/, "前端生成的提示词应该使用微信助理 ClawBot 命名");
assert.match(app, /最后汇报与推送/, "自动化提示词应该有明确的最后汇报与推送步骤");
assert.match(app, /通过微信助理 ClawBot 推送日报全文/, "最终汇报应该要求通过 ClawBot 推送日报全文");
assert.match(automationTemplate, /最后汇报与推送/, "模板应该同步最后汇报与推送策略");
assert.match(automationTemplate, /通过微信助理 ClawBot 推送日报全文/, "模板应该要求 ClawBot 推送日报全文");
assert.match(pushDoc, /默认推荐：微信助理 ClawBot/, "推送文档应该说明默认推荐 ClawBot");
