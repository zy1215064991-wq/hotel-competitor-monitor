param(
  [string]$ConfigPath = ".\config\hotel-monitor.json",
  [string]$OutputRoot = ".\data\flyai",
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$resolvedConfigPath = if ([System.IO.Path]::IsPathRooted($ConfigPath)) {
  $ConfigPath
} else {
  Join-Path $repoRoot $ConfigPath
}
$resolvedOutputRoot = if ([System.IO.Path]::IsPathRooted($OutputRoot)) {
  $OutputRoot
} else {
  Join-Path $repoRoot $OutputRoot
}

function Assert-Text {
  param(
    [object]$Value,
    [string]$Name
  )
  if ([string]::IsNullOrWhiteSpace([string]$Value)) {
    throw "$Name is required in $resolvedConfigPath"
  }
}

function Get-Config {
  if (-not (Test-Path -LiteralPath $resolvedConfigPath)) {
    throw "Config file not found: $resolvedConfigPath. Copy config/hotel-monitor.example.json to config/hotel-monitor.json first."
  }

  $json = [System.IO.File]::ReadAllText($resolvedConfigPath, [System.Text.Encoding]::UTF8)
  return $json | ConvertFrom-Json
}

function Get-QueryDates {
  param([pscustomobject]$Config)

  if ($Config.query.checkInDate -and $Config.query.checkOutDate) {
    return [ordered]@{
      CheckIn = [string]$Config.query.checkInDate
      CheckOut = [string]$Config.query.checkOutDate
    }
  }

  $offsetDays = if ($null -ne $Config.query.offsetDays) { [int]$Config.query.offsetDays } else { 7 }
  $nights = if ($null -ne $Config.query.nights) { [int]$Config.query.nights } else { 1 }
  $checkIn = (Get-Date).Date.AddDays($offsetDays)
  $checkOut = $checkIn.AddDays($nights)

  return [ordered]@{
    CheckIn = $checkIn.ToString("yyyy-MM-dd")
    CheckOut = $checkOut.ToString("yyyy-MM-dd")
  }
}

function Join-CommandLine {
  param([string[]]$FlyArgs)

  $quoted = $FlyArgs | ForEach-Object {
    if ($_ -match "\s") {
      '"' + ($_ -replace '"', '\"') + '"'
    } else {
      $_
    }
  }
  return "flyai " + ($quoted -join " ")
}

function New-FlyAIArgs {
  param(
    [pscustomobject]$Config,
    [hashtable]$Dates,
    [string]$Keyword,
    [string]$PoiName
  )

  $sort = if ($Config.discovery.sort) { [string]$Config.discovery.sort } else { "distance_asc" }
  $args = @(
    "search-hotel",
    "--dest-name", [string]$Config.city,
    "--check-in-date", [string]$Dates.CheckIn,
    "--check-out-date", [string]$Dates.CheckOut,
    "--sort", $sort
  )

  if (-not [string]::IsNullOrWhiteSpace($Keyword)) {
    $args += @("--key-words", $Keyword)
  }
  if (-not [string]::IsNullOrWhiteSpace($PoiName)) {
    $args += @("--poi-name", $PoiName)
  }
  if ($null -ne $Config.discovery.maxPrice -and [int]$Config.discovery.maxPrice -gt 0) {
    $args += @("--max-price", [string]$Config.discovery.maxPrice)
  }

  return $args
}

function Invoke-FlyAIQuery {
  param(
    [string]$Label,
    [string[]]$FlyArgs,
    [string]$OutputDir
  )

  $safeName = ($Label -replace "[^a-zA-Z0-9_-]", "_").Trim("_")
  if (-not $safeName) { $safeName = "query" }
  $outputPath = Join-Path $OutputDir "$safeName.txt"
  $commandLine = Join-CommandLine -FlyArgs $FlyArgs

  if ($DryRun) {
    $content = @(
      "DRY RUN",
      "Label: $Label",
      "Command: $commandLine"
    ) -join "`n"
    [System.IO.File]::WriteAllText($outputPath, $content, [System.Text.Encoding]::UTF8)
    return [ordered]@{ Label = $Label; Command = $commandLine; OutputPath = $outputPath; Output = $content }
  }

  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $output = & flyai @FlyArgs 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
  $hasSuccessPayload = $output -match '"status"\s*:\s*0'
  if ($exitCode -ne 0 -and -not $hasSuccessPayload) {
    [System.IO.File]::WriteAllText($outputPath, $output, [System.Text.Encoding]::UTF8)
    throw "FlyAI query failed for $Label. Output saved to $outputPath"
  }

  if ($exitCode -ne 0 -and $hasSuccessPayload) {
    $output = $output.TrimEnd() + "`n`n[warning] flyai CLI returned exit code $exitCode after emitting a success payload. The payload above was kept for MVP analysis."
  }

  [System.IO.File]::WriteAllText($outputPath, $output, [System.Text.Encoding]::UTF8)
  return [ordered]@{ Label = $Label; Command = $commandLine; OutputPath = $outputPath; Output = $output }
}

function Write-ReportInput {
  param(
    [pscustomobject]$Config,
    [hashtable]$Dates,
    [array]$Results,
    [string]$OutputDir
  )

  $reportInputPath = Join-Path $OutputDir "report-input.md"
  $latestPath = Join-Path $resolvedOutputRoot "latest-report-input.md"
  $brandText = if ($Config.discovery.brandKeywords) { @($Config.discovery.brandKeywords) -join ", " } else { "none" }
  $competitorCount = if ($Config.discovery.competitorCount) { [int]$Config.discovery.competitorCount } else { 5 }

  $lines = @(
    "# FlyAI Hotel Competitor Report Input",
    "",
    "GeneratedAt: $(Get-Date -Format s)",
    "DryRun: $DryRun",
    "",
    "## Query Config",
    "",
    "- City: $($Config.city)",
    "- HomeHotelName: $($Config.homeHotelName)",
    "- PoiName: $($Config.poiName)",
    "- CheckIn: $($Dates.CheckIn)",
    "- CheckOut: $($Dates.CheckOut)",
    "- RoomType: $($Config.query.roomType)",
    "- Rooms: $($Config.query.rooms)",
    "- Adults: $($Config.query.adults)",
    "- Children: $($Config.query.children)",
    "- CompetitorCount: $competitorCount",
    "- BrandSupplementKeywords: $brandText",
    "- MaxPrice: $($Config.discovery.maxPrice)",
    "",
    "## Analysis Instructions",
    "",
    "Use only the FlyAI/Fliggy outputs below. Do not browse Ctrip or any OTA website.",
    "Classify hotels into core competitors, price pressure competitors, extended competitors, substitute competitors, and excluded hotels.",
    "If prices are masked, treat them as rough price-band signals and say data is not precise.",
    "",
    "## FlyAI Outputs"
  )

  foreach ($result in $Results) {
    $lines += ""
    $lines += "### $($result.Label)"
    $lines += ""
    $lines += "Command: $($result.Command)"
    $lines += ""
    $lines += '```text'
    $lines += ([string]$result.Output).Trim()
    $lines += '```'
  }

  New-Item -ItemType Directory -Force -Path $resolvedOutputRoot | Out-Null
  [System.IO.File]::WriteAllText($reportInputPath, ($lines -join "`n"), [System.Text.Encoding]::UTF8)
  [System.IO.File]::WriteAllText($latestPath, ($lines -join "`n"), [System.Text.Encoding]::UTF8)
  return $reportInputPath
}

$config = Get-Config
Assert-Text -Value $config.city -Name "city"
Assert-Text -Value $config.homeHotelName -Name "homeHotelName"
Assert-Text -Value $config.poiName -Name "poiName"

if (-not $DryRun) {
  $apiKey = [Environment]::GetEnvironmentVariable("FLYAI_API_KEY", "Process")
  if ([string]::IsNullOrWhiteSpace($apiKey)) {
    $apiKey = [Environment]::GetEnvironmentVariable("FLYAI_API_KEY", "User")
  }
  if ([string]::IsNullOrWhiteSpace($apiKey)) {
    throw "FLYAI_API_KEY is not set. Set it in Windows environment variables, then restart WorkBuddy."
  }
  $env:FLYAI_API_KEY = $apiKey

  if (-not (Get-Command "flyai" -ErrorAction SilentlyContinue)) {
    throw "flyai CLI was not found in PATH. Install and authenticate FlyAI CLI first."
  }
}

$dates = Get-QueryDates -Config $config
$runId = Get-Date -Format "yyyy-MM-dd-HHmmss"
$outputDir = Join-Path $resolvedOutputRoot $runId
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$queries = @(
  [ordered]@{ Label = "home"; Args = New-FlyAIArgs -Config $config -Dates $dates -Keyword ([string]$config.homeHotelName) -PoiName "" },
  [ordered]@{ Label = "area"; Args = New-FlyAIArgs -Config $config -Dates $dates -Keyword ([string]$config.poiName) -PoiName ([string]$config.poiName) }
)

foreach ($brand in @($config.discovery.brandKeywords)) {
  if ([string]::IsNullOrWhiteSpace([string]$brand)) { continue }
  $queries += [ordered]@{
    Label = "brand_$brand"
    Args = New-FlyAIArgs -Config $config -Dates $dates -Keyword "$brand $($config.poiName)" -PoiName ([string]$config.poiName)
  }
}

$results = foreach ($query in $queries) {
  Invoke-FlyAIQuery -Label $query.Label -FlyArgs $query.Args -OutputDir $outputDir
}

$reportInputPath = Write-ReportInput -Config $config -Dates $dates -Results $results -OutputDir $outputDir

Write-Host "FlyAI MVP input generated."
Write-Host "Output directory: $outputDir"
Write-Host "Report input: $reportInputPath"
Write-Host "Latest report input: $(Join-Path $resolvedOutputRoot 'latest-report-input.md')"
