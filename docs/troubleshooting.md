# 排障说明

## 缺少 API Key

脚本正式运行需要：

- `AMAP_API_KEY`
- `FLYAI_API_KEY`
- `BAIDU_MAP_AK`

检查方式：

```powershell
if ($env:AMAP_API_KEY) { "AMAP_API_KEY 已配置" } else { "缺少 AMAP_API_KEY" }
if ($env:FLYAI_API_KEY) { "FLYAI_API_KEY 已配置" } else { "缺少 FLYAI_API_KEY" }
if ($env:BAIDU_MAP_AK) { "BAIDU_MAP_AK 已配置" } else { "缺少 BAIDU_MAP_AK" }
```

不要把 Key 明文打印到群里、报告里或 GitHub。

## FlyAI CLI 不存在

正式采集价格前需要能运行 `flyai`：

```powershell
Get-Command flyai
```

如果找不到，安装：

```powershell
npm i -g @fly-ai/flyai-cli --registry=https://registry.npmmirror.com
```

安装后重新打开 WorkBuddy 或 PowerShell。

## DryRun 成功但正式运行失败

DryRun 只验证本地配置和输出链路，不调用真实 API。正式运行失败时按来源排查：

- 高德失败：检查 `AMAP_API_KEY` 是否有 Web 服务权限、是否达到配额。
- FlyAI 失败：检查 `FLYAI_API_KEY` 是否有效、`flyai search-hotel` 是否可用。
- 百度失败：检查 `BAIDU_MAP_AK` 是否有地点检索/详情权限、是否达到并发或配额限制。

## 价格显示脱敏

如果 FlyAI 返回 `¥1xx`、`¥3x` 这类价格，只能当作价格带信号。通常说明 Key、权限或返回字段不完整。不要把脱敏价格写成精确价格结论。

## 候选酒店噪音多

在 `config/hotel-monitor.json` 或本地向导中调整：

- 缩小 `discovery.radiusMeters`。
- 降低 `discovery.maxCandidates`。
- 增加 `discovery.excludeNameKeywords`，例如停车场、大堂、写字楼、公寓、民宿。
- 补充 `discovery.brandKeywords`，例如全季、汉庭、亚朵、智选假日。

## 分层不符合你的经营判断

优先调整 `tierRules`：

```json
"tierRules": {
  "coreRadiusMeters": 2000,
  "pricePressureRatio": 0.75,
  "qualityRatingThreshold": 4.7,
  "qualityRadiusMeters": 2500,
  "includeAlternativeLodging": true
}
```

常见调整：

- 想让核心竞品更严格：调小 `coreRadiusMeters`。
- 价格敏感市场：调高 `pricePressureRatio`，例如 `0.85`。
- 只看非常强的口碑压力：调高 `qualityRatingThreshold`。
- 不想看到公寓/民宿：把 `includeAlternativeLodging` 改成 `false`。

## 查询口径不一致

优先在本地向导 `app/index.html` 修改：

- 入住日期或未来第几天。
- 入住晚数。
- 房型。
- 成人数、儿童数、房间数。
- 竞对数量。

保存新的 `config/hotel-monitor.json` 后重新运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-api-mvp.ps1
```

## 日报说没有昨日同口径数据

第一次正式运行时这是正常现象。脚本只有在 `data/history/` 中找到同查询口径的上一份历史快照时，才会判断涨价、降价、持平。

检查历史快照：

```powershell
Get-ChildItem .\data\history
```

如果你改了本店、城市、POI、入住偏移、房型、房间数或住客数，查询口径会变化，脚本不会拿旧口径硬比。

如果不想做历史对比，在 `config/hotel-monitor.json` 中设置：

```json
"history": {
  "enabled": false,
  "directory": "data/history"
}
```

## 推送未到微信

个人微信优先使用 WorkBuddy 自带微信助理 ClawBot，需要在桌面端图形界面扫码绑定。脚本不能代替你绑定个人微信。

如果使用企业微信群机器人，检查：

- `HOTEL_MONITOR_WECOM_WEBHOOK` 是否存在。
- webhook 是否完整。
- 是否重新启动了 WorkBuddy。
- `scripts/push-wecom.ps1 -DryRun` 是否能生成预览。

详细步骤见 `docs/push-setup.md`。
