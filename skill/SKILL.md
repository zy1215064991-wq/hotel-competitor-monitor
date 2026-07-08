---
name: hotel-competitor-monitor
description: 帮助用户配置和运行 Windows WorkBuddy 酒店竞对每日监控 API 组合版，使用高德地图候选池、FlyAI/飞猪价格、百度地图口碑补充、本地历史对比、WorkBuddy 内置模型和微信助理 ClawBot 推送。
---

# 酒店竞对每日监控

当用户要部署、排障或扩展本项目时，使用这份说明。

## 工作流程

1. 确认用户在 Windows 电脑上，并已安装 WorkBuddy。
2. 检查 `AMAP_API_KEY`、`FLYAI_API_KEY`、`BAIDU_MAP_AK` 三个 Windows 环境变量是否存在。
3. 检查 `flyai` CLI 是否可用。
4. 运行 `install.ps1` 做零额度本地体检，读取 `data/setup-check-latest.md`。
5. 如果 `config shape` 是 `warning`，询问用户是否允许运行 `install.ps1 -RepairConfigFromExample` 补齐旧配置字段。
6. 打开 `app/index.html`，引导用户填写本店、城市、POI、入住口径、房型、人数、半径、竞对数量、百度补充数量。
7. 生成或确认 `config/hotel-monitor.json`。
8. 先运行 `scripts/run-api-mvp.ps1 -DryRun`。
9. DryRun 成功后运行 `scripts/run-api-mvp.ps1`。
10. 读取 `data/api-combo/api-combo-latest-report-input.md` 和 `templates/daily-prompt.md`。
11. 检查 `History` 和 `Yesterday Comparison`：有同口径历史时判断涨价、降价、持平；首次运行没有历史时只做今日横截面。
12. 使用 WorkBuddy 内置模型生成红黄绿日报。
13. 保存到 `reports/YYYY-MM-DD-hotel-competitor-daily.md`。
14. 默认通过微信助理 ClawBot 推送；如果 ClawBot 未配置，贴出日报全文并说明未推送。
15. 首次手动跑通后，读取 `docs/automation-setup.md`，再帮助用户创建每天 07:30 的 WorkBuddy 自动化任务。

## 约束

- 使用 WorkBuddy 内置模型，不要求用户提供第三方大模型接口密钥。
- 主流程不使用 OTA 网页浏览器自动化，不要求登录携程、飞猪、美团或去哪儿。
- 高德负责地图和候选池，FlyAI/飞猪负责价格，百度负责口碑补充。
- 本地历史保存在 `data/history/`，只和同查询口径的上一份快照比较。
- 不把 `AMAP_API_KEY`、`FLYAI_API_KEY`、`BAIDU_MAP_AK` 写进任何文件、聊天回复、报告或 GitHub。
- 不提交 `config/hotel-monitor.json`、`data/`、`reports/` 或任何密钥。
- 遇到 API 鉴权、额度、并发或 CLI 错误时停止并说明，不编造数据。
- `install.ps1` 和 DryRun 不应消耗高德、FlyAI 或百度正式调用额度。

## 常用提示词

部署：

```text
请阅读 workbuddy-start-here.md，并按步骤帮我部署酒店竞对每日监控 API 组合版。不要写入任何 Key 明文；缺少环境变量时停下来提醒我配置。
```

自动化：

```text
请阅读 docs/automation-setup.md，指导我在 WorkBuddy GUI 中创建每天 07:30 的酒店竞对每日监控 Automation。使用低成本内置模型，推送优先选微信助理 ClawBot；如果 ClawBot 未配置，不要伪造推送成功。
```

单次运行：

```text
请读取 templates/automation-prompt.template.md，按 API 组合流程立即跑一次酒店竞对每日监控。运行 scripts/run-api-mvp.ps1，读取 data/api-combo/api-combo-latest-report-input.md，再按 templates/daily-prompt.md 生成日报并用微信助理 ClawBot 推送。缺少 Key、CLI、ClawBot 或 API 返回异常时停止并说明，不要伪造结果。
```
