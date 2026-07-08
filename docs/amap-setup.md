# 高德地图 Key 设置

高德是本项目的主地图源，负责本店定位、商圈/POI 搜索、周边酒店候选池和距离字段。它不负责价格，也不负责评论。

## 1. 获取 Key

官方入口：

```text
https://lbs.amap.com/api/webservice/create-project-and-key
```

创建应用时选择 Web 服务类型 Key。正式运行前，请确认 Key 可用于地点文本检索和周边检索。

## 2. 写入环境变量

在 Windows PowerShell 中运行：

```powershell
setx AMAP_API_KEY "替换成你的高德 Key"
```

设置后重新打开 WorkBuddy 或 PowerShell。不要把 Key 写入 `config/hotel-monitor.json`、Markdown、日报或 GitHub。

## 3. 本地自检

只检查是否存在，不打印明文：

```powershell
if ($env:AMAP_API_KEY) { "AMAP_API_KEY 已配置" } else { "缺少 AMAP_API_KEY" }
```

## 4. DryRun 与正式运行

DryRun 不调用高德：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-api-mvp.ps1 -DryRun
```

正式运行会调用高德文本检索和周边检索，并把候选池写入：

```text
data/api-combo/
```

如果高德返回鉴权、配额或权限错误，先检查 Key 类型、Web 服务权限和环境变量是否在新的 WorkBuddy/PowerShell 进程里生效。
