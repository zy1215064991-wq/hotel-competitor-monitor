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

本地引导页面：

```text
app/flyai-guide.html
```

高德 Key 获取说明：

```text
https://lbs.amap.com/api/webservice/create-project-and-key
```

本地引导页面：

```text
app/amap-guide.html
```

百度 AK 获取说明：

```text
https://lbsyun.baidu.com/index.php?title=FAQ%2FobtainAK
```

本地引导页面：

```text
app/baidu-guide.html
```

把 Key 设置到 Windows 用户环境变量，不要写进项目文件：

```powershell
setx AMAP_API_KEY "替换成你的高德 Key"
setx FLYAI_API_KEY "替换成你的 FlyAI Key"
setx BAIDU_MAP_AK "替换成你的百度 AK"
```

设置后重新打开 WorkBuddy 或 PowerShell。

## 2. 先跑零额度本地体检

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

这一步只检查：

- 本地必需文件是否存在。
- 三个环境变量是否已配置，但不打印明文。
- `config/hotel-monitor.json` 是否存在、结构是否完整。
- `flyai` CLI 是否存在。
- 输出目录是否就绪。

它不会调用高德、FlyAI 或百度 API，不消耗任何额度。报告会写到：

```text
data/setup-check-latest.md
```

## 3. 打开本地向导

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
- 百度缓存、缓存天数和每日调用上限。
- 核心竞品半径、价格压力比例、品质评分阈值、替代住宿策略。
- 是否启用历史对比。

## 4. 保存配置

从向导下载：

```text
hotel-monitor.json
```

放到：

```text
config/hotel-monitor.json
```

这个文件包含你的本店信息和查询口径，默认不会提交 GitHub。

## 5. DryRun 验证

先不调用真实 API，只验证配置和输出链路：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-api-mvp.ps1 -DryRun
```

看到 `API combo MVP input generated.` 就说明本地配置链路通了。

## 6. 正式运行

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-api-mvp.ps1
```

脚本会生成：

```text
data/api-combo/api-combo-latest-report-input.md
data/history/YYYY-MM-DD.json
```

第一次正式运行时没有上一份同口径历史，日报只会做今日横截面。第二天开始，脚本会自动读取上一份同口径快照，输出涨价、降价、持平。

## 7. WorkBuddy 分析和推送

让 WorkBuddy 读取：

- `data/api-combo/api-combo-latest-report-input.md`
- `templates/daily-prompt.md`

生成日报后保存到 `reports/`，默认通过微信助理 ClawBot 推送。

详细推送配置见 `docs/push-setup.md`。
