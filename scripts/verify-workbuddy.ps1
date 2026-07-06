param(
  [string]$ConfigDir = "$env:USERPROFILE\.workbuddy"
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$profileDir = Join-Path $repoRoot "ctrip-profile"
$paths = @(
  (Join-Path $ConfigDir ".mcp.json"),
  (Join-Path $ConfigDir "mcp.json")
)

Write-Host "WorkBuddy 配置目录：$ConfigDir"
Write-Host "携程登录态目录：$profileDir"
Write-Host ""

foreach ($path in $paths) {
  if (-not (Test-Path -LiteralPath $path)) {
    Write-Host "[缺失] $path"
    continue
  }

  $bytes = [System.IO.File]::ReadAllBytes($path)
  $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
  $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
  $json = $text | ConvertFrom-Json
  $hasServer = $null -ne $json.mcpServers.'playwright-edge'

  Write-Host "[正常] $path"
  Write-Host "  JSON 合法：是"
  Write-Host "  UTF-8 BOM：$hasBom"
  Write-Host "  playwright-edge: $hasServer"
}

if (-not (Test-Path -LiteralPath $profileDir)) {
  New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
  Write-Host "[已创建] $profileDir"
} else {
  Write-Host "[正常] 登录态目录已存在"
}

Write-Host ""
Write-Host "下一步："
Write-Host "1. 完全退出并重启 WorkBuddy。"
Write-Host "2. 打开 app/index.html。"
Write-Host "3. 把登录验证提示词复制到 WorkBuddy。"
Write-Host "4. 扫码登录携程，并确认酒店房价可见。"
