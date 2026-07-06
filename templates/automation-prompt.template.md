# 酒店竞对每日监控 Automation Prompt

请用 WorkBuddy 内置模型执行本任务，不调用任何第三方模型接口，不读取或要求任何接口密钥。优先使用消耗最低的内置模型。

## 硬约束

- 全链路只使用国内可访问服务：WorkBuddy 内置模型、携程国内站、微信或企业微信 ClawBot。
- 浏览携程必须使用已配置的真实浏览器 MCP：playwright-browser / mcp__playwright-browser。
- playwright-browser 必须复用固定的持久化浏览器资料目录：ctrip-profile。
- 浏览器必须使用有头模式。不要使用 headless 模式。不要添加 stealth、绕检测、绕风控或伪造登录相关参数。
- 不要使用 fetch、WebFetch、requests、curl 或任何纯 HTTP 抓取方式访问携程页面。
- 不要绕过验证码、滑块、短信验证、登录墙或风控。
- 一天只跑一次；逐家酒店串行打开；每家打开后随机等待 3-7 秒；滚动和点击之间随机等待 1-3 秒；酒店之间随机等待 5-12 秒。

## 默认运行口径

- 入住日期模式：相对天数
- 入住偏移天数：{{OFFSET_DAYS}}
- 入住晚数：{{NIGHTS}}
- 房间数：{{ROOMS}}
- 成人数：{{ADULTS}}
- 儿童数：{{CHILDREN}}
- 儿童年龄：{{CHILD_AGES}}
- 默认目标房型：{{ROOM_TYPE}}
- 点评条数：{{REVIEW_COUNT}}
- 默认定时：{{SCHEDULE_TIME}}
- 推送方式：{{PUSH_MODE}}
- 价格口径：携程国内站页面可见到手价/含税费说明

## 对话框本次覆盖参数

用户可以在 WorkBuddy 对话框里用自然语言临时覆盖默认口径。覆盖只对本次运行生效，不写入文件，不影响下一次默认定时任务。

示例：

- 按默认跑
- 这次查 7月20 入住，住2晚，2成人，双床房
- 这次点评抓10条，其他默认

如果用户覆盖参数表达不完整但可推断，则按默认补齐未提到的参数；如果存在歧义，例如只说“下周”，先停下来问清楚。

## 执行顺序

1. 解析本轮 WorkBuddy 对话是否包含本次覆盖参数。
2. 计算本次实际查询口径。
3. 校验日期、房间数、成人数、儿童数、儿童年龄、房型和点评条数。
4. 读取 competitors.md，解析本店和用户确认的全部竞对酒店。
5. 执行登录态自检。
6. 用 playwright-browser 逐家打开携程详情页。
7. 页面链接或页面查询条件必须设置为本次入住日期、本次离店日期、房间数、成人数、儿童数、儿童年龄。
8. 页面加载后必须检查可见条件是否与本次实际查询口径一致；不一致时先改成一致再抓价。
9. 抓取酒店名、实际查询口径、目标房型可售状态、目标房型或相近房型价格、早餐、取消政策、房态和最新点评。
10. 任意一家查询口径不一致时，不要输出调价/跟价建议，只输出“查询口径未达成，需要重跑”。
11. 读取 daily-prompt.md 生成红黄绿日报。
12. 保存 reports/YYYY-MM-DD-raw.md 和 reports/YYYY-MM-DD-hotel-competitor-daily.md。
13. 执行推送策略。
14. 最终回复必须包含日报全文、保存路径、抓取状态、本次实际查询口径、参数来源和推送状态。

## 推送策略

- 如果推送方式是“只保存本地”：不要推送，只保存 reports 文件，并在最终回复里写“推送未配置”。
- 如果推送方式是“WorkBuddy ClawBot”：最终回复必须包含完整日报全文，让 WorkBuddy Automation / ClawBot 推送最终回复；如果桌面端没有配置 ClawBot，写“ClawBot 推送未配置”。
- 如果推送方式是“企业微信群机器人”：保存日报后，检查环境变量 HOTEL_MONITOR_WECOM_WEBHOOK。
- 企业微信群机器人已配置时，运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\push-wecom.ps1 -ReportPath .\reports\YYYY-MM-DD-hotel-competitor-daily.md
```

- 企业微信群机器人未配置时，不要伪造推送成功；最终回复写“企业微信推送未配置：缺少 HOTEL_MONITOR_WECOM_WEBHOOK”。
