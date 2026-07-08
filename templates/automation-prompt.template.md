# 酒店竞对每日监控 Automation Prompt

请用 WorkBuddy 内置模型执行本任务，不调用第三方大模型接口。酒店竞对数据通过三源 API 组合获取：高德负责地图和候选池，FlyAI/飞猪负责价格，百度负责口碑补充。

## 本地文件

- 本地配置：config/hotel-monitor.json
- 组合采集脚本：scripts/run-api-mvp.ps1
- 日报提示词：templates/daily-prompt.md
- API 原始数据目录：data/api-combo
- 历史快照目录：data/history
- 日报输出目录：reports

## 硬约束

- 全链路只使用国内可访问服务：高德地图、FlyAI/飞猪、百度地图、WorkBuddy 内置模型、微信助理 ClawBot，可选企业微信。
- Key 只允许从环境变量读取：AMAP_API_KEY、FLYAI_API_KEY、BAIDU_MAP_AK。
- 不要把任何 Key 写进项目文件、提示词、聊天记录、报告或 GitHub。
- 不要浏览 OTA 网页，不要要求用户登录 OTA 网站。
- 不要编造价格、距离、档位、评分、评论数或竞品分层理由。

## 执行顺序

1. 确认 config/hotel-monitor.json 存在；如果缺失，提醒用户从 config/hotel-monitor.example.json 复制并填写。
2. 确认 AMAP_API_KEY、FLYAI_API_KEY、BAIDU_MAP_AK 都存在；如果缺失，停止并提醒用户配置 Windows 环境变量。
3. 运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-api-mvp.ps1
```

4. 读取 data/api-combo/api-combo-latest-report-input.md。
5. 检查其中的 History / Yesterday Comparison 章节：有同口径历史时判断涨价、降价、持平；没有历史时只做今日横截面分析。
6. 读取 templates/daily-prompt.md。
7. 使用 WorkBuddy 内置模型生成红黄绿经营日报。
8. 保存 reports/YYYY-MM-DD-hotel-competitor-daily.md。
9. 默认通过微信助理 ClawBot 推送日报全文。
10. 如果 ClawBot 未绑定或 Automation 未启用 ClawBot 通知，不要伪造成功；最终回复写“ClawBot 推送未配置”，并贴出完整日报全文。

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
- 历史对比状态
- 推送状态
- 如果高德、FlyAI 或百度任一数据不完整，明确说明缺口
