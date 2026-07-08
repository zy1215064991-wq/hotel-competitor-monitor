# FlyAI 设置

## 1. 配置 API Key

FlyAI Key 只允许保存在 Windows 环境变量中，不要写进项目文件。

如果还没有 Key，请到飞猪 AI 开放平台获取：https://flyai.open.fliggy.com/#ability

```powershell
setx FLYAI_API_KEY "替换成你的 FlyAI Key"
```

设置后重新打开 WorkBuddy 或 PowerShell。

检查：

```powershell
if ($env:FLYAI_API_KEY) { "FLYAI_API_KEY 已配置" } else { "缺少 FLYAI_API_KEY" }
```

不要把 Key 打印到群里、报告里或提交到 GitHub。

## 2. FlyAI CLI

本项目默认通过 `flyai search-hotel` 获取酒店候选和飞猪价格。正式运行前请确认命令可用：

```powershell
npm i -g @fly-ai/flyai-cli --registry=https://registry.npmmirror.com
```

```powershell
Get-Command flyai
```

如果命令不存在，请先按 FlyAI 官方说明安装 CLI。

官方项目说明的 CLI 安装方式是：

```powershell
npm i -g @fly-ai/flyai-cli
```

国内环境建议加 `--registry=https://registry.npmmirror.com`。

## 3. 运行脚本

先 DryRun：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-flyai-mvp.ps1 -DryRun
```

再正式运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-flyai-mvp.ps1
```

输出会保存在：

```text
data/flyai/
```

## 4. Windows CLI 退出码提示

当前 Windows + Node 某些版本下，FlyAI CLI 可能已经输出 `status:0` 的成功 JSON，但退出时又打印 Node 断言错误。`scripts/run-flyai-mvp.ps1` 已做兼容：只要成功 JSON 存在，就保留结果并在原始输出里标记 warning。
