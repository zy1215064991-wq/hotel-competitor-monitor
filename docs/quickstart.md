# 快速开始

## 1. 配置 FlyAI Key

如果还没有 Key，请到飞猪 AI 开放平台获取：https://flyai.open.fliggy.com/#ability

在 Windows PowerShell 中运行：

```powershell
setx FLYAI_API_KEY "替换成你的 FlyAI Key"
```

重新打开 WorkBuddy 或 PowerShell。

## 2. 打开本地向导

双击打开：

```text
app/index.html
```

填写城市、本店、商圈/POI、查询口径、竞对数量和品牌补漏关键词。

## 3. 保存配置

从向导下载：

```text
hotel-monitor.json
```

放到：

```text
config/hotel-monitor.json
```

## 4. DryRun 验证

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-flyai-mvp.ps1 -DryRun
```

看到 `FlyAI MVP input generated.` 就说明本地配置链路通了。

## 5. 正式运行

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-flyai-mvp.ps1
```

脚本会生成：

```text
data/flyai/latest-report-input.md
```

## 6. WorkBuddy 分析和推送

让 WorkBuddy 读取：

- `data/flyai/latest-report-input.md`
- `templates/daily-prompt.md`

生成日报后保存到 `reports/`，默认通过微信助理 ClawBot 推送。

详细推送配置见 `docs/push-setup.md`。
