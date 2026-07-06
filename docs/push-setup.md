# 推送设置：怎么让用户收到日报

本项目支持两种推送路径：

- 个人微信：使用 WorkBuddy 自带的 ClawBot 绑定能力，在 WorkBuddy 桌面端图形界面里配置。
- 企业微信群：使用企业微信群机器人 webhook，通过 `scripts/push-wecom.ps1` 自动发送 Markdown 日报。

两种方式可以同时保留。没有配置推送时，自动化仍会把日报保存到本地 `reports/`。

## 方式一：个人微信 ClawBot

适合个人使用，优点是不用自己维护 webhook。

步骤：

1. 打开 WorkBuddy。
2. 打开左侧 Claw 面板。
3. 点击设置图标。
4. 找到微信 ClawBot 集成。
5. 点击配置。
6. 用微信扫码绑定。
7. 等状态显示已连接或已绑定。
8. 创建 Automation 时，在通知或推送方式里选择 ClawBot、微信或最终回复推送。

注意：

- 这一步必须在 WorkBuddy 图形界面里完成。
- 不要让自动化模拟微信登录。
- 如果 WorkBuddy 版本没有 ClawBot 推送入口，就只使用企业微信群机器人方式。

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

Automation prompt 已经包含推送策略：

1. 先生成并保存 `reports/YYYY-MM-DD-hotel-competitor-daily.md`。
2. 如果环境变量 `HOTEL_MONITOR_WECOM_WEBHOOK` 存在，运行 `scripts/push-wecom.ps1` 推送。
3. 如果没有配置 webhook，只在本地保存日报，并在最终回复里说明“推送未配置”。

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

个人微信不要走脚本和 webhook。个人微信请用 WorkBuddy 自带的 ClawBot 绑定能力，在图形界面扫码绑定。
