param(
  [string]$ConfigPath = ".\config\hotel-monitor.json",
  [switch]$CreateConfigFromExample,
  [switch]$SkipFlyAICommandCheck,
  [string]$StatusReportPath = ".\data\setup-check-latest.md"
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
$targetStatusReport = if ([System.IO.Path]::IsPathRooted($StatusReportPath)) {
  $StatusReportPath
} else {
  Join-Path $repoRoot $StatusReportPath
}
$checks = New-Object System.Collections.Generic.List[object]

function Write-Step {
  param([string]$Text)
  Write-Host ""
  Write-Host "==> $Text"
}

function Add-Check {
  param(
    [string]$Item,
    [string]$Status,
    [string]$Detail,
    [string]$NextAction
  )

  $script:checks.Add([pscustomobject]@{
    Item = $Item
    Status = $Status
    Detail = $Detail
    NextAction = $NextAction
  }) | Out-Null
}

function Test-PrivateEnv {
  param(
    [string]$Name,
    [string]$Hint,
    [string]$Guide
  )

  $value = [Environment]::GetEnvironmentVariable($Name, "Process")
  if ([string]::IsNullOrWhiteSpace($value)) {
    $value = [Environment]::GetEnvironmentVariable($Name, "User")
  }

  if ([string]::IsNullOrWhiteSpace($value)) {
    Write-Warning "$Name is missing. Set it with: setx $Name `"$Hint`""
    Add-Check -Item $Name -Status "missing" -Detail "Environment variable is not configured." -NextAction "Open $Guide, then run: setx $Name `"$Hint`""
    return $false
  }

  Write-Host "[ok] $Name is configured."
  Add-Check -Item $Name -Status "ok" -Detail "Environment variable exists. Secret value was not printed." -NextAction "No action."
  return $true
}

function Test-RequiredFile {
  param(
    [string]$RelativePath,
    [string]$Label
  )

  $fullPath = Join-Path $repoRoot $RelativePath
  if (Test-Path -LiteralPath $fullPath) {
    Add-Check -Item $Label -Status "ok" -Detail "$RelativePath exists." -NextAction "No action."
    return $true
  }

  Add-Check -Item $Label -Status "missing" -Detail "$RelativePath is missing." -NextAction "Restore the file from the GitHub repository."
  return $false
}

function Test-ConfigShape {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    return
  }

  try {
    $configText = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $config = $configText | ConvertFrom-Json
  } catch {
    Add-Check -Item "config shape" -Status "error" -Detail "Config exists but is not valid JSON." -NextAction "Regenerate config/hotel-monitor.json from app/index.html."
    return
  }

  $missing = @()
  foreach ($path in @("city", "homeHotelName", "poiName", "query", "discovery", "baidu", "flyai", "tierRules", "history")) {
    if (-not $config.PSObject.Properties[$path]) {
      $missing += $path
    }
  }

  if ($missing.Count -gt 0) {
    Add-Check -Item "config shape" -Status "warning" -Detail ("Missing fields: " + ($missing -join ", ")) -NextAction "Regenerate config/hotel-monitor.json from app/index.html."
  } else {
    Add-Check -Item "config shape" -Status "ok" -Detail "Required top-level fields exist." -NextAction "No action."
  }
}

function Write-StatusReport {
  param([string]$Path)

  $directory = Split-Path -Parent $Path
  if ($directory) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }

  $generatedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("# Hotel Competitor Monitor Setup Check") | Out-Null
  $lines.Add("") | Out-Null
  $lines.Add("- GeneratedAt: $generatedAt") | Out-Null
  $lines.Add("- ProjectDirectory: $repoRoot") | Out-Null
  $lines.Add("- ZeroQuotaCheck: true") | Out-Null
  $lines.Add("- NetworkCalls: 0") | Out-Null
  $lines.Add("- Note: This installer only checks local files, local environment variables and local CLI availability. It does not call Amap, FlyAI or Baidu APIs.") | Out-Null
  $lines.Add("") | Out-Null
  $lines.Add("| Item | Status | Detail | NextAction |") | Out-Null
  $lines.Add("| --- | --- | --- | --- |") | Out-Null

  foreach ($check in $script:checks) {
    $detail = ([string]$check.Detail) -replace "\|", "/"
    $next = ([string]$check.NextAction) -replace "\|", "/"
    $lines.Add("| $($check.Item) | $($check.Status) | $detail | $next |") | Out-Null
  }

  [System.IO.File]::WriteAllLines($Path, $lines, [System.Text.Encoding]::UTF8)
}

Write-Host "Hotel competitor monitor API combo installer"
Write-Host "Project directory: $repoRoot"

Write-Step "Check required local files"
Test-RequiredFile -RelativePath "app\index.html" -Label "wizard" | Out-Null
Test-RequiredFile -RelativePath "app\flyai-guide.html" -Label "FlyAI guide" | Out-Null
Test-RequiredFile -RelativePath "app\amap-guide.html" -Label "Amap guide" | Out-Null
Test-RequiredFile -RelativePath "app\baidu-guide.html" -Label "Baidu guide" | Out-Null
Test-RequiredFile -RelativePath "scripts\run-api-mvp.ps1" -Label "collector script" | Out-Null
Test-RequiredFile -RelativePath "templates\daily-prompt.md" -Label "daily prompt" | Out-Null
Test-RequiredFile -RelativePath "docs\push-setup.md" -Label "push setup guide" | Out-Null

Write-Step "Check private API keys"
$hasAmap = Test-PrivateEnv -Name "AMAP_API_KEY" -Hint "your_amap_key" -Guide "app\amap-guide.html"
$hasFlyai = Test-PrivateEnv -Name "FLYAI_API_KEY" -Hint "your_flyai_key" -Guide "app\flyai-guide.html"
$hasBaidu = Test-PrivateEnv -Name "BAIDU_MAP_AK" -Hint "your_baidu_ak" -Guide "app\baidu-guide.html"

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
    Add-Check -Item "config/hotel-monitor.json" -Status "created" -Detail "Created from config/hotel-monitor.example.json." -NextAction "Open app/index.html and customize it before formal runs."
  } else {
    Write-Warning "Config file missing: $targetConfig"
    Write-Host "Create it from the local wizard app/index.html or from: $exampleConfig"
    Add-Check -Item "config/hotel-monitor.json" -Status "missing" -Detail "Local private config does not exist." -NextAction "Open app/index.html, generate hotel-monitor.json and save it to config/hotel-monitor.json."
  }
} else {
  Write-Host "[ok] Config file exists: $targetConfig"
  Add-Check -Item "config/hotel-monitor.json" -Status "ok" -Detail "Local private config exists." -NextAction "No action."
  Test-ConfigShape -Path $targetConfig
}

Write-Step "Check FlyAI CLI"
if ($SkipFlyAICommandCheck) {
  Write-Host "[skip] FlyAI CLI check skipped."
  Add-Check -Item "flyai CLI" -Status "skipped" -Detail "Check skipped by -SkipFlyAICommandCheck." -NextAction "Run Get-Command flyai before formal runs."
} elseif (Get-Command "flyai" -ErrorAction SilentlyContinue) {
  Write-Host "[ok] flyai CLI found."
  Add-Check -Item "flyai CLI" -Status "ok" -Detail "flyai command is available in PATH." -NextAction "No action."
} else {
  Write-Warning "flyai CLI was not found in PATH. Install it before formal runs:"
  Write-Host "npm i -g @fly-ai/flyai-cli --registry=https://registry.npmmirror.com"
  Add-Check -Item "flyai CLI" -Status "missing" -Detail "flyai command was not found in PATH." -NextAction "Run: npm i -g @fly-ai/flyai-cli --registry=https://registry.npmmirror.com"
}

Write-Step "Create local output directories"
New-Item -ItemType Directory -Force -Path (Join-Path $repoRoot "data\api-combo"), (Join-Path $repoRoot "data\cache\baidu"), (Join-Path $repoRoot "data\history"), (Join-Path $repoRoot "reports") | Out-Null
Write-Host "[ok] data/api-combo, data/cache/baidu, data/history and reports directories are ready."
Add-Check -Item "output directories" -Status "ok" -Detail "data/api-combo, data/cache/baidu, data/history and reports are ready." -NextAction "No action."

Write-Step "Write zero-quota setup report"
Write-StatusReport -Path $targetStatusReport
Write-Host "[ok] Setup status report: $targetStatusReport"

Write-Step "DryRun command"
Write-Host "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-api-mvp.ps1 -DryRun"

Write-Host ""
Write-Host "Install check completed. No OTA login is required for this MVP."
Write-Host "No Amap, FlyAI or Baidu HTTP/API call was made by this installer."
