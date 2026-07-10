param(
  [switch]$SkipNodeTests,
  [switch]$SkipSecretScan,
  [string]$ConfigPath = ".\config\hotel-monitor.json",
  [string]$ReportPath = ".\data\verify-local-latest.md"
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding

$repoRoot = Split-Path -Parent $PSScriptRoot
$targetReport = if ([System.IO.Path]::IsPathRooted($ReportPath)) {
  $ReportPath
} else {
  Join-Path $repoRoot $ReportPath
}
$results = New-Object System.Collections.Generic.List[object]

function Add-Result {
  param(
    [string]$Step,
    [string]$Status,
    [string]$Detail
  )

  $script:results.Add([pscustomobject]@{
    Step = $Step
    Status = $Status
    Detail = $Detail
  }) | Out-Null
}

function Invoke-VerifyStep {
  param(
    [string]$Name,
    [scriptblock]$Action
  )

  Write-Host ""
  Write-Host "==> $Name"
  try {
    & $Action
    Add-Result -Step $Name -Status "ok" -Detail "Passed."
  } catch {
    Add-Result -Step $Name -Status "failed" -Detail $_.Exception.Message
    throw
  }
}

function Get-ReportValue {
  param(
    [string]$Path,
    [string]$Name,
    [string]$Default = "unknown"
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    return $Default
  }

  $pattern = "^- $([regex]::Escape($Name)): (.+)$"
  foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
    $match = [regex]::Match($line, $pattern)
    if ($match.Success) {
      return $match.Groups[1].Value
    }
  }

  return $Default
}

function Get-VerifyReadiness {
  $failed = @($script:results | Where-Object { $_.Status -eq "failed" } | ForEach-Object { "$($_.Step)=$($_.Status)" })
  $setupReport = Join-Path $repoRoot "data\setup-check-latest.md"
  $setupDryRun = Get-ReportValue -Path $setupReport -Name "ReadyForDryRun"
  $setupFormal = Get-ReportValue -Path $setupReport -Name "ReadyForFormalRun"
  $setupBlocking = Get-ReportValue -Path $setupReport -Name "BlockingIssues" -Default "unknown"
  $setupWarnings = Get-ReportValue -Path $setupReport -Name "Warnings" -Default "unknown"

  $allStepsPassed = (@($failed).Count -eq 0)
  $readyForDryRun = ($allStepsPassed -and $setupDryRun -eq "True")
  $blockingIssues = if (@($failed).Count -gt 0) {
    $failed -join "; "
  } else {
    $setupBlocking
  }

  return [ordered]@{
    ReadyForDryRun = $readyForDryRun
    ReadyForFormalRun = $setupFormal
    BlockingIssues = $blockingIssues
    Warnings = $setupWarnings
  }
}

function Write-VerifyReport {
  param([string]$Path)

  $directory = Split-Path -Parent $Path
  if ($directory) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }

  $readiness = Get-VerifyReadiness
  $generatedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("# Hotel Competitor Monitor Local Verification") | Out-Null
  $lines.Add("") | Out-Null
  $lines.Add("- GeneratedAt: $generatedAt") | Out-Null
  $lines.Add("- ProjectDirectory: $repoRoot") | Out-Null
  $lines.Add("- ZeroQuotaCheck: true") | Out-Null
  $lines.Add("- NetworkCallsToAmapFlyAIBaidu: 0") | Out-Null
  $lines.Add("- ReadyForDryRun: $($readiness.ReadyForDryRun)") | Out-Null
  $lines.Add("- ReadyForFormalRun: $($readiness.ReadyForFormalRun)") | Out-Null
  $lines.Add("- BlockingIssues: $($readiness.BlockingIssues)") | Out-Null
  $lines.Add("- Warnings: $($readiness.Warnings)") | Out-Null
  $lines.Add("- Note: This script runs install.ps1, run-api-mvp.ps1 -DryRun, local tests and secret scanning. It does not run formal collection.") | Out-Null
  $lines.Add("") | Out-Null
  $lines.Add("| Step | Status | Detail |") | Out-Null
  $lines.Add("| --- | --- | --- |") | Out-Null

  foreach ($result in $script:results) {
    $detail = ([string]$result.Detail) -replace "\|", "/"
    $lines.Add("| $($result.Step) | $($result.Status) | $detail |") | Out-Null
  }

  [System.IO.File]::WriteAllLines($Path, $lines, [System.Text.Encoding]::UTF8)
}

try {
  Push-Location $repoRoot

  Invoke-VerifyStep -Name "zero-quota setup check" -Action {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot "install.ps1") -ConfigPath $ConfigPath -SkipFlyAICommandCheck -StatusReportPath ".\data\setup-check-latest.md" | Out-Host
    $setupExitCode = $LASTEXITCODE
    if ($setupExitCode -ne 0) {
      throw "install.ps1 failed with exit code $setupExitCode."
    }
  }

  Invoke-VerifyStep -Name "api combo dryrun" -Action {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot "scripts\run-api-mvp.ps1") -ConfigPath $ConfigPath -DryRun | Out-Host
    $dryRunExitCode = $LASTEXITCODE
    if ($dryRunExitCode -ne 0) {
      throw "run-api-mvp.ps1 -DryRun failed with exit code $dryRunExitCode."
    }
  }

  if ($SkipNodeTests) {
    Write-Host ""
    Write-Host "==> node tests"
    Write-Host "[skip] Node tests skipped by -SkipNodeTests."
    Add-Result -Step "node tests" -Status "skipped" -Detail "Skipped by -SkipNodeTests."
  } else {
    Invoke-VerifyStep -Name "node tests" -Action {
    if (-not (Get-Command "node" -ErrorAction SilentlyContinue)) {
      throw "Node.js was not found. Install Node.js or rerun with -SkipNodeTests."
    }
    Get-ChildItem -Path (Join-Path $repoRoot "tests") -Filter "*.test.mjs" | Sort-Object Name | ForEach-Object {
      Write-Host "node $($_.FullName)"
      & node $_.FullName
      if ($LASTEXITCODE -ne 0) {
        throw "Node test failed: $($_.Name)"
      }
    }
    }
  }

  if ($SkipSecretScan) {
    Write-Host ""
    Write-Host "==> secret scan"
    Write-Host "[skip] Secret scan skipped by -SkipSecretScan."
    Add-Result -Step "secret scan" -Status "skipped" -Detail "Skipped by -SkipSecretScan."
  } else {
    Invoke-VerifyStep -Name "secret scan" -Action {
    $scanOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot "scripts\scan-secrets.ps1") -RootPath $repoRoot 2>&1
    $scanExitCode = $LASTEXITCODE
    $scanOutput | Out-Host
    if ($scanExitCode -ne 0) {
      throw "Secret scan failed with exit code $scanExitCode."
    }
    }
  }
} finally {
  Pop-Location
  Write-VerifyReport -Path $targetReport
  Write-Host ""
  Write-Host "Local verification report: $targetReport"
  Write-Host "No formal Amap, FlyAI or Baidu collection was run by this verifier."
}
