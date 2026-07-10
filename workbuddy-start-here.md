# WorkBuddy Start Here

你是我的 WorkBuddy 配置助手。请按本文件一步步帮我部署“酒店竞对每日监控 API 组合版”，不要一次性假装完成。

## MVP 目标

只跑通这一条链路：

```text
高德地图候选池 -> FlyAI/飞猪价格 -> 百度地图口碑补充 -> WorkBuddy 内置模型分析 -> 按 pushMode 推送
```

## 硬约束

- 全链路只使用国内可访问服务：高德地图、FlyAI/飞猪、百度地图、WorkBuddy 内置模型、微信助理 ClawBot，可选企业微信。
- 不使用 OTA 网页浏览器自动化作为主流程。
- 不要求用户登录携程、飞猪、美团、去哪儿等 OTA 网站。
- 不创建或修改 WorkBuddy 的 `models.json`。
- `AMAP_API_KEY`、`FLYAI_API_KEY`、`BAIDU_MAP_AK` 和 `HOTEL_MONITOR_WECOM_WEBHOOK` 只能从 Windows 环境变量读取，不要写进项目文件、聊天回复、报告或 GitHub。
- 需要用户配置环境变量、WorkBuddy Automation、ClawBot 推送时，停下来让我手动操作。

## 你要执行的步骤

1. 确认当前目录是本项目根目录，应该能看到 `app/`、`config/`、`scripts/`、`templates/`。
2. 检查环境变量：

```powershell
if ($env:AMAP_API_KEY) { "AMAP_API_KEY 已配置" } else { "缺少 AMAP_API_KEY" }
if ($env:FLYAI_API_KEY) { "FLYAI_API_KEY 已配置" } else { "缺少 FLYAI_API_KEY" }
if ($env:BAIDU_MAP_AK) { "BAIDU_MAP_AK 已配置" } else { "BAIDU_MAP_AK 未配置；只有启用百度真实调用且 dailyCallLimit 不为 0 时才必需" }
```

3. 如果缺少 AMAP_API_KEY、FLYAI_API_KEY，或在启用百度真实调用且 `dailyCallLimit` 不为 0 时缺少 BAIDU_MAP_AK，停下来让我配置，不要要求我把 Key 发给你或写进文件。
4. 检查 FlyAI CLI：

```powershell
Get-Command flyai
```

5. 如果 `flyai` 不存在，提示我安装：

```powershell
npm i -g @fly-ai/flyai-cli --registry=https://registry.npmmirror.com
```

6. 运行零额度本地体检：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

7. 读取 `data/setup-check-latest.md`，告诉我哪些项目是 `missing`、`warning` 或 `error`。这一步不得调用高德、FlyAI 或百度 API。
8. 如果 `config shape` 是 `warning`，先询问我是否允许补齐旧配置缺失字段；我同意后运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -RepairConfigFromExample
```

9. 如果我还没有配置必需 Key，先让我打开对应本地引导页面：`app/flyai-guide.html`、`app/amap-guide.html`、`app/baidu-guide.html`。如果百度额度紧张，可以先在向导里点“百度省额度模式”，它会关闭百度真实调用，并把百度补充数量和每日调用上限设为 `0`。
10. 打开 `app/index.html`，让我填写本店、城市、POI、入住口径、房型、人数、半径、竞对数量、候选池上限、FlyAI 请求节奏、百度补充数量、百度缓存/每日调用上限、分层规则和历史对比设置。
11. 让我下载或生成 `config/hotel-monitor.json`。
12. 先跑 DryRun：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-api-mvp.ps1 -DryRun
```

13. 更推荐使用安全单次运行入口：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-once.ps1
```

这一步默认只跑 DryRun，并会写入 `data/run-once-latest.md`。
14. 如果需要完整本地验收，运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-local.ps1
```

这一步只做零额度体检、DryRun、本地测试和敏感信息扫描，不跑正式采集。
15. DryRun 成功后，再跑正式采集：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-once.ps1 -Formal
```

16. 如果正式运行被拦住，读取 `data/run-once-latest.md` 和 `data/setup-check-latest.md`，说明 `BlockingIssues`，不要绕过 `run-once.ps1` 直接调用底层正式采集脚本。
17. 读取 `data/api-combo/api-combo-latest-report-input.md` 和 `templates/daily-prompt.md`。
18. 检查 `Applied Query Scope`：明确入住/离店日期和床型是否实际传给 FlyAI；如果房间数、成人数或儿童数是 `not-applied-by-flyai-cli`，日报必须披露，不能声称价格已按人数筛选。
19. 检查 `FlyAI Usage` 和酒店身份状态：说明价格源是否成功、是否空结果、是否失败、是否脱敏、是否出现 `identity-mismatch`。脱敏价不能参与精确差额、比例或涨跌幅计算。
20. 检查 `Baidu Usage`：说明百度缓存命中、本次真实调用、运行前已用、自然日累计、每日上限和被限额跳过数量。如果百度关闭、补充数量为 0 或每日上限为 0，说明“百度省额度模式，本次不调用百度”，不要把它当作采集失败。
21. 检查 `Tier Rules`：日报解释分层时必须尊重用户配置。
22. 优先检查 `History` 和 `Yesterday Comparison`：有同口径历史时判断涨价、降价、持平；没有历史时说明“首次运行，无同口径历史”。任一侧为脱敏价时写“价格带不可精确比较”。
23. 用 WorkBuddy 内置模型生成红黄绿日报，保存到 `reports/YYYY-MM-DD-hotel-competitor-daily.md`。
24. 读取 `config/hotel-monitor.json` 的 `pushMode`，只执行对应路径：`clawbot` 以微信实收为准，`wecom` 调用 `scripts/push-wecom.ps1`，`none` 只保存本地。Automation 官方可确认的通知方式是“推送到 WorkBuddy 小程序”。
25. 如果对应渠道未配置或未实际收到，不要伪造成功；贴出日报全文并说明真实状态。
26. 首次手动跑通后，读取 `docs/automation-setup.md`，指导我在 WorkBuddy GUI 里创建 Automation，每天 07:30 运行。

## 停止条件

遇到以下情况必须停止并告诉我：

- 正式运行所需 Key 缺失：高德和 FlyAI 必需；百度只有在启用真实调用且每日上限大于 0 时必需。
- `flyai` CLI 不存在或命令运行失败。
- 高德、FlyAI 或百度 API 返回鉴权错误、额度错误、并发错误。
- 百度省额度模式下缺少百度口碑不算错误；只有启用百度真实调用时百度 API 错误才需要停止。
- WorkBuddy Automation 或 ClawBot 只能在桌面端 GUI 配置。
- 任意一步需要境外服务或 VPN。
