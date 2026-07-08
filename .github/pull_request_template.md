## 改动说明

- 

## 本地验证

- [ ] 已运行 `npm test`
- [ ] 如改到 PowerShell/配置/数据输出/安全边界，已运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-local.ps1`

## 安全确认

- [ ] 未提交任何 Key、token、webhook 或真实酒店经营数据
- [ ] 未提交 `config/hotel-monitor.json`、`.env`、`data/`、`reports/`、`output/`
- [ ] 未运行 `run-once.ps1 -Formal`
- [ ] 未把正式 API 调用加入 CI、测试或默认脚本

## 同步确认

- [ ] 如果改了模板，已同步前端下载版提示词
- [ ] 如果改了配置字段，已同步示例配置、向导、文档和测试
- [ ] 如果改了数据源/额度/推送策略，已同步 `docs/`、`workbuddy-start-here.md` 和 `skill/SKILL.md`
