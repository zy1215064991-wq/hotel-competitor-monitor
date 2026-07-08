const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => Array.from(document.querySelectorAll(selector));

const state = {
  activePreview: "config",
  generated: {
    config: "",
    automation: "",
    daily: ""
  }
};

function init() {
  bindActions();
  generateFiles();
}

function readNumber(id, fallback) {
  const value = Number($(`#${id}`).value);
  return Number.isFinite(value) ? value : fallback;
}

function readText(id, fallback = "") {
  return $(`#${id}`).value.trim() || fallback;
}

function readBrands() {
  return readText("brandKeywords")
    .split(/[,，]/)
    .map((item) => item.trim())
    .filter(Boolean);
}

function buildConfigJson() {
  return JSON.stringify({
    city: readText("city", "上海"),
    homeHotelName: readText("homeHotelName"),
    poiName: readText("poiName"),
    query: {
      offsetDays: readNumber("offsetDays", 7),
      nights: readNumber("nights", 1),
      rooms: readNumber("rooms", 1),
      adults: readNumber("adults", 1),
      children: readNumber("children", 0),
      roomType: readText("roomType", "大床房")
    },
    discovery: {
      competitorCount: readNumber("competitorCount", 5),
      brandKeywords: readBrands(),
      maxPrice: readNumber("maxPrice", 0),
      sort: readText("sort", "distance_asc")
    },
    pushMode: readText("pushMode", "clawbot")
  }, null, 2);
}

function buildAutomationPrompt() {
  return `# 酒店竞对每日监控 Automation Prompt

请执行 FlyAI MVP 链路：运行本地脚本获取飞猪酒店数据，用 WorkBuddy 内置模型分析，并通过微信助理 ClawBot 推送。

## 执行步骤

1. 确认 FLYAI_API_KEY 已配置在 Windows 环境变量。
2. 确认 config/hotel-monitor.json 已存在。
3. 运行：

\`\`\`powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\run-flyai-mvp.ps1
\`\`\`

4. 读取 data/flyai/latest-report-input.md。
5. 读取 templates/daily-prompt.md。
6. 生成红黄绿日报并保存到 reports/YYYY-MM-DD-hotel-competitor-daily.md。
7. 默认通过微信助理 ClawBot 推送日报全文。

## 约束

- 不要浏览 OTA 网页。
- 不要要求用户登录 OTA 网站。
- 不要把 FLYAI_API_KEY 写入文件、报告或回复。
- 如果 FlyAI 返回脱敏价格，只按价格带分析。
- 如果 ClawBot 未配置，不要伪造推送成功，直接贴出完整日报。`;
}

function buildDailyPrompt() {
  return `# FlyAI/飞猪酒店竞对日报 Prompt

你是酒店收益管理和竞品筛选助手。请只基于 FlyAI/飞猪搜索结果分析，不要编造数据。

请按以下结构输出：

🔴 价格压力与今日风险

- 本店价格信号：
- 今日价格压力最大的 3 家：
- 是否建议立刻跟价：
- 理由：

🟡 竞品分层

- 核心竞品：
- 价格压力：
- 延展竞品：
- 替代竞品：
- 剔除或暂不纳入：

🟢 今日优先动作

- 优先动作1：
- 优先动作2：
- 明天继续观察什么：

约束：FlyAI/飞猪是单一渠道；脱敏价格只能作为价格带；数据不足时直接说明。`;
}

function buildRunPrompt() {
  return "请阅读 workbuddy-start-here.md，并按 FlyAI MVP 流程跑一次酒店竞对每日监控。先运行 scripts/run-flyai-mvp.ps1，读取 data/flyai/latest-report-input.md，再按 templates/daily-prompt.md 生成日报并用微信助理 ClawBot 推送。";
}

function generateFiles() {
  state.generated.config = buildConfigJson();
  state.generated.automation = buildAutomationPrompt();
  state.generated.daily = buildDailyPrompt();
  updatePreview();
  toast("预览已生成");
}

function updatePreview() {
  $("#filePreview").value = state.generated[state.activePreview] || "";
}

function bindActions() {
  $("#generateFiles").addEventListener("click", generateFiles);
  $("#downloadConfig").addEventListener("click", () => download("hotel-monitor.json", state.generated.config || buildConfigJson(), "application/json"));
  $("#downloadAutomation").addEventListener("click", () => download("automation-prompt.md", state.generated.automation || buildAutomationPrompt()));
  $("#downloadDaily").addEventListener("click", () => download("daily-prompt.md", state.generated.daily || buildDailyPrompt()));
  $("#copyRunPrompt").addEventListener("click", () => copyText(buildRunPrompt(), "已复制运行提示词"));
  $$("[data-preview]").forEach((button) => {
    button.addEventListener("click", () => {
      state.activePreview = button.dataset.preview;
      $$(".tab").forEach((tab) => tab.classList.toggle("is-active", tab === button));
      updatePreview();
    });
  });
}

function download(filename, content, type = "text/markdown;charset=utf-8") {
  const blob = new Blob([content], { type });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(url);
}

async function copyText(text, message) {
  try {
    await navigator.clipboard.writeText(text);
  } catch {
    const area = document.createElement("textarea");
    area.value = text;
    document.body.appendChild(area);
    area.select();
    document.execCommand("copy");
    area.remove();
  }
  toast(message);
}

function toast(message) {
  const node = $("#toast");
  node.textContent = message;
  node.classList.add("show");
  setTimeout(() => node.classList.remove("show"), 2200);
}

document.addEventListener("DOMContentLoaded", init);
