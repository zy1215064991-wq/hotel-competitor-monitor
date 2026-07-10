import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const read = (relativePath) => fs.readFileSync(path.join(repoRoot, relativePath), "utf8");

const readme = read("README.md");
const quickstart = read("docs/quickstart.md");
const dataSources = read("docs/data-sources.md");
const automationSetup = read("docs/automation-setup.md");
const pushSetup = read("docs/push-setup.md");
const troubleshooting = read("docs/troubleshooting.md");
const startHere = read("workbuddy-start-here.md");
const skill = read("skill/SKILL.md");
const appJs = read("app/app.js");
const packageJson = JSON.parse(read("package.json"));

for (const [name, content] of [["README", readme], ["快速开始", quickstart], ["数据源", dataSources]]) {
  assert.match(content, /品牌加权/, `${name} 应把 brandKeywords 解释为加权，不是额外搜索`);
  assert.doesNotMatch(content, /品牌补漏关键词|补漏关键词/, `${name} 不应把品牌加权字段标成补漏关键词`);
}

assert.match(readme, /baidu\.usageDirectory/, "README 应说明百度自然日额度账本目录");
assert.match(readme, /自然日/, "README 应说明百度上限跨运行按自然日累计");
assert.match(dataSources, /--hotel-bed-types/, "数据源文档应说明房型到 FlyAI 床型参数的映射");
assert.match(dataSources, /not-applied-by-flyai-cli/, "数据源文档应说明住客数没有传给当前 FlyAI CLI");
assert.match(dataSources, /酒店身份/, "数据源文档应说明 FlyAI 结果必须通过酒店身份匹配");
assert.match(troubleshooting, /价格带不可精确比较/, "排障文档应说明脱敏价不能做历史精确比较");

assert.match(automationSetup, /推送到 WorkBuddy 小程序/, "Automation 文档应把官方可确认的小程序通知写清楚");
assert.match(automationSetup, /界面.*ClawBot|ClawBot.*界面/, "Automation 文档应说明 ClawBot 入口以实际界面为准");
assert.match(pushSetup, /pushMode/, "推送文档应说明三种推送模式由配置决定");
assert.match(pushSetup, /三选一|只执行对应/, "推送文档应说明推送分支互斥");
assert.match(startHere, /Applied Query Scope/, "WorkBuddy 起步提示应要求检查实际应用查询口径");
assert.match(startHere, /pushMode/, "WorkBuddy 起步提示应按配置选择推送路径");
assert.match(skill, /description: Use when/, "Skill 描述应只陈述触发场景");
assert.match(skill, /Applied Query Scope/, "Skill 应要求核对价格源实际应用口径");
assert.match(skill, /自然日/, "Skill 应说明百度额度跨运行按自然日累计");
assert.match(skill, /pushMode/, "Skill 应按配置选择推送分支");
assert.doesNotMatch(skill, /默认通过微信助理 ClawBot 推送/, "Skill 不应无视 pushMode 强制 ClawBot");

assert.match(appJs, /Applied Query Scope/, "向导生成的日报提示词应包含实际应用查询口径");
assert.match(appJs, /not-applied-by-flyai-cli/, "向导生成的日报提示词应披露住客数未传入价格源");
assert.match(appJs, /不得计算精确差额、涨跌幅或价格比例/, "向导日报提示词应禁止脱敏价精确计算");
assert.equal(packageJson.version, "0.2.0", "本轮可靠性升级应更新包版本");
