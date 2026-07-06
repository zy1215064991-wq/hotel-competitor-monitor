param(
  [string]$ConfigDir = "$env:USERPROFILE\.workbuddy",
  [ValidateSet("auto", "chrome", "edge")]
  [string]$Browser = "auto"
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$profileRoot = Join-Path $repoRoot "ctrip-profile"
$nodeNpx = "C:\Program Files\nodejs\npx.cmd"
$chromeCandidates = @(
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
  "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
)
$edgeCandidates = @(
  "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
  "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
)

function Get-FirstExistingPath {
  param([string[]]$Paths)
  $Paths | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

if (-not (Test-Path -LiteralPath $nodeNpx)) {
  throw "未在 $nodeNpx 找到 npx。请先安装 Windows 版 Node.js，或在 setup-workbuddy-mcp.ps1 中更新路径。"
}

function Resolve-BrowserChoice {
  $chromePath = Get-FirstExistingPath -Paths $chromeCandidates
  $edgePath = Get-FirstExistingPath -Paths $edgeCandidates

  if ($Browser -eq "chrome") {
    if (-not $chromePath) { throw "未找到 Chrome 浏览器。请先安装 Chrome，或改用 -Browser edge。" }
    return [ordered]@{ Name = "chrome"; DisplayName = "Google Chrome"; BrowserArg = "chrome"; ExecutablePath = $chromePath }
  }

  if ($Browser -eq "edge") {
    if (-not $edgePath) { throw "未找到微软 Edge 浏览器。请先安装 Edge，或改用 -Browser chrome。" }
    return [ordered]@{ Name = "edge"; DisplayName = "Microsoft Edge"; BrowserArg = "msedge"; ExecutablePath = $edgePath }
  }

  if ($chromePath) {
    return [ordered]@{ Name = "chrome"; DisplayName = "Google Chrome"; BrowserArg = "chrome"; ExecutablePath = $chromePath }
  }

  if ($edgePath) {
    return [ordered]@{ Name = "edge"; DisplayName = "Microsoft Edge"; BrowserArg = "msedge"; ExecutablePath = $edgePath }
  }

  throw "未找到 Chrome 或 Edge 浏览器。请先安装其中一个浏览器。"
}

$browserChoice = Resolve-BrowserChoice
$profileDir = Join-Path $profileRoot $browserChoice.Name
$browserOutputDir = Join-Path $repoRoot "output\browser\$($browserChoice.Name)"

New-Item -ItemType Directory -Force -Path $ConfigDir, $profileRoot, $profileDir, $browserOutputDir | Out-Null

$config = [ordered]@{
  mcpServers = [ordered]@{
    "playwright-browser" = [ordered]@{
      type = "stdio"
      command = $nodeNpx
      args = @(
        "-y",
        "@playwright/mcp@latest",
        "--browser=$($browserChoice.BrowserArg)",
        "--executable-path=$($browserChoice.ExecutablePath)",
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
      description = "Playwright MCP for WorkBuddy hotel competitor monitoring. Uses real browser and persistent Ctrip login profile."
    }
  }
  permissions = [ordered]@{
    allow = @("mcp__playwright-browser")
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
Write-Host "已选择浏览器：$($browserChoice.DisplayName)"
Write-Host "浏览器路径：$($browserChoice.ExecutablePath)"
Write-Host "携程登录态目录：$profileDir"
Write-Host "配置完成。请完全重启 WorkBuddy，然后打开 app/index.html，完成携程扫码登录。"
