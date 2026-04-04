$ErrorActionPreference = 'SilentlyContinue'
$repo = Split-Path -Parent $PSScriptRoot
$watchScript = Join-Path $PSScriptRoot 'arya-sync-watch.ps1'

$existing = Get-CimInstance Win32_Process | Where-Object {
  $_.Name -match 'pwsh|powershell' -and $_.CommandLine -match 'arya-sync-watch\.ps1'
}

if (-not $existing) {
  Start-Process pwsh -WindowStyle Hidden -ArgumentList @('-NoProfile', '-File', $watchScript)
}

