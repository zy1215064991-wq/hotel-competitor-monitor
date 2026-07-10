param(
  [string]$ConfigPath = ".\config\hotel-monitor.json",
  [string]$OutputRoot = ".\data\api-combo",
  [string]$SetupReportPath = ".\data\setup-check-latest.md",
  [string]$RunReportPath = ".\data\run-once-latest.md",
  [switch]$Formal,
  [switch]$SkipSetupCheck
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding

$repoRoot = Split-Path -Parent $PSScriptRoot
$mode = if ($Formal) { "Formal" } else { "DryRun" }
$targetRunReport = if ([System.IO.Path]::IsPathRooted($RunReportPath)) {
  $RunReportPath
} else {
  Join-Path $repoRoot $RunReportPath
}
$targetSetupReport = if ([System.IO.Path]::IsPathRooted($SetupReportPath)) {
  $SetupReportPath
} else {
  Join-Path $repoRoot $SetupReportPath
}
$runReportWritten = $false

function Get-ReportValue {
  param(
    [string]$Path,
    [string]$Name,
    [string]$Default = "unknown"
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    return $Default
  }

  $pattern = "^(?:- )?$([regex]::Escape($Name)): (.+)$"
  foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
    $match = [regex]::Match($line, $pattern)
    if ($match.Success) {
      return $match.Groups[1].Value
    }
  }

  return $Default
}

function Write-RunReport {
  param(
    [string]$Path,
    [string]$Status,
    [string]$Detail,
    [string]$LatestReportInput,
    [string]$RunId = ""
  )

  $directory = Split-Path -Parent $Path
  if ($directory) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }

  $generatedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"
  $readyForDryRun = Get-ReportValue -Path $targetSetupReport -Name "ReadyForDryRun"
  $readyForFormalRun = Get-ReportValue -Path $targetSetupReport -Name "ReadyForFormalRun"
  $blockingIssues = Get-ReportValue -Path $targetSetupReport -Name "BlockingIssues"
  $warnings = Get-ReportValue -Path $targetSetupReport -Name "Warnings"
  $formalCollection = if ($Formal) { "true" } else { "false" }
  $networkCalls = if ($Formal) { "possible" } else { "0" }

  $lines = @(
    "# Hotel Competitor Monitor Run Once",
    "",
    "- GeneratedAt: $generatedAt",
    "- Mode: $mode",
    "- FormalCollection: $formalCollection",
    "- NetworkCallsToAmapFlyAIBaidu: $networkCalls",
    "- Status: $Status",
    "- Detail: $Detail",
    "- RunId: $RunId",
    "- ReadyForDryRun: $readyForDryRun",
    "- ReadyForFormalRun: $readyForFormalRun",
    "- BlockingIssues: $blockingIssues",
    "- Warnings: $warnings",
    "- SetupReportPath: $targetSetupReport",
    "- LatestReportInput: $LatestReportInput",
    "",
    "## Next Step",
    "",
    'Ask WorkBuddy to read data/api-combo/api-combo-latest-report-input.md and templates/daily-prompt.md, then generate the red/yellow/green daily report.'
  )

  [System.IO.File]::WriteAllLines($Path, $lines, [System.Text.Encoding]::UTF8)
}

try {
  Push-Location $repoRoot

  if (-not $SkipSetupCheck) {
    Write-Host "==> Setup readiness check"
    $setupArgs = @(
      "-NoProfile",
      "-ExecutionPolicy",
      "Bypass",
      "-File",
      (Join-Path $repoRoot "install.ps1"),
      "-ConfigPath",
      $ConfigPath,
      "-StatusReportPath",
      $SetupReportPath
    )
    if (-not $Formal) {
      $setupArgs += "-SkipFlyAICommandCheck"
    }
    & powershell @setupArgs | Out-Host
    $setupExitCode = $LASTEXITCODE
    if ($setupExitCode -ne 0) {
      throw "Setup readiness check failed with exit code $setupExitCode."
    }
  }

  $requiredReadiness = if ($Formal) { "ReadyForFormalRun" } else { "ReadyForDryRun" }
  $readyValue = Get-ReportValue -Path $targetSetupReport -Name $requiredReadiness
  if ($readyValue -ne "True") {
    $blocking = Get-ReportValue -Path $targetSetupReport -Name "BlockingIssues"
    $detail = "$requiredReadiness is $readyValue. BlockingIssues: $blocking"
    Write-RunReport -Path $targetRunReport -Status "blocked" -Detail $detail -LatestReportInput ""
    $runReportWritten = $true
    throw $detail
  }

  Write-Host "==> API combo $mode"
  $latestReportInput = if ([System.IO.Path]::IsPathRooted($OutputRoot)) {
    Join-Path $OutputRoot "api-combo-latest-report-input.md"
  } else {
    Join-Path (Join-Path $repoRoot $OutputRoot) "api-combo-latest-report-input.md"
  }
  $collectionStartedAtUtc = (Get-Date).ToUniversalTime()
  $runArgs = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    (Join-Path $repoRoot "scripts\run-api-mvp.ps1"),
    "-ConfigPath",
    $ConfigPath,
    "-OutputRoot",
    $OutputRoot
  )
  if (-not $Formal) {
    $runArgs += "-DryRun"
  }
  & powershell @runArgs | Out-Host
  $collectorExitCode = $LASTEXITCODE
  if ($collectorExitCode -ne 0) {
    throw "API combo collector failed with exit code $collectorExitCode."
  }

  if (-not (Test-Path -LiteralPath $latestReportInput)) {
    throw "Collector completed without creating latest report input: $latestReportInput"
  }
  $latestItem = Get-Item -LiteralPath $latestReportInput
  if ($latestItem.LastWriteTimeUtc -lt $collectionStartedAtUtc.AddSeconds(-2)) {
    throw "Latest report input is stale: $latestReportInput"
  }
  $runId = Get-ReportValue -Path $latestReportInput -Name "RunId" -Default ""
  if ([string]::IsNullOrWhiteSpace($runId)) {
    throw "Latest report input is missing RunId: $latestReportInput"
  }
  $expectedDryRun = if ($Formal) { "False" } else { "True" }
  $actualDryRun = Get-ReportValue -Path $latestReportInput -Name "DryRun" -Default "unknown"
  if ($actualDryRun -ne $expectedDryRun) {
    throw "Latest report input mode mismatch. Expected DryRun=$expectedDryRun, got $actualDryRun."
  }

  Write-RunReport -Path $targetRunReport -Status "ok" -Detail "$mode completed." -LatestReportInput $latestReportInput -RunId $runId
  $runReportWritten = $true
  Write-Host "Run-once report: $targetRunReport"
  if (-not $Formal) {
    Write-Host "DryRun completed. No formal Amap, FlyAI or Baidu collection was run."
  }
} catch {
  if (-not $runReportWritten) {
    Write-RunReport -Path $targetRunReport -Status "failed" -Detail $_.Exception.Message -LatestReportInput ""
  }
  throw
} finally {
  Pop-Location
}
