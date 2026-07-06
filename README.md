# Hotel Competitor Monitor for WorkBuddy

Local-first Windows setup kit for a WorkBuddy + Playwright MCP Ctrip hotel competitor daily report.

The project helps a hotel operator configure a daily workflow:

1. WorkBuddy opens Ctrip with a real browser.
2. The user scan-logs in once with WeChat or the Ctrip app.
3. WorkBuddy searches and confirms one home hotel plus three competitors.
4. WorkBuddy captures prices, room types, and recent reviews.
5. The built-in WorkBuddy model writes a red/yellow/green operating report.
6. WorkBuddy can push the result through ClawBot or Enterprise WeChat if configured.

No third-party model API key is required. Do not use fetch/WebFetch/curl/requests for Ctrip pages.

## Quick Start

1. Download or clone this repository.
2. Open the folder in WorkBuddy.
3. Ask WorkBuddy to read `workbuddy-start-here.md` and follow it step by step.
4. Or run `install.ps1` manually, restart WorkBuddy, then open `app/index.html`.
5. Complete browser login and hotel confirmation.
6. Copy the generated Automation prompt into WorkBuddy.
7. Run once, then schedule daily `07:30`.

## What Users Fill In

Users should not paste Ctrip hotel URLs. They provide:

- City
- Home hotel name and optional address/business district keyword
- Three competitor names or search keywords
- Default query policy such as room type, adults, nights, and review count

The setup wizard generates a WorkBuddy prompt that asks the AI assistant to search Ctrip with `playwright-edge`, return candidate hotels, and let the user confirm the right branches.

## Repository Contents

```text
install.ps1 Root installer for checks, MCP setup, and verification
workbuddy-start-here.md Entry instructions for WorkBuddy agents
app/        Local setup wizard
templates/  WorkBuddy prompt and report templates
scripts/    Windows setup and verification scripts
docs/       Quick start, login, push, and troubleshooting docs
skill/      Optional skill for agents using this project
```

## Safety Boundaries

- Use WorkBuddy built-in models only.
- Use Ctrip domestic site only.
- Use Playwright MCP with a real Microsoft Edge browser.
- Do not bypass captcha, sliders, SMS verification, login walls, or risk-control pages.
- Do not commit local `ctrip-profile/`, reports, cookies, logs, or secrets.
