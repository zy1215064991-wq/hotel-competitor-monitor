import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const setup = fs.readFileSync(path.join(repoRoot, "scripts", "setup-workbuddy-mcp.ps1"), "utf8");
const install = fs.readFileSync(path.join(repoRoot, "install.ps1"), "utf8");
const app = fs.readFileSync(path.join(repoRoot, "app", "app.js"), "utf8");
const startHere = fs.readFileSync(path.join(repoRoot, "workbuddy-start-here.md"), "utf8");

assert.match(setup, /\[ValidateSet\("auto", "chrome", "edge"\)\]/, "setup 脚本应该允许选择 auto/chrome/edge");
assert.match(setup, /\$chromeCandidates/, "setup 脚本应该检测 Chrome 安装路径");
assert.match(setup, /Google\\Chrome\\Application\\chrome\.exe/, "setup 脚本应该包含 Chrome 默认路径");
assert.match(setup, /"playwright-browser"/, "MCP server 名称应该是中性的 playwright-browser");
assert.match(setup, /--browser=\$\(\$browserChoice\.BrowserArg\)/, "MCP browser 参数应该使用自动选择结果");
assert.match(setup, /--executable-path=\$\(\$browserChoice\.ExecutablePath\)/, "MCP executable-path 应该使用自动选择结果");
assert.match(setup, /allow = @\("mcp__playwright-browser"\)/, "权限应该允许 playwright-browser");

assert.match(install, /\[ValidateSet\("auto", "chrome", "edge"\)\]/, "install 脚本应该把浏览器选择参数传给 setup");
assert.match(install, /-Browser \$Browser/, "install 脚本应该调用 setup 时传递浏览器选择");

assert.match(app, /playwright-browser/, "前端生成提示词应该使用中性 MCP 名称");
assert.doesNotMatch(app, /playwright-edge/, "前端生成提示词不应该再写死 Edge MCP 名称");
assert.match(startHere, /playwright-browser/, "部署入口说明应该使用中性 MCP 名称");
