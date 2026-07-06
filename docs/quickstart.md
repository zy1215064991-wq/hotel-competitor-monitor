# 快速开始

## 1. 下载项目

下载压缩包或克隆仓库到 Windows 电脑。路径不要放在需要管理员权限的系统目录。

## 2. 配置 WorkBuddy Playwright MCP

推荐方式：用 WorkBuddy 打开项目目录，然后对 WorkBuddy 说：

```text
请阅读 workbuddy-start-here.md，并按步骤帮我部署。
```

手动方式：在 PowerShell 中进入项目目录，运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

如果只想重新写入 MCP 配置，也可以运行底层脚本：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-workbuddy-mcp.ps1
```

然后完全退出并重启 WorkBuddy。

## 3. 打开本地向导

双击打开：

```text
app/index.html
```

## 4. 登录携程

在向导第一步复制登录验证提示词，粘贴到 WorkBuddy 普通对话中。WorkBuddy 会用 `playwright-edge` 打开携程。

请用微信或携程 App 扫码登录。不要让自动化输入账号、密码、手机号、短信验证码或滑块。

## 5. 搜索并确认酒店

在向导中输入城市、本店名称、竞对名称。复制候选搜索提示词到 WorkBuddy。WorkBuddy 返回候选表后，粘贴回向导并确认正确酒店。

## 6. 生成文件

在向导中设置默认查询口径，生成并下载：

- `competitors.md`
- `automation-prompt.md`
- `daily-prompt.md`

把这些文件放在你的 WorkBuddy 项目目录里。

## 7. 创建 Automation

在 WorkBuddy 的 Automation 中：

- 名称：酒店竞对每日监控
- 模型：低积分内置模型
- Prompt：粘贴 `automation-prompt.md`
- 定时：每天 07:30
- 推送：按需选择 ClawBot 或企业微信

先点 `Run once` 验证。
