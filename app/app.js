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

function readBoolean(id, fallback) {
  const value = $(`#${id}`).value;
  if (value === "true") return true;
  if (value === "false") return false;
  return fallback;
}

function buildConfigJson() {
  return JSON.stringify({
    city: readText("city", "上海"),
    homeHotelName: readText("homeHotelName"),
    poiName: readText("poiName"),
    dataSources: {
      primaryMap: "amap",
      price: "flyai",
      reputation: "baidu"
    },
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
      radiusMeters: readNumber("radiusMeters", 2000),
      maxCandidates: readNumber("maxCandidates", 20),
      brandKeywords: readBrands(),
      maxPrice: readNumber("maxPrice", 0),
      sort: readText("sort", "distance_asc"),
      excludeNameKeywords: ["停车场", "大堂", "前台", "写字楼", "商场", "公寓入口"]
    },
    baidu: {
      enabled: readBoolean("baiduEnabled", true),
      enrichTopN: readNumber("baiduEnrichTopN", 10),
      cacheEnabled: readBoolean("baiduCacheEnabled", true),
      cacheDirectory: readText("baiduCacheDirectory", "data/cache/baidu"),
      cacheTtlDays: readNumber("baiduCacheTtlDays", 30),
      dailyCallLimit: readNumber("baiduDailyCallLimit", 20)
    },
    flyai: {
      enabled: readBoolean("flyaiEnabled", true),
      requestDelayMs: readNumber("flyaiRequestDelayMs", 800),
      maxRetries: readNumber("flyaiMaxRetries", 1)
    },
    tierRules: {
      coreRadiusMeters: readNumber("coreRadiusMeters", 2000),
      pricePressureRatio: readNumber("pricePressureRatio", 0.75),
      qualityRatingThreshold: readNumber("qualityRatingThreshold", 4.7),
      qualityRadiusMeters: readNumber("qualityRadiusMeters", 2500),
      includeAlternativeLodging: readBoolean("includeAlternativeLodging", true)
    },
    history: {
      enabled: readBoolean("historyEnabled", true),
      directory: readText("historyDirectory", "data/history")
    },
    pushMode: readText("pushMode", "clawbot")
  }, null, 2);
}

function buildAutomationPrompt() {
  return `# 酒店竞对每日监控 Automation Prompt

请执行 API 组合链路：高德生成候选池，FlyAI/飞猪补价格，百度补口碑，用 WorkBuddy 内置模型分析，并通过微信助理 ClawBot 推送。

## 执行步骤

1. 确认必需环境变量已配置在 Windows 环境变量中；常规模式需要 AMAP_API_KEY、FLYAI_API_KEY，只有启用百度真实调用且 dailyCallLimit 不为 0 时才需要 BAIDU_MAP_AK。
2. 确认 config/hotel-monitor.json 已存在。
3. 运行安全单次入口执行正式采集；它会先检查 readiness：

\`\`\`powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\run-once.ps1 -Formal
\`\`\`

4. 如果 run-once 停止，读取 data/run-once-latest.md 和 data/setup-check-latest.md，说明 BlockingIssues，不要继续生成日报。
5. 读取 data/run-once-latest.md，确认 FormalCollection: true 且 Status: ok。
6. 读取 data/api-combo/api-combo-latest-report-input.md。
7. 检查 FlyAI Usage，说明价格源是否成功、是否空结果、是否脱敏、是否 DryRun。
8. 检查 Baidu Usage，说明百度缓存命中、真实调用次数、每日上限和被限额跳过的情况。
9. 检查 Tier Rules，按用户配置解释核心竞品、价格压力、品质压力和替代竞品。
10. 读取 templates/daily-prompt.md。
11. 优先使用其中的 History / Yesterday Comparison 判断调价；没有同口径历史时，只输出今日横截面。
12. 生成红黄绿日报并保存到 reports/YYYY-MM-DD-hotel-competitor-daily.md。
13. 默认通过微信助理 ClawBot 推送日报全文。

## 约束

- 不要浏览 OTA 网页。
- 不要要求用户登录 OTA 网站。
- 不要把 AMAP_API_KEY、FLYAI_API_KEY、BAIDU_MAP_AK 写入文件、报告或回复。
- 如果 FlyAI 返回脱敏价格，只按价格带分析。
- 如果 run-once readiness 未通过，不要绕过 scripts/run-once.ps1 直接调用正式采集。
- 如果 ClawBot 未配置，不要伪造推送成功，直接贴出完整日报。`;
}

function buildDailyPrompt() {
  return `# 酒店竞对 API 组合日报 Prompt

你是酒店收益管理和竞品筛选助手。请只基于我提供的 API 组合结果分析，不要编造没有出现在数据里的酒店、价格、地址、距离、档位、评分、评论数或品牌。

## 数据来源

- 高德：本店定位、周边候选、距离、商圈、档位、类型、高德评分。
- FlyAI/飞猪：本店和候选酒店在飞猪生态下的价格。
- FlyAI Usage：价格源是否启用、请求次数、真实调用次数、成功/空结果/失败/脱敏价格数量。
- 百度：入围候选的总评分、评论数、设施评分、卫生评分、服务评分、图片数。
- Baidu Usage：百度是否启用、缓存命中、真实 API 调用次数、每日上限、被限额跳过数量。
- 本地历史库：同查询口径的上一份价格和口碑快照，用于判断涨价、降价、持平。
- Tier Rules：用户配置的核心半径、价格压力阈值、品质评分阈值、品质半径和替代住宿策略。
- Query：本次入住/离店日期、房型、房间数、成人数、儿童数、竞对数量、候选池上限和筛选排序。

## 分析规则

- 高德候选池是主候选池，优先相信高德距离和 POI 类型。
- FlyAI/飞猪价格只代表飞猪生态，不等于全 OTA 最低价。
- 必须说明 FlyAI 价格状态；如果是空结果、失败或脱敏价，不要当作精确价格。
- 百度口碑只用于入围候选补充，不要求所有候选都有百度字段。
- 必须说明百度口碑数据来自 API、缓存、DryRun 还是被限额跳过。
- 如果价格是 ¥1xx、¥3x 这类脱敏价格，只能做价格带判断。
- 优先读取 ## Yesterday Comparison。有同口径历史时，才判断“谁调价了”。
- 没有昨日同口径数据时，不要判断调价方向，只判断今日价格压力。
- 对降价先判断：清库存、抢团客、真降价、或数据不足，不要一看到降价就建议跟。
- 竞品分层必须尊重 ## Tier Rules，不要按你自己的默认经验重分层。
- 分层必须包含：核心竞品、价格压力、品质压力、替代竞品、剔除或暂不纳入。

## 输出格式

请严格按下面结构输出，不要写长篇背景：

查询口径：入住[CheckIn]，离店[CheckOut]，[RoomType]，[Rooms]间，[Adults]成人，[Children]儿童，竞对数量[CompetitorCount]，排序[Sort]

🔴 价格压力与今日风险

- 本店价格信号：
- FlyAI 价格源状态：
- 谁调价了：
- 降价性质判断：
- 今日价格压力最大的 3 家：
- 是否建议立刻跟价：
- 理由：

🟡 竞品分层与口碑压力

- 核心竞品：
- 价格压力：
- 品质压力：
- 替代竞品：
- 剔除或暂不纳入：
- 百度口碑重点信号：
- 百度额度/缓存状态：

🟢 今日优先动作

- 优先动作1：
- 优先动作2：
- 明天继续观察什么：

## 约束

- 不建议违反平台规则、刷评、虚假宣传或绕过风控。
- 不把 FlyAI/飞猪单一渠道价格当作全网最低价。
- 数据不足时直接写“数据不足”，不要补脑。`;
}

function buildRunPrompt() {
  return "请阅读 workbuddy-start-here.md，并按 API 组合流程跑一次酒店竞对每日监控。如缺少 Key，先引导我打开 app/flyai-guide.html、app/amap-guide.html、app/baidu-guide.html。先运行 scripts/run-once.ps1 做安全 DryRun，再读取 data/api-combo/api-combo-latest-report-input.md，按 templates/daily-prompt.md 生成日报并用微信助理 ClawBot 推送。";
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
