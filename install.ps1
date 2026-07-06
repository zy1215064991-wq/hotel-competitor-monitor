param(
  [string]$ConfigDir = "$env:USERPROFILE\.workbuddy",
  [switch]$SkipMcpWrite,
  [switch]$OpenWizard
)

$ErrorActionPreference = "Stop"

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

Write-Host "Hotel Competitor Monitor installer"
Write-Host "Project: $repoRoot"
Write-Host "WorkBuddy config: $ConfigDir"

Write-Step "Checking local environment"
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
  Write-Step "Configuring WorkBuddy Playwright MCP"
  & $setupScript -ConfigDir $ConfigDir
} else {
  Write-Step "Skipping MCP write because -SkipMcpWrite was provided"
}

Write-Step "Verifying WorkBuddy MCP files"
& $verifyScript -ConfigDir $ConfigDir

if ($OpenWizard) {
  Write-Step "Opening setup wizard"
  Start-Process -FilePath $wizardPath
}

Write-Step "Manual steps that remain"
Write-Host "1. Restart WorkBuddy completely."
Write-Host "2. In WorkBuddy, trust/enable the playwright-edge MCP server if prompted."
Write-Host "3. Open app\index.html or rerun this installer with -OpenWizard."
Write-Host "4. Copy the login prompt from the wizard into WorkBuddy."
Write-Host "5. Scan-login to Ctrip with WeChat or the Ctrip app. Do not enter account passwords."
Write-Host "6. Continue in the wizard to search and confirm the home hotel plus three competitors."

Write-Host ""
Write-Host "Install script finished. It did not bypass Ctrip login, captcha, or WorkBuddy GUI trust prompts."
