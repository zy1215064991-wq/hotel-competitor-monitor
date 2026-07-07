import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const html = fs.readFileSync(path.join(repoRoot, "app", "index.html"), "utf8");
const app = fs.readFileSync(path.join(repoRoot, "app", "app.js"), "utf8");
const readme = fs.readFileSync(path.join(repoRoot, "README.md"), "utf8");
const firstLogin = fs.readFileSync(path.join(repoRoot, "docs", "first-login.md"), "utf8");
const quickstart = fs.readFileSync(path.join(repoRoot, "docs", "quickstart.md"), "utf8");
const startHere = fs.readFileSync(path.join(repoRoot, "workbuddy-start-here.md"), "utf8");
const installScript = fs.readFileSync(path.join(repoRoot, "install.ps1"), "utf8");
const verifyScript = fs.readFileSync(path.join(repoRoot, "scripts", "verify-workbuddy.ps1"), "utf8");
const setupScript = fs.readFileSync(path.join(repoRoot, "scripts", "setup-workbuddy-mcp.ps1"), "utf8");

assert.match(app, /CTRIP_LOGIN_URL/, "登录页 URL 应该集中定义");
assert.match(app, /https:\/\/passport\.ctrip\.com\/user\/login/, "登录验证应该优先直达携程 Passport 登录页");
assert.match(app, /自行选择登录方式/, "登录提示词应该允许用户自行选择登录方式");
assert.match(app, /不要替我输入账号、密码、手机号、短信验证码/, "WorkBuddy 不能代替用户输入敏感登录信息");
assert.doesNotMatch(app, /打开携程首页 https:\/\/www\.ctrip\.com\/ 或任意携程酒店详情页/, "不应该再让用户从官网首页寻找登录入口");
assert.doesNotMatch(app, /重新扫码登录/, "会话过期提醒不应该限定用户只能扫码");

assert.match(html, /已完成一次携程人工登录/, "前端清单不应该限定扫码登录");
assert.doesNotMatch(html, /已用微信或携程 App 扫码登录携程/, "前端不应该把登录方式限定为扫码");

assert.match(readme, /自行选择登录方式/, "README 应该说明用户可以自行选择登录方式");
assert.match(firstLogin, /直达携程登录页/, "首次登录文档应该说明直达登录页");
assert.match(firstLogin, /自行选择登录方式/, "首次登录文档应该说明登录方式由用户选择");
assert.match(quickstart, /自行选择登录方式/, "快速开始应该说明登录方式由用户选择");
assert.match(startHere, /打开携程登录页/, "WorkBuddy 入口文档应该要求直达登录页");
assert.match(installScript, /自行选择登录方式/, "安装脚本下一步提示不应该限定扫码");
assert.match(verifyScript, /自行选择登录方式/, "验证脚本下一步提示不应该限定扫码");
assert.match(setupScript, /自行选择登录方式/, "MCP 配置脚本完成提示不应该限定扫码");
