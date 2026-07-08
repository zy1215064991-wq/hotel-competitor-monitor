# 酒店竞对每日监控 Automation Prompt

请用 WorkBuddy 内置模型执行本任务，不调用第三方大模型接口，不读取或要求任何模型 API Key。酒店价格数据只通过 FlyAI/飞猪 CLI 获取。

## 本地文件

- 本地配置：config/hotel-monitor.json
- FlyAI 采集脚本：scripts/run-flyai-mvp.ps1
- 日报提示词：templates/daily-prompt.md
- FlyAI 原始数据目录：data/flyai
- 日报输出目录：reports

## 硬约束

- 全链路只使用国内可访问服务：FlyAI/飞猪、WorkBuddy 内置模型、微信助理 ClawBot，可选企业微信。
- FlyAI API Key 只允许从环境变量 FLYAI_API_KEY 读取，不要要求用户把 Key 写进项目文件、提示词、聊天记录、报告或 GitHub。
- 不要浏览 OTA 网页，不要使用浏览器自动化，不要要求用户登录任何 OTA 网站。
- 不要编造价格、距离、档位、品牌、地址或竞品分层理由。
- 如果 FlyAI 返回脱敏价格，例如 ¥1xx，只能当作价格带信号，不要当作精确价格。

## 执行顺序

1. 确认 config/hotel-monitor.json 存在；如果缺失，提醒用户从 config/hotel-monitor.example.json 复制并填写。
2. 确认环境变量 FLYAI_API_KEY 存在；如果缺失，停止并提醒用户在 Windows 环境变量里配置。
3. 运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-flyai-mvp.ps1
```

4. 读取 data/flyai/latest-report-input.md。
5. 读取 templates/daily-prompt.md。
6. 使用 WorkBuddy 内置模型生成红黄绿经营日报。
7. 保存 reports/YYYY-MM-DD-hotel-competitor-daily.md。
8. 默认通过微信助理 ClawBot 推送日报全文。
9. 如果 ClawBot 未绑定或 Automation 未启用 ClawBot 通知，不要伪造成功；最终回复写“ClawBot 推送未配置”，并贴出完整日报全文。

## 可选企业微信备用推送

如果用户明确选择企业微信群机器人，并且环境变量 HOTEL_MONITOR_WECOM_WEBHOOK 存在，保存日报后运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\push-wecom.ps1 -ReportPath .\reports\YYYY-MM-DD-hotel-competitor-daily.md
```

如果 webhook 缺失，不要伪造推送成功。

## 最终回复

最终回复必须包含：

- 日报全文
- FlyAI 数据输入路径
- 日报保存路径
- 查询口径
- 推送状态
- 如果 FlyAI 数据不完整，明确说明缺口
