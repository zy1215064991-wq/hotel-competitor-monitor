param(
  [string]$ConfigDir = "$env:USERPROFILE\.workbuddy"
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$profileDir = Join-Path $repoRoot "ctrip-profile"
$paths = @(
  (Join-Path $ConfigDir ".mcp.json"),
  (Join-Path $ConfigDir "mcp.json")
)

Write-Host "WorkBuddy config directory: $ConfigDir"
Write-Host "Ctrip profile directory: $profileDir"
Write-Host ""

foreach ($path in $paths) {
  if (-not (Test-Path -LiteralPath $path)) {
    Write-Host "[missing] $path"
    continue
  }

  $bytes = [System.IO.File]::ReadAllBytes($path)
  $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
  $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
  $json = $text | ConvertFrom-Json
  $hasServer = $null -ne $json.mcpServers.'playwright-edge'

  Write-Host "[ok] $path"
  Write-Host "  JSON valid: yes"
  Write-Host "  UTF-8 BOM: $hasBom"
  Write-Host "  playwright-edge: $hasServer"
}

if (-not (Test-Path -LiteralPath $profileDir)) {
  New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
  Write-Host "[created] $profileDir"
} else {
  Write-Host "[ok] profile directory exists"
}

Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Restart WorkBuddy completely."
Write-Host "2. Open app/index.html."
Write-Host "3. Copy the login verification prompt into WorkBuddy."
Write-Host "4. Scan-login to Ctrip and verify room prices are visible."
