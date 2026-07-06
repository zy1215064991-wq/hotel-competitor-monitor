param(
  [string]$ConfigDir = "$env:USERPROFILE\.workbuddy",
  [switch]$SkipMcpWrite,
  [switch]$OpenWizard
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding

$repoRoot = $PSScriptRoot
$setupScript = Join-Path $repoRoot "scripts\setup-workbuddy-mcp.ps1"
$verifyScript = Join-Path $repoRoot "scripts\verify-workbuddy.ps1"
$wizardPath = Join-Path $repoRoot "app\index.html"

function Write-Step {
  param([string]$Text)
  Write-Host ""
  Write-Host "==> $Text"
}

function Test-CommandAvailable {
  param([string]$Name)
  $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

Write-Host "酒店竞对每日监控安装脚本"
Write-Host "项目目录：$repoRoot"
Write-Host "WorkBuddy 配置目录：$ConfigDir"

Write-Step "检查本机环境"
if ($env:OS -and $env:OS -notlike "*Windows*") {
  Write-Warning "This kit is designed for Windows WorkBuddy desktops."
}

if (-not (Test-CommandAvailable "powershell")) {
  throw "PowerShell was not found in PATH."
}

$edgeCandidates = @(
  "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
  "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
)
$edgePath = $edgeCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $edgePath) {
  throw "Microsoft Edge was not found. Install Microsoft Edge before continuing."
}
Write-Host "[ok] Microsoft Edge: $edgePath"

$nodeNpx = "C:\Program Files\nodejs\npx.cmd"
if (-not (Test-Path -LiteralPath $nodeNpx)) {
  throw "npx was not found at $nodeNpx. Install Node.js for Windows before continuing."
}
Write-Host "[ok] npx: $nodeNpx"

if (-not (Test-Path -LiteralPath $setupScript)) {
  throw "Missing setup script: $setupScript"
}
if (-not (Test-Path -LiteralPath $verifyScript)) {
  throw "Missing verify script: $verifyScript"
}
if (-not (Test-Path -LiteralPath $wizardPath)) {
  throw "Missing setup wizard: $wizardPath"
}

if (-not $SkipMcpWrite) {
  Write-Step "配置 WorkBuddy Playwright 浏览器连接器"
  & $setupScript -ConfigDir $ConfigDir
} else {
  Write-Step "已按参数要求跳过浏览器连接器写入"
}

Write-Step "验证 WorkBuddy 浏览器连接器配置"
& $verifyScript -ConfigDir $ConfigDir

if ($OpenWizard) {
  Write-Step "打开本地配置向导"
  Start-Process -FilePath $wizardPath
}

Write-Step "仍需要人工完成的步骤"
Write-Host "1. 完全退出并重启 WorkBuddy。"
Write-Host "2. 如果 WorkBuddy 提示需要信任或启用 playwright-edge，请在图形界面中确认。"
Write-Host "3. 打开 app\index.html，或使用 -OpenWizard 参数重新运行本安装脚本。"
Write-Host "4. 从向导复制登录验证提示词到 WorkBuddy。"
Write-Host "5. 用微信或携程应用扫码登录携程，不要输入账号密码。"
Write-Host "6. 继续在向导里搜索并确认本店和用户指定数量的竞对。"

Write-Host ""
Write-Host "安装脚本已结束。脚本不会绕过携程登录、验证码或 WorkBuddy 图形界面确认。"
