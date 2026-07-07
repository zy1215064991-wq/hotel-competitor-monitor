# 酒店竞对每日监控 WorkBuddy 部署包

这是一个面向 Windows + WorkBuddy 的本地部署包，用来搭建“酒店竞对每日监控”最小可用版本。

目标流程：

1. WorkBuddy 用真实的 Chrome 或 Edge 浏览器打开携程国内站。
2. 用户首次在携程登录页自行选择登录方式，人工登录一次。
3. 用户输入城市、本店名称、商圈或地标，以及需要监控的竞对数量，不需要手填携程页面链接。
4. WorkBuddy 在携程搜索候选酒店，也可以通过列表页侧边栏自动发现竞对，用户确认正确酒店。
5. WorkBuddy 抓取价格、房型和最新点评。
6. WorkBuddy 内置模型生成红黄绿三色经营日报。
7. 默认通过微信助理 ClawBot 把日报推送到微信侧；企业微信群机器人作为可选替代。

本项目不需要第三方模型接口密钥，不配置 DeepSeek/OpenAI 等外部模型，不依赖 VPN 或翻墙服务。

## 快速开始

推荐方式：

1. 下载或克隆本项目到 Windows 电脑。
2. 用 WorkBuddy 打开这个文件夹。
3. 对 WorkBuddy 说：

```text
请阅读 workbuddy-start-here.md，并按步骤帮我部署。
```

WorkBuddy 会按入口文档一步步检查环境、配置 Playwright 浏览器连接器、提示你重启 WorkBuddy、打开携程登录页让你自行选择登录方式，并引导你完成本店和竞对配置。

安装脚本会先备份已有 WorkBuddy MCP 配置，并只新增或更新 `playwright-browser`，不会清空你原来配置的其他 MCP 连接器。

手动方式：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

浏览器默认使用 `auto` 模式：优先使用 Chrome，未安装 Chrome 时回退 Edge。也可以手动指定：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Browser chrome
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Browser edge
```

然后完全重启 WorkBuddy，打开：

```text
app/index.html
```

## 用户需要填写什么

用户不需要粘贴携程酒店页面链接。最省事的方式是使用“自动发现竞对”：填写本店和一个位置、商圈或地标，例如“江桥万达”，让 WorkBuddy 在携程列表页用侧边栏筛选品牌、价格、距离和评分，生成候选后再由用户确认。

用户通常只需要填写：

- 城市
- 本店酒店名
- 本店可选地址、商圈或地标关键词
- 竞对数量
- 自动发现竞对条件：位置/商圈/地标、可选品牌、可选价格带、距离范围
- 默认查询口径：房型、成人数、儿童数、入住偏移天数、入住晚数、点评条数

如果用户已经知道竞对是谁，也可以切换为“手动指定酒店关键词”，逐家输入竞对名称或关键词。

前端向导会生成候选搜索提示词，让 WorkBuddy 用 `playwright-browser` 浏览器连接器在携程真实浏览器里搜索候选酒店，并输出候选表格。自动发现竞对时，提示词会要求 WorkBuddy 先搜索位置或地标，再使用携程侧边栏进行品牌筛选、价格筛选、距离和评分筛选，同时排除本店。用户确认后，向导会生成 WorkBuddy 后续自动化需要的配置文件。

## 目录说明

```text
install.ps1                根目录安装入口：检查环境、配置浏览器连接器、验证结果
workbuddy-start-here.md    给 WorkBuddy 读取的部署入口说明
app/                       本地配置向导，直接打开 app/index.html
templates/                 WorkBuddy 自动化提示词和日报模板
scripts/                   Windows 配置与验证脚本
docs/                      快速开始、首次登录、推送和排障说明
skill/                     可选的 WorkBuddy/Codex skill 说明
```

## 会生成哪些文件

完成向导后会生成：

- `competitors.md`：本店 + 用户指定数量的竞对清单
- `automation-prompt.md`：WorkBuddy 自动化抓取与分析提示词
- `daily-prompt.md`：红黄绿三色日报分析模板

这些文件放到你的 WorkBuddy 项目目录后，可以先手动单次运行验证，再配置每天 07:30 自动运行。

## 安全边界

- 只使用 WorkBuddy 内置模型。
- 只使用携程国内站。
- 携程页面必须通过 Playwright 浏览器连接器和真实 Chrome 或 Edge 浏览器访问。
- 不使用 fetch、WebFetch、curl、requests 等纯 HTTP 方式抓携程页面。
- 不自动输入账号、密码、手机号、短信验证码。
- 不绕过验证码、滑块、登录墙或风控页面。
- 不把 `ctrip-profile/`、报告、cookies、日志、密钥提交到 GitHub。

## 登录态说明

携程价格可能需要登录才能看到。本项目使用固定的 `ctrip-profile/` 目录保存浏览器登录态。

首次运行时，WorkBuddy 会直达携程登录页并停下来，让你自行选择登录方式完成一次人工登录。之后每天运行前会先检查登录态：

- 如果价格可见：继续抓取。
- 如果会话过期：停止运行，并提醒你重新人工登录。

## 推送和定时

WorkBuddy Automation 定时任务和微信助理 ClawBot 绑定如果只能在桌面端 GUI 中配置，本项目不会假装自动完成。

推送设置请看：

- `docs/push-setup.md`：完整推送说明，默认推荐微信助理 ClawBot，也包含企业微信群机器人。
- `docs/clawbot-setup.md`：ClawBot 图形界面绑定步骤。

企业微信群机器人可以用环境变量自动推送：

```powershell
setx HOTEL_MONITOR_WECOM_WEBHOOK "https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=替换成你的key"
```

建议默认定时：

```text
每天 07:30
```

## 手动验证

运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-workbuddy.ps1
```

通过标准：

- `.workbuddy\.mcp.json` 或 `.workbuddy\mcp.json` 是合法 JSON。
- 文件没有 UTF-8 BOM。
- 存在 `playwright-browser` 浏览器连接器。
- 项目根目录下存在 `ctrip-profile` 登录态目录。

如果验证不通过，请先看 `docs/troubleshooting.md`。
