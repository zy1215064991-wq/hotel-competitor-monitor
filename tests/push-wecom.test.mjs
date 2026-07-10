import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const scriptPath = path.join(repoRoot, "scripts", "push-wecom.ps1");
const setupDocPath = path.join(repoRoot, "docs", "push-setup.md");
const automationSetupPath = path.join(repoRoot, "docs", "automation-setup.md");
const automationTemplatePath = path.join(repoRoot, "templates", "automation-prompt.template.md");
const appPath = path.join(repoRoot, "app", "index.html");

assert.ok(fs.existsSync(scriptPath), "应该提供企业微信推送脚本");
assert.ok(fs.existsSync(setupDocPath), "应该提供详细推送设置文档");
assert.ok(fs.existsSync(automationSetupPath), "应该提供 WorkBuddy Automation 设置文档");

const script = fs.readFileSync(scriptPath, "utf8");
const setupDoc = fs.readFileSync(setupDocPath, "utf8");
const automationSetup = fs.readFileSync(automationSetupPath, "utf8");
const automationTemplate = fs.readFileSync(automationTemplatePath, "utf8");
const app = fs.readFileSync(appPath, "utf8");

assert.match(script, /HOTEL_MONITOR_WECOM_WEBHOOK/, "推送脚本必须从环境变量读取 webhook");
assert.match(script, /msgtype.*markdown/s, "推送脚本应该发送 markdown 消息");
assert.match(script, /Invoke-RestMethod/, "推送脚本应该用 PowerShell 发起 POST 请求");
assert.match(script, /4096/, "推送脚本应该处理企业微信 markdown 长度限制");
assert.doesNotMatch(script, /qyapi\.weixin\.qq\.com\/cgi-bin\/webhook\/send\?key=[0-9a-z-]+/i, "脚本不能写死 webhook key");

assert.match(setupDoc, /企业微信群机器人/, "文档应该说明企业微信机器人方式");
assert.match(setupDoc, /HOTEL_MONITOR_WECOM_WEBHOOK/, "文档应该说明环境变量");
assert.match(setupDoc, /ClawBot/, "文档应该说明个人微信 ClawBot 方式");
assert.match(setupDoc, /setx/, "文档应该给出 Windows 设置环境变量命令");
assert.match(setupDoc, /测试推送/, "文档应该包含测试推送步骤");
assert.match(setupDoc, /docs\/automation-setup\.md/, "推送文档应该链接 Automation 设置文档");
assert.match(automationSetup, /最终回复|完整任务结果/, "Automation 文档应说明推送最终回复或完整任务结果");
assert.match(automationSetup, /ClawBot 尚未验证/, "Automation 文档应区分任务完成与 ClawBot 实际送达");
assert.match(automationSetup, /不能伪造成功|不要把没有推送成功/, "Automation 文档应禁止伪造推送成功");

assert.match(automationTemplate, /pushMode/, "自动化模板应该读取配置中的推送模式");
assert.match(automationTemplate, /clawbot/, "自动化模板应该说明 ClawBot 分支");
assert.match(automationTemplate, /wecom/, "自动化模板应该说明企业微信分支");
assert.match(automationTemplate, /none/, "自动化模板应该说明只保存本地分支");
assert.match(automationTemplate, /微信端实际收到/, "ClawBot 首次验证应以微信实收为准");
assert.match(automationTemplate, /WorkBuddy 小程序/, "模板应该说明可验证的小程序通知回退路径");
assert.match(automationTemplate, /run-once\.ps1/, "自动化模板应该通过安全入口采集");
assert.match(automationTemplate, /push-wecom\.ps1/, "自动化模板应该调用企业微信推送脚本");
assert.match(app, /推送方式/, "前端向导应该包含推送方式");
