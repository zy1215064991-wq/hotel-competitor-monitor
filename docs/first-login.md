# 携程首次扫码登录

携程价格可能需要登录后才能看到。本项目不保存账号密码，不自动输入验证码，不绕过任何平台验证。

## 操作步骤

1. 确认已运行 `scripts/setup-workbuddy-mcp.ps1`。
2. 完全退出并重启 WorkBuddy。
3. 打开 `app/index.html`。
4. 复制第一步里的登录验证提示词。
5. 粘贴到 WorkBuddy 普通对话。
6. WorkBuddy 用 `playwright-edge` 打开携程后停止。
7. 用微信或携程 App 扫码登录。
8. 登录后告诉 WorkBuddy：“已登录”。
9. WorkBuddy 会打开酒店页验证价格是否可见。

## 登录态保存位置

登录态保存在项目目录：

```text
ctrip-profile/
```

不要提交这个目录到 GitHub，也不要把它发给别人。

## 会话过期

如果以后自动化推送：

```text
携程会话已过期，请重新扫码登录后重新运行酒店竞对每日监控。
```

重新执行本页扫码流程即可。

