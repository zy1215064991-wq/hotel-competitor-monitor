# WorkBuddy Automation 定时设置

本项目的定时任务需要在 WorkBuddy 桌面端图形界面里创建。脚本不能替你点击 Automation，也不能替你完成 WorkBuddy 小程序、ClawBot 或企业微信授权。

官方参考：

- WorkBuddy 自动化说明：https://www.codebuddy.cn/docs/workbuddy/From-Beginner-to-Expert-Guide/Function-Description/Automation-Guide
- 微信助理 ClawBot 接入说明：https://www.codebuddy.ai/docs/ide/Platform-integration/weixinbot-guide

## 创建前检查

先在项目根目录完成这些本地检查：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-api-mvp.ps1 -DryRun
```

确认：

- `data/setup-check-latest.md` 里 `NetworkCalls: 0`，没有正式调用 API。
- `config/hotel-monitor.json` 存在，`config shape` 为 `ok`。
- 如果百度已关闭、`baidu.enrichTopN` 为 0 或 `baidu.dailyCallLimit` 为 0，`BAIDU_MAP_AK` 可以不是正式运行阻塞项。
- `data/api-combo/api-combo-latest-report-input.md` 能正常生成。
- 已在 `config/hotel-monitor.json` 选择 `pushMode`：`clawbot`、`wecom` 或 `none`，并按 `docs/push-setup.md` 完成对应准备。

## 推荐模型

本方案使用 WorkBuddy 内置模型，不需要第三方大模型 API Key。

为了省积分，创建 Automation 时优先选择低成本内置模型，例如 MiniMax 2.5 或 WorkBuddy 当前标注为轻量、省积分的模型。不同版本的模型列表可能变动，原则是：

- 日常定时任务用低成本模型。
- 第一次调试或复杂异常分析时，再手动切换更强模型。
- 不要把 DeepSeek、OpenAI 或其他第三方 API Key 写进本项目文件。

## 创建 Automation

1. 打开 WorkBuddy 桌面端。
2. 打开 Automation / 自动化 页面。
3. 点击添加、新建或右上角加号。
4. 名称填写：

```text
酒店竞对每日监控
```

5. 工作空间选择本项目根目录：

```text
hotel-competitor-monitor
```

如果界面要求选择具体目录，请选择包含 `README.md`、`install.ps1`、`scripts/` 的目录。

6. 提示词填写 `templates/automation-prompt.template.md` 的全文。
7. 模型选择低成本内置模型，例如 MiniMax 2.5。
8. 技能或连接器保持默认即可；不要启用 OTA 浏览器自动化，不要启用会登录酒店网站的浏览器任务。
9. 定时规则选择每天 07:30。

如果界面提供 cron 输入框，使用：

```text
30 7 * * *
```

如果界面使用自然语言，填写：

```text
每天 07:30
```

10. 生效日期保持从今天开始，结束日期留空或按酒店运营周期设置。
11. 最大执行时长建议设为 30 分钟；MVP 正常应远低于这个时间。
12. 打开官方 Automation 开关“推送到 WorkBuddy 小程序”。手机微信进入“腾讯 WorkBuddy”小程序，并确保小程序与电脑端使用同一账号。
13. 如果当前桌面端实际界面另外提供 ClawBot 或微信助理通知入口，且配置的 `pushMode` 是 `clawbot`，可以启用；不要根据文档猜测一个界面里不存在的选项。
14. 保存 Automation。

“推送到 WorkBuddy 小程序”是官方 Automation 文档可确认的路径。ClawBot 绑定能接收微信侧任务结果，但 Automation 是否能直接选择 ClawBot 以当前版本界面为准。企业微信 `wecom` 模式不依赖 GUI 通知选项，由任务末尾运行 `scripts/push-wecom.ps1`。

Automation 里的正式采集必须通过安全入口执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-once.ps1 -Formal
```

不要在 Automation 里直接运行 `scripts/run-api-mvp.ps1` 做正式采集。`run-once.ps1 -Formal` 会先检查 `ReadyForFormalRun`，不满足条件时会停止并写入 `data/run-once-latest.md`。

## 首次试跑

保存后不要直接等第二天，先手动触发一次。

手动触发后检查：

- 是否生成 `data/api-combo/api-combo-latest-report-input.md`。
- `data/run-once-latest.md` 是否显示 `FormalCollection: true` 和 `Status: ok`。
- 是否生成 `reports/YYYY-MM-DD-hotel-competitor-daily.md`。
- 最终回复里是否包含日报全文。
- WorkBuddy 小程序是否收到完整结果。
- `pushMode=clawbot` 时，微信 ClawBot 是否实际收到完整结果；没有实收就标记“ClawBot 尚未验证”，不能只凭任务完成判断成功。
- `pushMode=wecom` 时，企业微信群是否收到消息，且脚本退出码为 0。
- `pushMode=none` 时，是否只保存本地且未调用任何外部推送。

## 失败时的正确处理

如果任一步失败，不要让 WorkBuddy 猜数据或继续编日报。

常见处理：

- Key 缺失：按 `app/flyai-guide.html`、`app/amap-guide.html`、`app/baidu-guide.html` 配置环境变量。
- 旧配置缺字段：运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -RepairConfigFromExample`。
- 百度额度紧张：把 `config/hotel-monitor.json` 里的 `baidu.dailyCallLimit` 调成 `0`、`5` 或 `10`。
- 小程序未收到：确认 Automation 的“推送到 WorkBuddy 小程序”已开启，且手机和电脑端账号一致。
- ClawBot 未绑定：按 `docs/clawbot-setup.md` 在 GUI 里绑定；登录方式以当前界面提供的选项为准。
- 企业微信 webhook 未配置：按 `docs/push-setup.md` 配置 `HOTEL_MONITOR_WECOM_WEBHOOK`，或把推送方式改为只保存本地。

## 每周巡检

建议每周手动看一次：

- WorkBuddy Automation 是否仍启用。
- WorkBuddy 小程序是否持续收到 Automation 结果。
- 使用 ClawBot 时，绑定状态和微信实收是否正常。
- `data/usage/` 的百度自然日账本是否正常累计。
- `data/cache/baidu/` 是否在正常增长。
- `data/history/` 是否每天有新快照。
- `reports/` 是否每天有日报。
- WorkBuddy 积分消耗是否符合预期。

## 安全边界

- Automation 的工作空间必须指向本项目目录。
- 不要把 `AMAP_API_KEY`、`FLYAI_API_KEY`、`BAIDU_MAP_AK` 或 webhook 写进提示词。
- 不要在 Automation 里要求登录携程、飞猪、美团或去哪儿网页。
- 不要把没有推送成功的任务标记为成功。
