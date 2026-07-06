# Troubleshooting

## WorkBuddy 找不到 playwright-edge

运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-workbuddy.ps1
```

如果 `.mcp.json` 或 `mcp.json` 缺失，重新运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-workbuddy-mcp.ps1
```

然后重启 WorkBuddy。

## Edge 找不到

确认 Microsoft Edge 安装在以下路径之一：

```text
C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe
C:\Program Files\Microsoft\Edge\Application\msedge.exe
```

如果安装在其他路径，修改 `scripts/setup-workbuddy-mcp.ps1` 里的 `$edgeCandidates`。

## 携程显示验证码、滑块或短信验证

停止自动化。不要绕过验证。请人工完成扫码登录或等待风控解除后再运行。

## 价格显示“解锁优惠”

说明当前携程会话没有可用登录态。重新扫码登录。

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

