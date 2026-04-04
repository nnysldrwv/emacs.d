param(
  [int]$DebounceSeconds = 8
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$script = Join-Path $PSScriptRoot 'arya-sync-run.ps1'
$watched = @(
  (Join-Path $repo 'init.el'),
  (Join-Path $repo 'README.md'),
  (Join-Path $repo '.gitignore'),
  (Join-Path $repo '.gitattributes'),
  (Join-Path $repo 'init.local.example.el'),
  (Join-Path $repo 'lisp')
)

$pending = $false
$lastEvent = Get-Date '2000-01-01'
$timer = New-Object Timers.Timer
$timer.Interval = 2000
$timer.AutoReset = $true

$action = {
  $global:pending = $true
  $global:lastEvent = Get-Date
}

$watchers = @()

function New-Watcher($path, $filter, $includeSubdirs) {
  $fsw = New-Object System.IO.FileSystemWatcher
  $fsw.Path = $path
  $fsw.Filter = $filter
  $fsw.IncludeSubdirectories = $includeSubdirs
  $fsw.NotifyFilter = [IO.NotifyFilters]'FileName, LastWrite, CreationTime, DirectoryName'
  $fsw.EnableRaisingEvents = $true
  Register-ObjectEvent $fsw Changed -Action $action | Out-Null
  Register-ObjectEvent $fsw Created -Action $action | Out-Null
  Register-ObjectEvent $fsw Deleted -Action $action | Out-Null
  Register-ObjectEvent $fsw Renamed -Action $action | Out-Null
  return $fsw
}

$watchers += New-Watcher $repo 'init.el' $false
$watchers += New-Watcher $repo 'README.md' $false
$watchers += New-Watcher $repo '.gitignore' $false
$watchers += New-Watcher $repo '.gitattributes' $false
$watchers += New-Watcher $repo 'init.local.example.el' $false
$watchers += New-Watcher (Join-Path $repo 'lisp') '*' $true
$watchers += New-Watcher (Join-Path $repo 'scripts') '*' $true

Register-ObjectEvent $timer Elapsed -Action {
  if ($global:pending) {
    $elapsed = (Get-Date) - $global:lastEvent
    if ($elapsed.TotalSeconds -ge $DebounceSeconds) {
      $global:pending = $false
      try {
        & pwsh -NoProfile -File $using:script sync | Out-Host
      }
      catch {
        Write-Host "arya-sync-watch failed: $($_.Exception.Message)"
      }
    }
  }
} | Out-Null

$timer.Start()
Write-Host "arya-sync-watch started for $repo"
while ($true) { Start-Sleep -Seconds 60 }

