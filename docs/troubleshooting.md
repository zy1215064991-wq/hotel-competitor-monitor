# 排障说明

## WorkBuddy 找不到 playwright-browser

运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-workbuddy.ps1
```

如果 `.mcp.json` 或 `mcp.json` 缺失，重新运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-workbuddy-mcp.ps1
```

然后完全退出并重启 WorkBuddy。

## 浏览器找不到

安装脚本默认使用 `auto` 模式：优先使用 Chrome，未安装 Chrome 时回退 Edge。

常见 Chrome 路径：

```text
C:\Program Files\Google\Chrome\Application\chrome.exe
C:\Program Files (x86)\Google\Chrome\Application\chrome.exe
C:\Users\<用户名>\AppData\Local\Google\Chrome\Application\chrome.exe
```

常见 Edge 路径：

```text
C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe
C:\Program Files\Microsoft\Edge\Application\msedge.exe
```

如果想强制使用某个浏览器：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Browser chrome
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Browser edge
```

## 携程显示验证码、滑块或短信验证

停止自动化。不要绕过验证。请人工完成扫码登录或等待风控解除后再运行。

## 价格显示“解锁优惠”

说明当前携程会话没有可用登录态。重新扫码登录。

注意：Chrome 和 Edge 使用不同的登录态目录。如果从 Edge 切换到 Chrome，首次运行时需要重新扫码登录一次。

## 酒店候选不准确

在输入酒店名时增加地址、地铁站、商圈、机场/车站等辅助关键词。候选必须由用户确认后才能保存。

## 查询口径不一致

如果报告显示页面实际是 `2成人` 或日期不对，不要使用经营建议。重新运行，并在 WorkBuddy 对话里明确说：

```text
按默认跑，确认页面是1间、1成人、0儿童
```

或给出本次覆盖：

```text
这次查 2成人，双床房
```
