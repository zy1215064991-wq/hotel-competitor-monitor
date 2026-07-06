param(
  [string]$ConfigDir = "$env:USERPROFILE\.workbuddy"
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$profileDir = Join-Path $repoRoot "ctrip-profile"
$browserOutputDir = Join-Path $repoRoot "output\browser"
$nodeNpx = "C:\Program Files\nodejs\npx.cmd"
$edgeCandidates = @(
  "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
  "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
)
$edgePath = $edgeCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

if (-not $edgePath) {
  throw "Microsoft Edge executable was not found. Install Edge or update setup-workbuddy-mcp.ps1 with the executable path."
}

if (-not (Test-Path -LiteralPath $nodeNpx)) {
  throw "npx was not found at $nodeNpx. Install Node.js or update setup-workbuddy-mcp.ps1."
}

New-Item -ItemType Directory -Force -Path $ConfigDir, $profileDir, $browserOutputDir | Out-Null

$config = [ordered]@{
  mcpServers = [ordered]@{
    "playwright-edge" = [ordered]@{
      type = "stdio"
      command = $nodeNpx
      args = @(
        "-y",
        "@playwright/mcp@latest",
        "--browser=msedge",
        "--executable-path=$edgePath",
        "--user-data-dir=$profileDir",
        "--output-dir=$browserOutputDir",
        "--output-mode=file",
        "--save-session",
        "--shared-browser-context",
        "--viewport-size=1360x900",
        "--timeout-action=15000",
        "--timeout-navigation=90000"
      )
      env = [ordered]@{
        npm_config_registry = "https://registry.npmmirror.com"
        PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1"
      }
      description = "Playwright MCP for WorkBuddy hotel competitor monitoring. Uses real Microsoft Edge and persistent Ctrip login profile."
    }
  }
  permissions = [ordered]@{
    allow = @("mcp__playwright-edge")
  }
}

$json = $config | ConvertTo-Json -Depth 10
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

foreach ($name in @(".mcp.json", "mcp.json")) {
  $path = Join-Path $ConfigDir $name
  if (Test-Path -LiteralPath $path) {
    $backup = "$path.bak-$(Get-Date -Format yyyyMMddHHmmss)"
    Copy-Item -LiteralPath $path -Destination $backup -Force
    Write-Host "Backed up existing $name to $backup"
  }
  [System.IO.File]::WriteAllText($path, $json, $utf8NoBom)
  Write-Host "Wrote $path"
}

Write-Host ""
Write-Host "Done. Restart WorkBuddy, then open app/index.html and complete Ctrip scan-login."

