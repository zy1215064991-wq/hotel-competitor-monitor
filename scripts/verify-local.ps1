param(
  [switch]$SkipNodeTests,
  [switch]$SkipSecretScan,
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

function Write-VerifyReport {
  param([string]$Path)

  $directory = Split-Path -Parent $Path
  if ($directory) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }

  $generatedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("# Hotel Competitor Monitor Local Verification") | Out-Null
  $lines.Add("") | Out-Null
  $lines.Add("- GeneratedAt: $generatedAt") | Out-Null
  $lines.Add("- ProjectDirectory: $repoRoot") | Out-Null
  $lines.Add("- ZeroQuotaCheck: true") | Out-Null
  $lines.Add("- NetworkCallsToAmapFlyAIBaidu: 0") | Out-Null
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
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot "install.ps1") -SkipFlyAICommandCheck -StatusReportPath ".\data\setup-check-latest.md" | Out-Host
  }

  Invoke-VerifyStep -Name "api combo dryrun" -Action {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot "scripts\run-api-mvp.ps1") -DryRun | Out-Host
  }

  Invoke-VerifyStep -Name "node tests" -Action {
    if ($SkipNodeTests) {
      Write-Host "[skip] Node tests skipped by -SkipNodeTests."
      return
    }
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

  Invoke-VerifyStep -Name "secret scan" -Action {
    if ($SkipSecretScan) {
      Write-Host "[skip] Secret scan skipped by -SkipSecretScan."
      return
    }
    $pattern = "sk-[A-Za-z0-9]{10,}"
    $excludeDirs = @(".git", "data", "reports", "ctrip-profile", "output", "node_modules", "dist", "work")
    if (Get-Command "rg" -ErrorAction SilentlyContinue) {
      $rgArgs = @("-n", $pattern, ".", "-S")
      foreach ($dir in $excludeDirs) {
        $rgArgs += "--glob"
        $rgArgs += "!$dir/**"
      }
      $rgOutput = & rg @rgArgs 2>&1
      $exitCode = $LASTEXITCODE
      if ($exitCode -eq 0) {
        $rgOutput | Out-Host
        throw "Potential secret matched by rg."
      }
      if ($exitCode -gt 1) {
        throw "rg secret scan failed with exit code $exitCode."
      }
      Write-Host "[ok] No sk-style secret found by rg."
      return
    }

    $files = Get-ChildItem -Path $repoRoot -Recurse -File | Where-Object {
      $relative = [System.IO.Path]::GetRelativePath($repoRoot, $_.FullName)
      foreach ($dir in $excludeDirs) {
        if ($relative -eq $dir -or $relative.StartsWith("$dir\")) {
          return $false
        }
      }
      return $true
    }
    $matches = $files | Select-String -Pattern $pattern
    if ($matches) {
      $matches | ForEach-Object { Write-Host "$($_.Path):$($_.LineNumber): $($_.Line)" }
      throw "Potential secret matched by Select-String."
    }
    Write-Host "[ok] No sk-style secret found by Select-String."
  }
} finally {
  Pop-Location
  Write-VerifyReport -Path $targetReport
  Write-Host ""
  Write-Host "Local verification report: $targetReport"
  Write-Host "No formal Amap, FlyAI or Baidu collection was run by this verifier."
}
