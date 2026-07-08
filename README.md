# 酒店竞对每日监控 API 组合版

这是一个面向 Windows + WorkBuddy 的 API 组合版，用来跑通：

```text
高德候选池 -> FlyAI/飞猪价格 -> 百度口碑补充 -> WorkBuddy 内置模型分析 -> 微信助理 ClawBot 推送
```

这版不走 OTA 网页浏览器，不要求登录酒店网站，不抓点评页面。目标是把“地图候选 + 飞猪价格 + 百度口碑 + 历史对比 + 竞品分层 + 日报推送”稳定跑起来。

## 数据边界

- 主地图源：高德地图。
- 价格源：FlyAI/飞猪酒店搜索。
- FlyAI 低频策略：默认每次真实请求间隔 800ms，失败重试 1 次，并在报告中标出价格状态。
- 口碑补充：百度地图。
- 百度省额度策略：默认启用本地缓存 `data/cache/baidu/`，并限制每日真实调用次数。
- 分析模型：WorkBuddy 内置模型。
- 推送：默认微信助理 ClawBot；企业微信群机器人作为备用。
- 历史对比：本地 `data/history/` 保存每日同口径快照，用于判断涨价、降价、持平。
- API Key：只从 Windows 环境变量 `AMAP_API_KEY`、`FLYAI_API_KEY`、`BAIDU_MAP_AK` 读取。
- 私有文件：`.env`、`config/hotel-monitor.json`、`data/`、`reports/` 不提交 GitHub。

## 快速开始

1. 下载或克隆本项目到 Windows 电脑。
2. 配置 API Key 到 Windows 环境变量：

如果还没有 Key：

- FlyAI Key：https://flyai.open.fliggy.com/#ability
- 高德 Key：https://lbs.amap.com/api/webservice/create-project-and-key
- 百度 AK：https://lbsyun.baidu.com/index.php?title=FAQ%2FobtainAK

本地引导页面：

- `app/flyai-guide.html`
- `app/amap-guide.html`
- `app/baidu-guide.html`

```powershell
setx FLYAI_API_KEY "替换成你的 FlyAI Key"
setx AMAP_API_KEY "替换成你的高德 Key"
setx BAIDU_MAP_AK "替换成你的百度 AK"
```

重新打开 WorkBuddy 或 PowerShell，让新环境变量生效。常规完整模式建议三把 Key 都配置好；如果今天百度额度紧张，可以先在向导里点“百度省额度模式”，它会关闭百度真实调用，并把 `baidu.enrichTopN` 和 `baidu.dailyCallLimit` 设为 `0`。此时正式运行 readiness 不会要求 `BAIDU_MAP_AK`。

3. 用 WorkBuddy 打开项目目录，对 WorkBuddy 说：

```text
请阅读 workbuddy-start-here.md，并按步骤帮我部署酒店竞对每日监控 API 组合版。
```

4. 先跑零额度本地体检：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

这一步只检查本地文件、环境变量、配置文件和 FlyAI CLI 是否存在，不调用高德、FlyAI 或百度 API。体检报告会写到：

```text
data/setup-check-latest.md
```

优先看报告顶部的 `ReadyForDryRun`、`ReadyForFormalRun` 和 `BlockingIssues`。

如果体检报告提示 `config shape` 是 `warning`，说明你的本地 `config/hotel-monitor.json` 是旧结构或缺少新字段。可以用示例配置补齐缺失字段：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -RepairConfigFromExample
```

修复会保留已有的本店、城市、入住口径等字段，只补缺失字段，并在原文件旁边生成 `.bak-时间戳` 备份。

5. 打开本地向导：

```text
app/index.html
```

6. 填写本店、城市、商圈/POI、半径、入住口径、竞对数量、品牌补漏关键词、百度补充数量。百度额度紧张时，直接点“百度省额度模式”，先跑高德 + FlyAI + 分析 + 推送主链路。
7. 下载 `hotel-monitor.json`，放到：

```text
config/hotel-monitor.json
```

8. 先跑 DryRun：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-api-mvp.ps1 -DryRun
```

更推荐新手使用安全单次运行入口：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-once.ps1
```

它默认只跑 DryRun，并在正式采集前检查 readiness。只有明确加 `-Formal` 才会尝试正式采集。

每日 Automation 正式采集也使用同一个安全入口：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-once.ps1 -Formal
```

也可以跑完整本地验收：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-local.ps1
```

它会执行零额度体检、DryRun、本地测试和敏感信息扫描，报告写到：

```text
data/verify-local-latest.md
```

同样优先看顶部的 `ReadyForDryRun`、`ReadyForFormalRun` 和 `BlockingIssues`。

9. 正式运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-once.ps1 -Formal
```

脚本会生成：

```text
data/api-combo/api-combo-latest-report-input.md
data/history/YYYY-MM-DD.json
```

如果正式运行被 readiness 拦住，先读：

```text
data/run-once-latest.md
data/setup-check-latest.md
```

根据 `BlockingIssues` 补齐 Key、CLI、配置或推送设置，不要直接绕过 `run-once.ps1` 去跑底层正式采集脚本。

10. WorkBuddy 读取 `templates/daily-prompt.md` 和 `data/api-combo/api-combo-latest-report-input.md`，生成日报并通过 ClawBot 推送。

## 配置文件

示例配置在：

```text
config/hotel-monitor.example.json
```

本地私有配置应保存为：

```text
config/hotel-monitor.json
```

字段包括：

- `city`：城市
- `homeHotelName`：本店名称
- `poiName`：商圈、地标或 POI
- `query.offsetDays`：未来第几天入住
- `query.nights`：入住晚数
- `query.roomType`：目标房型
- `discovery.competitorCount`：最终监控并进入日报/历史的竞对数量
- `discovery.radiusMeters`：高德周边搜索半径
- `discovery.maxCandidates`：高德先拉取的候选池上限，后续会再按价格、排序和竞对数量收口
- `discovery.brandKeywords`：品牌补漏关键词
- `discovery.maxPrice`：最高价格筛选，只过滤明确高于上限的候选；价格缺失或脱敏时保留给日报说明
- `discovery.sort`：FlyAI 查询和最终候选排序方式，支持距离、低价、评分和默认排序
- `baidu.enrichTopN`：百度口碑补充数量
- `baidu.cacheEnabled`：是否启用百度口碑缓存
- `baidu.cacheDirectory`：百度缓存目录，默认 `data/cache/baidu`
- `baidu.cacheTtlDays`：百度缓存有效天数
- `baidu.dailyCallLimit`：百度每日真实 HTTP 调用上限，DryRun 不消耗真实额度
- `flyai.enabled`：是否启用 FlyAI/飞猪价格源
- `flyai.requestDelayMs`：正式运行时 FlyAI 请求间隔，默认 800ms
- `flyai.maxRetries`：FlyAI 失败重试次数
- `tierRules.coreRadiusMeters`：核心竞品半径
- `tierRules.pricePressureRatio`：价格压力阈值，默认低于本店 75% 算价格压力
- `tierRules.qualityRatingThreshold`：品质压力评分阈值
- `tierRules.qualityRadiusMeters`：品质压力可比半径
- `tierRules.includeAlternativeLodging`：是否把公寓、民宿等纳入替代竞品
- `history.enabled`：是否启用历史快照和昨日对比
- `history.directory`：历史快照目录，默认 `data/history`
- `pushMode`：`clawbot`、`wecom` 或 `none`

## 目录说明

```text
app/                         本地配置向导
config/hotel-monitor.example.json  配置示例
scripts/run-api-mvp.ps1      高德 + FlyAI + 百度组合采集脚本
scripts/run-flyai-mvp.ps1    FlyAI-only 备用脚本
scripts/push-wecom.ps1       企业微信群机器人备用推送
scripts/verify-local.ps1     零额度本地验收脚本
scripts/run-once.ps1         安全单次运行入口，默认 DryRun
templates/daily-prompt.md    红黄绿日报提示词
templates/automation-prompt.template.md WorkBuddy Automation 提示词
docs/                        配置、数据源和推送说明
data/                        本地 API 原始数据，已忽略
data/cache/baidu/            本地百度口碑缓存，已忽略
data/history/                本地每日历史快照，已忽略
data/setup-check-latest.md   本地零额度体检报告，已忽略
data/verify-local-latest.md  本地验收报告，已忽略
data/run-once-latest.md      安全单次运行报告，已忽略
reports/                     本地日报，已忽略
```

## 安全边界

- 不把 `AMAP_API_KEY`、`FLYAI_API_KEY`、`BAIDU_MAP_AK` 写进任何项目文件。
- 不把本地配置、原始数据、报告或日志提交到 GitHub。
- 不把 FlyAI 单一渠道价格当作全网最低价。
- 如果价格被脱敏，例如 `¥1xx`，只能当作价格带信号。

## 更多说明

- `docs/flyai-setup.md`：FlyAI Key 和 CLI 配置。
- `docs/amap-setup.md`：高德 Web 服务 Key 配置。
- `docs/baidu-setup.md`：百度 AK、缓存和每日调用上限配置。
- `docs/data-sources.md`：为什么选择高德 + FlyAI/飞猪 + 百度。
- `docs/automation-setup.md`：WorkBuddy 每天 07:30 自动化任务设置。
- `docs/push-setup.md`：ClawBot 和企业微信推送。
