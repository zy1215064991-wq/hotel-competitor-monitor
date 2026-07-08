# 贡献说明

这个项目面向 Windows + WorkBuddy 的本地自动化部署包。贡献时请优先保护用户的 API Key、酒店数据和推送地址，并避免在评审或 CI 里触发任何正式采集。

## 本地检查

提交前至少运行：

```powershell
npm test
```

如果你改了 PowerShell 脚本、配置结构、日报输入或安全边界，再运行完整零额度验收：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-local.ps1
```

`verify-local.ps1` 只做安装体检、DryRun、本地测试和敏感信息扫描，不调用高德、FlyAI 或百度正式 API。

## 不要提交的内容

- 不要提交 `config/hotel-monitor.json`。
- 不要提交 `.env`、`.env.*` 或任何包含 Key 的文件。
- 不要提交 `data/`、`reports/`、`output/`、`ctrip-profile/`。
- 不要提交 ClawBot、企业微信 webhook、酒店内部经营数据或原始日报。
- 不要提交任何形如真实 API Key、token、webhook key 的字符串。

这些路径已经写进 `.gitignore`，但提交前仍要自己检查：

```powershell
git status --short
```

## 正式采集边界

PR 验证不要运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-once.ps1 -Formal
```

`-Formal` 只允许用户在自己的 Windows 电脑上、确认环境变量和额度后手动运行。CI 和普通 PR 验证只能跑 `npm test` 或 `verify-local.ps1`。

## 改动同步规则

- 如果改了 `templates/automation-prompt.template.md`，也要同步 `app/app.js` 里的前端下载版 Automation Prompt。
- 如果改了 `templates/daily-prompt.md`，也要同步 `app/app.js` 里的前端下载版 Daily Prompt。
- 如果新增配置字段，要同步 `config/hotel-monitor.example.json`、`app/index.html`、`app/app.js`、README 和相关测试。
- 如果改变数据源、额度策略或推送方式，要同步 `docs/`、`workbuddy-start-here.md` 和 `skill/SKILL.md`。

## 推荐 PR 内容

- 简短说明为什么改。
- 列出改了哪些文件。
- 贴出 `npm test` 或 `verify-local.ps1` 的结果摘要。
- 明确说明没有运行正式采集、没有提交 Key、没有提交本地数据。
