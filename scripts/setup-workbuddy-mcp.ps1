param(
  [string]$ConfigDir = "$env:USERPROFILE\.workbuddy"
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$profileDir = Join-Path $repoRoot "ctrip-profile"
$browserOutputDir = Join-Path $repoRoot "output\browser"
$nodeNpx = "C:\Program Files\nodejs\npx.cmd"
$edgeCandidates = @(
  "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
  "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
)
$edgePath = $edgeCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

if (-not $edgePath) {
  throw "未找到微软 Edge 浏览器。请先安装 Edge，或在 setup-workbuddy-mcp.ps1 中更新浏览器路径。"
}

if (-not (Test-Path -LiteralPath $nodeNpx)) {
  throw "未在 $nodeNpx 找到 npx。请先安装 Windows 版 Node.js，或在 setup-workbuddy-mcp.ps1 中更新路径。"
}

New-Item -ItemType Directory -Force -Path $ConfigDir, $profileDir, $browserOutputDir | Out-Null

$config = [ordered]@{
  mcpServers = [ordered]@{
    "playwright-edge" = [ordered]@{
      type = "stdio"
      command = $nodeNpx
      args = @(
        "-y",
        "@playwright/mcp@latest",
        "--browser=msedge",
        "--executable-path=$edgePath",
        "--user-data-dir=$profileDir",
        "--output-dir=$browserOutputDir",
        "--output-mode=file",
        "--save-session",
        "--shared-browser-context",
        "--viewport-size=1360x900",
        "--timeout-action=15000",
        "--timeout-navigation=90000"
      )
      env = [ordered]@{
        npm_config_registry = "https://registry.npmmirror.com"
        PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1"
      }
      description = "Playwright MCP for WorkBuddy hotel competitor monitoring. Uses real Microsoft Edge and persistent Ctrip login profile."
    }
  }
  permissions = [ordered]@{
    allow = @("mcp__playwright-edge")
  }
}

$json = $config | ConvertTo-Json -Depth 10
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

foreach ($name in @(".mcp.json", "mcp.json")) {
  $path = Join-Path $ConfigDir $name
  if (Test-Path -LiteralPath $path) {
    $backup = "$path.bak-$(Get-Date -Format yyyyMMddHHmmss)"
    Copy-Item -LiteralPath $path -Destination $backup -Force
    Write-Host "已备份现有 $name 到 $backup"
  }
  [System.IO.File]::WriteAllText($path, $json, $utf8NoBom)
  Write-Host "已写入 $path"
}

Write-Host ""
Write-Host "配置完成。请完全重启 WorkBuddy，然后打开 app/index.html，完成携程扫码登录。"
