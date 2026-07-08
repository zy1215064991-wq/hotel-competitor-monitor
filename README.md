# 酒店竞对每日监控 API 组合版

这是一个面向 Windows + WorkBuddy 的 API 组合版，用来跑通：

```text
高德候选池 -> FlyAI/飞猪价格 -> 百度口碑补充 -> WorkBuddy 内置模型分析 -> 微信助理 ClawBot 推送
```

这版不走 OTA 网页浏览器，不要求登录酒店网站，不抓点评页面。目标是把“地图候选 + 飞猪价格 + 百度口碑 + 历史对比 + 竞品分层 + 日报推送”稳定跑起来。

## 数据边界

- 主地图源：高德地图。
- 价格源：FlyAI/飞猪酒店搜索。
- 口碑补充：百度地图。
- 分析模型：WorkBuddy 内置模型。
- 推送：默认微信助理 ClawBot；企业微信群机器人作为备用。
- 历史对比：本地 `data/history/` 保存每日同口径快照，用于判断涨价、降价、持平。
- API Key：只从 Windows 环境变量 `AMAP_API_KEY`、`FLYAI_API_KEY`、`BAIDU_MAP_AK` 读取。
- 私有文件：`.env`、`config/hotel-monitor.json`、`data/`、`reports/` 不提交 GitHub。

## 快速开始

1. 下载或克隆本项目到 Windows 电脑。
2. 配置 API Key 到 Windows 环境变量：

如果还没有 Key，请到飞猪 AI 开放平台获取：https://flyai.open.fliggy.com/#ability

```powershell
setx FLYAI_API_KEY "替换成你的 FlyAI Key"
setx AMAP_API_KEY "替换成你的高德 Key"
setx BAIDU_MAP_AK "替换成你的百度 AK"
```

重新打开 WorkBuddy 或 PowerShell，让新环境变量生效。

3. 用 WorkBuddy 打开项目目录，对 WorkBuddy 说：

```text
请阅读 workbuddy-start-here.md，并按步骤帮我部署酒店竞对每日监控 API 组合版。
```

4. 打开本地向导：

```text
app/index.html
```

5. 填写本店、城市、商圈/POI、半径、入住口径、竞对数量、品牌补漏关键词、百度补充数量。
6. 下载 `hotel-monitor.json`，放到：

```text
config/hotel-monitor.json
```

7. 先跑 DryRun：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-api-mvp.ps1 -DryRun
```

8. 正式运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-api-mvp.ps1
```

脚本会生成：

```text
data/api-combo/api-combo-latest-report-input.md
data/history/YYYY-MM-DD.json
```

9. WorkBuddy 读取 `templates/daily-prompt.md` 和 `data/api-combo/api-combo-latest-report-input.md`，生成日报并通过 ClawBot 推送。

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
- `discovery.competitorCount`：希望监控的竞对数量
- `discovery.radiusMeters`：高德周边搜索半径
- `discovery.maxCandidates`：候选池上限
- `discovery.brandKeywords`：品牌补漏关键词
- `discovery.maxPrice`：最高价格筛选
- `discovery.sort`：FlyAI 排序方式
- `baidu.enrichTopN`：百度口碑补充数量
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
templates/daily-prompt.md    红黄绿日报提示词
templates/automation-prompt.template.md WorkBuddy Automation 提示词
docs/                        配置、数据源和推送说明
data/                        本地 API 原始数据，已忽略
data/history/                本地每日历史快照，已忽略
reports/                     本地日报，已忽略
```

## 安全边界

- 不把 `AMAP_API_KEY`、`FLYAI_API_KEY`、`BAIDU_MAP_AK` 写进任何项目文件。
- 不把本地配置、原始数据、报告或日志提交到 GitHub。
- 不把 FlyAI 单一渠道价格当作全网最低价。
- 如果价格被脱敏，例如 `¥1xx`，只能当作价格带信号。

## 更多说明

- `docs/flyai-setup.md`：高德、FlyAI、百度 Key 和 CLI 配置。
- `docs/data-sources.md`：为什么选择高德 + FlyAI/飞猪 + 百度。
- `docs/push-setup.md`：ClawBot 和企业微信推送。
