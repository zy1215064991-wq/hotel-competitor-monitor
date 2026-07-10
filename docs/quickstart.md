# 快速开始

给 WorkBuddy 的一句话：

```text
请阅读 workbuddy-start-here.md，并按步骤帮我部署酒店竞对每日监控 API 组合版。
```

## 1. 准备三个 Key

本项目 API 组合版支持三个国内数据源：

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

常规完整模式建议把 Key 设置到 Windows 用户环境变量，不要写进项目文件：

```powershell
setx AMAP_API_KEY "替换成你的高德 Key"
setx FLYAI_API_KEY "替换成你的 FlyAI Key"
setx BAIDU_MAP_AK "替换成你的百度 AK"
```

设置后重新打开 WorkBuddy 或 PowerShell。如果今天百度额度紧张，可以先在本地向导里点“百度省额度模式”，它会关闭百度真实调用，并把 `baidu.enrichTopN` 和 `baidu.dailyCallLimit` 设为 `0`。此时正式运行 readiness 不会要求 `BAIDU_MAP_AK`。

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

优先看报告顶部：

- `ReadyForDryRun`：是否可以安全跑 DryRun。
- `ReadyForFormalRun`：是否具备正式运行条件。
- `BlockingIssues`：还差什么。

如果报告里 `config shape` 是 `warning`，可以用示例配置补齐缺失字段：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -RepairConfigFromExample
```

这个命令会先备份旧配置，再补齐缺少的 `baidu`、`flyai`、`tierRules`、`history` 等字段。已有的城市、本店名称、入住口径不会被覆盖。

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
- 候选池上限：先从高德拉多少附近酒店。
- 需要监控的竞对数量：最终进入日报和历史对比的竞对数量。
- 品牌加权关键词：只提高匹配品牌的候选评分，不额外发起品牌补漏搜索。
- 最高价格和排序：用于从候选池收口最终竞对；默认“可比性优先”，价格缺失或脱敏时不会被直接删掉。
- 百度口碑补充数量。
- 百度缓存、缓存天数和每日调用上限。
- 百度省额度模式：额度紧张时一键关闭百度真实调用，先验证高德、FlyAI、日报和推送主链路。
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

更推荐新手使用安全单次运行入口：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-once.ps1
```

它默认只跑 DryRun，并会在正式采集前检查 readiness。只有明确加 `-Formal` 才会尝试正式采集。

每日 Automation 正式采集也使用同一个安全入口：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-once.ps1 -Formal
```

也可以跑完整本地验收：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-local.ps1
```

它会执行零额度体检、DryRun、本地测试和敏感信息扫描，不跑正式采集。报告会写到：

```text
data/verify-local-latest.md
```

报告顶部同样会给出 `ReadyForDryRun`、`ReadyForFormalRun` 和 `BlockingIssues`。

## 6. 正式运行

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-once.ps1 -Formal
```

脚本会生成：

```text
data/api-combo/api-combo-latest-report-input.md
data/history/YYYY-MM-DD.json
```

如果命令停止，先读取：

```text
data/run-once-latest.md
data/setup-check-latest.md
```

按 `BlockingIssues` 处理缺失项。不要在正式采集时跳过 `run-once.ps1` 的 readiness 检查。

第一次正式运行时没有上一份同口径历史，日报只会做今日横截面。第二天开始，脚本会自动读取上一份同口径快照，输出涨价、降价、持平。

正式报告里的 `Applied Query Scope` 会区分用户配置与价格源实际参数：入住/离店日期会传给 FlyAI；大床类映射为 `--hotel-bed-types king`，双床类映射为 `twin`；房间数、成人数和儿童数当前会标记为 `not-applied-by-flyai-cli`，不能声称价格已按人数筛选。

## 7. WorkBuddy 分析和推送

让 WorkBuddy 读取：

- `data/api-combo/api-combo-latest-report-input.md`
- `templates/daily-prompt.md`

生成日报后保存到 `reports/`，再按 `config/hotel-monitor.json` 的 `pushMode` 只执行一种路径：`clawbot`、`wecom` 或 `none`。WorkBuddy Automation 官方可确认的通知开关是“推送到 WorkBuddy 小程序”；如果桌面端实际界面提供 ClawBot 入口，可以选择并以微信实收验证。

每天 07:30 的 WorkBuddy Automation 设置见：

```text
docs/automation-setup.md
```

详细推送配置见 `docs/push-setup.md`。
