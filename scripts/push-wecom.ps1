param(
  [string]$ReportPath,
  [string]$Title = "酒店竞对每日监控日报",
  [string]$Webhook = $env:HOTEL_MONITOR_WECOM_WEBHOOK,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding

if (-not $Webhook) {
  throw "未设置 HOTEL_MONITOR_WECOM_WEBHOOK。请先在系统环境变量里配置企业微信群机器人 webhook。"
}

if ($Webhook -notmatch '^https://qyapi\.weixin\.qq\.com/cgi-bin/webhook/send\?key=') {
  throw "HOTEL_MONITOR_WECOM_WEBHOOK 格式不正确，应以 https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key= 开头。"
}

if (-not $ReportPath) {
  $reportDir = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "reports"
  $latestReport = Get-ChildItem -Path $reportDir -Filter "*hotel-competitor-daily.md" -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  if (-not $latestReport) {
    throw "未提供 ReportPath，且 reports 目录下没有找到 *hotel-competitor-daily.md。"
  }
  $ReportPath = $latestReport.FullName
}

if (-not (Test-Path -LiteralPath $ReportPath)) {
  throw "日报文件不存在：$ReportPath"
}

$content = [System.IO.File]::ReadAllText((Resolve-Path $ReportPath), [System.Text.Encoding]::UTF8).Trim()
if (-not $content) {
  throw "日报文件为空：$ReportPath"
}

$resolvedReportPath = Resolve-Path $ReportPath
$message = @"
# $Title

$content

---
本地完整报告：$resolvedReportPath
"@

$utf8 = [System.Text.Encoding]::UTF8
$wecomMarkdownLimitBytes = 4096
$reservedBytes = 196
$maxBytes = $wecomMarkdownLimitBytes - $reservedBytes
if ($utf8.GetByteCount($message) -gt $maxBytes) {
  $suffix = "`n`n---`n内容较长，已截断。请查看本地完整报告：$resolvedReportPath"
  $suffixBytes = $utf8.GetByteCount($suffix)
  $builder = New-Object System.Text.StringBuilder
  foreach ($char in $message.ToCharArray()) {
    $candidate = $builder.ToString() + $char
    if ($utf8.GetByteCount($candidate) + $suffixBytes -gt $maxBytes) {
      break
    }
    [void]$builder.Append($char)
  }
  $message = $builder.ToString().TrimEnd() + $suffix
}

$payload = @{
  msgtype = "markdown"
  markdown = @{
    content = $message
  }
} | ConvertTo-Json -Depth 5

if ($DryRun) {
  Write-Host "企业微信推送预览："
  Write-Host $payload
  exit 0
}

$response = Invoke-RestMethod -Method Post -Uri $Webhook -ContentType "application/json; charset=utf-8" -Body $payload

if ($response.errcode -ne 0) {
  throw "企业微信推送失败：errcode=$($response.errcode), errmsg=$($response.errmsg)"
}

Write-Host "企业微信推送成功：$ReportPath"
