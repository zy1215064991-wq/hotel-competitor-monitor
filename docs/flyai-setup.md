# 数据源 Key 与 FlyAI CLI 设置

这个文件保留 `flyai-setup.md` 文件名，方便旧链接继续可用。当前 MVP 实际需要三类国内数据源：

- `AMAP_API_KEY`：高德地图，本店定位和周边酒店候选池。
- `FLYAI_API_KEY`：FlyAI/飞猪，酒店价格。
- `BAIDU_MAP_AK`：百度地图，评论数和细分评分补充。

所有 Key 都只允许保存在 Windows 环境变量中，不要写进项目文件、Markdown、日报、聊天回复或 GitHub。

## 1. 获取 Key

FlyAI Key 获取地址：

```text
https://flyai.open.fliggy.com/#ability
```

高德和百度 Key 请在各自开放平台创建 Web 服务类型应用。创建后只把 Key 写入 Windows 环境变量。

## 2. 配置环境变量

在 Windows PowerShell 中运行：

```powershell
setx AMAP_API_KEY "替换成你的高德 Key"
setx FLYAI_API_KEY "替换成你的 FlyAI Key"
setx BAIDU_MAP_AK "替换成你的百度 AK"
```

设置后重新打开 WorkBuddy 或 PowerShell。

检查是否已配置：

```powershell
if ($env:AMAP_API_KEY) { "AMAP_API_KEY 已配置" } else { "缺少 AMAP_API_KEY" }
if ($env:FLYAI_API_KEY) { "FLYAI_API_KEY 已配置" } else { "缺少 FLYAI_API_KEY" }
if ($env:BAIDU_MAP_AK) { "BAIDU_MAP_AK 已配置" } else { "缺少 BAIDU_MAP_AK" }
```

不要用 `echo $env:...` 打印 Key 明文。

## 3. FlyAI CLI

本项目默认通过 `flyai search-hotel` 获取飞猪生态价格。正式运行前请确认命令可用：

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

## 4. 运行脚本

先 DryRun：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-api-mvp.ps1 -DryRun
```

再正式运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-api-mvp.ps1
```

输出会保存在：

```text
data/api-combo/
```

## 5. Windows CLI 退出码提示

当前 Windows + Node 某些版本下，FlyAI CLI 可能已经输出 `status:0` 的成功 JSON，但退出时又打印 Node 断言错误。组合脚本兼容这种情况：只要成功 JSON 存在，就保留结果并在原始输出里标记 warning。
