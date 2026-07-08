# WorkBuddy Start Here

你是我的 WorkBuddy 配置助手。请按本文件一步步帮我部署“酒店竞对每日监控 FlyAI MVP”，不要一次性假装完成。

## MVP 目标

只跑通这一条链路：

```text
FlyAI/飞猪酒店搜索 -> WorkBuddy 内置模型分析 -> 微信助理 ClawBot 推送
```

## 硬约束

- 全链路只使用国内可访问服务：FlyAI/飞猪、WorkBuddy 内置模型、微信助理 ClawBot，可选企业微信。
- 不使用浏览器自动化作为主流程。
- 不要求用户登录 OTA 网站。
- 不创建或修改 WorkBuddy 的 `models.json`。
- FLYAI_API_KEY 只能从 Windows 环境变量读取，不要写进项目文件、聊天回复、报告或 GitHub。
- 需要用户配置环境变量、WorkBuddy Automation、ClawBot 推送时，停下来让我手动操作。

## 你要执行的步骤

1. 确认当前目录是本项目根目录，应该能看到 `app/`、`config/`、`scripts/`、`templates/`。
2. 检查环境变量：

```powershell
if ($env:FLYAI_API_KEY) { "FLYAI_API_KEY 已配置" } else { "缺少 FLYAI_API_KEY" }
```

3. 如果缺少 FLYAI_API_KEY，停下来让我配置，不要要求我把 Key 发给你或写进文件。
4. 打开 `app/index.html`，让我填写本店、城市、POI、入住口径、竞对数量、品牌补漏。
5. 让我下载或生成 `config/hotel-monitor.json`。
6. 先跑 DryRun：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-flyai-mvp.ps1 -DryRun
```

7. DryRun 成功后，再跑正式采集：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-flyai-mvp.ps1
```

8. 读取 `data/flyai/latest-report-input.md` 和 `templates/daily-prompt.md`。
9. 用 WorkBuddy 内置模型生成红黄绿日报，保存到 `reports/YYYY-MM-DD-hotel-competitor-daily.md`。
10. 默认用微信助理 ClawBot 推送日报全文。
11. 如果 ClawBot 未配置，不要伪造推送成功；贴出日报全文，并指导我在 WorkBuddy GUI 里绑定 ClawBot。
12. 首次手动跑通后，再指导我创建 Automation，每天 07:30 运行。

## 停止条件

遇到以下情况必须停止并告诉我：

- FLYAI_API_KEY 缺失。
- `flyai` CLI 不存在或命令运行失败。
- WorkBuddy Automation 或 ClawBot 只能在桌面端 GUI 配置。
- 任意一步需要境外服务或 VPN。
