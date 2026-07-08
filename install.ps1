param(
  [string]$ConfigPath = ".\config\hotel-monitor.json",
  [switch]$CreateConfigFromExample,
  [switch]$RepairConfigFromExample,
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
    [string]$Guide,
    [bool]$Required = $true,
    [string]$OptionalReason = "Not required by current config."
  )

  $value = [Environment]::GetEnvironmentVariable($Name, "Process")
  if ([string]::IsNullOrWhiteSpace($value)) {
    $value = [Environment]::GetEnvironmentVariable($Name, "User")
  }

  if ([string]::IsNullOrWhiteSpace($value)) {
    if (-not $Required) {
      Write-Host "[optional] $Name is not configured. $OptionalReason"
      Add-Check -Item $Name -Status "optional" -Detail $OptionalReason -NextAction "No action unless you enable this data source."
      return $true
    }
    Write-Warning "$Name is missing. Set it with: setx $Name `"$Hint`""
    Add-Check -Item $Name -Status "missing" -Detail "Environment variable is not configured." -NextAction "Open $Guide, then run: setx $Name `"$Hint`""
    return $false
  }

  Write-Host "[ok] $Name is configured."
  Add-Check -Item $Name -Status "ok" -Detail "Environment variable exists. Secret value was not printed." -NextAction "No action."
  return $true
}

function Read-ConfigOrNull {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    return $null
  }
  try {
    return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8) | ConvertFrom-Json
  } catch {
    return $null
  }
}

function Get-NestedConfigValue {
  param(
    [object]$Config,
    [string]$Section,
    [string]$Name,
    [object]$Default
  )

  if ($null -eq $Config) { return $Default }
  if (-not $Config.PSObject.Properties[$Section]) { return $Default }
  $sectionValue = $Config.$Section
  if ($null -eq $sectionValue) { return $Default }
  if (-not $sectionValue.PSObject.Properties[$Name]) { return $Default }
  if ($null -eq $sectionValue.$Name) { return $Default }
  return $sectionValue.$Name
}

function Get-FormalRequirements {
  param([object]$Config)

  $flyaiEnabled = [bool](Get-NestedConfigValue -Config $Config -Section "flyai" -Name "enabled" -Default $true)
  $baiduEnabled = [bool](Get-NestedConfigValue -Config $Config -Section "baidu" -Name "enabled" -Default $true)
  $baiduEnrichTopN = [int](Get-NestedConfigValue -Config $Config -Section "baidu" -Name "enrichTopN" -Default 10)
  $baiduDailyCallLimit = [int](Get-NestedConfigValue -Config $Config -Section "baidu" -Name "dailyCallLimit" -Default 20)
  $baiduCanCallApi = ($baiduEnabled -and $baiduEnrichTopN -gt 0 -and $baiduDailyCallLimit -ne 0)

  return [ordered]@{
    AmapKeyRequired = $true
    FlyAIKeyRequired = $flyaiEnabled
    FlyAICommandRequired = $flyaiEnabled
    BaiduAkRequired = $baiduCanCallApi
    BaiduRequirementReason = if ($baiduCanCallApi) {
      "baidu.enabled=true, enrichTopN=$baiduEnrichTopN, dailyCallLimit=$baiduDailyCallLimit."
    } else {
      "Baidu formal API calls are disabled by current config: enabled=$baiduEnabled, enrichTopN=$baiduEnrichTopN, dailyCallLimit=$baiduDailyCallLimit."
    }
  }
}

function Add-RequirementSummary {
  param([System.Collections.IDictionary]$Requirements)

  Add-Check -Item "BAIDU_MAP_AK requirement" -Status $(if ($Requirements.BaiduAkRequired) { "required" } else { "optional" }) -Detail $Requirements.BaiduRequirementReason -NextAction $(if ($Requirements.BaiduAkRequired) { "Configure BAIDU_MAP_AK or set baidu.dailyCallLimit to 0 / baidu.enabled to false." } else { "No Baidu AK is required for formal runs unless you enable real Baidu calls." })
  Add-Check -Item "FLYAI_API_KEY requirement" -Status $(if ($Requirements.FlyAIKeyRequired) { "required" } else { "optional" }) -Detail $(if ($Requirements.FlyAIKeyRequired) { "flyai.enabled=true." } else { "flyai.enabled=false." }) -NextAction $(if ($Requirements.FlyAIKeyRequired) { "Configure FLYAI_API_KEY and flyai CLI before formal runs." } else { "No FlyAI key is required unless you enable FlyAI pricing." })
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

function Add-MissingConfigProperties {
  param(
    [pscustomobject]$Target,
    [pscustomobject]$Defaults
  )

  $added = New-Object System.Collections.Generic.List[string]

  foreach ($property in $Defaults.PSObject.Properties) {
    $name = $property.Name
    if (-not $Target.PSObject.Properties[$name]) {
      $Target | Add-Member -NotePropertyName $name -NotePropertyValue $property.Value
      $added.Add($name) | Out-Null
      continue
    }

    $targetValue = $Target.$name
    $defaultValue = $property.Value
    if ($targetValue -is [pscustomobject] -and $defaultValue -is [pscustomobject]) {
      $nested = Add-MissingConfigProperties -Target $targetValue -Defaults $defaultValue
      foreach ($nestedName in $nested) {
        $added.Add("$name.$nestedName") | Out-Null
      }
    }
  }

  return $added
}

function Repair-ConfigFromExample {
  param(
    [string]$Path,
    [string]$ExamplePath
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    Add-Check -Item "config repair" -Status "skipped" -Detail "Config file does not exist." -NextAction "Use -CreateConfigFromExample or generate config from app/index.html."
    return
  }

  try {
    $configText = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $exampleText = Get-Content -LiteralPath $ExamplePath -Raw -Encoding UTF8
    $config = $configText | ConvertFrom-Json
    $defaults = $exampleText | ConvertFrom-Json
  } catch {
    Add-Check -Item "config repair" -Status "error" -Detail "Could not parse config or example JSON." -NextAction "Regenerate config/hotel-monitor.json from app/index.html."
    return
  }

  $added = Add-MissingConfigProperties -Target $config -Defaults $defaults
  if (@($added).Count -eq 0) {
    Add-Check -Item "config repair" -Status "ok" -Detail "No missing config fields found." -NextAction "No action."
    return
  }

  $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $backupPath = "$Path.bak-$timestamp"
  Copy-Item -LiteralPath $Path -Destination $backupPath -Force
  $json = $config | ConvertTo-Json -Depth 20
  [System.IO.File]::WriteAllText($Path, $json, [System.Text.Encoding]::UTF8)
  Add-Check -Item "config repair" -Status "repaired" -Detail ("Added missing fields: " + (($added | Sort-Object) -join ", ") + ". Backup: $backupPath") -NextAction "Review config/hotel-monitor.json before formal runs."
}

function Get-SetupReadiness {
  $dryRunItems = @("wizard", "collector script", "daily prompt", "config/hotel-monitor.json", "config shape", "output directories")
  $formalItems = $dryRunItems + @("AMAP_API_KEY", "FLYAI_API_KEY", "BAIDU_MAP_AK", "flyai CLI")
  $dryRunBlockingStatuses = @("missing", "error", "warning", "failed")
  $formalBlockingStatuses = @("missing", "error", "warning", "failed", "skipped")

  $dryRunBlockers = @()
  $formalBlockers = @()
  $warnings = @()

  foreach ($check in $script:checks) {
    $label = "$($check.Item)=$($check.Status)"
    if ($check.Status -in @("warning", "skipped", "repaired")) {
      $warnings += $label
    }
    if ($check.Item -in $dryRunItems -and $check.Status -in $dryRunBlockingStatuses) {
      $dryRunBlockers += $label
    }
    if ($check.Item -in $formalItems -and $check.Status -in $formalBlockingStatuses) {
      $formalBlockers += $label
    }
  }

  return [ordered]@{
    ReadyForDryRun = (@($dryRunBlockers).Count -eq 0)
    ReadyForFormalRun = (@($formalBlockers).Count -eq 0)
    BlockingIssues = if (@($formalBlockers).Count -gt 0) { ($formalBlockers -join "; ") } elseif (@($dryRunBlockers).Count -gt 0) { ($dryRunBlockers -join "; ") } else { "none" }
    Warnings = if (@($warnings).Count -gt 0) { ($warnings -join "; ") } else { "none" }
  }
}

function Write-StatusReport {
  param([string]$Path)

  $directory = Split-Path -Parent $Path
  if ($directory) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }

  $readiness = Get-SetupReadiness
  $generatedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("# Hotel Competitor Monitor Setup Check") | Out-Null
  $lines.Add("") | Out-Null
  $lines.Add("- GeneratedAt: $generatedAt") | Out-Null
  $lines.Add("- ProjectDirectory: $repoRoot") | Out-Null
  $lines.Add("- ZeroQuotaCheck: true") | Out-Null
  $lines.Add("- NetworkCalls: 0") | Out-Null
  $lines.Add("- ReadyForDryRun: $($readiness.ReadyForDryRun)") | Out-Null
  $lines.Add("- ReadyForFormalRun: $($readiness.ReadyForFormalRun)") | Out-Null
  $lines.Add("- BlockingIssues: $($readiness.BlockingIssues)") | Out-Null
  $lines.Add("- Warnings: $($readiness.Warnings)") | Out-Null
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

Write-Step "Check local config"
if (-not (Test-Path -LiteralPath $targetConfig)) {
  if ($CreateConfigFromExample) {
    Copy-Item -LiteralPath $exampleConfig -Destination $targetConfig -Force
    Write-Host "[created] $targetConfig"
    Add-Check -Item "config/hotel-monitor.json" -Status "created" -Detail "Created from config/hotel-monitor.example.json." -NextAction "Open app/index.html and customize it before formal runs."
    Test-ConfigShape -Path $targetConfig
  } else {
    Write-Warning "Config file missing: $targetConfig"
    Write-Host "Create it from the local wizard app/index.html or from: $exampleConfig"
    Add-Check -Item "config/hotel-monitor.json" -Status "missing" -Detail "Local private config does not exist." -NextAction "Open app/index.html, generate hotel-monitor.json and save it to config/hotel-monitor.json."
  }
} else {
  Write-Host "[ok] Config file exists: $targetConfig"
  Add-Check -Item "config/hotel-monitor.json" -Status "ok" -Detail "Local private config exists." -NextAction "No action."
  if ($RepairConfigFromExample) {
    Repair-ConfigFromExample -Path $targetConfig -ExamplePath $exampleConfig
  } else {
    Add-Check -Item "config repair" -Status "skipped" -Detail "Run with -RepairConfigFromExample to merge missing fields from the example config." -NextAction "Use this only when setup-check reports missing config fields."
  }
  Test-ConfigShape -Path $targetConfig
}

$configForRequirements = Read-ConfigOrNull -Path $targetConfig
$formalRequirements = Get-FormalRequirements -Config $configForRequirements
Add-RequirementSummary -Requirements $formalRequirements

Write-Step "Check private API keys"
$hasAmap = Test-PrivateEnv -Name "AMAP_API_KEY" -Hint "your_amap_key" -Guide "app\amap-guide.html" -Required ([bool]$formalRequirements.AmapKeyRequired)
$hasFlyai = Test-PrivateEnv -Name "FLYAI_API_KEY" -Hint "your_flyai_key" -Guide "app\flyai-guide.html" -Required ([bool]$formalRequirements.FlyAIKeyRequired) -OptionalReason "FlyAI pricing is disabled by current config."
$hasBaidu = Test-PrivateEnv -Name "BAIDU_MAP_AK" -Hint "your_baidu_ak" -Guide "app\baidu-guide.html" -Required ([bool]$formalRequirements.BaiduAkRequired) -OptionalReason ([string]$formalRequirements.BaiduRequirementReason)

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

Write-Step "Check FlyAI CLI"
if (-not ([bool]$formalRequirements.FlyAICommandRequired)) {
  Write-Host "[optional] FlyAI CLI is not required because flyai.enabled=false."
  Add-Check -Item "flyai CLI" -Status "optional" -Detail "flyai.enabled=false in current config." -NextAction "Install flyai CLI only if you enable FlyAI pricing."
} elseif ($SkipFlyAICommandCheck) {
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
