---
name: hotel-competitor-monitor
description: Use when deploying, running, troubleshooting, or extending the hotel-competitor-monitor project on Windows with WorkBuddy.
---

# 酒店竞对每日监控

当用户要部署、排障或扩展本项目时，使用这份说明。

## 工作流程

1. 确认用户在 Windows 电脑上，并已安装 WorkBuddy。
2. 检查 `AMAP_API_KEY`、`FLYAI_API_KEY` 是否存在；只有启用百度真实调用且 `baidu.dailyCallLimit` 不为 0 时，才把 `BAIDU_MAP_AK` 当作正式运行必需项。
3. 检查 `flyai` CLI 是否可用；如果 `flyai.enabled=false`，它不是正式运行阻塞项。
4. 运行 `install.ps1` 做零额度本地体检，读取 `data/setup-check-latest.md`。
5. 如果 `config shape` 是 `warning`，询问用户是否允许运行 `install.ps1 -RepairConfigFromExample` 补齐旧配置字段。
6. 打开 `app/index.html`，引导用户填写本店、城市、POI、入住口径、房型、人数、半径、竞对数量、品牌加权、百度补充数量和 `pushMode`。
7. 生成或确认 `config/hotel-monitor.json`。
8. 先运行 `scripts/run-api-mvp.ps1 -DryRun`。
9. 更推荐新手运行 `scripts/run-once.ps1`，它默认只跑 DryRun。
10. 如需完整本地验收，运行 `scripts/verify-local.ps1`。
11. DryRun 成功后运行 `scripts/run-once.ps1 -Formal`。如果 readiness 不通过，读取 `data/run-once-latest.md` 和 `data/setup-check-latest.md`，说明 `BlockingIssues`，不要绕过安全入口。
12. 读取 `data/api-combo/api-combo-latest-report-input.md` 和 `templates/daily-prompt.md`。
13. 检查 `Applied Query Scope`：日期和床型是否实际传给 FlyAI；房间数、成人数、儿童数若为 `not-applied-by-flyai-cli`，必须披露。检查酒店身份状态，`identity-mismatch` 不得采用价格。
14. 检查 `History` 和 `Yesterday Comparison`：有同口径历史时判断涨价、降价、持平；首次运行没有历史时只做今日横截面。脱敏价只能判断价格带，不能算差额、比例或涨跌幅。
15. 检查 `Baidu Usage`：额度按北京时间自然日跨运行累计，DryRun 不写额度账本。
16. 使用 WorkBuddy 内置模型生成红黄绿日报，保存到 `reports/YYYY-MM-DD-hotel-competitor-daily.md`。
17. 按配置的 `pushMode` 只执行一条路径：`clawbot` 以微信实收为准，`wecom` 调用企业微信脚本，`none` 只保存本地。Automation 官方可确认的通知开关是“推送到 WorkBuddy 小程序”。
18. 首次手动跑通后，读取 `docs/automation-setup.md`，再帮助用户创建每天 07:30 的 WorkBuddy 自动化任务。

## 约束

- 使用 WorkBuddy 内置模型，不要求用户提供第三方大模型接口密钥。
- 主流程不使用 OTA 网页浏览器自动化，不要求登录携程、飞猪、美团或去哪儿。
- 高德负责地图和候选池，FlyAI/飞猪负责价格，百度负责口碑补充。
- `discovery.brandKeywords` 只做品牌加权，不额外发起补充搜索。
- 本地历史保存在 `data/history/`，只和同查询口径的上一份快照比较。
- 不把 `AMAP_API_KEY`、`FLYAI_API_KEY`、`BAIDU_MAP_AK`、`HOTEL_MONITOR_WECOM_WEBHOOK` 写进任何文件、聊天回复、报告或 GitHub。
- 不提交 `config/hotel-monitor.json`、`data/`、`reports/` 或任何密钥。
- 遇到 API 鉴权、额度、并发或 CLI 错误时停止并说明，不编造数据。
- `install.ps1` 和 DryRun 不应消耗高德、FlyAI 或百度正式调用额度。
- `scripts/verify-local.ps1` 只做本地验收，不跑正式采集。
- `scripts/run-once.ps1` 默认只跑 DryRun；只有显式 `-Formal` 才允许正式采集。

## 常用提示词

部署：

```text
请阅读 workbuddy-start-here.md，并按步骤帮我部署酒店竞对每日监控 API 组合版。不要写入任何 Key 明文；缺少环境变量时停下来提醒我配置。
```

自动化：

```text
请阅读 docs/automation-setup.md，指导我在 WorkBuddy GUI 中创建每天 07:30 的酒店竞对每日监控 Automation。使用低成本内置模型，开启推送到 WorkBuddy 小程序，并按 config/hotel-monitor.json 的 pushMode 执行对应推送；没有实际收到时不要伪造成功。
```

单次运行：

```text
请读取 templates/automation-prompt.template.md，按 API 组合流程立即跑一次酒店竞对每日监控。运行 scripts/run-once.ps1 -Formal，读取 data/api-combo/api-combo-latest-report-input.md，再按 templates/daily-prompt.md 生成日报并按 pushMode 推送。缺少必需 Key、CLI、对应推送配置或 API 返回异常时停止并说明，不要伪造结果。
```
