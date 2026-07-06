const DEFAULT_COMPETITOR_COUNT = 3;
const MIN_COMPETITOR_COUNT = 1;
const MAX_COMPETITOR_COUNT = 10;

function buildRoles(count = DEFAULT_COMPETITOR_COUNT) {
  return ["本店", ...Array.from({ length: count }, (_, index) => `竞对${index + 1}`)];
}

function createHotelState() {
  return { desiredName: "", keyword: "", confirmed: null };
}

function buildHotels(count = DEFAULT_COMPETITOR_COUNT) {
  return Object.fromEntries(buildRoles(count).map((role) => [role, createHotelState()]));
}

const state = {
  city: "上海",
  competitorCount: DEFAULT_COMPETITOR_COUNT,
  hotels: buildHotels(DEFAULT_COMPETITOR_COUNT),
  query: {
    offsetDays: 7,
    nights: 1,
    rooms: 1,
    adults: 1,
    children: 0,
    childAges: "",
    roomType: "大床房",
    reviewCount: 5,
    scheduleTime: "07:30",
    pushMode: "none"
  },
  generated: {
    competitors: "",
    automation: "",
    daily: ""
  },
  activePreview: "competitors"
};

const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => Array.from(document.querySelectorAll(selector));

function init() {
  renderHotelInputs();
  bindNavigation();
  bindInputs();
  bindActions();
  updateLoginPrompt();
  updateCompletion();
  updateSummary();
}

function renderHotelInputs() {
  const container = $("#hotelInputs");
  const roles = buildRoles(state.competitorCount);
  container.innerHTML = roles
    .map((role) => {
      const item = state.hotels[role] || createHotelState();
      const placeholder = role === "本店" ? "例如 汉庭酒店 前滩 东方体育中心" : "例如 汉庭酒店 江宁路";
      return `
        <div class="hotel-row" data-role="${role}">
          <div class="role">${role}</div>
          <label class="field">
            <span>酒店名或关键词</span>
            <input data-hotel-name="${role}" value="${escapeHtml(item.desiredName)}" placeholder="${placeholder}">
          </label>
          <label class="field">
            <span>地址/商圈辅助</span>
            <input data-hotel-keyword="${role}" value="${escapeHtml(item.keyword)}" placeholder="可选，例如 三林路 / 虹桥站">
          </label>
        </div>
      `;
    })
    .join("");
  bindHotelInputs();
}

function bindNavigation() {
  $$("[data-jump]").forEach((button) => button.addEventListener("click", () => showStep(button.dataset.jump)));
  $$("[data-next]").forEach((button) => button.addEventListener("click", () => showStep(button.dataset.next)));
  $$("[data-prev]").forEach((button) => button.addEventListener("click", () => showStep(button.dataset.prev)));
}

function bindInputs() {
  $("#city").addEventListener("input", (event) => {
    state.city = event.target.value.trim() || "上海";
    updateSummary();
  });
  $("#competitorCount").addEventListener("input", updateSummary);
  $("#homeKeyword").addEventListener("input", (event) => {
    state.hotels["本店"].keyword = event.target.value.trim();
  });
  Object.keys(state.query).forEach((key) => {
    const input = document.getElementById(key);
    if (!input) return;
    input.addEventListener("input", () => {
      const numberKeys = ["offsetDays", "nights", "rooms", "adults", "children", "reviewCount"];
      state.query[key] = numberKeys.includes(key) ? Number(input.value || 0) : input.value.trim();
      updateSummary();
    });
  });
}

function bindHotelInputs() {
  $$("[data-hotel-name]").forEach((input) => {
    input.addEventListener("input", (event) => {
      state.hotels[input.dataset.hotelName].desiredName = event.target.value.trim();
      updateSummary();
    });
  });
  $$("[data-hotel-keyword]").forEach((input) => {
    input.addEventListener("input", (event) => {
      state.hotels[input.dataset.hotelKeyword].keyword = event.target.value.trim();
    });
  });
}

function bindActions() {
  $("#copyLoginPrompt").addEventListener("click", () => copyText($("#loginPrompt").value, "已复制登录验证提示词"));
  $("#applyCompetitorCount").addEventListener("click", () => applyCompetitorCount());
  $("#buildSearchPrompt").addEventListener("click", () => {
    applyCompetitorCount({ silent: true });
    $("#searchPrompt").value = buildCandidateSearchPrompt();
    copyText($("#searchPrompt").value, "已生成并复制候选搜索提示词");
  });
  $("#copySearchPrompt").addEventListener("click", () => {
    applyCompetitorCount({ silent: true });
    copyText($("#searchPrompt").value || buildCandidateSearchPrompt(), "已复制候选搜索提示词");
  });
  $("#parseCandidates").addEventListener("click", () => renderCandidates(parseCandidateTable($("#candidatePaste").value)));
  $("#generateFiles").addEventListener("click", generateFiles);
  $("#downloadCompetitors").addEventListener("click", () => download("competitors.md", state.generated.competitors || buildCompetitorsMarkdown()));
  $("#downloadAutomation").addEventListener("click", () => download("automation-prompt.md", state.generated.automation || buildAutomationPrompt()));
  $("#downloadDaily").addEventListener("click", () => download("daily-prompt.md", state.generated.daily || buildDailyPrompt()));
  $("#copyRunPrompt").addEventListener("click", () => copyText(buildRunOncePrompt(), "已复制单次运行验证提示词"));
  $$("[data-preview]").forEach((button) => {
    button.addEventListener("click", () => {
      state.activePreview = button.dataset.preview;
      $$(".tab").forEach((tab) => tab.classList.toggle("is-active", tab === button));
      updatePreview();
    });
  });
}

function readCompetitorCount() {
  const input = $("#competitorCount");
  const parsed = Number(input.value);
  const safeCount = Number.isFinite(parsed) ? parsed : DEFAULT_COMPETITOR_COUNT;
  return Math.min(MAX_COMPETITOR_COUNT, Math.max(MIN_COMPETITOR_COUNT, Math.round(safeCount)));
}

function applyCompetitorCount({ silent = false } = {}) {
  const input = $("#competitorCount");
  const nextCount = readCompetitorCount();
  input.value = String(nextCount);
  if (nextCount === state.competitorCount) return;

  state.competitorCount = nextCount;

  const nextHotels = {};
  buildRoles(nextCount).forEach((role) => {
    nextHotels[role] = state.hotels[role] || createHotelState();
  });
  state.hotels = nextHotels;
  state.generated = { competitors: "", automation: "", daily: "" };

  renderHotelInputs();
  $("#candidateGrid").innerHTML = "";
  $("#candidatePaste").value = "";
  $("#searchPrompt").value = "";
  updatePreview();
  updateSummary();
  updateCompletion();
  if (!silent) toast(`竞对数量已更新为 ${nextCount} 家`);
}

function showStep(step) {
  $$(".panel").forEach((panel) => panel.classList.toggle("is-active", panel.dataset.step === step));
  $$(".step").forEach((button) => button.classList.toggle("is-active", button.dataset.jump === step));
  updateCompletion();
  updateSummary();
}

function updateLoginPrompt() {
  $("#loginPrompt").value = `请只使用 playwright-browser 真实浏览器 MCP，打开携程首页 https://www.ctrip.com/ 或任意携程酒店详情页。打开后停止自动操作，提示我用微信或携程 App 扫码登录。不要输入账号、密码、手机号、短信验证码，不要处理滑块。等我告诉你“已登录”后，再打开一页携程酒店详情页，检查房型价格是否可见。如果价格可见，回复“登录态验证通过”；如果仍显示“解锁优惠/登录后查看”，回复“携程会话未生效，请重新扫码”。`;
}

function buildCandidateSearchPrompt() {
  const roles = buildRoles(state.competitorCount);
  const hotelLines = roles
    .map((role) => {
      const item = state.hotels[role];
      const name = item.desiredName || "未填写";
      const keyword = item.keyword ? `，辅助关键词：${item.keyword}` : "";
      return `- ${role}：${name}${keyword}`;
    })
    .join("\n");

  return `请只使用 playwright-browser 真实浏览器 MCP，在携程国内站搜索酒店候选，不要使用 fetch、WebFetch、curl、requests 或任何纯 HTTP 抓取方式。

城市：${state.city}

竞对数量：${state.competitorCount} 家

待确认酒店总数：${roles.length} 家（本店 1 家，竞对 ${state.competitorCount} 家）

待确认酒店：
${hotelLines}

操作要求：
1. 使用真实浏览器打开携程酒店搜索或携程首页。
2. 对每个角色分别搜索，尽量返回 3 个候选。
3. 不登录、不输入账号密码、不绕过验证码；如果出现验证码、滑块、短信验证或风控页面，停止并说明。
4. 每个候选需要给出：角色、候选序号、酒店名、地址、评分、hotelId、稳定链接、匹配理由。
5. 稳定链接只保留 cityEnName/cityId/hotelId 等稳定参数，不要包含过期入住日期、tracking id 或 subStamp。

请只输出 Markdown 表格，列名严格为：
| 角色 | 候选序号 | 酒店名 | 地址 | 评分 | hotelId | 稳定链接 | 匹配理由 |`;
}

function parseCandidateTable(text) {
  const rows = [];
  const roles = buildRoles(state.competitorCount);
  text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.startsWith("|") && line.endsWith("|"))
    .forEach((line) => {
      if (/^\|\s*-+/.test(line) || line.includes("候选序号")) return;
      const cells = line
        .slice(1, -1)
        .split("|")
        .map((cell) => cell.trim());
      if (cells.length < 8) return;
      const [role, rank, name, address, rating, hotelId, url, reason] = cells;
      if (!roles.includes(role)) return;
      rows.push({ role, rank, name, address, rating, hotelId, url, reason });
    });
  return rows;
}

function renderCandidates(candidates) {
  const container = $("#candidateGrid");
  if (!candidates.length) {
    container.innerHTML = '<div class="candidate">没有解析到候选。请确认表格列名和顺序是否正确。</div>';
    return;
  }
  container.innerHTML = candidates
    .map((candidate, index) => `
      <article class="candidate" data-candidate="${index}">
        <div class="candidate-title">
          <strong>${candidate.role} · 候选 ${candidate.rank || index + 1}</strong>
          <button data-confirm="${index}">确认</button>
        </div>
        <dl>
          <dt>酒店</dt><dd>${escapeHtml(candidate.name)}</dd>
          <dt>地址</dt><dd>${escapeHtml(candidate.address)}</dd>
          <dt>评分</dt><dd>${escapeHtml(candidate.rating)}</dd>
          <dt>hotelId</dt><dd>${escapeHtml(candidate.hotelId)}</dd>
          <dt>理由</dt><dd>${escapeHtml(candidate.reason)}</dd>
        </dl>
      </article>
    `)
    .join("");
  $$("[data-confirm]").forEach((button) => {
    button.addEventListener("click", () => {
      const candidate = candidates[Number(button.dataset.confirm)];
      state.hotels[candidate.role].confirmed = candidate;
      renderCandidates(candidates);
      $$(`[data-candidate]`).forEach((card) => {
        const current = candidates[Number(card.dataset.candidate)];
        card.classList.toggle("is-confirmed", state.hotels[current.role].confirmed === current);
      });
      updateSummary();
      updateCompletion();
      toast(`${candidate.role} 已确认：${candidate.name}`);
    });
  });
}

function buildCompetitorsMarkdown() {
  const roles = buildRoles(state.competitorCount);
  const lines = [
    "# 酒店竞对清单",
    "",
    "查询口径由 automation-prompt.md 的默认运行口径控制；临时查询可在 WorkBuddy 对话框里自然语言覆盖。",
    "",
    "| 角色 | 酒店名 | 携程页面链接 | 目标房型 | 查询口径 |",
    "| --- | --- | --- | --- | --- |"
  ];

  roles.forEach((role) => {
    const confirmed = state.hotels[role].confirmed;
    const desired = state.hotels[role].desiredName || "未确认";
    const name = confirmed?.name || desired;
    const url = confirmed?.url || "未确认，请先用 WorkBuddy 搜索并确认候选";
    lines.push(`| ${role} | ${name} | ${url} | 使用本次运行目标房型 | 以默认口径或对话覆盖为准 |`);
  });
  lines.push("");
  return lines.join("\n");
}

function buildAutomationPrompt() {
  const q = state.query;
  const roles = buildRoles(state.competitorCount);
  return `# 酒店竞对每日监控 Automation Prompt

请用 WorkBuddy 内置模型执行本任务，不调用任何第三方模型接口，不读取或要求任何接口密钥。优先使用消耗最低的内置模型。

## 本地文件

- 竞对清单：competitors.md
- 日报提示词：daily-prompt.md
- 日报输出目录：reports

## 硬约束

- 全链路只使用国内可访问服务：WorkBuddy 内置模型、携程国内站、微信或企业微信 ClawBot。
- 浏览携程必须使用已配置的真实浏览器 MCP：playwright-browser / mcp__playwright-browser。
- playwright-browser 必须复用固定的持久化浏览器资料目录：ctrip-profile。
- 浏览器必须使用有头模式。不要使用 headless 模式。不要添加 stealth、绕检测、绕风控或伪造登录相关参数。
- 不要使用 fetch、WebFetch、requests、curl 或任何纯 HTTP 抓取方式访问携程页面。
- 不要绕过验证码、滑块、短信验证、登录墙或风控。
- 一天只跑一次；逐家酒店串行打开；每家打开后随机等待 3-7 秒；滚动和点击之间随机等待 1-3 秒；酒店之间随机等待 5-12 秒。

## 默认运行口径

- 入住日期模式：相对天数
- 入住偏移天数：${q.offsetDays}
- 入住晚数：${q.nights}
- 房间数：${q.rooms}
- 成人数：${q.adults}
- 儿童数：${q.children}
- 儿童年龄：${q.childAges || "空"}
- 默认目标房型：${q.roomType}
- 点评条数：${q.reviewCount}
- 默认定时：${q.scheduleTime}
- 推送方式：${formatPushMode(q.pushMode)}
- 监控对象：本店 1 家，竞对 ${state.competitorCount} 家，共 ${roles.length} 家酒店
- 价格口径：携程国内站页面可见到手价/含税费说明

## 对话框本次覆盖参数

用户可以在 WorkBuddy 对话框里用自然语言临时覆盖默认口径。覆盖只对本次运行生效，不写入文件，不影响下一次默认定时任务。

示例：

- 按默认跑
- 这次查 7月20 入住，住2晚，2成人，双床房
- 这次点评抓10条，其他默认

如果用户覆盖参数表达不完整但可推断，则按默认补齐未提到的参数；如果存在歧义，例如只说“下周”，先停下来问清楚。

## 每次运行前登录态自检

正式抓取前，先确定本次实际查询口径，再访问 competitors.md 第一家酒店详情页，用本次查询口径检查登录态。

- 已登录：页面能看到房型价格，或不再出现“解锁优惠/登录后查看/登录查看更多点评/登录页重定向”，继续抓价。
- 已掉线：不要自动重新登录，不要输入账号密码，不要改用其他平台或接口补抓携程价格；停止本次运行。
- 已掉线时推送：携程会话已过期，请重新扫码登录后重新运行酒店竞对每日监控。

## 执行顺序

1. 解析本轮 WorkBuddy 对话是否包含本次覆盖参数。
2. 计算本次实际查询口径。
3. 校验日期、房间数、成人数、儿童数、儿童年龄、房型和点评条数。
4. 读取 competitors.md，解析本店和用户确认的全部竞对酒店。
5. 执行登录态自检。
6. 用 playwright-browser 逐家打开携程详情页。
7. 页面链接或页面查询条件必须设置为本次入住日期、本次离店日期、房间数、成人数、儿童数、儿童年龄。
8. 页面加载后必须检查可见条件是否与本次实际查询口径一致；不一致时先改成一致再抓价。
9. 抓取酒店名、实际查询口径、目标房型可售状态、目标房型或相近房型价格、早餐、取消政策、房态和最新点评。
10. 任意一家查询口径不一致时，不要输出调价/跟价建议，只输出“查询口径未达成，需要重跑”。
11. 读取 daily-prompt.md 生成红黄绿日报。
12. 保存 reports/YYYY-MM-DD-raw.md 和 reports/YYYY-MM-DD-hotel-competitor-daily.md。
13. 执行推送策略。
14. 最终回复必须包含日报全文、保存路径、抓取状态、本次实际查询口径、参数来源和推送状态。

## 推送策略

- 如果推送方式是“只保存本地”：不要推送，只保存 reports 文件，并在最终回复里写“推送未配置”。
- 如果推送方式是“WorkBuddy ClawBot”：最终回复必须包含完整日报全文，让 WorkBuddy Automation / ClawBot 推送最终回复；如果桌面端没有配置 ClawBot，写“ClawBot 推送未配置”。
- 如果推送方式是“企业微信群机器人”：保存日报后，检查环境变量 HOTEL_MONITOR_WECOM_WEBHOOK。
- 企业微信群机器人已配置时，运行：

\`\`\`powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\push-wecom.ps1 -ReportPath .\\reports\\YYYY-MM-DD-hotel-competitor-daily.md
\`\`\`

- 企业微信群机器人未配置时，不要伪造推送成功；最终回复写“企业微信推送未配置：缺少 HOTEL_MONITOR_WECOM_WEBHOOK”。
`;
}

function buildDailyPrompt() {
  const roles = buildRoles(state.competitorCount);
  return `# 酒店竞对每日监控日报 Prompt

你是酒店收益管理和点评运营助手。请只基于我提供的携程抓取数据分析，不要编造没有出现在数据里的价格、房型、点评或原因。

## 输入数据

- 本店和用户确认的 ${state.competitorCount} 家竞对酒店名、携程页面链接、目标房型、查询口径
- 本次监控对象总数：${roles.length} 家酒店
- 本次实际查询口径：入住日期、离店日期、房间数、成人数、儿童数、目标房型、点评条数、参数来源
- 每家酒店在统一口径下抓到的价格、可售房型、房态/早餐/取消政策等可见信息
- 每家酒店最新点评内容、评分、点评时间
- 如有历史日报，会提供昨日价格和昨日结论用于判断调价

## 分析规则

- 所有比较必须使用同一查询口径，并以自动化解析出的本次实际查询口径为准。
- 如果抓取数据里的页面实际查询口径与本次实际查询口径不一致，不要输出调价/跟价建议，只指出“查询口径未达成，需要重跑”。
- 价格判断优先看同目标房型；如果目标房型不可售，再说明使用了哪个相近房型替代。
- 判断“谁调价了”时，必须对比昨日同口径价格；没有昨日价格时，只能写“无法判断是否调价”。
- 对竞对降价不要直接建议跟价，先判断更可能是：清库存、抢团客、真降价，或数据不足。
- 点评分析只提炼最近点评中反复出现或高影响的事实，不要把单条偶发反馈夸大成趋势。

## 输出格式

请只回答下面三个经营问题，并严格按红黄绿三色输出：

🔴 调价与跟价判断

- 谁调价了：
- 是否建议跟：
- 如果竞对降价，判断属于：清库存 / 抢团客 / 真降价 / 数据不足
- 理由：

🟡 点评卖点与短板

- 竞对最近被夸什么，可放大的卖点：
- 竞对最近被骂什么，本店可补位的短板：
- 本店点评需要优先关注的问题：

🟢 今日优先动作

- 优先动作1：
- 优先动作2：
- 预期影响：

## 约束

- 不输出长篇背景分析。
- 不输出与上述三个问题无关的内容。
- 不建议违反平台规则、刷评、虚假宣传或绕过风控。
`;
}

function buildRunOncePrompt() {
  return "请读取本目录的 automation-prompt.md，并严格按里面的步骤立即跑一次酒店竞对每日监控。只使用 playwright-browser 真实浏览器 MCP，不要使用 fetch 或 WebFetch。遇到携程登录、验证码或风控就停止并说明。";
}

function generateFiles() {
  state.generated.competitors = buildCompetitorsMarkdown();
  state.generated.automation = buildAutomationPrompt();
  state.generated.daily = buildDailyPrompt();
  updatePreview();
  updateSummary();
  toast("配置文件预览已生成");
}

function updatePreview() {
  const content = state.generated[state.activePreview] || {
    competitors: buildCompetitorsMarkdown(),
    automation: buildAutomationPrompt(),
    daily: buildDailyPrompt()
  }[state.activePreview];
  $("#filePreview").value = content;
}

function updateSummary() {
  const roles = buildRoles(state.competitorCount);
  const confirmedCount = roles.filter((role) => state.hotels[role].confirmed).length;
  $("#summary").innerHTML = `
    <strong>当前配置</strong>
    <p>城市：${escapeHtml(state.city)}；竞对数量：${state.competitorCount} 家；已确认酒店：${confirmedCount}/${roles.length}；默认房型：${escapeHtml(state.query.roomType)}；${state.query.rooms}间，${state.query.adults}成人，${state.query.children}儿童；未来第 ${state.query.offsetDays} 天入住，住 ${state.query.nights} 晚；每天 ${state.query.scheduleTime}；推送方式：${escapeHtml(formatPushMode(state.query.pushMode))}。</p>
  `;
}

function formatPushMode(mode) {
  return {
    none: "只保存本地",
    clawbot: "WorkBuddy ClawBot",
    wecom: "企业微信群机器人"
  }[mode] || "只保存本地";
}

function updateCompletion() {
  const roles = buildRoles(state.competitorCount);
  const checks = $$("[data-check]").filter((input) => input.checked).length;
  const confirmed = roles.filter((role) => state.hotels[role].confirmed).length;
  const queryDone = state.query.roomType && state.query.reviewCount > 0 ? 1 : 0;
  const generated = state.generated.automation ? 1 : 0;
  const done = (checks === 4 ? 1 : 0) + (confirmed === roles.length ? 1 : 0) + queryDone + generated;
  $("#completionStatus").textContent = `${done}/4 已完成`;
}

function download(filename, content) {
  const blob = new Blob([content], { type: "text/markdown;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(url);
}

async function copyText(text, message) {
  const content = text || "";
  if (!content.trim()) {
    toast("没有可复制的内容");
    return;
  }
  try {
    await navigator.clipboard.writeText(content);
  } catch {
    const area = document.createElement("textarea");
    area.value = content;
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

function escapeHtml(value) {
  return String(value || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

document.addEventListener("DOMContentLoaded", init);
