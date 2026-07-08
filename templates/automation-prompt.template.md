# 酒店竞对每日监控 Automation Prompt

请用 WorkBuddy 内置模型执行本任务，不调用第三方大模型接口。酒店竞对数据通过三源 API 组合获取：高德负责地图和候选池，FlyAI/飞猪负责价格，百度负责口碑补充。

## 本地文件

- 本地配置：config/hotel-monitor.json
- 组合采集脚本：scripts/run-api-mvp.ps1
- 安全单次运行入口：scripts/run-once.ps1
- 日报提示词：templates/daily-prompt.md
- API 原始数据目录：data/api-combo
- 历史快照目录：data/history
- 日报输出目录：reports

## 硬约束

- 全链路只使用国内可访问服务：高德地图、FlyAI/飞猪、百度地图、WorkBuddy 内置模型、微信助理 ClawBot，可选企业微信。
- Key 只允许从环境变量读取：AMAP_API_KEY、FLYAI_API_KEY、BAIDU_MAP_AK；是否必需由 `config/hotel-monitor.json` 和 `run-once.ps1` readiness 判断。
- 不要把任何 Key 写进项目文件、提示词、聊天记录、报告或 GitHub。
- 不要浏览 OTA 网页，不要要求用户登录 OTA 网站。
- 不要编造价格、距离、档位、评分、评论数或竞品分层理由。

## 执行顺序

1. 确认 config/hotel-monitor.json 存在；如果缺失，提醒用户从 config/hotel-monitor.example.json 复制并填写。
2. 先运行安全单次入口执行正式采集；它会按 `config/hotel-monitor.json` 自动检查必需 Key 和 readiness，不满足正式采集条件时会停止：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-once.ps1 -Formal
```

3. 如果 `scripts/run-once.ps1 -Formal` 停止，读取 `data/run-once-latest.md` 和 `data/setup-check-latest.md`，最终回复说明 `BlockingIssues`，不要继续生成日报，不要伪造数据或推送成功。
4. 读取 data/run-once-latest.md，确认 `FormalCollection: true` 且 `Status: ok`。
5. 读取 data/api-combo/api-combo-latest-report-input.md。
6. 检查其中的 FlyAI Usage 章节：说明价格源成功、空结果、失败、脱敏价格和 DryRun 状态。
7. 检查其中的 Baidu Usage 章节：说明百度缓存命中、真实 API 调用次数、每日上限和被限额跳过数量。
8. 检查其中的 Tier Rules 章节：按用户配置解释核心竞品、价格压力、品质压力和替代住宿，不要用默认经验覆盖配置。
9. 检查其中的 History / Yesterday Comparison 章节：有同口径历史时判断涨价、降价、持平；没有历史时只做今日横截面分析。
10. 读取 templates/daily-prompt.md。
11. 使用 WorkBuddy 内置模型生成红黄绿经营日报。
12. 保存 reports/YYYY-MM-DD-hotel-competitor-daily.md。
13. 默认通过微信助理 ClawBot 推送日报全文。
14. 如果 ClawBot 未绑定或 Automation 未启用 ClawBot 通知，不要伪造成功；最终回复写“ClawBot 推送未配置”，并贴出完整日报全文。

## 可选企业微信备用推送

如果用户明确选择企业微信群机器人，并且环境变量 HOTEL_MONITOR_WECOM_WEBHOOK 存在，保存日报后运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\push-wecom.ps1 -ReportPath .\reports\YYYY-MM-DD-hotel-competitor-daily.md
```

如果 webhook 缺失，不要伪造推送成功。

## 最终回复

最终回复必须包含：

- 日报全文
- API 组合数据输入路径
- 日报保存路径
- 查询口径
- FlyAI 价格源状态
- 分层规则
- 百度缓存和额度状态
- 历史对比状态
- 推送状态
- run-once 状态
- 如果高德、FlyAI 或百度任一数据不完整，明确说明缺口
