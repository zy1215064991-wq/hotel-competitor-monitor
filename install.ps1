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

function Test-PrivateEnv {
  param(
    [string]$Name,
    [string]$Hint
  )

  $value = [Environment]::GetEnvironmentVariable($Name, "Process")
  if ([string]::IsNullOrWhiteSpace($value)) {
    $value = [Environment]::GetEnvironmentVariable($Name, "User")
  }

  if ([string]::IsNullOrWhiteSpace($value)) {
    Write-Warning "$Name is missing. Set it with: setx $Name `"$Hint`""
    return $false
  }

  Write-Host "[ok] $Name is configured."
  return $true
}

Write-Host "Hotel competitor monitor API combo installer"
Write-Host "Project directory: $repoRoot"

Write-Step "Check private API keys"
$hasAmap = Test-PrivateEnv -Name "AMAP_API_KEY" -Hint "your_amap_key"
$hasFlyai = Test-PrivateEnv -Name "FLYAI_API_KEY" -Hint "your_flyai_key"
$hasBaidu = Test-PrivateEnv -Name "BAIDU_MAP_AK" -Hint "your_baidu_ak"

if (-not ($hasAmap -and $hasFlyai -and $hasBaidu)) {
  Write-Host ""
  Write-Host "Local setup guides:"
  Write-Host "- app\flyai-guide.html"
  Write-Host "- app\amap-guide.html"
  Write-Host "- app\baidu-guide.html"
  Write-Host "Official key entries:"
  Write-Host "- FlyAI: https://flyai.open.fliggy.com/#ability"
  Write-Host "- Amap: https://lbs.amap.com/api/webservice/create-project-and-key"
  Write-Host "- Baidu: https://lbsyun.baidu.com/index.php?title=FAQ%2FobtainAK"
  Write-Host "After setting env vars, reopen WorkBuddy or PowerShell before running the workflow."
}

Write-Step "Check local config"
if (-not (Test-Path -LiteralPath $targetConfig)) {
  if ($CreateConfigFromExample) {
    Copy-Item -LiteralPath $exampleConfig -Destination $targetConfig -Force
    Write-Host "[created] $targetConfig"
  } else {
    Write-Warning "Config file missing: $targetConfig"
    Write-Host "Create it from the local wizard app/index.html or from: $exampleConfig"
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
  Write-Warning "flyai CLI was not found in PATH. Install it before formal runs:"
  Write-Host "npm i -g @fly-ai/flyai-cli --registry=https://registry.npmmirror.com"
}

Write-Step "Create local output directories"
New-Item -ItemType Directory -Force -Path (Join-Path $repoRoot "data\api-combo"), (Join-Path $repoRoot "data\cache\baidu"), (Join-Path $repoRoot "data\history"), (Join-Path $repoRoot "reports") | Out-Null
Write-Host "[ok] data/api-combo, data/cache/baidu, data/history and reports directories are ready."

Write-Step "DryRun command"
Write-Host "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-api-mvp.ps1 -DryRun"

Write-Host ""
Write-Host "Install check completed. No OTA login is required for this MVP."
