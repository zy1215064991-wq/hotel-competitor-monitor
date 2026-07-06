---
name: hotel-competitor-monitor
description: 帮助用户配置和运行 Windows WorkBuddy 酒店竞对每日监控项目，包含携程、Playwright 浏览器连接器、持久化扫码登录、候选酒店确认和红黄绿日报。
---

# 酒店竞对每日监控

当用户要部署、排障或扩展本项目时，使用这份说明。

## 工作流程

1. 确认用户在 Windows 电脑上，并已安装 WorkBuddy。
2. 运行或检查 `scripts/setup-workbuddy-mcp.ps1`。
3. 验证 WorkBuddy 能看到 `playwright-edge`。
4. 打开 `app/index.html`，引导用户完成浏览器登录。
5. 询问城市、本店酒店名、竞对数量和每家竞对酒店名。
6. 使用 WorkBuddy 和 `playwright-edge` 搜索携程候选酒店；不要对携程使用 fetch、WebFetch、curl、requests。
7. 返回候选酒店，并在保存任何酒店前要求用户确认。
8. 生成 `competitors.md`、`automation-prompt.md`、`daily-prompt.md`。
9. 帮助用户创建每天 07:30 的 WorkBuddy 自动化任务。
10. 遇到验证码、滑块、短信验证、登录墙或风控页面时停止。

## 约束

- 使用 WorkBuddy 内置模型，不要求用户提供第三方接口密钥。
- 使用携程国内站。
- 通过 Playwright 浏览器连接器使用真实微软 Edge 浏览器。
- 复用持久化 `ctrip-profile/` 目录保存登录态。
- 不要提交 `ctrip-profile/`、报告、日志、cookies 或密钥。

## 常用提示词

候选酒店搜索：

```text
请只使用 playwright-edge 真实浏览器 MCP，在携程国内站搜索酒店候选，不要使用 fetch、WebFetch、curl、requests 或任何纯 HTTP 抓取方式。请为每家返回 3 个候选：角色、候选序号、酒店名、地址、评分、hotelId、稳定链接、匹配理由。
```

单次运行：

```text
请读取本目录的 automation-prompt.md，并严格按里面的步骤立即跑一次酒店竞对每日监控。只使用 playwright-edge 真实浏览器 MCP，不要使用 fetch 或 WebFetch。遇到携程登录、验证码或风控就停止并说明。
```
