# 微信助理 ClawBot 推送设置

更完整的推送设置，包括企业微信群机器人 webhook，请看 `docs/push-setup.md`。

WorkBuddy 的推送需要在桌面端 UI 中配置，不能由脚本代替你扫码或授权。

## 微信助理 ClawBot

1. 打开 WorkBuddy。
2. 进入 Claw 面板。
3. 点击设置。
4. 找到 WeChat ClawBot Integration / 微信助理 ClawBot 集成。
5. 点击 Configure / 配置。
6. 用微信扫码。
7. 状态显示 Connected / Bound / 已连接后完成。

## 企业微信

如果你的 WorkBuddy 版本支持企业微信或团队推送，在同一集成区域选择企业微信/WeCom。需要管理员授权或选择群聊时，必须人工完成。

## Automation 中启用推送

详细的每日定时任务创建步骤见 `docs/automation-setup.md`。

创建酒店竞对每日监控 Automation 时，通知方式优先选择微信助理 ClawBot。推送内容选择最终回复或完整任务结果，让日报全文能被推到微信侧。

如果还没配置推送，自动化仍会把日报保存到本地 `reports/`。
