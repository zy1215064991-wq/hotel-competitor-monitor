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
      sort: readText("sort", "balanced"),
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

请用 WorkBuddy 内置模型执行本任务，不调用第三方大模型接口。酒店竞对数据通过三源 API 组合获取：高德负责地图和候选池，FlyAI/飞猪负责价格，百度负责口碑补充。

## 本地文件

- 本地配置：config/hotel-monitor.json
- 组合采集脚本：scripts/run-api-mvp.ps1
- 安全单次运行入口：scripts/run-once.ps1
- 日报提示词：templates/daily-prompt.md
- API 原始数据目录：data/api-combo
- 历史快照目录：data/history
- 日报输出目录：reports

## 硬约束

- 全链路只使用国内可访问服务：高德地图、FlyAI/飞猪、百度地图、WorkBuddy 内置模型、微信助理 ClawBot，可选企业微信。
- Key 只允许从环境变量读取：AMAP_API_KEY、FLYAI_API_KEY、BAIDU_MAP_AK；是否必需由 config/hotel-monitor.json 和 run-once.ps1 readiness 判断。
- 不要把任何 Key 写进项目文件、提示词、聊天记录、报告或 GitHub。
- 不要浏览 OTA 网页，不要要求用户登录 OTA 网站。
- 不要编造价格、距离、档位、评分、评论数或竞品分层理由。
- 如果用户启用了百度省额度模式，或配置里百度关闭、补充数量为 0 或每日上限为 0，把百度口碑缺口解释为“用户主动省额度”，不要当作失败。

## 执行顺序

1. 确认 config/hotel-monitor.json 存在；如果缺失，提醒用户从 config/hotel-monitor.example.json 复制并填写。
2. 先运行安全单次入口执行正式采集；它会按 config/hotel-monitor.json 自动检查必需 Key 和 readiness，不满足正式采集条件时会停止：

\`\`\`powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\run-once.ps1 -Formal
\`\`\`

3. 如果 scripts/run-once.ps1 -Formal 停止，读取 data/run-once-latest.md 和 data/setup-check-latest.md，最终回复说明 BlockingIssues，不要继续生成日报，不要伪造数据或推送成功。
4. 读取 data/run-once-latest.md，确认 FormalCollection: true 且 Status: ok。
5. 读取 data/api-combo/api-combo-latest-report-input.md。
6. 检查其中的 FlyAI Usage 章节：说明价格源成功、空结果、失败、脱敏价格和 DryRun 状态。
7. 检查其中的 Baidu Usage 章节：说明百度缓存命中、真实 API 调用次数、每日上限和被限额跳过数量；如果百度关闭、补充数量为 0 或每日上限为 0，明确写“百度省额度模式，本次不调用百度”。
8. 检查其中的 Tier Rules 章节：按用户配置解释核心竞品、价格压力、品质压力和替代住宿，不要用默认经验覆盖配置。
9. 检查其中的 History / Yesterday Comparison 章节：有同口径历史时判断涨价、降价、持平；没有历史时只做今日横截面分析。
10. 读取 templates/daily-prompt.md。
11. 使用 WorkBuddy 内置模型生成红黄绿经营日报。
12. 保存 reports/YYYY-MM-DD-hotel-competitor-daily.md。
13. 默认通过微信助理 ClawBot 推送日报全文。
14. 如果 ClawBot 未绑定或 Automation 未启用 ClawBot 通知，不要伪造成功；最终回复写“ClawBot 推送未配置”，并贴出完整日报全文。

## 可选企业微信备用推送

如果用户明确选择企业微信群机器人，并且环境变量 HOTEL_MONITOR_WECOM_WEBHOOK 存在，保存日报后运行：

\`\`\`powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\push-wecom.ps1 -ReportPath .\\reports\\YYYY-MM-DD-hotel-competitor-daily.md
\`\`\`

如果 webhook 缺失，不要伪造推送成功。

## 最终回复

最终回复必须包含：

- 日报全文
- API 组合数据输入路径
- 日报保存路径
- 查询口径
- FlyAI 价格源状态
- 分层规则
- 百度缓存和额度状态
- 历史对比状态
- 推送状态
- run-once 状态
- 如果高德或 FlyAI 数据不完整，明确说明缺口；如果百度因省额度模式关闭，只说明状态，不要写成采集失败`;
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
- SelectionBucket / SelectionScore / SelectionReason：脚本在最终收口前计算的可比性筛选依据，用来解释为什么某家进入最终名单。

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
- 如果 Sort 是 balanced，必须优先参考 SelectionScore 和 SelectionReason 解释竞品为什么入围；不要把替代住宿当成同档核心竞品。
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
  $("#baiduQuotaSafeMode").addEventListener("click", enableBaiduQuotaSafeMode);
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

function enableBaiduQuotaSafeMode() {
  $("#baiduEnabled").value = "false";
  $("#baiduEnrichTopN").value = "0";
  $("#baiduDailyCallLimit").value = "0";
  $("#baiduCacheEnabled").value = "true";
  generateFiles();
  toast("已启用百度省额度模式：正式运行不会调用百度");
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
