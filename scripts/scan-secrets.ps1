param(
  [string]$RootPath = "."
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding

$root = (Resolve-Path -LiteralPath $RootPath).Path.TrimEnd("\")
$excludedDirectories = @(".git", ".worktrees", "data", "reports", "ctrip-profile", "output", "node_modules", "dist", "work")
$textExtensions = @("", ".css", ".env", ".example", ".gitignore", ".html", ".js", ".json", ".md", ".mjs", ".ps1", ".txt", ".yaml", ".yml")
$environmentSecretNames = @("AMAP_API_KEY", "FLYAI_API_KEY", "BAIDU_MAP_AK", "HOTEL_MONITOR_WECOM_WEBHOOK")
$knownSecrets = @{}

foreach ($name in $environmentSecretNames) {
  $value = [Environment]::GetEnvironmentVariable($name)
  if (-not [string]::IsNullOrWhiteSpace($value) -and $value.Length -ge 8) {
    $knownSecrets[$name] = $value
  }
}

function Test-ExcludedPath {
  param([string]$RelativePath)

  $segments = $RelativePath -split "[\\/]"
  foreach ($segment in $segments) {
    if ($excludedDirectories -contains $segment) {
      return $true
    }
  }
  return $false
}

function Get-RelativePathSafe {
  param([string]$FullPath)

  if ($FullPath.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $FullPath.Substring($root.Length).TrimStart([char[]]@("\", "/"))
  }
  return $FullPath
}

function Get-ScanFiles {
  $git = Get-Command "git" -ErrorAction SilentlyContinue
  if ($git -and (Test-Path -LiteralPath (Join-Path $root ".git"))) {
    $gitPaths = @(& git -C $root ls-files --cached --others --exclude-standard)
    if ($LASTEXITCODE -ne 0) {
      throw "git ls-files failed with exit code $LASTEXITCODE."
    }
    foreach ($relativePath in $gitPaths) {
      if ([string]::IsNullOrWhiteSpace($relativePath) -or (Test-ExcludedPath -RelativePath $relativePath)) {
        continue
      }
      $fullPath = Join-Path $root ($relativePath -replace "/", "\")
      if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
        Get-Item -LiteralPath $fullPath
      }
    }
    return
  }

  Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object {
    -not (Test-ExcludedPath -RelativePath (Get-RelativePathSafe -FullPath $_.FullName))
  }
}

$findings = New-Object System.Collections.Generic.List[object]
$files = @(Get-ScanFiles)

foreach ($file in $files) {
  $extension = [System.IO.Path]::GetExtension($file.Name).ToLowerInvariant()
  if ($textExtensions -notcontains $extension) {
    continue
  }

  try {
    $lines = [System.IO.File]::ReadAllLines($file.FullName)
  } catch {
    continue
  }

  for ($index = 0; $index -lt $lines.Length; $index++) {
    $line = $lines[$index]
    $kinds = New-Object System.Collections.Generic.HashSet[string]

    if ($line -match "sk-[A-Za-z0-9_-]{10,}") {
      $kinds.Add("sk-token") | Out-Null
    }

    $webhookMatch = [regex]::Match($line, "https://qyapi\.weixin\.qq\.com/cgi-bin/webhook/send\?key=([0-9A-Za-z-]{10,})", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($webhookMatch.Success) {
      $webhookKey = $webhookMatch.Groups[1].Value
      if ($webhookKey -notmatch "^x+(-x+)*$" -and $webhookKey -notmatch "replace|placeholder") {
        $kinds.Add("wecom-webhook") | Out-Null
      }
    }

    foreach ($entry in $knownSecrets.GetEnumerator()) {
      if ($line.IndexOf([string]$entry.Value, [System.StringComparison]::Ordinal) -ge 0) {
        $kinds.Add([string]$entry.Key) | Out-Null
      }
    }

    foreach ($kind in $kinds) {
      $findings.Add([pscustomobject]@{
        Path = Get-RelativePathSafe -FullPath $file.FullName
        Line = $index + 1
        Kind = $kind
      }) | Out-Null
    }
  }
}

if ($findings.Count -gt 0) {
  foreach ($finding in $findings) {
    Write-Output "Potential secret: $($finding.Path):$($finding.Line) ($($finding.Kind))"
  }
  Write-Output "Secret scan failed. Values are intentionally redacted."
  exit 1
}

Write-Output "Secret scan passed: $($files.Count) publishable text files checked."
