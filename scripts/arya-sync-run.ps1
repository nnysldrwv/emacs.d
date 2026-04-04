param(
  [ValidateSet('pull','sync')]
  [string]$Mode = 'sync'
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$remote = 'origin'
$branch = 'main'
$hostName = [System.Net.Dns]::GetHostName()

Set-Location $repo

$null = git rev-parse --is-inside-work-tree 2>$null
if ($LASTEXITCODE -ne 0) { Write-Output 'SKIP: not a git repo'; exit 0 }

$null = git remote get-url $remote 2>$null
if ($LASTEXITCODE -ne 0) { Write-Output 'SKIP: remote not found'; exit 0 }

if ((Test-Path '.git/rebase-merge') -or (Test-Path '.git/rebase-apply') -or (Test-Path '.git/MERGE_HEAD')) {
  Write-Output 'SKIP: repo busy'
  exit 0
}

$conflicts = git diff --name-only --diff-filter=U
if ($conflicts) {
  Write-Output 'SKIP: conflicts present'
  exit 0
}

git pull --rebase --autostash $remote $branch

if ($Mode -eq 'pull') {
  Write-Output 'PULL_OK'
  exit 0
}

git add -- .gitattributes .gitignore README.md init.el init.local.example.el lisp scripts
$null = git diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
  Write-Output 'NO_CHANGES'
  exit 0
}

$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
git commit -m "sync: emacs auto-update $hostName $timestamp"
git pull --rebase --autostash $remote $branch
git push $remote $branch
Write-Output 'SYNC_OK'

