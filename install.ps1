param(
  [string]$ConfigDir = "$env:USERPROFILE\.workbuddy",
  [ValidateSet("auto", "chrome", "edge")]
  [string]$Browser = "auto",
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
Write-Host "浏览器选择：$Browser（auto 会优先使用 Chrome，未安装 Chrome 时回退 Edge）"

Write-Step "检查本机环境"
if ($env:OS -and $env:OS -notlike "*Windows*") {
  Write-Warning "本部署包面向 Windows WorkBuddy 桌面端。"
}

if (-not (Test-CommandAvailable "powershell")) {
  throw "未在 PATH 中找到 PowerShell。"
}

$chromeCandidates = @(
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
  "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
)
$edgeCandidates = @(
  "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
  "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
)
$chromePath = $chromeCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
$edgePath = $edgeCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $chromePath -and -not $edgePath) {
  throw "未找到 Chrome 或 Edge 浏览器。请先安装其中一个浏览器。"
}
if ($Browser -eq "chrome" -and -not $chromePath) {
  throw "你指定了 -Browser chrome，但本机未找到 Chrome。"
}
if ($Browser -eq "edge" -and -not $edgePath) {
  throw "你指定了 -Browser edge，但本机未找到 Edge。"
}
if ($chromePath) {
  Write-Host "[ok] Chrome: $chromePath"
} else {
  Write-Host "[提示] 未找到 Chrome，将在 auto 模式下尝试 Edge。"
}
if ($edgePath) {
  Write-Host "[ok] Edge: $edgePath"
} else {
  Write-Host "[提示] 未找到 Edge。"
}

$nodeNpx = "C:\Program Files\nodejs\npx.cmd"
if (-not (Test-Path -LiteralPath $nodeNpx)) {
  throw "未在 $nodeNpx 找到 npx。请先安装 Windows 版 Node.js。"
}
Write-Host "[ok] npx: $nodeNpx"

if (-not (Test-Path -LiteralPath $setupScript)) {
  throw "缺少配置脚本：$setupScript"
}
if (-not (Test-Path -LiteralPath $verifyScript)) {
  throw "缺少验证脚本：$verifyScript"
}
if (-not (Test-Path -LiteralPath $wizardPath)) {
  throw "缺少本地向导：$wizardPath"
}

if (-not $SkipMcpWrite) {
  Write-Step "配置 WorkBuddy Playwright 浏览器连接器"
  & $setupScript -ConfigDir $ConfigDir -Browser $Browser
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
Write-Host "2. 如果 WorkBuddy 提示需要信任或启用 playwright-browser，请在图形界面中确认。"
Write-Host "3. 打开 app\index.html，或使用 -OpenWizard 参数重新运行本安装脚本。"
Write-Host "4. 从向导复制登录验证提示词到 WorkBuddy。"
Write-Host "5. WorkBuddy 会直达携程登录页；请在浏览器里自行选择登录方式，不要让自动化输入账号密码或验证码。"
Write-Host "6. 继续在向导里搜索并确认本店和用户指定数量的竞对。"

Write-Host ""
Write-Host "安装脚本已结束。脚本不会绕过携程登录、验证码或 WorkBuddy 图形界面确认。"
