# 百度地图 AK 设置

百度是本项目的口碑补充源，负责给入围候选酒店补充评论数、评分、设施、卫生、服务等信号。它不是主候选池，也不负责价格。

## 1. 获取 AK

官方入口：

```text
https://lbsyun.baidu.com/index.php?title=FAQ%2FobtainAK
```

创建服务端可用 AK，并确认地点检索和地点详情接口可用。

## 2. 写入环境变量

在 Windows PowerShell 中运行：

```powershell
setx BAIDU_MAP_AK "替换成你的百度 AK"
```

设置后重新打开 WorkBuddy 或 PowerShell。不要把 AK 写入 `config/hotel-monitor.json`、Markdown、日报或 GitHub。

## 3. 本地自检

只检查是否存在，不打印明文：

```powershell
if ($env:BAIDU_MAP_AK) { "BAIDU_MAP_AK 已配置" } else { "缺少 BAIDU_MAP_AK" }
```

## 4. 省额度配置

百度默认启用缓存，并限制每日真实调用次数：

```json
"baidu": {
  "enabled": true,
  "enrichTopN": 10,
  "cacheEnabled": true,
  "cacheDirectory": "data/cache/baidu",
  "cacheTtlDays": 30,
  "dailyCallLimit": 20
}
```

额度紧张时，把 `dailyCallLimit` 先设为 `0` 或 `5`。设为 `0` 时，脚本会跳过百度真实调用，正式运行 readiness 也不会要求 `BAIDU_MAP_AK`，但高德候选、FlyAI 价格、历史对比和日报输入仍能继续跑。

## 5. 查看本次用量

运行后查看报告输入里的百度用量：

```powershell
Select-String -Path .\data\api-combo\api-combo-latest-report-input.md -Pattern "## Baidu Usage" -Context 0,12
```

重点看：

- `CacheHits`：命中本地缓存，不消耗额度。
- `ApiCallsUsed`：本次真实调用次数。
- `DailyCallLimit`：本地配置的每日上限。
- `SkippedByLimit`：因为上限被跳过的候选。

DryRun 不调用百度，也不消耗额度。
