param(
  [string]$ConfigPath = ".\config\hotel-monitor.json",
  [switch]$CreateConfigFromExample,
  [switch]$SkipFlyAICommandCheck
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding

$repoRoot = $PSScriptRoot
$exampleConfig = Join-Path $repoRoot "config\hotel-monitor.example.json"
$targetConfig = if ([System.IO.Path]::IsPathRooted($ConfigPath)) {
  $ConfigPath
} else {
  Join-Path $repoRoot $ConfigPath
}

function Write-Step {
  param([string]$Text)
  Write-Host ""
  Write-Host "==> $Text"
}

Write-Host "Hotel competitor monitor FlyAI MVP installer"
Write-Host "Project directory: $repoRoot"

Write-Step "Check private FlyAI key"
$apiKey = [Environment]::GetEnvironmentVariable("FLYAI_API_KEY", "Process")
if ([string]::IsNullOrWhiteSpace($apiKey)) {
  $apiKey = [Environment]::GetEnvironmentVariable("FLYAI_API_KEY", "User")
}
if ([string]::IsNullOrWhiteSpace($apiKey)) {
  Write-Warning "FLYAI_API_KEY is missing. Set it with: setx FLYAI_API_KEY `"your_key`""
} else {
  Write-Host "[ok] FLYAI_API_KEY is configured."
}

Write-Step "Check local config"
if (-not (Test-Path -LiteralPath $targetConfig)) {
  if ($CreateConfigFromExample) {
    Copy-Item -LiteralPath $exampleConfig -Destination $targetConfig -Force
    Write-Host "[created] $targetConfig"
  } else {
    Write-Warning "Config file missing: $targetConfig"
    Write-Host "Create it from: $exampleConfig"
  }
} else {
  Write-Host "[ok] Config file exists: $targetConfig"
}

Write-Step "Check FlyAI CLI"
if ($SkipFlyAICommandCheck) {
  Write-Host "[skip] FlyAI CLI check skipped."
} elseif (Get-Command "flyai" -ErrorAction SilentlyContinue) {
  Write-Host "[ok] flyai CLI found."
} else {
  Write-Warning "flyai CLI was not found in PATH. Install it before formal runs."
}

Write-Step "Create local output directories"
New-Item -ItemType Directory -Force -Path (Join-Path $repoRoot "data\flyai"), (Join-Path $repoRoot "reports") | Out-Null
Write-Host "[ok] data/flyai and reports directories are ready."

Write-Step "DryRun command"
Write-Host "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-flyai-mvp.ps1 -DryRun"

Write-Host ""
Write-Host "Install check completed. No OTA login is required for this MVP."
