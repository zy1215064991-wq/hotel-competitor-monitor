# 推送设置：怎么让用户收到日报

向导默认选择微信助理 ClawBot，但首次必须以微信端实际收到消息为准。

本项目由 `config/hotel-monitor.json` 的 `pushMode` 控制三种互斥路径，每次只执行对应的一条：

- `clawbot`：尝试通过已绑定的微信助理 ClawBot 接收结果；Automation 同时建议开启官方“推送到 WorkBuddy 小程序”作为可验证通知路径。
- `wecom`：使用企业微信群机器人 webhook，通过 `scripts/push-wecom.ps1` 发送 Markdown 日报。
- `none`：只保存本地 `reports/`，不调用 ClawBot 或企业微信。

可以同时准备多个渠道，但一次任务只按 `pushMode` 选择一个项目推送分支。无论选择哪种方式，日报都先保存到本地 `reports/`；没有收到或脚本失败时必须如实标记，不能伪造推送成功。

## Automation 官方通知：WorkBuddy 小程序

1. 在微信搜索并打开“腾讯 WorkBuddy”小程序。
2. 按页面提示授权登录，确保微信账号与电脑端 WorkBuddy 登录账号一致。
3. 在桌面端创建 Automation 时打开“推送到 WorkBuddy 小程序”。
4. 手动测试运行一次，以小程序实际收到完整结果为成功依据。

这是 WorkBuddy Automation 官方文档明确提供的通知开关。它是任务通知路径，不改变项目里的 `pushMode`：例如 `pushMode=wecom` 时，日报仍由脚本发到企业微信群。

## 方式一：微信助理 ClawBot

适合个人使用，优点是不用自己维护 webhook。日报生成后，WorkBuddy 会把最后汇报通过微信助理 ClawBot 推送到微信侧。

步骤：

1. 打开 WorkBuddy。
2. 打开左侧 Claw 面板。
3. 点击设置图标。
4. 找到微信助理 ClawBot 集成。
5. 点击配置。
6. 用微信扫码绑定。
7. 等状态显示已连接或已绑定。
8. 创建 Automation 时，如果当前界面确实提供微信助理 ClawBot 通知入口，再选择“最终回复”或“完整任务结果”。
9. 手动测试运行一次，确认微信 ClawBot 实际收到日报全文。

注意：

- 这一步必须在 WorkBuddy 图形界面里完成。
- 不要让自动化模拟微信登录。
- Automation 是否能直接选择 ClawBot 以当前桌面端实际界面为准；如果没有该入口，保留 WorkBuddy 小程序通知，并将 ClawBot 标记为尚未验证，也可以把 `pushMode` 改成 `wecom` 或 `none`。
- 如果没有绑定 ClawBot，自动化不能假装推送成功；它会保存本地报告，并在最终回复里提示你去绑定 ClawBot。

## 方式二：企业微信群机器人

适合酒店运营群、收益管理群、门店日报群。

### 1. 在企业微信群里添加机器人

1. 打开企业微信。
2. 进入要接收日报的群聊。
3. 点击右上角群设置。
4. 找到群机器人。
5. 添加机器人。
6. 名称建议填：酒店竞对日报。
7. 保存后复制机器人 webhook。

webhook 形如：

```text
https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

这个链接等同于推送密钥，不要发到群里，不要写进 GitHub，不要写进任何项目文件。

### 2. 在 Windows 系统环境变量里保存 webhook

在 PowerShell 里运行：

```powershell
setx HOTEL_MONITOR_WECOM_WEBHOOK "https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=替换成你的key"
```

然后：

1. 完全关闭 WorkBuddy。
2. 重新打开 WorkBuddy。
3. 重新打开本项目。

原因：`setx` 写入的是新进程环境变量，已经打开的 WorkBuddy 读不到。

### 3. 测试推送

先创建一个测试文件：

```powershell
New-Item -ItemType Directory -Force -Path .\reports
@"
🔴 测试红色区域

🟡 测试黄色区域

🟢 测试绿色区域
"@ | Set-Content -Encoding UTF8 .\reports\test-hotel-competitor-daily.md
```

预览推送内容，不真正发送：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\push-wecom.ps1 -ReportPath .\reports\test-hotel-competitor-daily.md -DryRun
```

真正发送：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\push-wecom.ps1 -ReportPath .\reports\test-hotel-competitor-daily.md
```

如果成功，企业微信群里会收到 Markdown 日报。

### 4. 在 WorkBuddy Automation 里启用

详细的 Automation 创建步骤见 `docs/automation-setup.md`。

Automation prompt 已经包含按 `pushMode` 三选一的推送策略：

1. 先生成并保存 `reports/YYYY-MM-DD-hotel-competitor-daily.md`。
2. `clawbot`：尝试通过已绑定的微信助理发送，并以微信实收判断；若 Automation 只有小程序开关，则使用小程序并写明 ClawBot 尚未验证。
3. `wecom`：环境变量 `HOTEL_MONITOR_WECOM_WEBHOOK` 存在时运行 `scripts/push-wecom.ps1`，失败就报告失败。
4. `none`：只保存本地，不调用外部推送。

## 常见问题

### 群里收不到

检查：

- 企业微信群机器人 webhook 是否复制完整。
- 是否重新启动了 WorkBuddy。
- 是否在正确项目目录运行脚本。
- `HOTEL_MONITOR_WECOM_WEBHOOK` 是否能读到。

检查环境变量：

```powershell
echo $env:HOTEL_MONITOR_WECOM_WEBHOOK
```

### 提示 webhook 格式错误

必须以这个地址开头：

```text
https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=
```

### 日报太长

企业微信 Markdown 消息有长度限制。脚本会自动截断超长内容，并附上本地完整报告路径。

### 能不能推个人微信

个人微信不要走脚本和 webhook。个人微信请用 WorkBuddy 自带的微信助理 ClawBot 绑定能力；具体绑定方式以当前图形界面提供的选项为准。定时任务建议同时开启“推送到 WorkBuddy 小程序”。
