# 快速开始

## 1. 准备三个 Key

本项目 API 组合版需要三个国内数据源：

- 高德 Key：用于本店定位和周边酒店候选池。
- FlyAI Key：用于飞猪酒店价格查询。
- 百度 AK：用于评论数和细分评分补充。

FlyAI Key 获取地址：

```text
https://flyai.open.fliggy.com/#ability
```

把 Key 设置到 Windows 用户环境变量，不要写进项目文件：

```powershell
setx AMAP_API_KEY "替换成你的高德 Key"
setx FLYAI_API_KEY "替换成你的 FlyAI Key"
setx BAIDU_MAP_AK "替换成你的百度 AK"
```

设置后重新打开 WorkBuddy 或 PowerShell。

## 2. 打开本地向导

双击打开：

```text
app/index.html
```

填写：

- 城市。
- 本店名称。
- 商圈、地标或 POI。
- 入住日期口径。
- 房型和住客数。
- 高德周边半径。
- 候选池上限。
- 需要监控的竞对数量。
- 百度口碑补充数量。

## 3. 保存配置

从向导下载：

```text
hotel-monitor.json
```

放到：

```text
config/hotel-monitor.json
```

这个文件包含你的本店信息和查询口径，默认不会提交 GitHub。

## 4. DryRun 验证

先不调用真实 API，只验证配置和输出链路：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-api-mvp.ps1 -DryRun
```

看到 `API combo MVP input generated.` 就说明本地配置链路通了。

## 5. 正式运行

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-api-mvp.ps1
```

脚本会生成：

```text
data/api-combo/api-combo-latest-report-input.md
```

## 6. WorkBuddy 分析和推送

让 WorkBuddy 读取：

- `data/api-combo/api-combo-latest-report-input.md`
- `templates/daily-prompt.md`

生成日报后保存到 `reports/`，默认通过微信助理 ClawBot 推送。

详细推送配置见 `docs/push-setup.md`。
