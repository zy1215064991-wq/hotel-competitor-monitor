---
name: hotel-competitor-monitor
description: Configure and operate a Windows WorkBuddy hotel competitor daily monitor using Ctrip, Playwright MCP, persistent scan-login, candidate hotel confirmation, and red/yellow/green daily reports. Use when setting up, debugging, or extending this project.
---

# Hotel Competitor Monitor

Use this skill when helping a user deploy or operate this repository.

## Workflow

1. Confirm the user is on Windows and has WorkBuddy installed.
2. Run or inspect `scripts/setup-workbuddy-mcp.ps1`.
3. Verify WorkBuddy can see `playwright-edge`.
4. Open `app/index.html` and guide the user through browser login.
5. Ask the user for city, home hotel name, and three competitor names.
6. Use WorkBuddy with `playwright-edge` to search Ctrip candidates; do not use fetch/WebFetch/curl/requests for Ctrip.
7. Return candidates and require user confirmation before saving any hotel.
8. Generate `competitors.md`, `automation-prompt.md`, and `daily-prompt.md`.
9. Help create a WorkBuddy Automation scheduled at 07:30.
10. Stop at captcha, slider, SMS verification, login wall, or risk-control pages.

## Constraints

- Use WorkBuddy built-in models; do not ask for third-party API keys.
- Use Ctrip domestic site.
- Use real Microsoft Edge through Playwright MCP.
- Reuse the persistent `ctrip-profile/` directory for login cookies.
- Never commit `ctrip-profile/`, reports, logs, cookies, or secrets.

## Common Prompts

Candidate search:

```text
请只使用 playwright-edge 真实浏览器 MCP，在携程国内站搜索酒店候选，不要使用 fetch、WebFetch、curl、requests 或任何纯 HTTP 抓取方式。请为每家返回 3 个候选：角色、候选序号、酒店名、地址、评分、hotelId、稳定URL、匹配理由。
```

Run once:

```text
请读取本目录的 automation-prompt.md，并严格按里面的步骤立即跑一次酒店竞对每日监控。只使用 playwright-edge 真实浏览器 MCP，不要使用 fetch 或 WebFetch。遇到携程登录、验证码或风控就停止并说明。
```

