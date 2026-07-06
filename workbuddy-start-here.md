# WorkBuddy Start Here

你是我的 WorkBuddy 配置助手。请按本文件一步步帮我部署“酒店竞对每日监控”，不要一次性假装完成。

## 硬约束

- 全链路只使用国内可访问服务：WorkBuddy、携程国内站、本机 Chrome 或 Edge 浏览器。
- 使用 WorkBuddy 内置模型，不配置第三方模型接口密钥，不创建或修改 `models.json`。
- 携程页面必须用 `playwright-browser` 真实浏览器 MCP，不要使用 fetch、WebFetch、curl、requests 或任何纯 HTTP 抓取。
- 不绕过登录墙、验证码、滑块、短信验证或风控页面。
- 需要用户扫码登录、WorkBuddy GUI Trust、定时任务、ClawBot 推送配置时，停下来让我手动操作。

## 你要执行的步骤

1. 确认当前目录是本项目根目录，应该能看到 `install.ps1`、`app/`、`scripts/`、`docs/`、`templates/`。
2. 运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

3. 把脚本输出的验证结果贴给我。
4. 提醒我完全重启 WorkBuddy。
5. 如果 WorkBuddy 提示 MCP 连接器需要 Trust/启用，停下来让我在 GUI 里确认。
6. 打开 `app/index.html`，让我从第 1 步开始配置。
7. 复制前端里的“登录验证提示词”，用 `playwright-browser` 打开携程，然后停止自动操作，让我用微信或携程 App 扫码登录。
8. 我说“已登录”后，打开一页携程酒店详情页，确认价格是否可见。
9. 让我填写城市、本店酒店名、竞对数量和每家竞对酒店名。不要让我手填携程页面链接。
10. 使用前端生成的候选搜索提示词，通过真实浏览器在携程搜索候选酒店，输出候选 Markdown 表格。
11. 等我确认本店和用户指定数量的竞对后，生成：
    - `competitors.md`
    - `automation-prompt.md`
    - `daily-prompt.md`
12. 让我复制“单次运行验证提示词”，在 WorkBuddy 里手动跑一次。
13. 如果首次运行抓到价格、房型、点评并生成日报，再指导我设置 Automation 每天 07:30 和 ClawBot/企业微信推送。

## 安装后手动验证

如果我想自己检查，请让我运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-workbuddy.ps1
```

通过标准：

- `.workbuddy\.mcp.json` 或 `.workbuddy\mcp.json` 是合法 JSON。
- 文件没有 UTF-8 BOM。
- 存在 `playwright-browser` 浏览器连接器。
- 项目根目录下存在 `ctrip-profile` 登录态目录。

## 停止条件

遇到以下情况必须停止并告诉我，不要替我绕过：

- 携程要求扫码登录。
- 携程出现验证码、滑块、短信验证或风控。
- WorkBuddy 需要在 GUI 里 Trust/启用 MCP。
- Automation 定时或 ClawBot 推送只能在桌面端 GUI 配置。
- 任意一步需要境外服务或 VPN。
